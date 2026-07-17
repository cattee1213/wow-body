class_name GameWorld
extends Node2D
## Monsters, projectiles, scoring, spell on-hit FX (burn / slow / splash).

signal state_changed
signal player_hit
signal defeated(score: int, kills: int)
## Emitted when a wave is cleared and player should pick an upgrade.
signal wave_cleared(completed_wave: int)

const PLAYER_MAX_HP := 5
const MONSTER_BASE_HP := 3
const BASE_SPEED := 1190.0
## Kills required to clear a wave (longer waves for body play).
const KILLS_PER_WAVE := 12
## Rain bolt size vs basic (~72–96px): clearly larger to sell ultimate power.
const RAIN_SIZE_MIN := 130.0
const RAIN_SIZE_MAX := 210.0

var score: int = 0
var kills: int = 0
var wave: int = 1
var player_hp: int = PLAYER_MAX_HP
var game_over: bool = false
## Combat paused for upgrade pick (no spawn / no cast).
var awaiting_upgrade: bool = false
var message: String = ""
var message_ttl: float = 0.0
var elapsed: float = 0.0
var spawn_timer: float = 0.6
var shake: float = 0.0

var _monsters: Array = []
var _projectiles: Array = []
var _ultimates: Array = [] # Dictionary active fields
var _sfx: SfxPlayer
var _wave_offer_pending: bool = false

@onready var monster_layer: Node2D = $MonsterLayer
@onready var projectile_layer: Node2D = $ProjectileLayer
@onready var fx_layer: Node2D = $FxLayer


func _ready() -> void:
	_sfx = SfxPlayer.new()
	add_child(_sfx)
	message = "指尖即射 · 双手仪式放终极"
	message_ttl = 4.0
	emit_signal("state_changed")


func restart() -> void:
	for m in _monsters:
		if is_instance_valid(m):
			m.queue_free()
	for p in _projectiles:
		if is_instance_valid(p):
			p.queue_free()
	_clear_ultimates()
	_monsters.clear()
	_projectiles.clear()
	score = 0
	kills = 0
	wave = 1
	player_hp = PLAYER_MAX_HP
	game_over = false
	awaiting_upgrade = false
	_wave_offer_pending = false
	spawn_timer = 0.6
	elapsed = 0.0
	shake = 0.0
	message = "指尖即射 · 双手仪式释放终极"
	message_ttl = 2.5
	emit_signal("state_changed")


func _clear_ultimates() -> void:
	for u in _ultimates:
		if u is Dictionary and u.has("root") and is_instance_valid(u["root"]):
			(u["root"] as Node).queue_free()
	_ultimates.clear()


func cast_spell(from_norm: Vector2, spell: StringName, power: float) -> void:
	if game_over or awaiting_upgrade:
		return
	var vp := get_viewport_rect().size
	var palm := Vector2(from_norm.x * vp.x, from_norm.y * vp.y)
	var dir := _aim_dir_from_palm(palm)
	# 分裂 = parallel fan; 连发 = serial volleys
	var volleys: int = GameBus.upgrades.roll_multishot_volleys()
	_fire_split_volley(palm, spell, power, dir)
	for i in range(1, volleys):
		var delay := 0.08 * float(i)
		var captured_palm := palm
		var captured_dir := dir
		var captured_spell := spell
		var captured_power := power
		get_tree().create_timer(delay).timeout.connect(func():
			if game_over or awaiting_upgrade or not is_instance_valid(self):
				return
			_fire_split_volley(captured_palm, captured_spell, captured_power, captured_dir)
		)

	_spawn_cast_flash(palm, spell, power)
	if _sfx:
		_sfx.play_spell(spell)
	var tag := GameBus.spell_cast_text(spell)
	if volleys > 1:
		message = "%s 连发×%d" % [tag, volleys]
	else:
		message = tag
	message_ttl = 0.55
	emit_signal("state_changed")


