class_name GestureController
extends RefCounted
## Basic cast: pointing finger only (locked school).
## Ultimate cast: two-hand rituals via RitualDetector (independent CDs on GameBus).

const OPEN_CHARGE := 0.10
const CAST_FORWARD := 0.55
const MIN_CAST_CHARGE := 0.12
const AUTO_CAST_CHARGE := 0.88
const CHARGE_RATE := 0.85
const CHARGE_RATE_KID := 0.95
const CHARGE_DECAY := 0.55
const COOLDOWN_SEC := 0.32
const COOLDOWN_SEC_KID := 0.45
const HISTORY_SEC := 0.16
const OPEN_SMOOTH := 14.0

var auto_fire: bool = true

var phase: StringName = &"idle"
var charge: float = 0.0
var openness: float = 0.0
## Locked basic school (set from select screen / GameBus.basic_spell).
var spell: StringName = GameBus.SPELL_FIRE
var cooldown: float = 0.0
var last_cast_at: float = 0.0

var ritual_channel: float = 0.0
var ritual_active: StringName = &""
var pose_label: StringName = PoseClassifier.POSE_UNKNOWN

var debug_forward: float = 0.0
var debug_hands: int = 0
var debug_fist: bool = false
var debug_fist_score: float = 0.0
var debug_ritual: String = ""

var _histories: Dictionary = {}
var _fist_detectors: Dictionary = {}
var _pose_classifiers: Dictionary = {}
var _ritual := RitualDetector.new()


class UpdateResult:
	var cast: bool = false
	var cast_hand: HandTypes.HandSample = null
	var charge_used: float = 0.0
	var spell: StringName = GameBus.SPELL_FIRE
	var ultimate_cast: bool = false
	var ultimate: StringName = &""
	var ritual_channel: float = 0.0
	var ritual_active: StringName = &""
	var pose: StringName = PoseClassifier.POSE_UNKNOWN


func reset() -> void:
	phase = &"idle"
	charge = 0.0
	openness = 0.0
	cooldown = 0.0
	ritual_channel = 0.0
	ritual_active = &""
	pose_label = PoseClassifier.POSE_UNKNOWN
	_histories.clear()
	_fist_detectors.clear()
	_pose_classifiers.clear()
	_ritual.reset()
	spell = GameBus.basic_spell


