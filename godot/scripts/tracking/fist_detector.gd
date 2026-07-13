class_name FistDetector
extends RefCounted
## Optimized fist recognition with multi-feature scoring + temporal hysteresis.
##
## Improvements vs simple openness threshold:
## 1) Finger curl ratio (tip vs PIP distance to wrist)
## 2) Tip cluster compactness (fist tips bunch together)
## 3) Thumb tuck (thumb tip near index MCP)
## 4) Palm openness inverse
## 5) Enter/exit hysteresis + multi-frame confirmation (anti flicker)

const ENTER_SCORE := 0.62
const EXIT_SCORE := 0.42
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
		# Fallback: openness-only with soft curve
		return clampf(1.0 - openness * 1.35, 0.0, 1.0)

	var wrist := landmarks[HandTypes.LM_WRIST]
	var index_mcp := landmarks[HandTypes.LM_INDEX_MCP]
	var hs := maxf(hand_size, 0.012)

	# --- 1) Curl: each non-thumb fingertip closer to wrist than its PIP ---
	var curl := 0.0
	for i in HandTypes.FINGER_PIPS.size():
		var tip_i: int = HandTypes.FINGER_TIPS[i + 1] # index..pinky tips
		var pip_i: int = HandTypes.FINGER_PIPS[i]
		var tip: Vector2 = landmarks[tip_i]
		var pip: Vector2 = landmarks[pip_i]
		var d_tip := wrist.distance_to(tip)
		var d_pip := wrist.distance_to(pip)
		# Strongly curled when tip is not much farther than PIP
		var ratio := d_tip / maxf(d_pip, 0.001)
		curl += clampf(1.25 - ratio, 0.0, 1.0)
	curl /= float(HandTypes.FINGER_PIPS.size())

	# --- 2) Tip cluster: non-thumb tips near each other ---
	var tips: Array[Vector2] = []
	for i in range(1, HandTypes.FINGER_TIPS.size()):
		tips.append(landmarks[HandTypes.FINGER_TIPS[i]])
	var centroid := Vector2.ZERO
	for t in tips:
		centroid += t
	centroid /= float(tips.size())
	var spread := 0.0
	for t in tips:
		spread += centroid.distance_to(t)
	spread = (spread / float(tips.size())) / hs
	var compact := clampf(1.15 - spread * 0.85, 0.0, 1.0)

	# --- 3) Thumb tuck toward index MCP ---
	var thumb := landmarks[HandTypes.LM_THUMB_TIP]
	var thumb_d := thumb.distance_to(index_mcp) / hs
	var thumb_tuck := clampf(1.2 - thumb_d * 0.75, 0.0, 1.0)

	# --- 4) Openness inverse (soft) ---
	var open_inv := clampf(1.0 - openness * 1.25, 0.0, 1.0)

	# Weighted fusion — curl + compact dominate
	var score := curl * 0.40 + compact * 0.28 + thumb_tuck * 0.17 + open_inv * 0.15
	return clampf(score, 0.0, 1.0)
