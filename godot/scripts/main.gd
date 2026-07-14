extends Control
## WoW Body — Godot client.
## Primary: camera body/hand sensing. Fallback: keyboard + mouse (cursor hidden while sensing).
## Flow: Start → Select school → Combat (point basic + ritual ultimates).

const DWELL_START_SEC := 3.0
const DWELL_SELECT_SEC := 1.5
const DWELL_RESTART_SEC := 2.0

@onready var camera_bg: TextureRect = %CameraBg
@onready var dimmer: ColorRect = %Dimmer
@onready var game_world: GameWorld = %GameWorld
@onready var hand_skeleton: Node2D = %HandSkeleton
@onready var palm_layer: Node2D = %PalmLayer
@onready var tracker: HandTracker = %HandTracker
@onready var hud: CanvasLayer = %HUD
@onready var start_panel: PanelContainer = %StartPanel
@onready var btn_start: Button = %BtnStart
@onready var start_dwell_bar: ProgressBar = %StartDwellBar
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
@onready var restart_dwell_bar: ProgressBar = %RestartDwellBar
@onready var btn_spell_fire: Button = %BtnSpellFire
@onready var btn_spell_frost: Button = %BtnSpellFrost
@onready var btn_spell_lightning: Button = %BtnSpellLightning
@onready var spell_bar: HBoxContainer = %SpellBar
@onready var gesture_cursor: Control = %GestureCursor
@onready var select_panel: PanelContainer = %SelectPanel
@onready var select_dwell_bar: ProgressBar = %SelectDwellBar
@onready var select_hint: Label = %SelectHint
@onready var btn_ult_blizzard: Button = %BtnUltBlizzard
@onready var btn_ult_firestorm: Button = %BtnUltFirestorm
@onready var btn_ult_chain: Button = %BtnUltChain

var _gesture := GestureController.new()
var _palms: Array = [] # PalmVfx
var _playing := false
var _selecting := false
var _starting := false
var _has_palm := false
var _last_palm_px := Vector2.ZERO
var _sensing_active := false

var _dwell_start: DwellTarget
var _dwell_restart: DwellTarget
var _dwell_selects: Array = [] # DwellTarget
var _start_btn_base_text := "体感：悬停 3 秒  ·  键鼠：点击开始"
var _restart_btn_base_text := "体感：悬停 2 秒  ·  键鼠：点击重开"