func _fire_split_volley(palm: Vector2, spell: StringName, power: float, dir: Vector2) -> void:
	## Main ray always along `dir` (angle 0). Side pellets optional & probabilistic.
	var angles: PackedFloat32Array = GameBus.upgrades.split_angles_for_volley()
	for a in angles:
		var shot_dir := dir if absf(a) < 0.0001 else dir.rotated(a)
		_spawn_projectile(palm, spell, power, shot_dir)


func _aim_dir_from_palm(palm: Vector2) -> Vector2:
	var target := Vector2(palm.x, 48.0)
	var best := INF
	for m in _monsters:
		if not is_instance_valid(m) or m.hp <= 0.0:
			continue
		var d: float = palm.distance_to(m.position)
		if m.position.y > palm.y + 20.0:
			d *= 1.35
		if d < best:
			best = d
			target = m.position
	var dir := (target - palm)
	if dir.length_squared() < 0.001:
		dir = Vector2(0, -1)
	return dir.normalized()


func _spawn_projectile(palm: Vector2, spell: StringName, power: float, dir: Vector2) -> void:
	var origin := palm + dir * 28.0
	var speed := BASE_SPEED * (1.0 + clampf(power, 0.0, 1.0) * 0.2)
	var proj := SpellProjectile.new()
	projectile_layer.add_child(proj)
	proj.global_position = origin
	proj.setup(spell, power, dir, speed)
	_projectiles.append(proj)


func cast_ultimate(ult: StringName, power: float = 1.0) -> bool:
	if game_over or awaiting_upgrade or not GameBus.is_ultimate(ult):
		return false
	if not GameBus.can_cast_ultimate(ult):
		return false
	GameBus.start_ultimate_cooldown(ult)
	var p := clampf(power, 0.5, 1.0)
	match ult:
		GameBus.ULT_BLIZZARD, GameBus.ULT_FIRESTORM:
			_begin_field_ultimate(ult, p)
		_:
			return false
	if _sfx:
		_sfx.play_spell(ult)
	message = GameBus.spell_cast_text(ult)
	message_ttl = 1.4
	shake = maxf(shake, 0.55)
	emit_signal("state_changed")
	return true


func resume_after_upgrade() -> void:
	awaiting_upgrade = false
	_wave_offer_pending = false
	spawn_timer = 0.45
	message = "第 %d 波来袭！" % wave
	message_ttl = 1.6
	emit_signal("state_changed")


func _begin_field_ultimate(ult: StringName, power: float) -> void:
	var meta: Dictionary = GameBus.SPELL_META[ult]
	var duration := float(meta.get("duration", 3.0))
	var tick := float(meta.get("tick", 0.3))
	var dmg: float = float(meta.get("damage", 0.8)) * (0.85 + power * 0.3) * float(GameBus.upgrades.damage_mult)
	var vp := get_viewport_rect().size
	var root := _spawn_ultimate_overlay(ult, vp, power)
	# Opening volley: dense rain of oversized basic projectiles
	for i in 14:
		_spawn_rain_bolt(root, ult, vp, power, true)
	_ultimates.append({
		"id": ult,
		"t": 0.0,
		"duration": duration,
		"tick": tick,
		"tick_left": 0.05,
		"damage": dmg,
		"power": power,
		"root": root,
		"rain_left": 0.0,
	})
	# Immediate first pulse
	_pulse_field_ultimate(ult, dmg, power)


func _pulse_field_ultimate(ult: StringName, dmg: float, power: float) -> void:
	var to_kill: Array = []
	var element := GameBus.element_for(ult)
	for m in _monsters:
		if not is_instance_valid(m) or m.hp <= 0.0:
			continue
		m.apply_hit(dmg, ult, power)
		score += int(8 * dmg)
		# Impact uses basic-school frames (scaled up for ultimate punch)
		_spawn_impact(m.position, element, clampf(power + 0.35, 0.7, 1.2))
		if ult == GameBus.ULT_FIRESTORM:
			_ember(m.position)
		elif ult == GameBus.ULT_BLIZZARD:
			_frost_burst(m.position)
		if m.hp <= 0.0:
			to_kill.append(m)
	for m in to_kill:
		_kill_monster(m, ult)


