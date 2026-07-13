class_name PalmVfx
extends Node2D
## Palm charge aura driven by charge + openness, colored by spell.

var spell: StringName = GameBus.SPELL_FIRE
var charge: float = 0.0
var openness: float = 0.0

var _sprite: Sprite2D
var _mat: ShaderMaterial
var _particles: GPUParticles2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.centered = true
	_sprite.scale = Vector2(140, 160)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/palm_aura.gdshader")
	_sprite.material = _mat
	add_child(_sprite)

	_particles = GPUParticles2D.new()
	_particles.amount = 18
	_particles.lifetime = 0.6
	_particles.position = Vector2(0, -10)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 10.0
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 50.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 70.0
	pm.gravity = Vector3(0, -20, 0)
	pm.scale_min = 1.2
	pm.scale_max = 2.8
	_particles.process_material = pm
	_particles.texture = _sprite.texture
	add_child(_particles)
	_apply_spell()
	visible = false


func set_spell(s: StringName) -> void:
	spell = s
	_apply_spell()


func sync(world_pos: Vector2, p_charge: float, p_open: float) -> void:
	global_position = world_pos
	charge = p_charge
	openness = p_open
	var power := maxf(charge, openness * 0.7)
	if power < 0.05:
		visible = false
		if _particles:
			_particles.emitting = false
		return
	visible = true
	if _particles:
		_particles.emitting = true
	var scale_mul := 0.25 + _smooth(power) * 2.35
	_sprite.scale = Vector2(120, 140) * scale_mul
	if _mat:
		_mat.set_shader_parameter("charge", charge)
		_mat.set_shader_parameter("openness", openness)
	modulate.a = clampf(0.2 + power * 0.9, 0.0, 1.0)


func hide_palm() -> void:
	visible = false
	if _particles:
		_particles.emitting = false


func _apply_spell() -> void:
	if _mat == null:
		return
	var mode := 0
	if spell == GameBus.SPELL_FROST:
		mode = 1
	elif spell == GameBus.SPELL_LIGHTNING:
		mode = 2
	_mat.set_shader_parameter("mode", mode)
	_mat.set_shader_parameter("core_color", GameBus.spell_core(spell))
	_mat.set_shader_parameter("mid_color", GameBus.spell_accent(spell))
	_mat.set_shader_parameter("outer_color", GameBus.spell_color(spell))
	if _particles and _particles.process_material:
		(_particles.process_material as ParticleProcessMaterial).color = GameBus.spell_accent(spell)


func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