func _ready() -> void:
	randomize()
	SpellVfxLibrary.reload()
	_gesture.auto_fire = true
	tracker.always_open = true
	tracker.mouse_fallback = true
	tracker.use_vision = true

	if OS.has_feature("android") or OS.has_feature("mobile") or OS.get_name() == "macOS":
		tracker.mode = HandTracker.Mode.CAMERA
	else:
		tracker.mode = HandTracker.Mode.CAMERA

	tracker.sensing_active_changed.connect(_on_sensing_active_changed)

	if not btn_start.pressed.is_connected(_on_start_clicked):
		btn_start.pressed.connect(_on_start_clicked)
	if not btn_restart.pressed.is_connected(_on_restart):
		btn_restart.pressed.connect(_on_restart)
	if not btn_spell_fire.pressed.is_connected(_on_spell_fire_clicked):
		btn_spell_fire.pressed.connect(_on_spell_fire_clicked)
	if not btn_spell_frost.pressed.is_connected(_on_spell_frost_clicked):
		btn_spell_frost.pressed.connect(_on_spell_frost_clicked)
	if not btn_spell_lightning.pressed.is_connected(_on_spell_lightning_clicked):
		btn_spell_lightning.pressed.connect(_on_spell_lightning_clicked)
	if not btn_ult_blizzard.pressed.is_connected(_on_ult_blizzard_clicked):
		btn_ult_blizzard.pressed.connect(_on_ult_blizzard_clicked)
	if not btn_ult_firestorm.pressed.is_connected(_on_ult_firestorm_clicked):
		btn_ult_firestorm.pressed.connect(_on_ult_firestorm_clicked)
	if not btn_ult_chain.pressed.is_connected(_on_ult_chain_clicked):
		btn_ult_chain.pressed.connect(_on_ult_chain_clicked)

	game_world.state_changed.connect(_refresh_hud)
	game_world.defeated.connect(_on_defeated)
	GameBus.spell_changed.connect(_on_spell_changed)
	GameBus.ultimate_cds_changed.connect(_refresh_ultimate_buttons)

	for i in 2:
		var p := PalmVfx.new()
		palm_layer.add_child(p)
		_palms.append(p)

	_dwell_start = DwellTarget.new(btn_start, DWELL_START_SEC, &"start")
	_dwell_restart = DwellTarget.new(btn_restart, DWELL_RESTART_SEC, &"restart")
	_dwell_selects = [
		DwellTarget.new(btn_spell_fire, DWELL_SELECT_SEC, GameBus.SPELL_FIRE),
		DwellTarget.new(btn_spell_frost, DWELL_SELECT_SEC, GameBus.SPELL_FROST),
		DwellTarget.new(btn_spell_lightning, DWELL_SELECT_SEC, GameBus.SPELL_LIGHTNING),
	]

	btn_start.text = _start_btn_base_text
	btn_restart.text = _restart_btn_base_text
	start_dwell_bar.value = 0.0
	restart_dwell_bar.value = 0.0
	select_dwell_bar.value = 0.0
	game_over_panel.visible = false
	select_panel.visible = false
	spell_bar.visible = false
	lbl_message.text = ""
	lbl_tip.text = "优先体感 · 无手时键鼠备用 · 体感激活自动隐藏鼠标"
	if gesture_cursor:
		gesture_cursor.pivot_offset = gesture_cursor.size * 0.5
		if gesture_cursor.pivot_offset.length_squared() < 1.0:
			gesture_cursor.pivot_offset = Vector2(36, 36)
		gesture_cursor.visible = false

	_apply_input_mode(false)
	_refresh_hud()
	_boot_camera()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_sensing_active_changed(active: bool) -> void:
	_apply_input_mode(active)


func _apply_input_mode(sensing: bool) -> void:
	_sensing_active = sensing
	if sensing:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_set_buttons_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_set_buttons_mouse_filter(Control.MOUSE_FILTER_STOP)


func _set_buttons_mouse_filter(mode: Control.MouseFilter) -> void:
	var buttons: Array = [
		btn_start, btn_restart,
		btn_spell_fire, btn_spell_frost, btn_spell_lightning,
		btn_ult_blizzard, btn_ult_firestorm, btn_ult_chain,
	]
	for btn in buttons:
		if btn:
			btn.mouse_filter = mode
			btn.focus_mode = Control.FOCUS_NONE if mode == Control.MOUSE_FILTER_IGNORE else Control.FOCUS_ALL


func _boot_camera() -> void:
	lbl_status.text = "正在打开摄像头与手部识别…"
	var ok := await tracker.start_camera()
	_apply_camera_bg()
	for _i in 20:
		if tracker.has_vision():
			break
		await get_tree().create_timer(0.1).timeout
	_apply_input_mode(tracker.is_sensing_active())
	_update_boot_status(ok)


func _update_boot_status(camera_ok: bool) -> void:
	if tracker.is_sensing_active():
		lbl_status.text = "体感已激活（鼠标已隐藏）· 把手移到开始按钮上停 3 秒"
	elif tracker.has_vision():
		lbl_status.text = "手部服务就绪 · 请伸手，或使用键鼠点击开始"
	elif camera_ok:
		lbl_status.text = "摄像头已开，体感未连上 · 可用键鼠 · %s" % tracker.vision_status()
	else:
		lbl_status.text = "键鼠备用模式 · %s" % tracker.vision_status()


func _on_start_clicked() -> void:
	if tracker.is_sensing_active():
		return
	_open_select()


func _on_spell_fire_clicked() -> void:
	if tracker.is_sensing_active():
		return
	if _selecting:
		_confirm_school(GameBus.SPELL_FIRE)


func _on_spell_frost_clicked() -> void:
	if tracker.is_sensing_active():
		return
	if _selecting:
		_confirm_school(GameBus.SPELL_FROST)