func _spawn_ultimate_overlay(ult: StringName, vp: Vector2, power: float = 1.0) -> Node2D:
	## No dedicated ultimate atlas — rain of basic projectiles + color wash.
	var root := Node2D.new()
	root.z_index = 8
	root.position = Vector2.ZERO
	fx_layer.add_child(root)

	# Soft screen wash (element tint)
	var wash := ColorRect.new()
	wash.name = "Wash"
	wash.size = vp * 1.15
	wash.position = Vector2(-vp.x * 0.075, -vp.y * 0.075)
	var wc := GameBus.spell_color(ult)
	wc.a = 0.16 + power * 0.04
	wash.color = wc
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.z_index = -2
	root.add_child(wash)
	var tw := create_tween()
	tw.tween_property(wash, "color:a", 0.06, 0.55)

	return root


func _spawn_rain_bolt(
	root: Node2D,
	ult: StringName,
	vp: Vector2,
	power: float,
	opening: bool = false
) -> void:
	if not is_instance_valid(root):
		return
	SpellVfxLibrary.ensure_loaded()
	var element := GameBus.element_for(ult)
	var frames: Array = SpellVfxLibrary.get_frames(element, SpellVfxLibrary.STATE_PROJECTILE)
	if frames.is_empty():
		return
	var tex: Texture2D = frames[0]

	var bolt := Sprite2D.new()
	bolt.centered = true
	bolt.texture = tex
	bolt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bolt.z_index = 1

	# Spawn above the viewport; slight x jitter so columns don't look uniform.
	var x := randf_range(-20.0, vp.x + 20.0)
	var y := randf_range(-160.0, -40.0) if opening else randf_range(-180.0, -30.0)
	if opening:
		# Opening volley also seeds mid-screen for instant density.
		if randf() < 0.35:
			y = randf_range(-40.0, vp.y * 0.35)
	bolt.position = Vector2(x, y)

	# Tip points +X in art → rotate so bolts fall downward (with slight tilt).
	var tilt := randf_range(-0.22, 0.22)
	bolt.rotation = PI * 0.5 + tilt

	var size_px := randf_range(RAIN_SIZE_MIN, RAIN_SIZE_MAX) * (0.9 + power * 0.2)
	var longest := maxf(tex.get_size().x, tex.get_size().y)
	var s := size_px / maxf(longest, 1.0)
	bolt.scale = Vector2(s, s)
	bolt.modulate = Color(1, 1, 1, randf_range(0.72, 0.98))

	# Soft ghost trail (reuse same projectile art)
	var ghost := Sprite2D.new()
	ghost.centered = true
	ghost.texture = tex
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ghost.modulate = Color(1, 1, 1, 0.28)
	ghost.z_index = -1
	ghost.scale = Vector2(s * 0.88, s * 0.88)
	ghost.position = Vector2(-18.0, 0.0) # behind tip in local +X frame
	bolt.add_child(ghost)

	root.add_child(bolt)

	# Fall speed: fire rain slightly faster; both larger → feel heavy.
	var fall_speed := randf_range(520.0, 820.0)
	if ult == GameBus.ULT_FIRESTORM:
		fall_speed *= 1.12
	var drift := randf_range(-60.0, 60.0)
	var fall_dist := vp.y - y + 120.0
	var fall_time := clampf(fall_dist / fall_speed, 0.45, 1.8)

	var end := Vector2(x + drift, vp.y + 80.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bolt, "position", end, fall_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(bolt, "modulate:a", 0.15, fall_time)
	tw.chain().tween_callback(func():
		if is_instance_valid(bolt):
			# Occasional ground splash (basic impact) — sparse to avoid FX spam
			if randf() < 0.22:
				_spawn_impact(Vector2(end.x, vp.y * randf_range(0.72, 0.95)), element, 0.5)
			bolt.queue_free()
	)


func _tick_ultimates(dt: float) -> void:
	if _ultimates.is_empty():
		return
	var vp := get_viewport_rect().size
	var live: Array = []
	for u in _ultimates:
		if not (u is Dictionary):
			continue
		u["t"] = float(u["t"]) + dt
		var root: Node2D = u.get("root", null)
		var ult: StringName = u["id"]
		var power := float(u["power"])

		# Continuous rain of basic projectiles while field is active
		if is_instance_valid(root) and float(u["t"]) < float(u["duration"]):
			u["rain_left"] = float(u.get("rain_left", 0.0)) - dt
			if float(u["rain_left"]) <= 0.0:
				# ~12–16 bolts/sec depending on element
				var interval := 0.07 if ult == GameBus.ULT_FIRESTORM else 0.08
				u["rain_left"] = interval
				var burst := 2 if randf() < 0.45 else 1
				for i in burst:
					_spawn_rain_bolt(root, ult, vp, power, false)
			# Pulse wash alpha gently
			var wash := root.get_node_or_null("Wash") as ColorRect
			if wash:
				var base_a := 0.05 + 0.04 * (0.5 + 0.5 * sin(elapsed * 5.0))
				wash.color.a = base_a

		u["tick_left"] = float(u["tick_left"]) - dt
		if float(u["tick_left"]) <= 0.0:
			u["tick_left"] = float(u["tick"])
			_pulse_field_ultimate(ult, float(u["damage"]), power)
		if float(u["t"]) < float(u["duration"]):
			live.append(u)
		else:
			if is_instance_valid(root):
				var tw := create_tween()
				tw.tween_property(root, "modulate:a", 0.0, 0.3)
				tw.tween_callback(root.queue_free)
	_ultimates = live


func _physics_process(dt: float) -> void:
	if game_over:
		shake = maxf(0.0, shake - dt * 8.0)
		return

	elapsed += dt
	shake = maxf(0.0, shake - dt * 10.0)
	if message_ttl > 0.0:
		message_ttl -= dt

	if awaiting_upgrade:
		# Freeze combat during pick: no spawn, no monster advance, no new ultimates tick lightly
		position = Vector2.ZERO
		return

	_tick_ultimates(dt)

	var vp := get_viewport_rect().size
	# More on-screen monsters, slightly faster respawn → longer, denser waves.
	var target_count := mini(3 + int(wave * 0.75), 9)
	spawn_timer -= dt
	if _monsters.size() < target_count and spawn_timer <= 0.0:
		_spawn_monster(vp)
		spawn_timer = maxf(0.55, 1.65 - wave * 0.08)

	if kills > 0 and kills % KILLS_PER_WAVE == 0:
		var expected := 1 + int(kills / float(KILLS_PER_WAVE))
		if expected > wave and not _wave_offer_pending:
			var completed := wave
			wave = expected
			_wave_offer_pending = true
			awaiting_upgrade = true
			message = "第 %d 波清除！选择强化" % completed
			message_ttl = 2.5
			emit_signal("state_changed")
			emit_signal("wave_cleared", completed)
			return

	# monsters (+ burn DoT scoring)
	var survivors: Array = []
	for m in _monsters:
		if not is_instance_valid(m):
			continue
		var burn_dmg: float = m.tick(dt, vp.x)
		if burn_dmg > 0.0:
			score += int(6 * burn_dmg)
			_ember(m.position)
		if m.position.y > vp.y * 0.55:
			player_hp -= 1
			shake = 0.5
			_burst(m.position, Color(1, 0.3, 0.3), 14)
			message = "怪物突破防线！"
			message_ttl = 1.2
			m.queue_free()
			emit_signal("player_hit")
			emit_signal("state_changed")
			continue
		if m.hp <= 0.0:
			# Burn DoT kill (already not erased)
			kills += 1
			score += 40
			_burst(m.position, Color(1.0, 0.5, 0.15), 22)
			m.queue_free()
			continue
		survivors.append(m)
	_monsters = survivors

	# projectiles
	var live_p: Array = []
	for p in _projectiles:
		if not is_instance_valid(p):
			continue
		var alive: bool = p.tick(dt, elapsed)
		var hit := false
		for m in _monsters:
			if not is_instance_valid(m):
				continue
			if p.position.distance_to(m.position) < p.radius + m.radius * 0.85:
				_apply_projectile_hit(p, m)
				hit = true
				break
		if hit or not alive or p.position.y < -60 or p.position.y > vp.y + 60:
			p.queue_free()
		else:
			live_p.append(p)
	_projectiles = live_p

	position = Vector2(
		randf_range(-1, 1) * shake * 14.0,
		randf_range(-1, 1) * shake * 14.0
	)

	if player_hp <= 0:
		player_hp = 0
		game_over = true
		message = "你被击溃了 — 把手放在重开按钮上停 2 秒"
		message_ttl = 99.0
		emit_signal("defeated", score, kills)
		emit_signal("state_changed")


func _apply_projectile_hit(p: SpellProjectile, primary: Monster) -> void:
	var dmg: float = p.damage()
	primary.apply_hit(dmg, p.spell, p.power)
	_spawn_impact(p.position, p.spell, p.power)
	score += int(10 * dmg)

	if p.spell == GameBus.SPELL_FIRE:
		message = "灼烧！"
		message_ttl = 0.55
	elif p.spell == GameBus.SPELL_FROST:
		message = "减速！"
		message_ttl = 0.55

	if primary.hp <= 0.0:
		_kill_monster(primary, p.spell)


func _kill_monster(m: Monster, spell: StringName = GameBus.SPELL_FIRE) -> void:
	if not is_instance_valid(m):
		return
	kills += 1
	score += 40
	_spawn_impact(m.position, spell, 0.95)
	shake = maxf(shake, 0.25)
	_monsters.erase(m)
	m.queue_free()


func _spawn_monster(vp: Vector2) -> void:
	var m := _make_monster()
	monster_layer.add_child(m)
	var margin := 60.0
	m.position = Vector2(
		randf_range(margin, maxf(margin + 10.0, vp.x - margin)),
		randf_range(70.0, minf(190.0, vp.y * 0.18 + 70.0))
	)
	var hp := MONSTER_BASE_HP + int((wave - 1) / 2.0)
	var rad := 34.0 + minf(10.0, float(wave))
	var vx := (-1.0 if randf() < 0.5 else 1.0) * (40.0 + wave * 8.0)
	m.setup(hp, rad, vx)
	_monsters.append(m)


func _make_monster() -> Monster:
	var m := Monster.new()
	var body := Polygon2D.new()
	body.name = "Body"
	m.add_child(body)
	var hp_back := ColorRect.new()
	hp_back.name = "HpBack"
	hp_back.color = Color(0, 0, 0, 0.55)
	m.add_child(hp_back)
	var hp_fill := ColorRect.new()
	hp_fill.name = "HpFill"
	hp_fill.color = Color(0.9, 0.3, 0.3)
	m.add_child(hp_fill)
	return m


func _spawn_cast_flash(pos: Vector2, spell: StringName, power: float) -> void:
	## 出手爆发：charge 漩涡放大 + hold 闪光（双层叠加）。
	SpellVfxLibrary.ensure_loaded()
	var charge_frames := SpellVfxLibrary.get_frames(spell, SpellVfxLibrary.STATE_CHARGE)
	var hold_frames := SpellVfxLibrary.get_frames(spell, SpellVfxLibrary.STATE_HOLD)
	var node := Node2D.new()
	node.position = pos
	fx_layer.add_child(node)

	if charge_frames.size() > 0:
		var a := AnimatedVfxSprite.new()
		a.setup(charge_frames, 24.0, false, 64.0 + power * 28.0)
		node.add_child(a)
	if hold_frames.size() > 0:
		var b := AnimatedVfxSprite.new()
		b.setup(hold_frames, 20.0, false, 54.0 + power * 20.0)
		b.modulate = Color(1, 1, 1, 0.85)
		node.add_child(b)

	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.55, 1.55), 0.14).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "modulate:a", 0.0, 0.22)
	tw.tween_callback(node.queue_free)


