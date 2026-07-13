class_name GestureController
extends RefCounted
## Charge / cast / fist spell switch.
## Kid mode (auto_fire): aim with pointer, auto charge + auto shoot — no push gesture needed.

const OPEN_CHARGE := 0.14
const CAST_FORWARD := 0.55
const MIN_CAST_CHARGE := 0.12
## Auto-fire releases around this charge (kids don't need a push).
const AUTO_CAST_CHARGE := 0.42
const CHARGE_RATE := 0.85
const CHARGE_RATE_KID := 1.55
const CHARGE_DECAY := 0.55
const COOLDOWN_SEC := 0.32
const COOLDOWN_SEC_KID := 0.38
const FIST_SWITCH_COOLDOWN_SEC := 0.55
const HISTORY_SEC := 0.16
const OPEN_SMOOTH := 14.0

## When true: open palm auto-fills and auto-casts (kid-friendly).
var auto_fire: bool = true

var phase: StringName = &"idle"
var charge: float = 0.0
var openness: float = 0.0
var spell: StringName = GameBus.SPELL_FIRE
var cooldown: float = 0.0
var fist_cooldown: float = 0.0
var was_fist: bool = false
var last_cast_at: float = 0.0

var debug_forward: float = 0.0
var debug_hands: int = 0
var debug_fist: bool = false
var debug_fist_score: float = 0.0

## hand_key -> Array of {t, hand_size, depth}
var _histories: Dictionary = {}
## hand_key -> FistDetector
var _fist_detectors: Dictionary = {}


class UpdateResult:
	var cast: bool = false
	var cast_hand: HandTypes.HandSample = null
	var charge_used: float = 0.0
	var spell_switched: bool = false
	var spell: StringName = GameBus.SPELL_FIRE


func reset() -> void:
	phase = &"idle"
	charge = 0.0
	openness = 0.0
	cooldown = 0.0
	fist_cooldown = 0.0
	was_fist = false
	_histories.clear()
	_fist_detectors.clear()


func update(hands: Array, dt: float, now_sec: float) -> UpdateResult:
	var result := UpdateResult.new()
	result.spell = spell

	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - dt)
		if cooldown == 0.0 and phase == &"cooldown":
			phase = &"charging" if charge > 0.05 else &"idle"
	if fist_cooldown > 0.0:
		fist_cooldown = maxf(0.0, fist_cooldown - dt)

	# Apply optimized fist detector per hand
	for h in hands:
		var sample: HandTypes.HandSample = h
		var key := _hand_key(sample)
		if not _fist_detectors.has(key):
			_fist_detectors[key] = FistDetector.new()
		var det: FistDetector = _fist_detectors[key]
		sample.is_fist = det.update(sample.landmarks, sample.openness, sample.hand_size)
		sample.fist_score = det.get_last_score()

	# prune
	var live: Dictionary = {}
	for h in hands:
		live[_hand_key(h)] = true
	for k in _histories.keys():
		if not live.has(k):
			_histories.erase(k)
	for k in _fist_detectors.keys():
		if not live.has(k):
			_fist_detectors.erase(k)

	debug_hands = hands.size()

	if hands.is_empty():
		openness = maxf(0.0, openness - dt * 3.0)
		charge = maxf(0.0, charge - CHARGE_DECAY * dt)
		if phase != &"cooldown":
			phase = &"charging" if charge > 0.05 else &"idle"
		was_fist = false
		debug_forward = 0.0
		debug_fist = false
		debug_fist_score = 0.0
		return result

	var any_fist := false
	var best_fist_score := 0.0
	for h in hands:
		if h.is_fist:
			any_fist = true
		best_fist_score = maxf(best_fist_score, h.fist_score)
	debug_fist = any_fist
	debug_fist_score = best_fist_score

	# Fist edge → switch spell (optimized detector already de-bounced frames)
	if any_fist and not was_fist and fist_cooldown <= 0.0 and phase != &"cooldown":
		spell = GameBus.next_spell(spell)
		fist_cooldown = FIST_SWITCH_COOLDOWN_SEC
		result.spell_switched = true
		result.spell = spell
		charge = maxf(0.0, charge * 0.35)
		GameBus.spell_changed.emit(spell)
	was_fist = any_fist

	var open_hands: Array = []
	for h in hands:
		if not h.is_fist:
			open_hands.append(h)
	open_hands.sort_custom(func(a, b): return a.openness > b.openness)
	var cast_hand: HandTypes.HandSample = open_hands[0] if not open_hands.is_empty() else null
	var display: HandTypes.HandSample = cast_hand if cast_hand else hands[0]

	var k := 1.0 - exp(-OPEN_SMOOTH * dt)
	openness += (display.openness - openness) * k

	var forward := 0.0
	if cast_hand:
		var key := _hand_key(cast_hand)
		if not _histories.has(key):
			_histories[key] = []
		var hist: Array = _histories[key]
		hist.append({
			"t": cast_hand.timestamp_ms * 0.001,
			"hand_size": cast_hand.hand_size,
			"depth": cast_hand.depth,
		})
		var cutoff := cast_hand.timestamp_ms * 0.001 - HISTORY_SEC
		while hist.size() > 1 and hist[0]["t"] < cutoff:
			hist.pop_front()

		if hist.size() >= 2:
			var oldest: Dictionary = hist[0]
			var newest: Dictionary = hist[hist.size() - 1]
			var elapsed: float = maxf(newest["t"] - oldest["t"], 0.016)
			var size_speed: float = (newest["hand_size"] - oldest["hand_size"]) / elapsed
			var depth_speed: float = (oldest["depth"] - newest["depth"]) / elapsed
			forward = maxf(0.0, maxf(size_speed * 6.5, depth_speed * 3.5))

		var rate := CHARGE_RATE_KID if auto_fire else CHARGE_RATE
		if cast_hand.openness >= OPEN_CHARGE and phase != &"cooldown":
			phase = &"charging"
			var fill := 0.15 + cast_hand.openness * cast_hand.openness * 1.35
			# Kid mode: always fill steadily even if openness is moderate
			if auto_fire:
				fill = maxf(fill, 0.85)
			charge = minf(1.0, charge + fill * rate * dt)
		elif phase != &"cooldown":
			charge = maxf(0.0, charge - CHARGE_DECAY * dt)
			if charge <= 0.02:
				phase = &"idle"

		var can_release := (
			phase != &"cooldown"
			and cast_hand.openness >= OPEN_CHARGE
		)
		var push_cast := can_release and charge >= MIN_CAST_CHARGE and forward >= CAST_FORWARD
		var auto_cast := auto_fire and can_release and charge >= AUTO_CAST_CHARGE

		if push_cast or auto_cast:
			result.cast = true
			result.cast_hand = cast_hand
			result.charge_used = charge
			last_cast_at = now_sec
			phase = &"cooldown"
			cooldown = COOLDOWN_SEC_KID if auto_fire else COOLDOWN_SEC
			charge = 0.0
	else:
		charge = maxf(0.0, charge - CHARGE_DECAY * 1.2 * dt)
		if phase != &"cooldown" and charge <= 0.02:
			phase = &"idle"

	debug_forward = forward
	return result


func force_cast_from_input(power: float = 0.7) -> UpdateResult:
	var r := UpdateResult.new()
	r.cast = true
	r.charge_used = maxf(power, charge)
	r.spell = spell
	charge = 0.0
	phase = &"cooldown"
	cooldown = COOLDOWN_SEC_KID if auto_fire else COOLDOWN_SEC
	return r


func _hand_key(h: HandTypes.HandSample) -> String:
	return h.handedness if h.handedness != "" else "Unknown"
