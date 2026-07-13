extends Control
## WoW Body — Godot 4.7 client entry.
## Camera + gesture casting (fire / frost / lightning). Mac & Android.

@onready var camera_bg: TextureRect = %CameraBg
@onready var dimmer: ColorRect = %Dimmer
@onready var game_world: GameWorld = %GameWorld
@onready var hand_skeleton: Node2D = %HandSkeleton
@onready var palm_layer: Node2D = %PalmLayer
@onready var tracker: HandTracker = %HandTracker
@onready var hud: CanvasLayer = %HUD
@onready var start_panel: PanelContainer = %StartPanel
@onready var btn_start: Button = %BtnStart
@onready var lbl_status: Label = %LblStatus
@onready var lbl_score: Label = %LblScore
@onready var lbl_hp: Label = %LblHp
@onready var lbl_spell: Label = %LblSpell
@onready var charge_bar: ProgressBar = %ChargeBar
@onready var lbl_debug: Label = %LblDebug
@onready var lbl_message: Label = %LblMessage
@onready var lbl_tip: Label = %LblTip
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var btn_restart: Button = %BtnRestart

var _gesture := GestureController.new()
var _palms: Array = [] # PalmVfx
var _playing := false
var _swipe_start := Vector2.ZERO
var _swiping := false


func _ready() -> void:
	randomize()
	btn_start.pressed.connect(_on_start)
	btn_restart.pressed.connect(_on_restart)
	game_world.state_changed.connect(_refresh_hud)
	game_world.defeated.connect(_on_defeated)
	GameBus.spell_changed.connect(_on_spell_changed)

	for i in 2:
		var p := PalmVfx.new()
		palm_layer.add_child(p)
		_palms.append(p)

	_refresh_hud()
	game_over_panel.visible = false
	lbl_message.text = ""
	# Prefer camera on mobile
	if OS.has_feature("android") or OS.has_feature("mobile"):
		tracker.mode = HandTracker.Mode.CAMERA
	else:
		tracker.mode = HandTracker.Mode.INPUT


func _on_start() -> void:
	lbl_status.text = "正在启动摄像头…"
	btn_start.disabled = true
	var use_cam := (
		tracker.mode == HandTracker.Mode.CAMERA
		or OS.has_feature("android")
		or OS.has_feature("mobile")
		or OS.get_name() == "macOS"
	)
	if use_cam:
		await tracker.start_camera()
	_apply_camera_bg()
	start_panel.visible = false
	_playing = true
	_gesture.reset()
	game_world.restart()
	lbl_tip.text = "开掌蓄力 · 推掌/空格释放 · 握拳/右键/F 切法 · R 重开"
	_refresh_hud()


func _apply_camera_bg() -> void:
	var tex := tracker.get_camera_texture()
	if tex:
		camera_bg.texture = tex
		camera_bg.visible = true
		# Selfie mirror
		camera_bg.flip_h = true
		dimmer.color = Color(0.03, 0.02, 0.05, 0.45)
	else:
		camera_bg.visible = false
		dimmer.color = Color(0.05, 0.04, 0.08, 0.92)


func _process(dt: float) -> void:
	if not _playing:
		return

	if Input.is_action_just_pressed("restart"):
		_on_restart()
		return

	if Input.is_action_just_pressed("switch_spell"):
		_gesture.spell = GameBus.next_spell(_gesture.spell)
		GameBus.spell_changed.emit(_gesture.spell)
		game_world.message = "法术：%s" % GameBus.spell_name(_gesture.spell)
		game_world.message_ttl = 1.2

	var hands: Array = tracker.get_hands()
	var now := Time.get_ticks_msec() * 0.001
	var result: GestureController.UpdateResult = _gesture.update(hands, dt, now)

	if result.spell_switched:
		_on_spell_changed(result.spell)
		game_world.message = "切换法术：%s" % GameBus.spell_name(result.spell)
		game_world.message_ttl = 1.3

	if Input.is_action_just_pressed("cast_debug"):
		tracker.inject_forward_burst(0.12)
		var fr := _gesture.force_cast_from_input(maxf(_gesture.charge, 0.65))
		result.cast = true
		result.charge_used = fr.charge_used
		if hands.size() > 0:
			result.cast_hand = hands[0]

	if result.cast:
		var palm := Vector2(0.5, 0.72)
		if result.cast_hand:
			palm = result.cast_hand.palm
		elif hands.size() > 0:
			palm = hands[0].palm
		game_world.cast_spell(palm, _gesture.spell, maxf(0.2, result.charge_used))

	_draw_hands(hands)
	_sync_palms(hands)
	_refresh_hud()

	if game_world.message_ttl > 0.0 and game_world.message != "":
		lbl_message.text = game_world.message
		lbl_message.visible = true
	else:
		lbl_message.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	# Mobile swipe up/toward = forward cast burst
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_swiping = true
			_swipe_start = st.position
		else:
			if _swiping:
				var delta: Vector2 = st.position - _swipe_start
				# Forward: large movement toward bottom of screen (hand closer) or flick
				if delta.length() > 80.0:
					tracker.inject_forward_burst(clampf(delta.length() / 400.0, 0.06, 0.18))
			_swiping = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.relative.length() > 12.0:
			tracker.inject_forward_burst(0.01)