func _spawn_impact(pos: Vector2, spell: StringName, power: float = 0.7) -> void:
	## 击中：主 impact 动画 + 放大层 + 轻微屏幕震（多层合成）。
	SpellVfxLibrary.ensure_loaded()
	var frames := SpellVfxLibrary.get_frames(spell, SpellVfxLibrary.STATE_IMPACT)
	if frames.is_empty():
		return

	var root := Node2D.new()
	root.position = pos
	fx_layer.add_child(root)

	# Main impact animation
	var main := AnimatedVfxSprite.new()
	main.setup(frames, 18.0, false, 86.0 + power * 36.0)
	root.add_child(main)

	# Second layer: flash (first frame)
	var flash := Sprite2D.new()
	flash.centered = true
	flash.texture = frames[0]
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var longest := maxf(frames[0].get_size().x, frames[0].get_size().y)
	var fs := (96.0 + power * 36.0) / maxf(longest, 1.0)
	flash.scale = Vector2(fs, fs) * 0.6
	flash.modulate = Color(1, 1, 1, 0.75)
	flash.z_index = -1
	root.add_child(flash)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector2(fs, fs) * 1.35, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, 0.2)
	tw.tween_property(root, "scale", Vector2(1.15, 1.15), 0.1)
	tw.chain().tween_interval(0.05)

	main.anim_finished.connect(func():
		if is_instance_valid(root):
			var tw2 := create_tween()
			tw2.tween_property(root, "modulate:a", 0.0, 0.08)
			tw2.tween_callback(root.queue_free)
	)
	get_tree().create_timer(0.9).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free()
	)
	shake = maxf(shake, 0.12 + power * 0.1)

