class_name HandTracker
extends Node
## Hand tracker: Vision (macOS) primary, keyboard/mouse synthetic hand as fallback.

enum Mode { INPUT, CAMERA }

const VISION_HOST := "127.0.0.1"
const VISION_PORT := 17452
const VISION_STALE_SEC := 0.35
const VISION_RECONNECT_SEC := 1.25

@export var mode: Mode = Mode.INPUT
## When true, synthesize a hand from mouse/keys if Vision has no fresh hand.
@export var mouse_fallback: bool = true
## Synthetic hand stays open while charging (kid-friendly).
@export var always_open: bool = true
@export var use_vision: bool = true

signal hands_updated(hands: Array)
signal camera_ready(ok: bool)
signal vision_ready(ok: bool)
## Emitted when control source flips: true = body/vision, false = mouse/keyboard fallback.
signal sensing_active_changed(active: bool)

var _hands: Array = []
var _camera_tex: CameraTexture
var _feed: CameraFeed

# Vision TCP
var _tcp := StreamPeerTCP.new()
var _tcp_buf: String = ""
var _vision_hands: Array = [] # HandTypes.HandSample
var _vision_last_t: float = -999.0
var _vision_connected: bool = false
var _vision_hello: bool = false
var _vision_reconnect_cd: float = 0.0
var _vision_pid: int = -1
var _vision_status: String = "off"

# Mouse fallback state
var _touch_open: float = 0.75
var _is_charging: bool = false
var _fist_held: bool = false
var _last_palm := Vector2(0.5, 0.72)
var _prev_palm := Vector2(0.5, 0.72)
var _hand_size := 0.08
var _depth := 0.0
var _second_hand_enabled := true
var _was_sensing: bool = false


func get_hands() -> Array:
	return _hands


func get_camera_texture() -> CameraTexture:
	return _camera_tex


func has_camera() -> bool:
	return _feed != null


func has_vision() -> bool:
	return _vision_connected and _vision_hello


func is_vision_tracking() -> bool:
	return has_vision() and _is_vision_fresh() and not _vision_hands.is_empty()


## True when real body/hand sensing is driving input (not mouse fallback).
func is_sensing_active() -> bool:
	return is_vision_tracking()


func is_using_fallback() -> bool:
	return mouse_fallback and not is_sensing_active()


func vision_status() -> String:
	return _vision_status


func control_source_label() -> String:
	if is_sensing_active():
		return "体感"
	if mouse_fallback:
		return "键鼠备用"
	return "无输入"


