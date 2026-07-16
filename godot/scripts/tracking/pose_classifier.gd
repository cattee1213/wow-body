class_name PoseClassifier
extends RefCounted
## Single-hand pose labels from 21 landmarks.
## Pointing: index tip clearly leads; other fingers shorter / curled.
## Tuned for real Vision noise (curled fingers still have 2D length).

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
	point_score = score_point(sample)
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

	# Pointing first — never call a clear gun pose a fist.
	var pscore := score_point(sample)
	if pscore >= 0.45:
		return POSE_POINT

	if sample.is_fist or sample.fist_score >= 0.70:
		return POSE_FIST

	var ext: Array = _finger_extension(sample)
	var idx: float = float(ext[0])
	var mid: float = float(ext[1])
	var rng: float = float(ext[2])
	var pnk: float = float(ext[3])
	var others: float = (mid + rng + pnk) / 3.0
	var open := clampf((idx + mid + rng + pnk) * 0.28 + sample.openness * 0.25, 0.0, 1.0)
	if open >= 0.58 and sample.openness >= 0.32 and others >= 0.48 and pscore < 0.4:
		return POSE_OPEN
	if sample.openness >= 0.45 and mid >= 0.55 and idx >= 0.5 and pscore < 0.4:
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
		var ext := clampf((d_tip - 0.85) / 1.1, 0.0, 1.0)
		ext = maxf(ext, clampf((d_tip - d_pip) / 0.55, 0.0, 1.0))
		if straight < 1.35:
			ext = maxf(ext, 0.55)
		out.append(ext)
	return out


static func score_point(sample: HandTypes.HandSample) -> float:
	## Robust pointing score for Vision 2D: index tip leads all other tips.
	if sample == null or sample.landmarks.size() < 21:
		return 0.0
	if sample.is_fist or sample.fist_score >= 0.72:
		return 0.0

	var wrist: Vector2 = sample.landmarks[HandTypes.LM_WRIST]
	var palm: Vector2 = sample.palm
	var hs := maxf(sample.hand_size, 0.015)

	var tip_idx: Vector2 = sample.landmarks[HandTypes.LM_INDEX_TIP]
	var tip_mid: Vector2 = sample.landmarks[HandTypes.LM_MIDDLE_TIP]
	var tip_rng: Vector2 = sample.landmarks[HandTypes.LM_RING_TIP]
	var tip_pnk: Vector2 = sample.landmarks[HandTypes.LM_PINKY_TIP]
	var mcp_idx: Vector2 = sample.landmarks[HandTypes.LM_INDEX_MCP]
	var pip_idx: Vector2 = sample.landmarks[HandTypes.LM_INDEX_PIP]

	var d_idx := wrist.distance_to(tip_idx) / hs
	var d_mid := wrist.distance_to(tip_mid) / hs
	var d_rng := wrist.distance_to(tip_rng) / hs
	var d_pnk := wrist.distance_to(tip_pnk) / hs
	var d_other_max := maxf(d_mid, maxf(d_rng, d_pnk))

	# Core: index tip is the farthest fingertip from wrist (classic gun pose).
	var lead := clampf((d_idx - d_other_max) / 0.55, -0.4, 1.2)

	# Index finger fairly straight: tip far from MCP, PIP between.
	var idx_len := mcp_idx.distance_to(tip_idx) / hs
	var idx_reach := clampf((idx_len - 0.55) / 0.9, 0.0, 1.0)
	var mid_on_seg := 0.0
	var a := mcp_idx.distance_to(pip_idx) + pip_idx.distance_to(tip_idx)
	var b := mcp_idx.distance_to(tip_idx)
	if b > 0.001:
		mid_on_seg = clampf(1.35 - a / b, 0.0, 1.0)

	# Other tips near palm (curled) — softer than before for 2D noise.
	var curl_mid := clampf(1.15 - palm.distance_to(tip_mid) / hs * 0.85, 0.0, 1.0)
	var curl_rng := clampf(1.15 - palm.distance_to(tip_rng) / hs * 0.85, 0.0, 1.0)
	var curl_pnk := clampf(1.15 - palm.distance_to(tip_pnk) / hs * 0.85, 0.0, 1.0)
	var curl := (curl_mid + curl_rng + curl_pnk) / 3.0

	var score := lead * 0.42 + idx_reach * 0.28 + mid_on_seg * 0.12 + curl * 0.22

	# Soft open-palm penalty only when many tips are long (not when only index is long).
	if sample.openness > 0.55 and d_other_max > d_idx * 0.92:
		score -= (sample.openness - 0.55) * 1.1

	# Extension-array backup
	var ext: Array = _finger_extension(sample)
	var idx_e: float = float(ext[0])
	var others_e: float = (float(ext[1]) + float(ext[2]) + float(ext[3])) / 3.0
	if idx_e >= 0.55 and others_e <= 0.5:
		score = maxf(score, idx_e * 0.7 - others_e * 0.35)

	return clampf(score, 0.0, 1.0)
