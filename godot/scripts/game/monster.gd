class_name Monster
extends Node2D
## Enemy with status FX: burn (fire), slow (frost). Lightning splash is handled by GameWorld.

var hp: float = 3.0
var max_hp: float = 3.0
var radius: float = 36.0
var velocity_x: float = 60.0
var hit_flash: float = 0.0
var slow_timer: float = 0.0
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var _burn_tick: float = 0.0
var _base_vx: float = 60.0

@onready var body: Polygon2D = $Body
@onready var hp_back: ColorRect = $HpBack
@onready var hp_fill: ColorRect = $HpFill

var _burn_parts: GPUParticles2D
var _frost_ring: Polygon2D
var _status_label: Label


func setup(p_hp: float, p_radius: float, p_vx: float) -> void:
	hp = p_hp
	max_hp = p_hp
	radius = p_radius
	velocity_x = p_vx
	_base_vx = absf(p_vx)
	_rebuild_mesh()
	_ensure_status_fx()


func _ready() -> void:
	_rebuild_mesh()
	_ensure_status_fx()
	_update_hp_bar()


func _rebuild_mesh() -> void:
	if body == null:
		return
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * radius * 0.95, sin(a) * radius * 1.05))
	body.polygon = pts
	body.color = Color(0.42, 0.25, 0.63)
	if has_node("HornL"):
		return
	var hl := Polygon2D.new()
	hl.name = "HornL"
	hl.color = Color(0.79, 0.64, 0.15)
	hl.polygon = PackedVector2Array([
		Vector2(-radius * 0.45, -radius * 0.55),
		Vector2(-radius * 0.7, -radius * 1.15),
		Vector2(-radius * 0.1, -radius * 0.65),
	])
	add_child(hl)
	var hr := Polygon2D.new()
	hr.name = "HornR"
	hr.color = Color(0.79, 0.64, 0.15)
	hr.polygon = PackedVector2Array([
		Vector2(radius * 0.45, -radius * 0.55),
		Vector2(radius * 0.7, -radius * 1.15),
		Vector2(radius * 0.1, -radius * 0.65),
	])
	add_child(hr)
	var e1 := Polygon2D.new()
	e1.name = "EyeL"
	e1.color = Color(1, 0.23, 0.23)
	e1.polygon = _circle(Vector2(-radius * 0.28, -radius * 0.1), 4.0)
	add_child(e1)
	var e2 := Polygon2D.new()
	e2.name = "EyeR"
	e2.color = Color(1, 0.23, 0.23)
	e2.polygon = _circle(Vector2(radius * 0.28, -radius * 0.1), 4.0)
	add_child(e2)

	if hp_back:
		hp_back.position = Vector2(-radius * 0.8, -radius - 18)
		hp_back.size = Vector2(radius * 1.6, 6)
	if hp_fill:
		hp_fill.position = hp_back.position
		hp_fill.size = hp_back.size


func _ensure_status_fx() -> void:
	if _burn_parts == null:
		_burn_parts = GPUParticles2D.new()
		_burn_parts.name = "BurnParts"
		_burn_parts.amount = 18
		_burn_parts.lifetime = 0.45
		_burn_parts.emitting = false
		_burn_parts.local_coords = false
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = maxf(8.0, radius * 0.35)
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 40.0
		pm.initial_velocity_min = 20.0
		pm.initial_velocity_max = 70.0
		pm.gravity = Vector3(0, -30, 0)
		pm.scale_min = 1.5
		pm.scale_max = 3.2
		pm.color = Color(1.0, 0.45, 0.08, 0.9)
		_burn_parts.process_material = pm
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_burn_parts.texture = ImageTexture.create_from_image(img)
		add_child(_burn_parts)

	if _frost_ring == null:
		_frost_ring = Polygon2D.new()
		_frost_ring.name = "FrostRing"
		_frost_ring.color = Color(0.45, 0.85, 1.0, 0.35)
		var ring := PackedVector2Array()
		for i in 20:
			var a := TAU * float(i) / 20.0
			ring.append(Vector2(cos(a), sin(a)) * radius * 1.15)
		_frost_ring.polygon = ring
		_frost_ring.visible = false
		add_child(_frost_ring)

	if _status_label == null:
		_status_label = Label.new()
		_status_label.name = "StatusLabel"
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status_label.add_theme_font_size_override("font_size", 18)
		_status_label.position = Vector2(-40, -radius - 36)
		_status_label.size = Vector2(80, 18)
		add_child(_status_label)