func _burst(pos: Vector2, color: Color, count: int) -> void:
	var parts := GPUParticles2D.new()
	parts.one_shot = true
	parts.emitting = false
	parts.amount = count
	parts.lifetime = 0.55
	parts.explosiveness = 0.95
	parts.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 4.0
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 180.0
	pm.gravity = Vector3(0, 120, 0)
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	pm.color = color
	parts.process_material = pm
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	parts.texture = ImageTexture.create_from_image(img)
	fx_layer.add_child(parts)
	parts.emitting = true
	get_tree().create_timer(0.8).timeout.connect(parts.queue_free)


func _ember(pos: Vector2) -> void:
	_burst(pos + Vector2(randf_range(-8, 8), randf_range(-6, 6)), Color(1.0, 0.4, 0.05, 0.85), 6)


func _frost_burst(pos: Vector2) -> void:
	var parts := GPUParticles2D.new()
	parts.one_shot = true
	parts.emitting = false
	parts.amount = 22
	parts.lifetime = 0.65
	parts.explosiveness = 0.9
	parts.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 6.0
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 120.0
	pm.gravity = Vector3(0, 40, 0)
	pm.scale_min = 1.5
	pm.scale_max = 4.0
	pm.color = Color(0.55, 0.9, 1.0)
	parts.process_material = pm
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	parts.texture = ImageTexture.create_from_image(img)
	fx_layer.add_child(parts)
	parts.emitting = true
	get_tree().create_timer(0.9).timeout.connect(parts.queue_free)


func _hit_ring(pos: Vector2, spell: StringName) -> void:
	var ring := Polygon2D.new()
	var col := GameBus.spell_accent(spell)
	col.a = 0.55
	ring.color = col
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * 12.0)
	ring.polygon = pts
	ring.position = pos
	fx_layer.add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.28).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.tween_callback(ring.queue_free)


func _chain_bolt(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 4.5
	line.default_color = Color(0.95, 0.9, 0.35, 0.95)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	# Jagged lightning path
	var mid := (from + to) * 0.5
	var perp := (to - from).orthogonal().normalized()
	var j1 := mid + perp * randf_range(-28, 28)
	var j2 := mid * 0.5 + to * 0.5 + perp * randf_range(-18, 18)
	line.points = PackedVector2Array([from, j1, j2, to])
	fx_layer.add_child(line)
	# glow twin
	var glow := Line2D.new()
	glow.width = 10.0
	glow.default_color = Color(0.7, 0.55, 1.0, 0.35)
	glow.points = line.points
	fx_layer.add_child(glow)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(glow, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		line.queue_free()
		glow.queue_free()
	)
