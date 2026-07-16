class_name FistDetector
extends RefCounted
## Fist recognition with multi-feature scoring + hysteresis.
## Critical: pointing (index out, others curled) must NOT score as fist.

const ENTER_SCORE := 0.68
const EXIT_SCORE := 0.45
const CONFIRM_FRAMES := 3
const RELEASE_FRAMES := 2

var _fist_frames: int = 0
var _open_frames: int = 0
var _is_fist: bool = false
var _last_score: float = 0.0


func reset() -> void:
	_fist_frames = 0
	_open_frames = 0
	_is_fist = false
	_last_score = 0.0


func get_last_score() -> float:
	return _last_score


func is_fist() -> bool:
	return _is_fist


## Force-clear latch (e.g. when pointing is clearly detected).
func force_release() -> void:
	_is_fist = false
	_fist_frames = 0
	_open_frames = 0


## Evaluate one hand. `landmarks` must be 21 points in normalized image space.
func update(landmarks: PackedVector2Array, openness: float, hand_size: float) -> bool:
	var score := score_fist(landmarks, openness, hand_size)
	_last_score = score

	if _is_fist:
		if score < EXIT_SCORE:
			_open_frames += 1
			_fist_frames = 0
			if _open_frames >= RELEASE_FRAMES:
				_is_fist = false
				_open_frames = 0
		else:
			_open_frames = 0
	else:
		if score >= ENTER_SCORE:
			_fist_frames += 1
			_open_frames = 0
			if _fist_frames >= CONFIRM_FRAMES:
				_is_fist = true
				_fist_frames = 0
		else:
			_fist_frames = 0

	return _is_fist


static func score_fist(landmarks: PackedVector2Array, openness: float, hand_size: float) -> float:
	if landmarks.size() < 21:
		return clampf(1.0 - openness * 1.35, 0.0, 1.0)

	var wrist := landmarks[HandTypes.LM_WRIST]
	var index_mcp := landmarks[HandTypes.LM_INDEX_MCP]
	var hs := maxf(hand_size, 0.012)

	var tip_idx := landmarks[HandTypes.LM_INDEX_TIP]
	var tip_mid := landmarks[HandTypes.LM_MIDDLE_TIP]
	var tip_rng := landmarks[HandTypes.LM_RING_TIP]
	var tip_pnk := landmarks[HandTypes.LM_PINKY_TIP]

	var d_idx := wrist.distance_to(tip_idx) / hs
	var d_mid := wrist.distance_to(tip_mid) / hs
	var d_rng := wrist.distance_to(tip_rng) / hs
	var d_pnk := wrist.distance_to(tip_pnk) / hs
	var d_other_max := maxf(d_mid, maxf(d_rng, d_pnk))

	# --- Pointing veto: index tip clearly leads other tips ---
	# This is the gun pose users use to shoot; must never latch as fist.
	if d_idx > d_other_max * 1.10 and d_idx > 1.15:
		return clampf(0.15 + (1.0 - openness) * 0.12, 0.0, 0.35)

	# Per-finger curl (tip not much farther than PIP)
	var curls: Array[float] = []
	for i in HandTypes.FINGER_PIPS.size():
		var tip_i: int = HandTypes.FINGER_TIPS[i + 1]
		var pip_i: int = HandTypes.FINGER_PIPS[i]
		var tip: Vector2 = landmarks[tip_i]
		var pip: Vector2 = landmarks[pip_i]
		var d_tip := wrist.distance_to(tip)
		var d_pip := wrist.distance_to(pip)
		var ratio := d_tip / maxf(d_pip, 0.001)
		curls.append(clampf(1.25 - ratio, 0.0, 1.0))

	var index_curl: float = curls[0]
	var other_curl := (curls[1] + curls[2] + curls[3]) / 3.0

	# Pointing-like: others curled, index open → not a fist
	if index_curl < 0.40 and other_curl >= 0.45:
		return clampf(other_curl * 0.22, 0.0, 0.38)

	# True fist needs index curled too
	var curl := index_curl * 0.34 + other_curl * 0.66

	# Tip cluster (all non-thumb tips)
	var tips: Array[Vector2] = [tip_idx, tip_mid, tip_rng, tip_pnk]
	var centroid := Vector2.ZERO
	for t in tips:
		centroid += t
	centroid /= float(tips.size())
	var spread := 0.0
	for t in tips:
		spread += centroid.distance_to(t)
	spread = (spread / float(tips.size())) / hs
	var compact := clampf(1.15 - spread * 0.85, 0.0, 1.0)
	# If index tip is an outlier far from cluster, reduce compact (pointing)
	var idx_from_c := centroid.distance_to(tip_idx) / hs
	if idx_from_c > 0.55:
		compact *= 0.35

	var thumb := landmarks[HandTypes.LM_THUMB_TIP]
	var thumb_d := thumb.distance_to(index_mcp) / hs
	var thumb_tuck := clampf(1.2 - thumb_d * 0.75, 0.0, 1.0)

	var open_inv := clampf(1.0 - openness * 1.25, 0.0, 1.0)

	var score := curl * 0.48 + compact * 0.24 + thumb_tuck * 0.14 + open_inv * 0.14
	# Require meaningful index curl for high scores
	if index_curl < 0.45:
		score *= 0.55
	return clampf(score, 0.0, 1.0)
