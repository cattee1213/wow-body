class_name HandTracker
extends Node
## Produces up to 2 HandSamples per frame.
## INPUT: mouse / touch / keys (Mac desktop & editor)
## CAMERA: front camera background + same gesture input overlay (Android / Mac)

enum Mode { INPUT, CAMERA }

@export var mode: Mode = Mode.INPUT

signal hands_updated(hands: Array)
signal camera_ready(ok: bool)

var _hands: Array = []
var _camera_tex: CameraTexture
var _feed: CameraFeed
var _touch_open: float = 0.75
var _is_charging: bool = false
var _fist_held: bool = false
var _last_palm := Vector2(0.5, 0.72)
var _prev_palm := Vector2(0.5, 0.72)
var _hand_size := 0.08
var _depth := 0.0
var _second_hand_enabled := true


func get_hands() -> Array:
	return _hands


func get_camera_texture() -> CameraTexture:
	return _camera_tex


func has_camera() -> bool:
	return _feed != null


func start_camera() -> bool:
	## Call from UI (async-friendly). Returns true if a feed is active.
	if OS.get_name() == "Android":
		OS.request_permission("CAMERA")

	CameraServer.set_monitoring_feeds(true)
	# Give the OS a moment to enumerate feeds
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout

	var feeds: Array = CameraServer.feeds()
	if feeds.is_empty():
		push_warning("No camera feed — INPUT mode only")
		mode = Mode.INPUT
		camera_ready.emit(false)
		return false

	_feed = feeds[0]
	for f in feeds:
		var feed: CameraFeed = f
		var n := String(feed.get_name()).to_lower()
		if "front" in n or "facetime" in n or "user" in n or "face" in n:
			_feed = feed
			break

	_feed.set_active(true)
	_camera_tex = CameraTexture.new()
	_camera_tex.camera_feed_id = _feed.get_id()
	mode = Mode.CAMERA
	camera_ready.emit(true)
	return true


func _process(delta: float) -> void:
	_update_input_state(delta)
	_hands = _build_hands()
	hands_updated.emit(_hands)


func _update_input_state(delta: float) -> void:
	# Fist: right mouse, F key, or two-finger long-press (via action)
	_fist_held = (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		or Input.is_physical_key_pressed(KEY_F)
		or Input.is_action_pressed("fist_toggle")
	)

	_is_charging = (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_action_pressed("charge_hold")
	)

	# Touch charge: any press on screen (mobile)
	if DisplayServer.is_touchscreen_available():
		# Godot emulates mouse from touch when enabled
		pass

	var vp := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	if vp.x > 1.0 and vp.y > 1.0:
		_prev_palm = _last_palm
		_last_palm = Vector2(mouse.x / vp.x, mouse.y / vp.y)
		_last_palm = _last_palm.clamp(Vector2(0.02, 0.02), Vector2(0.98, 0.98))

	# Forward burst via cast_debug / swipe inject
	if Input.is_action_just_pressed("cast_debug"):
		_hand_size = minf(0.22, _hand_size + 0.1)
		_depth -= 0.04
	else:
		var vel := (_last_palm - _prev_palm) / maxf(delta, 0.001)
		if _is_charging and vel.length() > 1.8:
			# Quick thrust motion grows hand size (toward-camera proxy)
			_hand_size = minf(0.22, _hand_size + vel.length() * delta * 0.05)
			_depth -= vel.length() * delta * 0.02
		else:
			_hand_size = lerpf(_hand_size, 0.08, 1.0 - exp(-3.0 * delta))
			_depth = lerpf(_depth, 0.05, 1.0 - exp(-2.0 * delta))

	if _fist_held:
		# Pull openness down hard so FistDetector confirms quickly
		_touch_open = lerpf(_touch_open, 0.04, 1.0 - exp(-16.0 * delta))
	elif _is_charging:
		_touch_open = lerpf(_touch_open, 0.95, 1.0 - exp(-9.0 * delta))
	else:
		_touch_open = lerpf(_touch_open, 0.32, 1.0 - exp(-4.0 * delta))


func _build_hands() -> Array:
	var now_ms := float(Time.get_ticks_msec())
	var hands: Array = []

	var open := 0.06 if _fist_held else _touch_open
	var primary := HandMath.synthetic_open_hand(_last_palm, open, _hand_size, now_ms)
	primary.depth = _depth
	primary.handedness = "Right"
	hands.append(primary)

	# Second hand: hold Shift
	if _second_hand_enabled and Input.is_physical_key_pressed(KEY_SHIFT):
		var p2 := Vector2(1.0 - _last_palm.x, _last_palm.y)
		var secondary := HandMath.synthetic_open_hand(p2, open * 0.9, _hand_size * 0.95, now_ms)
		secondary.depth = _depth
		secondary.handedness = "Left"
		hands.append(secondary)

	return hands


func inject_forward_burst(amount: float = 0.1) -> void:
	_hand_size = minf(0.26, _hand_size + amount)
	_depth -= amount * 0.45