func start_camera() -> bool:
	if OS.get_name() == "Android":
		OS.request_permission("CAMERA")

	if use_vision and OS.get_name() == "macOS":
		_ensure_vision_server()
		_try_connect_vision()

	CameraServer.set_monitoring_feeds(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout

	var feeds: Array = CameraServer.feeds()
	if feeds.is_empty():
		push_warning("No camera feed — preview disabled (Vision / fallback may still work)")
		mode = Mode.INPUT
		camera_ready.emit(false)
		if use_vision and OS.get_name() == "macOS":
			await get_tree().create_timer(0.4).timeout
			_poll_vision(0.0)
		return has_vision() or mouse_fallback

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

	if use_vision and OS.get_name() == "macOS":
		await get_tree().create_timer(0.35).timeout
		_poll_vision(0.0)

	return true


func _exit_tree() -> void:
	_tcp.disconnect_from_host()
	if _vision_pid > 0 and OS.is_process_running(_vision_pid):
		OS.kill(_vision_pid)
		_vision_pid = -1


func _process(delta: float) -> void:
	if use_vision and OS.get_name() == "macOS":
		_poll_vision(delta)

	var sensing := is_sensing_active()
	if sensing != _was_sensing:
		_was_sensing = sensing
		sensing_active_changed.emit(sensing)

	if not sensing and mouse_fallback:
		_update_fallback_input(delta)

	_hands = _build_hands()
	hands_updated.emit(_hands)


func _ensure_vision_server() -> void:
	if _vision_pid > 0 and OS.is_process_running(_vision_pid):
		return

	var exe := _resolve_hand_server_path()
	if exe == "":
		_vision_status = "binary missing — run tools/macos_hand_server/build.sh"
		push_warning(_vision_status)
		vision_ready.emit(false)
		return

	if OS.get_name() == "macOS":
		var _out: Array = []
		OS.execute("killall", PackedStringArray(["macos_hand_server"]), _out)

	var args: PackedStringArray = ["--port", str(VISION_PORT)]
	var pid := OS.create_process(exe, args, false)
	if pid <= 0:
		_vision_status = "failed to spawn hand server"
		push_warning(_vision_status)
		vision_ready.emit(false)
		return
	_vision_pid = pid
	_vision_status = "spawned pid %d" % pid
	print("[HandTracker] ", _vision_status, " @ ", exe)


func _resolve_hand_server_path() -> String:
	var candidates: Array[String] = []
	candidates.append(ProjectSettings.globalize_path("res://bin/macos_hand_server.app/Contents/MacOS/macos_hand_server"))
	candidates.append(ProjectSettings.globalize_path("res://bin/macos_hand_server"))
	var base := ProjectSettings.globalize_path("res://")
	candidates.append(base.path_join("bin/macos_hand_server.app/Contents/MacOS/macos_hand_server"))
	candidates.append(base.path_join("bin/macos_hand_server"))
	for p in candidates:
		if p != "" and FileAccess.file_exists(p):
			return p
	return ""


func _try_connect_vision() -> void:
	_tcp.disconnect_from_host()
	_tcp_buf = ""
	_vision_connected = false
	_vision_hello = false
	var err := _tcp.connect_to_host(VISION_HOST, VISION_PORT)
	if err != OK:
		_vision_status = "connect err %s" % err
		return
	_vision_status = "connecting…"


func _poll_vision(delta: float) -> void:
	_tcp.poll()
	var st := _tcp.get_status()
	match st:
		StreamPeerTCP.STATUS_CONNECTED:
			if not _vision_connected:
				_vision_connected = true
				_vision_status = "connected"
				print("[HandTracker] Vision TCP connected")
			_read_vision_socket()
		StreamPeerTCP.STATUS_CONNECTING:
			_vision_status = "connecting…"
		_:
			if _vision_connected:
				print("[HandTracker] Vision TCP lost")
			_vision_connected = false
			_vision_hello = false
			_vision_reconnect_cd -= delta
			if _vision_reconnect_cd <= 0.0:
				_vision_reconnect_cd = VISION_RECONNECT_SEC
				_ensure_vision_server()
				_try_connect_vision()


func _read_vision_socket() -> void:
	var avail := _tcp.get_available_bytes()
	if avail <= 0:
		return
	var chunk: String = _tcp.get_utf8_string(avail)
	if chunk == "":
		return
	_tcp_buf += chunk
	while true:
		var nl := _tcp_buf.find("\n")
		if nl < 0:
			if _tcp_buf.length() > 200000:
				_tcp_buf = ""
			break
		var line := _tcp_buf.substr(0, nl).strip_edges()
		_tcp_buf = _tcp_buf.substr(nl + 1)
		if line != "":
			_parse_vision_line(line)


func _parse_vision_line(line: String) -> void:
	var data = JSON.parse_string(line)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	if d.get("hello", false):
		_vision_hello = true
		_vision_status = "ready"
		vision_ready.emit(true)
	if not bool(d.get("ok", true)):
		return

	var arr: Array = d.get("hands", [])
	var now_ms := float(Time.get_ticks_msec())
	var built: Array = []
	for item in arr:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var h: Dictionary = item
		var pts: Array = h.get("pts", [])
		if pts.size() < 21:
			continue
		var raw := PackedVector3Array()
		raw.resize(21)
		for i in 21:
			var p = pts[i]
			if typeof(p) != TYPE_ARRAY or p.size() < 2:
				raw[i] = Vector3(0, 0, 0)
			else:
				var conf := float(p[2]) if p.size() > 2 else 1.0
				raw[i] = Vector3(float(p[0]), float(p[1]), conf)
		var side := str(h.get("side", "Unknown"))
		var sample := HandMath.landmarks_to_sample(raw, now_ms, side, true)
		if sample.landmarks.size() < 21:
			continue
		sample.confidence = float(h.get("conf", sample.confidence))
		sample.depth = 0.05
		built.append(sample)

	_vision_hands = built
	_vision_last_t = Time.get_ticks_msec() * 0.001
	if not _vision_hello:
		_vision_hello = true
		_vision_status = "ready"
		vision_ready.emit(true)


func _is_vision_fresh() -> bool:
	return (Time.get_ticks_msec() * 0.001 - _vision_last_t) <= VISION_STALE_SEC


func _build_hands() -> Array:
	# Priority: live Vision hands
	if use_vision and _is_vision_fresh() and not _vision_hands.is_empty():
		return _vision_hands.duplicate()
	# Fallback: mouse / keyboard synthetic hand
	if mouse_fallback:
		return _build_fallback_hands()
	return []


func _update_fallback_input(delta: float) -> void:
	_fist_held = (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		or Input.is_physical_key_pressed(KEY_F)
		or Input.is_action_pressed("fist_toggle")
	)
	_is_charging = (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_action_pressed("charge_hold")
		or always_open
	)

	var vp := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	if vp.x > 1.0 and vp.y > 1.0:
		_prev_palm = _last_palm
		_last_palm = Vector2(mouse.x / vp.x, mouse.y / vp.y)
		_last_palm = _last_palm.clamp(Vector2(0.02, 0.02), Vector2(0.98, 0.98))

	if Input.is_action_just_pressed("cast_debug"):
		_hand_size = minf(0.22, _hand_size + 0.1)
		_depth -= 0.04
	else:
		var vel := (_last_palm - _prev_palm) / maxf(delta, 0.001)
		if _is_charging and vel.length() > 1.8:
			_hand_size = minf(0.22, _hand_size + vel.length() * delta * 0.05)
			_depth -= vel.length() * delta * 0.02
		else:
			_hand_size = lerpf(_hand_size, 0.08, 1.0 - exp(-3.0 * delta))
			_depth = lerpf(_depth, 0.05, 1.0 - exp(-2.0 * delta))

	if _fist_held:
		_touch_open = lerpf(_touch_open, 0.04, 1.0 - exp(-16.0 * delta))
	elif _is_charging or always_open:
		_touch_open = lerpf(_touch_open, 0.95, 1.0 - exp(-9.0 * delta))
	else:
		_touch_open = lerpf(_touch_open, 0.32, 1.0 - exp(-4.0 * delta))


func _build_fallback_hands() -> Array:
	var now_ms := float(Time.get_ticks_msec())
	var hands: Array = []
	var open := 0.06 if _fist_held else _touch_open
	var primary := HandMath.synthetic_open_hand(_last_palm, open, _hand_size, now_ms)
	primary.depth = _depth
	primary.handedness = "Right"
	hands.append(primary)

	if _second_hand_enabled and Input.is_physical_key_pressed(KEY_SHIFT):
		var p2 := Vector2(1.0 - _last_palm.x, _last_palm.y)
		var secondary := HandMath.synthetic_open_hand(p2, open * 0.9, _hand_size * 0.95, now_ms)
		secondary.depth = _depth
		secondary.handedness = "Left"
		hands.append(secondary)
	return hands


func inject_forward_burst(amount: float = 0.1) -> void:
	if is_sensing_active():
		return
	_hand_size = minf(0.26, _hand_size + amount)
	_depth -= amount * 0.45
