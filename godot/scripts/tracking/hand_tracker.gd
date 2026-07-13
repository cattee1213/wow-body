class_name HandTracker
extends Node
## Pure motion hand tracker (macOS Vision).
## No mouse / keyboard synthetic hands — empty array when no real hand.

enum Mode { INPUT, CAMERA }

const VISION_HOST := "127.0.0.1"
const VISION_PORT := 17452
const VISION_STALE_SEC := 0.35
const VISION_RECONNECT_SEC := 1.25

@export var mode: Mode = Mode.INPUT
## Pure body game: never synthesize a mouse hand.
@export var mouse_fallback: bool = false
## Kept for API compat; unused when mouse_fallback is false.
@export var always_open: bool = true
@export var use_vision: bool = true

signal hands_updated(hands: Array)
signal camera_ready(ok: bool)
signal vision_ready(ok: bool)

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


func vision_status() -> String:
	return _vision_status


func start_camera() -> bool:
	## Opens preview camera + (on macOS) Vision hand server.
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
		push_warning("No camera feed — preview disabled (Vision may still work)")
		mode = Mode.INPUT
		camera_ready.emit(false)
		if use_vision and OS.get_name() == "macOS":
			await get_tree().create_timer(0.4).timeout
			_poll_vision(0.0)
		return has_vision()

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

	# Prefer latest binary: stop any previous hand server holding the port.
	# Godot 4: OS.execute(path, args, output: Array, ...)
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
	if use_vision and _is_vision_fresh() and not _vision_hands.is_empty():
		return _vision_hands.duplicate()
	# Pure motion: no mouse/keyboard synthetic hands.
	return []


func inject_forward_burst(_amount: float = 0.1) -> void:
	## No-op in pure motion mode (kept for API compat).
	pass
