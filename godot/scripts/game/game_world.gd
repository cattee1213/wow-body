class_name GameWorld
extends Node2D
## Monsters, projectiles, scoring, spell on-hit FX (burn / slow / splash).

signal state_changed
signal player_hit
signal defeated(score: int, kills: int)

const PLAYER_MAX_HP := 5
const MONSTER_BASE_HP := 3
const BASE_SPEED := 820.0
const LIGHTNING_SPLASH_RADIUS := 170.0
const LIGHTNING_SPLASH_RATIO := 0.55

var score: int = 0
var kills: int = 0
var wave: int = 1
var player_hp: int = PLAYER_MAX_HP
var game_over: bool = false
var message: String = ""
var message_ttl: float = 0.0
var elapsed: float = 0.0
var spawn_timer: float = 0.6
var shake: float = 0.0

var _monsters: Array = []
var _projectiles: Array = []
var _sfx: SfxPlayer

@onready var monster_layer: Node2D = $MonsterLayer
@onready var projectile_layer: Node2D = $ProjectileLayer
@onready var fx_layer: Node2D = $FxLayer


func _ready() -> void:
	_sfx = SfxPlayer.new()
	add_child(_sfx)
	message = "纯体感：移动手掌瞄准 · 自动发射 · 悬停切法术"
	message_ttl = 4.0
	emit_signal("state_changed")


func restart() -> void:
	for m in _monsters:
		if is_instance_valid(m):
			m.queue_free()
	for p in _projectiles:
		if is_instance_valid(p):
			p.queue_free()
	_monsters.clear()
	_projectiles.clear()
	score = 0
	kills = 0
	wave = 1
	player_hp = PLAYER_MAX_HP
	game_over = false
	spawn_timer = 0.6
	elapsed = 0.0
	shake = 0.0
	message = "重新开始！移动手掌瞄准，自动发射"
	message_ttl = 2.5
	emit_signal("state_changed")


func cast_spell(from_norm: Vector2, spell: StringName, power: float) -> void:
	if game_over:
		return
	var vp := get_viewport_rect().size
	var origin := Vector2(from_norm.x * vp.x, from_norm.y * vp.y)
	var target := Vector2(origin.x, 40.0)
	var best := INF
	for m in _monsters:
		if not is_instance_valid(m):
			continue
		var d: float = origin.distance_to(m.position)
		if d < best:
			best = d
			target = m.position

	var dir := (target - origin)
	if dir.length_squared() < 0.001:
		dir = Vector2(0, -1)
	var speed := BASE_SPEED * (0.9 + clampf(power, 0.0, 1.0) * 0.25)
	var proj := SpellProjectile.new()
	projectile_layer.add_child(proj)
	proj.global_position = origin
	proj.setup(spell, power, dir, speed)
	_projectiles.append(proj)

	_burst(origin, GameBus.spell_accent(spell), 12 + int(power * 10))
	if _sfx:
		_sfx.play_spell(spell)
	message = GameBus.spell_cast_text(spell)
	message_ttl = 0.75
	emit_signal("state_changed")


func _physics_process(dt: float) -> void:
	if game_over:
		shake = maxf(0.0, shake - dt * 8.0)
		return

	elapsed += dt
	shake = maxf(0.0, shake - dt * 10.0)
	if message_ttl > 0.0:
		message_ttl -= dt

	var vp := get_viewport_rect().size
	var target_count := mini(2 + int(wave / 2.0), 6)
	spawn_timer -= dt
	if _monsters.size() < target_count and spawn_timer <= 0.0:
		_spawn_monster(vp)
		spawn_timer = maxf(0.8, 2.2 - wave * 0.12)

	if kills > 0 and kills % 5 == 0:
		var expected := 1 + int(kills / 5.0)
		if expected > wave:
			wave = expected
			message = "第 %d 波来袭！" % wave
			message_ttl = 2.0
			emit_signal("state_changed")

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
	_burst(p.position, GameBus.spell_color(p.spell), 16 + int(p.power * 8))
	_hit_ring(primary.position, p.spell)
	score += int(10 * dmg)

	if p.spell == GameBus.SPELL_FIRE:
		message = "灼烧！"
		message_ttl = 0.55
	elif p.spell == GameBus.SPELL_FROST:
		message = "减速！"
		message_ttl = 0.55
		_frost_burst(primary.position)
	elif p.spell == GameBus.SPELL_LIGHTNING:
		_lightning_splash(primary, dmg, p.power)
		message = "闪电溅射！"
		message_ttl = 0.6

	if primary.hp <= 0.0:
		_kill_monster(primary, GameBus.spell_accent(p.spell))


func _lightning_splash(primary: Monster, base_dmg: float, power: float) -> void:
	var splash_dmg := maxf(0.5, base_dmg * LIGHTNING_SPLASH_RATIO * (0.85 + power * 0.3))
	var radius := LIGHTNING_SPLASH_RADIUS * (0.9 + power * 0.25)
	var targets: Array = []
	for m in _monsters:
		if not is_instance_valid(m) or m == primary or m.hp <= 0.0:
			continue
		if primary.position.distance_to(m.position) <= radius:
			targets.append(m)
	# Closest first, max 3 splash targets
	targets.sort_custom(func(a, b): return primary.position.distance_to(a.position) < primary.position.distance_to(b.position))
	var n := mini(targets.size(), 3)
	for i in n:
		var m: Monster = targets[i]
		if not is_instance_valid(m) or m.hp <= 0.0:
			continue
		m.apply_hit(splash_dmg, GameBus.SPELL_LIGHTNING, power * 0.7)
		score += int(8 * splash_dmg)
		_chain_bolt(primary.position, m.position)
		_burst(m.position, GameBus.spell_accent(GameBus.SPELL_LIGHTNING), 12)
		if m.hp <= 0.0:
			_kill_monster(m, GameBus.spell_core(GameBus.SPELL_LIGHTNING))
	if n > 0:
		shake = maxf(shake, 0.18)


func _kill_monster(m: Monster, burst_color: Color) -> void:
	if not is_instance_valid(m):
		return
	kills += 1
	score += 40
	_burst(m.position, burst_color, 26)
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