func _on_spell_lightning_clicked() -> void:
	if tracker.is_sensing_active():
		return
	if _selecting:
		_confirm_school(GameBus.SPELL_LIGHTNING)


func _on_ult_blizzard_clicked() -> void:
	if tracker.is_sensing_active() or not _playing:
		return
	_try_ultimate(GameBus.ULT_BLIZZARD)


func _on_ult_firestorm_clicked() -> void:
	if tracker.is_sensing_active() or not _playing:
		return
	_try_ultimate(GameBus.ULT_FIRESTORM)


func _on_ult_chain_clicked() -> void:
	if tracker.is_sensing_active() or not _playing:
		return
	_try_ultimate(GameBus.ULT_CHAIN)


func _open_select() -> void:
	if _playing or _starting or _selecting:
		return
	_starting = true
	btn_start.disabled = true
	_dwell_start.enabled = false
	lbl_status.text = "选择学派…"
	if not tracker.has_camera():
		await tracker.start_camera()
		_apply_camera_bg()
	start_panel.visible = false
	select_panel.visible = true
	spell_bar.visible = false
	_selecting = true
	_starting = false
	for d: DwellTarget in _dwell_selects:
		d.reset()
		d.enabled = true
	select_dwell_bar.value = 0.0
	_apply_input_mode(tracker.is_sensing_active())
	_paint_select_dwell(null)
	_update_tip()


func _confirm_school(spell: StringName) -> void:
	if not _selecting:
		return
	_selecting = false
	select_panel.visible = false
	for d: DwellTarget in _dwell_selects:
		d.enabled = false
		d.reset()
	GameBus.reset_run_state(spell)
	_gesture.spell = spell
	_gesture.reset()
	_gesture.spell = spell
	_gesture.auto_fire = true
	_playing = true
	spell_bar.visible = true
	game_world.restart()
	game_world.message = "本局学派：%s · 指尖射击 · 双手放终极" % GameBus.spell_name(spell)
	game_world.message_ttl = 2.8
	_apply_input_mode(tracker.is_sensing_active())
	_update_tip()
	_refresh_hud()


func _try_ultimate(ult: StringName) -> void:
	if not _playing or game_world.game_over:
		return
	if not GameBus.can_cast_ultimate(ult):
		game_world.message = "%s 冷却中…" % GameBus.spell_name(ult)
		game_world.message_ttl = 0.9
		return
	var fr := _gesture.force_ultimate(ult)
	if fr.ultimate_cast:
		game_world.cast_ultimate(fr.ultimate, 1.0)


func _update_tip() -> void:
	if _selecting:
		lbl_tip.text = "选择基础学派 · 悬停确认 · 键鼠 1/2/3"
	elif tracker.is_sensing_active():
		lbl_tip.text = "体感 · 指尖蓄力射击 · 双手高举=暴风雪 · 合掌=火风暴 · 双拳=闪电链"
	else:
		lbl_tip.text = "键鼠 · 空格射击 · 4/5/6 终极 · R 重开"


func _apply_camera_bg() -> void:
	var tex := tracker.get_camera_texture()
	if tex:
		camera_bg.texture = tex
		camera_bg.visible = true
		camera_bg.flip_h = true
		dimmer.color = Color(0.03, 0.02, 0.05, 0.45)
	else:
		camera_bg.visible = false
		dimmer.color = Color(0.05, 0.04, 0.08, 0.92)