func _draw_hands(hands: Array) -> void:
	# Clear previous
	for c in hand_skeleton.get_children():
		c.queue_free()
	var vp := get_viewport_rect().size
	for h in hands:
		var sample: HandTypes.HandSample = h
		if sample.landmarks.size() < 21:
			continue
		var col := GameBus.spell_accent(_gesture.spell)
		if sample.is_fist:
			col = Color(0.8, 0.85, 1.0)
		for pair in HandTypes.CONNECTIONS:
			var a: Vector2 = sample.landmarks[pair[0]] * vp
			var b: Vector2 = sample.landmarks[pair[1]] * vp
			var line := Line2D.new()
			line.width = 3.0 if sample.is_fist else 2.2
			line.default_color = Color(col, 0.85)
			line.points = PackedVector2Array([a, b])
			hand_skeleton.add_child(line)
		for i in sample.landmarks.size():
			var p: Vector2 = sample.landmarks[i] * vp
			var dot := Polygon2D.new()
			dot.color = Color(1, 0.95, 0.85) if not sample.is_fist else Color(0.85, 0.9, 1)
			var r := 3.5 if sample.is_fist else 2.8
			var pts := PackedVector2Array()
			for k in 8:
				var ang := TAU * float(k) / 8.0
				pts.append(p + Vector2(cos(ang), sin(ang)) * r)
			dot.polygon = pts
			hand_skeleton.add_child(dot)


func _sync_palms(hands: Array) -> void:
	var vp := get_viewport_rect().size
	var open_hands: Array = []
	for h in hands:
		if not h.is_fist:
			open_hands.append(h)
	for i in _palms.size():
		var palm_vfx: PalmVfx = _palms[i]
		palm_vfx.set_spell(_gesture.spell)
		if i < open_hands.size():
			var h: HandTypes.HandSample = open_hands[i]
			var ch := maxf(_gesture.charge * (0.4 + h.openness * 0.6), h.openness * 0.85)
			palm_vfx.sync(h.palm * vp, ch, h.openness)
		else:
			palm_vfx.hide_palm()


func _refresh_hud() -> void:
	lbl_score.text = "分数 %d    击杀 %d    波次 %d" % [game_world.score, game_world.kills, game_world.wave]
	lbl_hp.text = "生命 " + "●".repeat(maxi(game_world.player_hp, 0)) + "○".repeat(maxi(GameWorld.PLAYER_MAX_HP - game_world.player_hp, 0))
	lbl_spell.text = "%s  %s" % [_spell_badge(_gesture.spell), GameBus.spell_name(_gesture.spell)]
	lbl_spell.add_theme_color_override("font_color", GameBus.spell_accent(_gesture.spell))
	charge_bar.value = _gesture.charge * 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = GameBus.spell_color(_gesture.spell)
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	charge_bar.add_theme_stylebox_override("fill", fill)
	lbl_debug.text = "状态 %s  开掌 %.2f  向前 %.2f  握拳 %.2f  手 %d" % [
		_phase_name(_gesture.phase),
		_gesture.openness,
		_gesture.debug_forward,
		_gesture.debug_fist_score,
		_gesture.debug_hands,
	]


func _spell_badge(s: StringName) -> String:
	match s:
		GameBus.SPELL_FROST:
			return "❄"
		GameBus.SPELL_LIGHTNING:
			return "⚡"
		_:
			return "🔥"


func _phase_name(p: StringName) -> String:
	match p:
		&"charging":
			return "蓄力中"
		&"cooldown":
			return "冷却"
		_:
			return "待机"


func _on_spell_changed(spell: StringName) -> void:
	for p in _palms:
		(p as PalmVfx).set_spell(spell)
	_refresh_hud()


func _on_defeated(_score: int, _kills: int) -> void:
	game_over_panel.visible = true


func _on_restart() -> void:
	game_over_panel.visible = false
	_gesture.reset()
	game_world.restart()
	_playing = true
	_refresh_hud()
