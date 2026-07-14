class_name RitualDetector
extends RefCounted
## Two-hand ultimate rituals.
## blizzard: both open palms raised high
## firestorm: both open palms close together (合掌)

const RITUAL_NONE := &""
const CHANNEL_NEED := 0.95
const LOST_GRACE := 0.28

var active: StringName = RITUAL_NONE
var channel: float = 0.0
var _lost_t: float = 0.0
var debug_hint: String = ""


func reset() -> void:
	active = RITUAL_NONE
	channel = 0.0
	_lost_t = 0.0
	debug_hint = ""


class RitualResult:
	var ritual: StringName = RITUAL_NONE
	var channel: float = 0.0
	var cast: bool = false
	var lost: bool = false


func update(hands: Array, dt: float) -> RitualResult:
	var result := RitualResult.new()
	var detected := _detect(hands)
	debug_hint = str(detected)

	if detected != RITUAL_NONE:
		_lost_t = 0.0
		if active == RITUAL_NONE or active == detected:
			active = detected
			channel = minf(1.0, channel + dt / CHANNEL_NEED)
		else:
			active = detected
			channel = minf(0.35, channel * 0.4 + dt / CHANNEL_NEED)
	elif active != RITUAL_NONE:
		_lost_t += dt
		if _lost_t >= LOST_GRACE:
			result.lost = true
			active = RITUAL_NONE
			channel = 0.0
			_lost_t = 0.0
		else:
			channel = maxf(0.0, channel - dt * 0.35)
	else:
		channel = maxf(0.0, channel - dt * 1.2)

	result.ritual = active
	result.channel = channel
	if active != RITUAL_NONE and channel >= 0.999 and GameBus.can_cast_ultimate(active):
		result.cast = true
		result.ritual = active
		channel = 0.0
		active = RITUAL_NONE
		_lost_t = 0.0
	return result


func _detect(hands: Array) -> StringName:
	if hands.size() < 2:
		return RITUAL_NONE

	var a: HandTypes.HandSample = hands[0]
	var b: HandTypes.HandSample = hands[1]
	if hands.size() > 2:
		var sorted: Array = hands.duplicate()
		sorted.sort_custom(func(x, y): return x.openness > y.openness)
		a = sorted[0]
		b = sorted[1]

	var fist_a := a.is_fist or a.fist_score >= 0.58
	var fist_b := b.is_fist or b.fist_score >= 0.58
	var open_a := (not fist_a) and a.openness >= 0.22
	var open_b := (not fist_b) and b.openness >= 0.22

	if not (open_a and open_b):
		return RITUAL_NONE

	var palm_dist: float = a.palm.distance_to(b.palm)
	var avg_y: float = (a.palm.y + b.palm.y) * 0.5
	var both_high := a.palm.y < 0.42 and b.palm.y < 0.42 and avg_y < 0.38

	# Firestorm: palms close (合掌聚能)
	if palm_dist < 0.16:
		return GameBus.ULT_FIRESTORM

	# Blizzard: both raised open palms
	if both_high and palm_dist > 0.12:
		return GameBus.ULT_BLIZZARD

	return RITUAL_NONE
