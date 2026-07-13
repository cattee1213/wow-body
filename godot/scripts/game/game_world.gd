class_name GameWorld
extends Node2D
## Monsters, projectiles, scoring.

signal state_changed
signal player_hit
signal defeated(score: int, kills: int)

const PLAYER_MAX_HP := 5
const MONSTER_BASE_HP := 3
const BASE_SPEED := 820.0

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
var _monster_scene_body := true

@onready var monster_layer: Node2D = $MonsterLayer
@onready var projectile_layer: Node2D = $ProjectileLayer
@onready var fx_layer: Node2D = $FxLayer


func _ready() -> void:
	message = "开掌蓄力，向前推掌释放 · 握拳切换法术"
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
	message = "重新开始！开掌蓄力，推掌释放"
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

	# monsters
	var survivors: Array = []
	for m in _monsters:
		if not is_instance_valid(m):
			continue
		m.tick(dt, vp.x)
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
				var dmg: float = p.damage()
				m.apply_hit(dmg, p.spell)
				_burst(p.position, GameBus.spell_color(p.spell), 16 + int(p.power * 8))
				score += int(10 * dmg)
				if m.hp <= 0.0:
					kills += 1
					score += 40
					_burst(m.position, GameBus.spell_accent(p.spell), 26)
					shake = 0.25
				hit = true
				break
		if hit or not alive or p.position.y < -60 or p.position.y > vp.y + 60:
			p.queue_free()
		else:
			live_p.append(p)
	_projectiles = live_p

	# camera shake
	position = Vector2(
		randf_range(-1, 1) * shake * 14.0,
		randf_range(-1, 1) * shake * 14.0
	)

	if player_hp <= 0:
		player_hp = 0
		game_over = true
		message = "你被击溃了 — 按 R 或点击重开"
		message_ttl = 99.0
		emit_signal("defeated", score, kills)
		emit_signal("state_changed")


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
	var vx := ( -1.0 if randf() < 0.5 else 1.0) * (40.0 + wave * 8.0)
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
	# auto free
	get_tree().create_timer(0.8).timeout.connect(parts.queue_free)