func update(hands: Array, dt: float, now_sec: float) -> UpdateResult:
	var result := UpdateResult.new()
	result.spell = spell
	GameBus.tick_cooldowns(dt)

	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - dt)
		if cooldown == 0.0 and phase == &"cooldown":
			phase = &"charging" if charge > 0.05 else &"idle"

	# Fist detectors + pose classifiers per hand
	for h in hands:
		var sample: HandTypes.HandSample = h
		var key := _hand_key(sample)
		if not _fist_detectors.has(key):
			_fist_detectors[key] = FistDetector.new()
		if not _pose_classifiers.has(key):
			_pose_classifiers[key] = PoseClassifier.new()
		var det: FistDetector = _fist_detectors[key]
		sample.is_fist = det.update(sample.landmarks, sample.openness, sample.hand_size)
		sample.fist_score = det.get_last_score()
		var pc: PoseClassifier = _pose_classifiers[key]
		pc.update(sample)

	_prune_dead_hands(hands)
	debug_hands = hands.size()

	if hands.is_empty():
		openness = maxf(0.0, openness - dt * 3.0)
		charge = maxf(0.0, charge - CHARGE_DECAY * dt)
		if phase != &"cooldown":
			phase = &"charging" if charge > 0.05 else &"idle"
		debug_forward = 0.0
		debug_fist = false
		debug_fist_score = 0.0
		pose_label = PoseClassifier.POSE_UNKNOWN
		result.pose = pose_label
		var empty_r := _ritual.update([], dt)
		ritual_channel = empty_r.channel
		ritual_active = empty_r.ritual
		result.ritual_channel = ritual_channel
		result.ritual_active = ritual_active
		return result

	var any_fist := false
	var best_fist_score := 0.0
	for h in hands:
		if h.is_fist:
			any_fist = true
		best_fist_score = maxf(best_fist_score, h.fist_score)
	debug_fist = any_fist
	debug_fist_score = best_fist_score

	# --- Ultimate ritual (priority over basic) ---
	var ritual_r: RitualDetector.RitualResult = _ritual.update(hands, dt)
	ritual_channel = ritual_r.channel
	ritual_active = ritual_r.ritual
	result.ritual_channel = ritual_channel
	result.ritual_active = ritual_active
	debug_ritual = _ritual.debug_hint

	if ritual_r.cast and GameBus.can_cast_ultimate(ritual_r.ritual):
		result.ultimate_cast = true
		result.ultimate = ritual_r.ritual
		charge = 0.0
		phase = &"cooldown"
		cooldown = 0.55
		return result

	# While channeling a ritual, pause basic charging
	if ritual_active != &"" and ritual_channel > 0.08:
		charge = maxf(0.0, charge - CHARGE_DECAY * 1.5 * dt)
		if phase != &"cooldown":
			phase = &"idle" if charge <= 0.02 else &"charging"
		result.pose = pose_label
		debug_forward = 0.0
		return result

	# --- Basic: pointing hand only ---
	var point_hand := _best_point_hand(hands)
	if point_hand:
		pose_label = PoseClassifier.POSE_POINT
	else:
		# fall back to most open non-fist for display
		pose_label = PoseClassifier.POSE_UNKNOWN
		for h in hands:
			var key2 := _hand_key(h)
			if _pose_classifiers.has(key2):
				var lb: StringName = (_pose_classifiers[key2] as PoseClassifier).get_label()
				if lb != PoseClassifier.POSE_UNKNOWN:
					pose_label = lb
					break
	result.pose = pose_label

	var cast_hand: HandTypes.HandSample = point_hand
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
		var pointing_ok := (
			PoseClassifier.score_point(cast_hand) >= 0.42
			or (auto_fire and cast_hand.openness >= 0.28 and not cast_hand.is_fist)
		)
		if pointing_ok and phase != &"cooldown":
			phase = &"charging"
			var fill := 0.55 + PoseClassifier.score_point(cast_hand) * 0.9
			if auto_fire:
				fill = maxf(fill, 0.85)
			charge = minf(1.0, charge + fill * rate * dt)
		elif phase != &"cooldown":
			charge = maxf(0.0, charge - CHARGE_DECAY * dt)
			if charge <= 0.02:
				phase = &"idle"

		var can_release := phase != &"cooldown" and pointing_ok
		var push_cast := can_release and charge >= MIN_CAST_CHARGE and forward >= CAST_FORWARD
		var auto_cast := auto_fire and can_release and charge >= AUTO_CAST_CHARGE

		if push_cast or auto_cast:
			result.cast = true
			result.cast_hand = cast_hand
			result.charge_used = charge
			result.spell = spell
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


func force_ultimate(ult: StringName) -> UpdateResult:
	var r := UpdateResult.new()
	if not GameBus.can_cast_ultimate(ult):
		return r
	r.ultimate_cast = true
	r.ultimate = ult
	r.spell = spell
	charge = 0.0
	phase = &"cooldown"
	cooldown = 0.4
	_ritual.reset()
	ritual_channel = 0.0
	ritual_active = &""
	return r


func _best_point_hand(hands: Array) -> HandTypes.HandSample:
	var best: HandTypes.HandSample = null
	var best_score := 0.38
	for h in hands:
		if h.is_fist:
			continue
		var key := _hand_key(h)
		var label := PoseClassifier.POSE_UNKNOWN
		if _pose_classifiers.has(key):
			label = (_pose_classifiers[key] as PoseClassifier).get_label()
		var score := PoseClassifier.score_point(h)
		if label == PoseClassifier.POSE_POINT:
			score = maxf(score, 0.55)
		# Also accept strong raw point even before confirm
		if score > best_score:
			best_score = score
			best = h
	# Mouse/synthetic fallback: open palm counts as aim hand in auto_fire
	if best == null and auto_fire:
		for h in hands:
			if not h.is_fist and h.openness >= 0.32:
				return h
	return best


func _prune_dead_hands(hands: Array) -> void:
	var live: Dictionary = {}
	for h in hands:
		live[_hand_key(h)] = true
	for k in _histories.keys():
		if not live.has(k):
			_histories.erase(k)
	for k in _fist_detectors.keys():
		if not live.has(k):
			_fist_detectors.erase(k)
	for k in _pose_classifiers.keys():
		if not live.has(k):
			_pose_classifiers.erase(k)


func _hand_key(h: HandTypes.HandSample) -> String:
	return h.handedness if h.handedness != "" else "Unknown"