func _process(dt: float) -> void:
	var sensing_now := tracker.is_sensing_active()
	if sensing_now != _sensing_active:
		_apply_input_mode(sensing_now)
	elif sensing_now and Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	var hands: Array = tracker.get_hands()
	var palm_px := _primary_palm_px(hands)

	_draw_hands(hands)
	_sync_palms_menu_or_game(hands)
	_sync_gesture_cursor(palm_px)

	if _selecting:
		_process_select(dt, palm_px)
		_process_fallback_keys_select()
		_refresh_hud()
		return

	if not _playing:
		_process_menu(dt, palm_px)
		_process_fallback_keys_menu()
		return

	_process_fallback_keys_game(hands)

	var now := Time.get_ticks_msec() * 0.001
	var result: GestureController.UpdateResult = _gesture.update(hands, dt, now)

	if result.ultimate_cast:
		game_world.cast_ultimate(result.ultimate, 1.0)

	if result.cast and hands.size() > 0:
		var palm := Vector2(0.5, 0.72)
		if result.cast_hand:
			palm = result.cast_hand.palm
		else:
			palm = hands[0].palm
		# Prefer index tip as aim point when pointing
		if result.cast_hand and result.cast_hand.landmarks.size() > HandTypes.LM_INDEX_TIP:
			var tip: Vector2 = result.cast_hand.landmarks[HandTypes.LM_INDEX_TIP]
			if tip.x > 0.0 and tip.y > 0.0:
				palm = tip
		game_world.cast_spell(palm, _gesture.spell, maxf(0.35, result.charge_used))

	_process_game_dwell(dt, palm_px)
	_refresh_hud()
	_update_tip()

	if game_world.message_ttl > 0.0 and game_world.message != "":
		lbl_message.text = game_world.message
		lbl_message.visible = true
	else:
		lbl_message.visible = false


func _process_fallback_keys_menu() -> void:
	if tracker.is_sensing_active():
		return
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("cast_debug"):
		_open_select()


func _process_fallback_keys_select() -> void:
	if tracker.is_sensing_active():
		return
	if Input.is_action_just_pressed("select_fire"):
		_confirm_school(GameBus.SPELL_FIRE)
	elif Input.is_action_just_pressed("select_frost"):
		_confirm_school(GameBus.SPELL_FROST)
	elif Input.is_action_just_pressed("select_lightning"):
		_confirm_school(GameBus.SPELL_LIGHTNING)


func _process_fallback_keys_game(hands: Array) -> void:
	if tracker.is_sensing_active():
		return

	if Input.is_action_just_pressed("restart"):
		_on_restart()
		return

	if Input.is_action_just_pressed("ult_blizzard"):
		_try_ultimate(GameBus.ULT_BLIZZARD)
	elif Input.is_action_just_pressed("ult_firestorm"):
		_try_ultimate(GameBus.ULT_FIRESTORM)
	elif Input.is_action_just_pressed("ult_chain"):
		_try_ultimate(GameBus.ULT_CHAIN)

	if Input.is_action_just_pressed("cast_debug"):
		tracker.inject_forward_burst(0.12)
		var fr := _gesture.force_cast_from_input(maxf(_gesture.charge, 0.65))
		var palm := Vector2(0.5, 0.72)
		if hands.size() > 0:
			palm = hands[0].palm
		game_world.cast_spell(palm, _gesture.spell, maxf(0.35, fr.charge_used))


func _process_menu(dt: float, palm_px: Vector2) -> void:
	if _starting or not start_panel.visible:
		return

	if tracker.is_sensing_active():
		if lbl_status.text.find("体感已激活") < 0:
			_update_boot_status(tracker.has_camera())
	elif tracker.has_vision():
		if lbl_status.text.find("请伸手") < 0 and lbl_status.text.find("键鼠") < 0:
			_update_boot_status(tracker.has_camera())

	var hovering := _has_palm and _dwell_start.is_hovering(palm_px)
	if _dwell_start.update(dt, hovering):
		_open_select()
		return

	start_dwell_bar.value = _dwell_start.progress * 100.0
	if _dwell_start.progress > 0.02:
		var left := ceili(_dwell_start.remaining_sec())
		btn_start.text = "保持不动… %d" % maxi(left, 1)
		btn_start.modulate = Color(1.15, 1.05, 0.75)
	else:
		btn_start.text = _start_btn_base_text
		btn_start.modulate = Color.WHITE

	lbl_debug.text = "菜单[%s] 掌心(%.0f,%.0f) 悬停%s 进度%.0f%%  鼠标%s  %s" % [
		tracker.control_source_label(),
		palm_px.x if _has_palm else -1.0,
		palm_px.y if _has_palm else -1.0,
		"是" if hovering else "否",
		_dwell_start.progress * 100.0,
		"隐藏" if tracker.is_sensing_active() else "显示",
		tracker.vision_status(),
	]


