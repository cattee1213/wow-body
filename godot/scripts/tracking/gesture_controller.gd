class_name GestureController
extends RefCounted
## Basic cast: pointing finger → instant shot (no charge).
## Ultimate cast: two-hand rituals via RitualDetector (independent CDs on GameBus).

## Slow base fire rate — upgrades raise it via fire_rate_mult.
const FIRE_COOLDOWN_SEC := 0.82
const OPEN_SMOOTH := 14.0
const INSTANT_POWER := 0.75
## Point threshold — tuned so clear index-up poses fire reliably.
const POINT_FIRE_SCORE := 0.48

var phase: StringName = &"idle"
## Kept for HUD/palm compatibility; no longer fills for basic shots.
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
			phase = &"idle"

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
		# Pointing overrides fist: index-out gun pose must never block basic fire.
		var pscore := PoseClassifier.score_point(sample)
		if pscore >= 0.42 and sample.is_fist:
			det.force_release()
			sample.is_fist = false
			sample.fist_score = minf(sample.fist_score, 0.35)
		var pc: PoseClassifier = _pose_classifiers[key]
		pc.update(sample)

	_prune_dead_hands(hands)
	debug_hands = hands.size()
	debug_forward = 0.0

	if hands.is_empty():
		openness = maxf(0.0, openness - dt * 3.0)
		charge = 0.0
		if phase != &"cooldown":
			phase = &"idle"
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
		cooldown = 0.45
		return result

	# While channeling a ritual, pause basic fire
	if ritual_active != &"" and ritual_channel > 0.08:
		charge = ritual_channel
		if phase != &"cooldown":
			phase = &"idle"
		result.pose = pose_label
		return result

	# --- Basic: point → instant fire on cooldown ---
	var point_hand := _best_point_hand(hands)
	if point_hand:
		pose_label = PoseClassifier.POSE_POINT
	else:
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

	if cast_hand and phase != &"cooldown" and cooldown <= 0.0:
		var pscore := PoseClassifier.score_point(cast_hand)
		var label_point := false
		var keyp := _hand_key(cast_hand)
		if _pose_classifiers.has(keyp):
			label_point = (_pose_classifiers[keyp] as PoseClassifier).get_label() == PoseClassifier.POSE_POINT
		# Only true pointing for body. Synthetic mouse hand (all conf=1) may use open aim.
		var pointing_ok := pscore >= POINT_FIRE_SCORE or (label_point and pscore >= 0.42)
		if not pointing_ok and _is_synthetic_hand(cast_hand) and cast_hand.openness >= 0.7:
			pointing_ok = true
		if pointing_ok:
			result.cast = true
			result.cast_hand = cast_hand
			result.charge_used = INSTANT_POWER
			result.spell = spell
			last_cast_at = now_sec
			phase = &"cooldown"
			cooldown = _shot_cooldown()
			charge = 0.0
		else:
			charge = 0.0
	else:
		if cast_hand and cooldown <= 0.0 and PoseClassifier.score_point(cast_hand) >= POINT_FIRE_SCORE:
			charge = 0.35
		else:
			charge = 0.0

	return result


func _shot_cooldown() -> float:
	return GameBus.upgrades.fire_cooldown(FIRE_COOLDOWN_SEC)


func force_cast_from_input(power: float = INSTANT_POWER) -> UpdateResult:
	var r := UpdateResult.new()
	if phase == &"cooldown" and cooldown > 0.0:
		return r
	r.cast = true
	r.charge_used = clampf(power, 0.35, 1.0)
	r.spell = spell
	charge = 0.0
	phase = &"cooldown"
	cooldown = _shot_cooldown()
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
	cooldown = 0.35
	_ritual.reset()
	ritual_channel = 0.0
	ritual_active = &""
	return r


func _best_point_hand(hands: Array) -> HandTypes.HandSample:
	var best: HandTypes.HandSample = null
	var best_score := 0.36
	for h in hands:
		var key := _hand_key(h)
		var label := PoseClassifier.POSE_UNKNOWN
		if _pose_classifiers.has(key):
			label = (_pose_classifiers[key] as PoseClassifier).get_label()
		var score := PoseClassifier.score_point(h)
		# Do not skip on is_fist if point score is good (already cleared above, belt+suspenders).
		if h.is_fist and score < 0.42:
			continue
		if label == PoseClassifier.POSE_POINT:
			score = maxf(score, 0.52)
		if score > best_score:
			best_score = score
			best = h
	if best == null:
		for h in hands:
			if not h.is_fist and _is_synthetic_hand(h) and h.openness >= 0.7:
				return h
	return best


func _is_synthetic_hand(h: HandTypes.HandSample) -> bool:
	## Mouse-fallback hands set joint_conf all to 1.0; real Vision conf is mixed.
	if h == null or h.joint_conf.size() < 21:
		return false
	var sum := 0.0
	for i in 21:
		sum += h.joint_conf[i]
	return sum >= 20.5


func _prune_dead_hands(hands: Array) -> void:
	var live: Dictionary = {}
	for h in hands:
		live[_hand_key(h)] = true
	for k in _fist_detectors.keys():
		if not live.has(k):
			_fist_detectors.erase(k)
	for k in _pose_classifiers.keys():
		if not live.has(k):
			_pose_classifiers.erase(k)


func _hand_key(h: HandTypes.HandSample) -> String:
	return h.handedness if h.handedness != "" else "Unknown"
