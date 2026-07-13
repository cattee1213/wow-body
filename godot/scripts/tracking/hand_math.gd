class_name HandMath
extends RefCounted
## Landmark → HandSample conversion (selfie-mirrored).


static func landmarks_to_sample(
	raw: PackedVector3Array,
	timestamp_ms: float,
	handedness: String = "Unknown",
	mirror_x: bool = true,
) -> HandTypes.HandSample:
	var sample := HandTypes.HandSample.new()
	sample.timestamp_ms = timestamp_ms
	sample.landmarks = PackedVector2Array()
	sample.landmarks.resize(21)

	if raw.size() < 21:
		return sample

	for i in 21:
		var p := raw[i]
		var x := (1.0 - p.x) if mirror_x else p.x
		sample.landmarks[i] = Vector2(x, p.y)

	# After mirror, swap handedness label for user-facing side
	if mirror_x:
		if handedness == "Left":
			sample.handedness = "Right"
		elif handedness == "Right":
			sample.handedness = "Left"
		else:
			sample.handedness = handedness
	else:
		sample.handedness = handedness

	var wrist := sample.landmarks[HandTypes.LM_WRIST]
	var mid_mcp := sample.landmarks[HandTypes.LM_MIDDLE_MCP]
	var idx_mcp := sample.landmarks[HandTypes.LM_INDEX_MCP]
	var pnk_mcp := sample.landmarks[HandTypes.LM_PINKY_MCP]

	sample.palm = (wrist + mid_mcp + idx_mcp + pnk_mcp) * 0.25
	sample.hand_size = maxf(wrist.distance_to(mid_mcp), idx_mcp.distance_to(pnk_mcp))
	sample.hand_size = maxf(sample.hand_size, 0.015)
	sample.depth = raw[HandTypes.LM_MIDDLE_MCP].z

	var tip_sum := 0.0
	for tip_i in HandTypes.FINGER_TIPS:
		tip_sum += sample.palm.distance_to(sample.landmarks[tip_i])
	var raw_open := tip_sum / (float(HandTypes.FINGER_TIPS.size()) * sample.hand_size)
	sample.openness = clampf((raw_open - 0.45) / 1.55, 0.0, 1.0)

	return sample


static func synthetic_open_hand(palm: Vector2, openness: float, hand_size: float, timestamp_ms: float) -> HandTypes.HandSample:
	## Build approximate 21 landmarks for input/touch mode so fist detector still works.
	var sample := HandTypes.HandSample.new()
	sample.palm = palm
	sample.openness = clampf(openness, 0.0, 1.0)
	sample.hand_size = maxf(hand_size, 0.04)
	sample.timestamp_ms = timestamp_ms
	sample.handedness = "Right"
	sample.landmarks = PackedVector2Array()
	sample.landmarks.resize(21)

	var hs := sample.hand_size
	var open := sample.openness
	# Wrist below palm
	sample.landmarks[HandTypes.LM_WRIST] = palm + Vector2(0, hs * 0.9)
	sample.landmarks[HandTypes.LM_MIDDLE_MCP] = palm + Vector2(0, -hs * 0.15)
	sample.landmarks[HandTypes.LM_INDEX_MCP] = palm + Vector2(-hs * 0.35, -hs * 0.05)
	sample.landmarks[HandTypes.LM_RING_MCP] = palm + Vector2(hs * 0.3, -hs * 0.05)
	sample.landmarks[HandTypes.LM_PINKY_MCP] = palm + Vector2(hs * 0.5, 0.0)

	# Finger extension scales with openness; fist pulls tips toward palm
	var ext := lerpf(0.15, 1.0, open)
	var dirs := [
		Vector2(-0.9, -0.2), # thumb
		Vector2(-0.45, -1.0),
		Vector2(0.0, -1.05),
		Vector2(0.4, -1.0),
		Vector2(0.7, -0.75),
	]
	var tip_ids := HandTypes.FINGER_TIPS
	var pip_ids := [2, HandTypes.LM_INDEX_PIP, HandTypes.LM_MIDDLE_PIP, HandTypes.LM_RING_PIP, HandTypes.LM_PINKY_PIP]
	for i in tip_ids.size():
		var dir: Vector2 = dirs[i].normalized()
		var tip_len := hs * (0.55 + 0.85 * ext)
		if open < 0.25:
			tip_len = hs * 0.28
		sample.landmarks[tip_ids[i]] = palm + dir * tip_len
		if i > 0:
			sample.landmarks[pip_ids[i]] = palm + dir * tip_len * 0.55

	# Fill remaining joints roughly
	for i in 21:
		if sample.landmarks[i] == Vector2.ZERO and i != HandTypes.LM_WRIST:
			sample.landmarks[i] = palm

	sample.landmarks[HandTypes.LM_WRIST] = palm + Vector2(0, hs * 0.9)
	return sample
