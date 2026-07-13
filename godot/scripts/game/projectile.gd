class_name SpellProjectile
extends Node2D

var spell: StringName = GameBus.SPELL_FIRE
var velocity: Vector2 = Vector2.ZERO
var radius: float = 22.0
var life: float = 2.2
var max_life: float = 2.2
var power: float = 0.7
var birth_scale: float = 1.0

var _orb: Sprite2D
var _mat: ShaderMaterial
var _particles: GPUParticles2D


func setup(p_spell: StringName, p_power: float, dir: Vector2, speed: float) -> void:
	spell = p_spell
	power = clampf(p_power, 0.15, 1.0)
	velocity = dir.normalized() * speed
	radius = 18.0 + power * 14.0
	birth_scale = 0.55 + power * 1.1
	life = 2.2
	max_life = 2.2
	_build_visuals()


func _build_visuals() -> void:
	_orb = Sprite2D.new()
	_orb.centered = true
	# 1x1 white texture; shader draws the orb
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_orb.texture = ImageTexture.create_from_image(img)
	_orb.scale = Vector2(90, 90) * birth_scale
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/spell_orb.gdshader")
	_apply_spell_colors()
	_orb.material = _mat
	add_child(_orb)

	_particles = GPUParticles2D.new()
	_particles.amount = 28
	_particles.lifetime = 0.45
	_particles.explosiveness = 0.05
	_particles.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 8.0
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 80.0
	pm.gravity = Vector3(0, 40, 0)
	pm.scale_min = 1.5
	pm.scale_max = 3.5
	pm.color = GameBus.spell_accent(spell)
	_particles.process_material = pm
	_particles.texture = _orb.texture
	add_child(_particles)
	_particles.emitting = true


func _apply_spell_colors() -> void:
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
	_mat.set_shader_parameter("intensity", 0.85 + power * 0.7)
	_mat.set_shader_parameter("time_scale", 1.2 if spell != GameBus.SPELL_LIGHTNING else 2.2)


func tick(dt: float, elapsed: float) -> bool:
	## Returns true if still alive.
	position += velocity * dt
	life -= dt
	if spell == GameBus.SPELL_LIGHTNING:
		position.x += sin(elapsed * 40.0 + float(get_instance_id() % 100)) * 40.0 * dt
	var life_t := clampf(life / max_life, 0.0, 1.0)
	var s := birth_scale * (0.5 + life_t * 0.6)
	if _orb:
		_orb.scale = Vector2(90, 90) * s
		_orb.rotation += dt * (3.5 if spell == GameBus.SPELL_LIGHTNING else 2.0)
	return life > 0.0


func damage() -> float:
	var base := 1.25 if spell == GameBus.SPELL_LIGHTNING else 1.0
	return ceilf(base + (0.5 if power >= 0.75 else 0.0))
