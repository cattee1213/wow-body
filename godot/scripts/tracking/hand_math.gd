class_name HandMath
extends RefCounted
## Landmark → HandSample conversion (selfie-mirrored).
## raw[i].z is joint confidence (0..1). Low-conf joints are filled from palm
## so skeleton never draws spikes to (0,0)/(1,0).

const MIN_JOINT_CONF := 0.12


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
	sample.joint_conf = PackedFloat32Array()
	sample.joint_conf.resize(21)

	if raw.size() < 21:
		return sample

	# Pass 1: place valid joints; remember conf
	var valid_count := 0
	var conf_sum := 0.0
	for i in 21:
		var p := raw[i]
		var conf := clampf(p.z, 0.0, 1.0)
		# Treat near-origin with zero conf as missing (legacy server filler).
		if conf < MIN_JOINT_CONF or (conf <= 0.001 and p.x <= 0.001 and p.y <= 0.001):
			sample.joint_conf[i] = 0.0
			sample.landmarks[i] = Vector2(-1, -1) # sentinel until fill
			continue
		var x := (1.0 - p.x) if mirror_x else p.x
		var y := p.y
		sample.landmarks[i] = Vector2(x, y)
		sample.joint_conf[i] = conf
		valid_count += 1
		conf_sum += conf

	if valid_count < 6:
		# Too few joints — empty sample (caller should drop).
		sample.landmarks.resize(0)
		sample.joint_conf.resize(0)
		return sample

	# Palm from valid palm-ish joints
	var palm_acc := Vector2.ZERO
	var palm_n := 0
	for idx in [HandTypes.LM_WRIST, HandTypes.LM_MIDDLE_MCP, HandTypes.LM_INDEX_MCP, HandTypes.LM_PINKY_MCP]:
		if sample.joint_conf[idx] >= MIN_JOINT_CONF:
			palm_acc += sample.landmarks[idx]
			palm_n += 1
	if palm_n == 0:
		# Average all valid
		for i in 21:
			if sample.joint_conf[i] >= MIN_JOINT_CONF:
				palm_acc += sample.landmarks[i]
				palm_n += 1
	sample.palm = palm_acc / float(maxi(palm_n, 1))

	# Pass 2: fill invalid joints toward palm (no screen-corner spikes)
	for i in 21:
		if sample.joint_conf[i] < MIN_JOINT_CONF:
			sample.landmarks[i] = sample.palm
			sample.joint_conf[i] = 0.0

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

	sample.hand_size = maxf(wrist.distance_to(mid_mcp), idx_mcp.distance_to(pnk_mcp))
	sample.hand_size = maxf(sample.hand_size, 0.015)
	sample.depth = 0.05
	sample.confidence = conf_sum / float(valid_count)

	var tip_sum := 0.0
	var tip_n := 0
	for tip_i in HandTypes.FINGER_TIPS:
		if sample.joint_conf[tip_i] >= MIN_JOINT_CONF:
			tip_sum += sample.palm.distance_to(sample.landmarks[tip_i])
			tip_n += 1
	if tip_n > 0:
		var raw_open := tip_sum / (float(tip_n) * sample.hand_size)
		sample.openness = clampf((raw_open - 0.45) / 1.55, 0.0, 1.0)
	else:
		sample.openness = 0.55

	return sample


static func synthetic_open_hand(palm: Vector2, openness: float, hand_size: float, timestamp_ms: float) -> HandTypes.HandSample:
	## Debug-only synthetic hand (disabled in pure motion mode).
	var sample := HandTypes.HandSample.new()
	sample.palm = palm
	sample.openness = clampf(openness, 0.0, 1.0)
	sample.hand_size = maxf(hand_size, 0.04)
	sample.timestamp_ms = timestamp_ms
	sample.handedness = "Right"
	sample.landmarks = PackedVector2Array()
	sample.landmarks.resize(21)
	sample.joint_conf = PackedFloat32Array()
	sample.joint_conf.resize(21)

	var hs := sample.hand_size
	var open := sample.openness
	sample.landmarks[HandTypes.LM_WRIST] = palm + Vector2(0, hs * 0.9)
	sample.landmarks[HandTypes.LM_MIDDLE_MCP] = palm + Vector2(0, -hs * 0.15)
	sample.landmarks[HandTypes.LM_INDEX_MCP] = palm + Vector2(-hs * 0.35, -hs * 0.05)
	sample.landmarks[HandTypes.LM_RING_MCP] = palm + Vector2(hs * 0.3, -hs * 0.05)
	sample.landmarks[HandTypes.LM_PINKY_MCP] = palm + Vector2(hs * 0.5, 0.0)

	var ext := lerpf(0.15, 1.0, open)
	var dirs := [
		Vector2(-0.9, -0.2),
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

	for i in 21:
		if sample.landmarks[i] == Vector2.ZERO and i != HandTypes.LM_WRIST:
			sample.landmarks[i] = palm
		sample.joint_conf[i] = 1.0

	sample.landmarks[HandTypes.LM_WRIST] = palm + Vector2(0, hs * 0.9)
	return sample
