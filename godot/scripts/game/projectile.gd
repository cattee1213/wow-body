class_name SpellProjectile
extends Node2D
## Single-facing projectile sprite + motion.
## Atlas frames often face different angles — we pick a stable frame and
## compensate with FACE_OFFSET so the tip always follows velocity.

var spell: StringName = GameBus.SPELL_FIRE
var velocity: Vector2 = Vector2.ZERO
var radius: float = 22.0
var life: float = 2.0
var max_life: float = 2.0
var power: float = 0.7
var birth_scale: float = 1.0

## Radians: art's forward direction when node.rotation == 0.
## Fire faces +X (~0). Frost faces down-right (~0.5). Lightning bolts vary — use first frame.
## image2 projectiles face roughly +X (right). Lightning slightly up-right.
const FACE_OFFSET := {
	&"fire": 0.0,
	&"frost": 0.0,
}

var _sprite: Sprite2D
var _trail: Array = [] # trailing ghost sprites
var _face: float = 0.0


func setup(p_spell: StringName, p_power: float, dir: Vector2, speed: float) -> void:
	spell = p_spell
	power = clampf(p_power, 0.15, 1.0)
	var d := dir.normalized()
	if d.length_squared() < 0.0001:
		d = Vector2.UP
	velocity = d * speed
	radius = 24.0 + power * 12.0
	birth_scale = 0.9 + power * 0.4
	life = 1.6
	max_life = 1.6
	_face = float(FACE_OFFSET.get(spell, 0.0))
	_build_visuals()
	_align_to_velocity()


func _build_visuals() -> void:
	SpellVfxLibrary.ensure_loaded()
	var frames: Array = SpellVfxLibrary.get_frames(spell, SpellVfxLibrary.STATE_PROJECTILE)
	var tex: Texture2D = null
	if frames.size() > 0:
		# Prefer a mid frame that is usually cleanest
		var idx := mini(1, frames.size() - 1)
		tex = frames[idx]
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture = tex
	_apply_size(_sprite, 96.0 + power * 40.0)
	add_child(_sprite)

	# Motion trail ghosts (common game trick)
	for i in 3:
		var g := Sprite2D.new()
		g.centered = true
		g.texture = tex
		g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		g.modulate = Color(1, 1, 1, 0.35 - i * 0.1)
		g.z_index = -1 - i
		_apply_size(g, (96.0 + power * 40.0) * (0.9 - i * 0.08))
		add_child(g)
		_trail.append(g)


func _apply_size(spr: Sprite2D, target_px: float) -> void:
	if spr == null or spr.texture == null:
		return
	var longest := maxf(spr.texture.get_size().x, spr.texture.get_size().y)
	var s := (target_px * birth_scale) / maxf(longest, 1.0)
	spr.scale = Vector2(s, s)


func _align_to_velocity() -> void:
	# rotation so sprite forward matches velocity
	rotation = velocity.angle() - _face


func tick(dt: float, elapsed: float) -> bool:
	# Store previous positions for trail
	var prev := global_position
	position += velocity * dt
	life -= dt

	_align_to_velocity()

	# Trail ghosts sit slightly behind along -velocity
	var back := -velocity.normalized()
	for i in _trail.size():
		var g: Sprite2D = _trail[i]
		if g:
			g.position = back * (14.0 + i * 16.0)
			g.rotation = 0.0 # inherits parent rotation
			g.modulate.a = clampf(0.32 - i * 0.08, 0.05, 0.4)

	var life_t := clampf(life / max_life, 0.0, 1.0)
	if _sprite:
		_apply_size(_sprite, (96.0 + power * 40.0) * (0.9 + life_t * 0.15))

	return life > 0.0


func damage() -> float:
	var base := 1.0 + (0.5 if power >= 0.75 else 0.0)
	return ceilf(GameBus.upgrades.scale_damage(base))