func _process_select(dt: float, palm_px: Vector2) -> void:
	if not _has_palm:
		for d: DwellTarget in _dwell_selects:
			d.update(dt, false)
		select_dwell_bar.value = 0.0
		_paint_select_dwell(null)
		return

	for d: DwellTarget in _dwell_selects:
		var hovering := d.is_hovering(palm_px)
		if hovering:
			for other: DwellTarget in _dwell_selects:
				if other != d:
					other.reset()
			if d.update(dt, true):
				_confirm_school(d.id)
				return
			select_dwell_bar.value = d.progress * 100.0
			_paint_select_dwell(d)
			return
		else:
			d.update(dt, false)
	select_dwell_bar.value = 0.0
	_paint_select_dwell(null)


func _process_game_dwell(dt: float, palm_px: Vector2) -> void:
	if not _has_palm:
		if game_over_panel.visible:
			_dwell_restart.update(dt, false)
			restart_dwell_bar.value = _dwell_restart.progress * 100.0
		return

	if game_over_panel.visible:
		var hov := _dwell_restart.is_hovering(palm_px)
		if _dwell_restart.update(dt, hov):
			_on_restart()
			return
		restart_dwell_bar.value = _dwell_restart.progress * 100.0
		if _dwell_restart.progress > 0.02:
			btn_restart.text = "保持不动… %d" % maxi(ceili(_dwell_restart.remaining_sec()), 1)
		else:
			btn_restart.text = _restart_btn_base_text


func _paint_select_dwell(active: DwellTarget) -> void:
	var map := {
		GameBus.SPELL_FIRE: btn_spell_fire,
		GameBus.SPELL_FROST: btn_spell_frost,
		GameBus.SPELL_LIGHTNING: btn_spell_lightning,
	}
	for spell in map.keys():
		var btn: Button = map[spell]
		var base := Color(1.05, 1.05, 1.05)
		if active and active.id == spell and active.progress > 0.02:
			var pulse := 1.0 + active.progress * 0.4
			btn.modulate = base * pulse
			btn.modulate.a = 1.0
		else:
			btn.modulate = base


func _primary_palm_px(hands: Array) -> Vector2:
	var vp := get_viewport_rect().size
	if hands.size() > 0:
		var h: HandTypes.HandSample = hands[0]
		_has_palm = true
		# Prefer index tip when pointing for cursor
		if h.landmarks.size() > HandTypes.LM_INDEX_TIP and PoseClassifier.score_point(h) > 0.45:
			_last_palm_px = h.landmarks[HandTypes.LM_INDEX_TIP] * vp
		else:
			_last_palm_px = h.palm * vp
		return _last_palm_px
	_has_palm = false
	return _last_palm_px


func _sync_gesture_cursor(palm_px: Vector2) -> void:
	if gesture_cursor == null:
		return
	if not _has_palm:
		gesture_cursor.visible = false
		return
	var size := gesture_cursor.size
	if size.x < 1.0:
		size = Vector2(72, 72)
	gesture_cursor.pivot_offset = size * 0.5
	gesture_cursor.position = palm_px - size * 0.5
	gesture_cursor.visible = true
	var dwell_p := 0.0
	if not _playing and not _selecting and _dwell_start:
		dwell_p = _dwell_start.progress
	elif _selecting:
		for d: DwellTarget in _dwell_selects:
			dwell_p = maxf(dwell_p, d.progress)
	elif game_over_panel.visible and _dwell_restart:
		dwell_p = _dwell_restart.progress
	elif _gesture.ritual_channel > 0.02:
		dwell_p = _gesture.ritual_channel
	var pulse := 1.0 + dwell_p * 0.55
	gesture_cursor.scale = Vector2(pulse, pulse)
	var accent := GameBus.spell_accent(_gesture.spell)
	if _gesture.ritual_active != &"":
		accent = GameBus.spell_accent(_gesture.ritual_active)
	if dwell_p > 0.02:
		accent = accent.lerp(Color(1, 1, 0.55), dwell_p)
	var outer := gesture_cursor.get_node_or_null("RingOuter") as ColorRect
	var inner := gesture_cursor.get_node_or_null("RingInner") as ColorRect
	if outer:
		outer.color = Color(accent.r, accent.g, accent.b, 0.25 + dwell_p * 0.55)
	if inner:
		inner.color = Color(1.0, 0.95, 0.8, 0.45 + dwell_p * 0.5)