func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func tick(dt: float, screen_w: float) -> float:
	## Returns burn damage dealt this frame (for scoring); 0 if none.
	var burn_dmg := 0.0
	if burn_timer > 0.0:
		burn_timer = maxf(0.0, burn_timer - dt)
		_burn_tick -= dt
		if _burn_tick <= 0.0:
			_burn_tick = 0.35
			var tick_dmg := burn_dps * 0.35
			hp -= tick_dmg
			burn_dmg = tick_dmg
			hit_flash = maxf(hit_flash, 0.12)
		if burn_timer <= 0.0:
			burn_dps = 0.0

	var spd := velocity_x
	var slow_mul := 1.0
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - dt)
		slow_mul = 0.38
		spd *= slow_mul
	position.x += spd * dt
	if position.x < radius or position.x > screen_w - radius:
		velocity_x *= -1.0
		position.x = clampf(position.x, radius, screen_w - radius)
	# Slowed monsters also advance more slowly downward
	position.y += 6.0 * dt * slow_mul
	hit_flash = maxf(0.0, hit_flash - dt)
	_update_body_color()
	_update_status_fx()
	_update_hp_bar()
	return burn_dmg


func apply_hit(damage: float, spell: StringName, power: float = 0.7) -> void:
	hp -= damage
	hit_flash = 0.22
	var element := GameBus.element_for(spell)
	match element:
		GameBus.SPELL_FIRE:
			var burn_mul := 1.35 if GameBus.is_ultimate(spell) else 1.0
			burn_timer = maxf(burn_timer, (2.2 + power * 0.8) * burn_mul)
			burn_dps = maxf(burn_dps, (0.55 + power * 0.55) * burn_mul)
			_burn_tick = minf(_burn_tick, 0.05)
		GameBus.SPELL_FROST:
			var slow_mul := 1.4 if GameBus.is_ultimate(spell) else 1.0
			slow_timer = maxf(slow_timer, (1.8 + power * 0.6) * slow_mul)
			var sign := 1.0 if velocity_x >= 0.0 else -1.0
			velocity_x = sign * maxf(absf(velocity_x) * 0.7, _base_vx * 0.28)
	_update_hp_bar()
	_update_status_fx()


func _update_body_color() -> void:
	if body == null:
		return
	var c := Color(0.42, 0.25, 0.63)
	if burn_timer > 0.0:
		c = c.lerp(Color(1.0, 0.35, 0.08), 0.55)
	if slow_timer > 0.0:
		c = c.lerp(Color(0.35, 0.75, 1.0), 0.5)
	if hit_flash > 0.0:
		c = c.lerp(Color(1.0, 0.85, 0.85), clampf(hit_flash / 0.22, 0.0, 1.0))
	body.color = c


func _update_status_fx() -> void:
	if _burn_parts:
		_burn_parts.emitting = burn_timer > 0.0
	if _frost_ring:
		_frost_ring.visible = slow_timer > 0.0
		if _frost_ring.visible:
			_frost_ring.modulate.a = 0.25 + 0.2 * sin(Time.get_ticks_msec() * 0.012)
	if _status_label:
		var tags: PackedStringArray = []
		if burn_timer > 0.0:
			tags.append("灼烧")
		if slow_timer > 0.0:
			tags.append("减速")
		_status_label.text = " ".join(tags)
		if burn_timer > 0.0:
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
		elif slow_timer > 0.0:
			_status_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))


func _update_hp_bar() -> void:
	if hp_fill == null or hp_back == null:
		return
	var t := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	hp_fill.size.x = hp_back.size.x * t
