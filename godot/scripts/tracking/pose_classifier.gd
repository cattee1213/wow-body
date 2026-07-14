class_name PoseClassifier
extends RefCounted
## Single-hand pose labels from 21 landmarks.
## Labels: open | point | fist | unknown

const POSE_OPEN := &"open"
const POSE_POINT := &"point"
const POSE_FIST := &"fist"
const POSE_UNKNOWN := &"unknown"

const CONFIRM_FRAMES := 3

var _label: StringName = POSE_UNKNOWN
var _pending: StringName = POSE_UNKNOWN
var _frames: int = 0
var last_raw: StringName = POSE_UNKNOWN
var point_score: float = 0.0
var open_score: float = 0.0


func reset() -> void:
	_label = POSE_UNKNOWN
	_pending = POSE_UNKNOWN
	_frames = 0
	last_raw = POSE_UNKNOWN
	point_score = 0.0
	open_score = 0.0


func get_label() -> StringName:
	return _label


func update(sample: HandTypes.HandSample) -> StringName:
	var raw := classify_raw(sample)
	last_raw = raw
	if raw == _pending:
		_frames += 1
	else:
		_pending = raw
		_frames = 1
	if _frames >= CONFIRM_FRAMES:
		_label = _pending
	return _label


static func classify_raw(sample: HandTypes.HandSample) -> StringName:
	if sample == null or sample.landmarks.size() < 21:
		return POSE_UNKNOWN
	if sample.is_fist or sample.fist_score >= 0.62:
		return POSE_FIST

	var ext := _finger_extension(sample)
	# index, middle, ring, pinky
	var idx: float = ext[0]
	var mid: float = ext[1]
	var rng: float = ext[2]
	var pnk: float = ext[3]
	var others := (mid + rng + pnk) / 3.0

	# Pointing: index out, other three curled
	var point := clampf(idx * 1.15 - others * 0.95, 0.0, 1.0)
	# Open palm: most fingers extended
	var open := clampf((idx + mid + rng + pnk) * 0.28 + sample.openness * 0.25, 0.0, 1.0)

	if point >= 0.48 and idx >= 0.55 and others <= 0.48:
		return POSE_POINT
	if open >= 0.55 and sample.openness >= 0.22 and others >= 0.4:
		return POSE_OPEN
	if sample.openness >= 0.35 and idx >= 0.5 and mid >= 0.45:
		return POSE_OPEN
	return POSE_UNKNOWN


static func _finger_extension(sample: HandTypes.HandSample) -> Array:
	## Returns [index, middle, ring, pinky] extension 0..1.
	var wrist: Vector2 = sample.landmarks[HandTypes.LM_WRIST]
	var hs := maxf(sample.hand_size, 0.015)
	var out: Array = []
	for i in HandTypes.FINGER_PIPS.size():
		var tip_i: int = HandTypes.FINGER_TIPS[i + 1]
		var pip_i: int = HandTypes.FINGER_PIPS[i]
		var mcp_i: int = HandTypes.FINGER_MCPS[i]
		var tip: Vector2 = sample.landmarks[tip_i]
		var pip: Vector2 = sample.landmarks[pip_i]
		var mcp: Vector2 = sample.landmarks[mcp_i]
		var d_tip := wrist.distance_to(tip) / hs
		var d_pip := wrist.distance_to(pip) / hs
		var chain := mcp.distance_to(pip) + pip.distance_to(tip)
		var straight := chain / maxf(mcp.distance_to(tip), 0.001)
		# Extended when tip far from wrist and finger nearly straight
		var ext := clampf((d_tip - 0.85) / 1.1, 0.0, 1.0)
		ext = maxf(ext, clampf((d_tip - d_pip) / 0.55, 0.0, 1.0))
		if straight < 1.35:
			ext = maxf(ext, 0.55)
		out.append(ext)
	return out


static func score_point(sample: HandTypes.HandSample) -> float:
	if sample == null or sample.landmarks.size() < 21:
		return 0.0
	if sample.is_fist:
		return 0.0
	var ext := _finger_extension(sample)
	var idx: float = ext[0]
	var others := (ext[1] + ext[2] + ext[3]) / 3.0
	return clampf(idx * 1.2 - others * 1.0, 0.0, 1.0)