func _draw_hands(hands: Array) -> void:
	for c in hand_skeleton.get_children():
		c.queue_free()
	var vp := get_viewport_rect().size
	for h in hands:
		var sample: HandTypes.HandSample = h
		if sample.landmarks.size() < 21:
			continue
		var col := GameBus.spell_accent(_gesture.spell)
		if sample.is_fist:
			col = Color(0.85, 0.7, 1.0)
		elif PoseClassifier.score_point(sample) > 0.45:
			col = Color(1.0, 0.95, 0.55)
		for pair in HandTypes.CONNECTIONS:
			var ia: int = pair[0]
			var ib: int = pair[1]
			if not sample.is_joint_valid(ia) or not sample.is_joint_valid(ib):
				continue
			var a: Vector2 = sample.landmarks[ia] * vp
			var b: Vector2 = sample.landmarks[ib] * vp
			var line := Line2D.new()
			line.width = 3.0 if sample.is_fist else 2.2
			line.default_color = Color(col, 0.85)
			line.points = PackedVector2Array([a, b])
			hand_skeleton.add_child(line)
		for i in sample.landmarks.size():
			if not sample.is_joint_valid(i):
				continue
			var p: Vector2 = sample.landmarks[i] * vp
			var dot := Polygon2D.new()
			dot.color = Color(1, 0.95, 0.85) if not sample.is_fist else Color(0.85, 0.9, 1)
			var r := 3.5 if sample.is_fist else 2.8
			if i == HandTypes.LM_INDEX_TIP:
				r = 4.5
				dot.color = Color(1.0, 0.92, 0.4)
			var pts := PackedVector2Array()
			for k in 8:
				var ang := TAU * float(k) / 8.0
				pts.append(p + Vector2(cos(ang), sin(ang)) * r)
			dot.polygon = pts
			hand_skeleton.add_child(dot)


func _sync_palms_menu_or_game(hands: Array) -> void:
	var vp := get_viewport_rect().size
	var show_hands: Array = []
	for h in hands:
		if not h.is_fist:
			show_hands.append(h)
	for i in _palms.size():
		var palm_vfx: PalmVfx = _palms[i]
		palm_vfx.set_spell(_gesture.spell)
		if i < show_hands.size():
			var h: HandTypes.HandSample = show_hands[i]
			var ch: float
			if _playing:
				if _gesture.ritual_channel > 0.05:
					ch = _gesture.ritual_channel
					if _gesture.ritual_active != &"":
						palm_vfx.set_spell(GameBus.element_for(_gesture.ritual_active))
				else:
					ch = maxf(_gesture.charge * (0.4 + h.openness * 0.6), PoseClassifier.score_point(h) * 0.9)
			else:
				ch = maxf(0.45, h.openness * 0.9)
				if start_panel.visible and _dwell_start:
					ch = maxf(ch, 0.35 + _dwell_start.progress * 0.9)
			var aim := h.palm
			if PoseClassifier.score_point(h) > 0.45 and h.landmarks.size() > HandTypes.LM_INDEX_TIP:
				aim = h.landmarks[HandTypes.LM_INDEX_TIP]
			palm_vfx.sync(aim * vp, ch, h.openness)
		else:
			palm_vfx.hide_palm()


