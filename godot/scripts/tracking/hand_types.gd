class_name HandTypes
extends RefCounted
## Shared hand tracking data structures.

const LM_WRIST := 0
const LM_THUMB_TIP := 4
const LM_INDEX_TIP := 8
const LM_MIDDLE_TIP := 12
const LM_RING_TIP := 16
const LM_PINKY_TIP := 20
const LM_INDEX_MCP := 5
const LM_MIDDLE_MCP := 9
const LM_RING_MCP := 13
const LM_PINKY_MCP := 17
const LM_INDEX_PIP := 6
const LM_MIDDLE_PIP := 10
const LM_RING_PIP := 14
const LM_PINKY_PIP := 18

const FINGER_TIPS: Array[int] = [LM_THUMB_TIP, LM_INDEX_TIP, LM_MIDDLE_TIP, LM_RING_TIP, LM_PINKY_TIP]
const FINGER_PIPS: Array[int] = [LM_INDEX_PIP, LM_MIDDLE_PIP, LM_RING_PIP, LM_PINKY_PIP]
const FINGER_MCPS: Array[int] = [LM_INDEX_MCP, LM_MIDDLE_MCP, LM_RING_MCP, LM_PINKY_MCP]

## Connections for skeleton draw (MediaPipe topology).
const CONNECTIONS := [
	[0, 1], [1, 2], [2, 3], [3, 4],
	[0, 5], [5, 6], [6, 7], [7, 8],
	[0, 9], [9, 10], [10, 11], [11, 12],
	[0, 13], [13, 14], [14, 15], [15, 16],
	[0, 17], [17, 18], [18, 19], [19, 20],
	[5, 9], [9, 13], [13, 17],
]


class HandSample:
	var palm: Vector2 = Vector2(0.5, 0.6)
	var openness: float = 0.0
	var is_fist: bool = false
	var fist_score: float = 0.0
	var hand_size: float = 0.05
	var depth: float = 0.0
	## 21 normalized points (0..1), selfie-mirrored.
	var landmarks: PackedVector2Array = PackedVector2Array()
	## Per-joint confidence 0..1 (0 = invalid / do not draw).
	var joint_conf: PackedFloat32Array = PackedFloat32Array()
	var handedness: String = "Unknown"
	var timestamp_ms: float = 0.0
	var confidence: float = 1.0

	func is_joint_valid(i: int, min_conf: float = 0.12) -> bool:
		if i < 0 or i >= landmarks.size():
			return false
		if joint_conf.size() == landmarks.size():
			return joint_conf[i] >= min_conf
		# Synthetic hands have no conf array — treat as valid.
		return true
