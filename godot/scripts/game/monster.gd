class_name Monster
extends Node2D

var hp: float = 3.0
var max_hp: float = 3.0
var radius: float = 36.0
var velocity_x: float = 60.0
var hit_flash: float = 0.0
var slow_timer: float = 0.0

@onready var body: Polygon2D = $Body
@onready var hp_back: ColorRect = $HpBack
@onready var hp_fill: ColorRect = $HpFill


func setup(p_hp: float, p_radius: float, p_vx: float) -> void:
	hp = p_hp
	max_hp = p_hp
	radius = p_radius
	velocity_x = p_vx
	_rebuild_mesh()


func _ready() -> void:
	_rebuild_mesh()
	_update_hp_bar()


func _rebuild_mesh() -> void:
	if body == null:
		return
	var pts := PackedVector2Array()
	# Soft ellipse body
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * radius * 0.95, sin(a) * radius * 1.05))
	body.polygon = pts
	body.color = Color(0.42, 0.25, 0.63)
	# horns as child polygons created once
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
	# eyes
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


func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func tick(dt: float, screen_w: float) -> bool:
	## Returns true if broke through (damage player).
	var spd := velocity_x
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - dt)
		spd *= 0.45
	position.x += spd * dt
	if position.x < radius or position.x > screen_w - radius:
		velocity_x *= -1.0
		position.x = clampf(position.x, radius, screen_w - radius)
	position.y += 6.0 * dt
	hit_flash = maxf(0.0, hit_flash - dt)
	if body:
		body.color = Color(0.9, 0.4, 0.4) if hit_flash > 0.0 else Color(0.42, 0.25, 0.63)
	_update_hp_bar()
	return false


func apply_hit(damage: float, spell: StringName) -> void:
	hp -= damage
	hit_flash = 0.2
	if spell == GameBus.SPELL_FROST:
		slow_timer = 1.4
		velocity_x *= 0.7
	_update_hp_bar()


func _update_hp_bar() -> void:
	if hp_fill == null or hp_back == null:
		return
	var t := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	hp_fill.size.x = hp_back.size.x * t