func _refresh_hud() -> void:
	lbl_score.text = "分数 %d    击杀 %d    波次 %d" % [game_world.score, game_world.kills, game_world.wave]
	lbl_hp.text = "生命 " + "●".repeat(maxi(game_world.player_hp, 0)) + "○".repeat(maxi(GameWorld.PLAYER_MAX_HP - game_world.player_hp, 0))
	var school := _gesture.spell
	lbl_spell.text = "%s  %s" % [GameBus.spell_badge(school), GameBus.spell_name(school)]
	lbl_spell.add_theme_color_override("font_color", GameBus.spell_accent(school))

	# Charge bar: basic charge, or ritual channel when active
	var bar_v := _gesture.charge
	var bar_col := GameBus.spell_color(school)
	if _gesture.ritual_channel > 0.02 and _gesture.ritual_active != &"":
		bar_v = _gesture.ritual_channel
		bar_col = GameBus.spell_color(_gesture.ritual_active)
		lbl_spell.text = "%s  蓄力 %s" % [
			GameBus.spell_badge(_gesture.ritual_active),
			GameBus.spell_name(_gesture.ritual_active),
		]
		lbl_spell.add_theme_color_override("font_color", GameBus.spell_accent(_gesture.ritual_active))
	charge_bar.value = bar_v * 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = bar_col
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	charge_bar.add_theme_stylebox_override("fill", fill)

	if _playing:
		lbl_debug.text = "[%s] %s  蓄力%.0f%%  手%d  姿%s  仪式%s %.0f%%  %s" % [
			tracker.control_source_label(),
			_phase_name(_gesture.phase),
			_gesture.charge * 100.0,
			_gesture.debug_hands,
			_pose_name(_gesture.pose_label),
			GameBus.spell_name(_gesture.ritual_active) if _gesture.ritual_active != &"" else "-",
			_gesture.ritual_channel * 100.0,
			tracker.vision_status(),
		]
	_refresh_ultimate_buttons()


func _refresh_ultimate_buttons() -> void:
	if btn_ult_blizzard == null:
		return
	_paint_ult_btn(btn_ult_blizzard, GameBus.ULT_BLIZZARD)
	_paint_ult_btn(btn_ult_firestorm, GameBus.ULT_FIRESTORM)
	_paint_ult_btn(btn_ult_chain, GameBus.ULT_CHAIN)


func _paint_ult_btn(btn: Button, ult: StringName) -> void:
	var ready := GameBus.can_cast_ultimate(ult)
	var cd := float(GameBus.ultimate_cd.get(ult, 0.0))
	var name := GameBus.spell_name(ult)
	var badge := GameBus.spell_badge(ult)
	if ready:
		btn.text = "%s %s" % [badge, name]
		btn.modulate = Color(1.05, 1.05, 1.05)
	else:
		btn.text = "%s %s %ds" % [badge, name, ceili(cd)]
		btn.modulate = Color(0.55, 0.55, 0.55)
	btn.disabled = false
	if _gesture.ritual_active == ult:
		btn.modulate = Color(1.2, 1.15, 0.85)


func _pose_name(p: StringName) -> String:
	match p:
		PoseClassifier.POSE_POINT:
			return "指尖"
		PoseClassifier.POSE_OPEN:
			return "开掌"
		PoseClassifier.POSE_FIST:
			return "握拳"
		_:
			return "—"


func _phase_name(p: StringName) -> String:
	match p:
		&"charging":
			return "蓄力中"
		&"cooldown":
			return "发射！"
		_:
			return "准备"


func _on_spell_changed(spell: StringName) -> void:
	for p in _palms:
		(p as PalmVfx).set_spell(spell)
	_refresh_hud()


func _on_defeated(_score: int, _kills: int) -> void:
	game_over_panel.visible = true
	_dwell_restart.reset()
	_dwell_restart.enabled = true
	restart_dwell_bar.value = 0.0
	btn_restart.text = _restart_btn_base_text
	_apply_input_mode(tracker.is_sensing_active())


func _on_restart() -> void:
	game_over_panel.visible = false
	_dwell_restart.reset()
	_playing = false
	_selecting = false
	spell_bar.visible = false
	select_panel.visible = false
	start_panel.visible = true
	btn_start.disabled = false
	_dwell_start.enabled = true
	_dwell_start.reset()
	_gesture.reset()
	GameBus.reset_run_state(GameBus.SPELL_FIRE)
	_apply_input_mode(tracker.is_sensing_active())
	_update_tip()
	_refresh_hud()
