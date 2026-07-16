class_name PalmVfx
extends Node2D
## Rich palm feedback: hold always + charge overlay grows with charge.
## Industry-style layering: base orb, charge swirl, additive pulse ring.

var spell: StringName = GameBus.SPELL_FIRE
var charge: float = 0.0
var openness: float = 0.0

var _hold: AnimatedVfxSprite
var _charge: AnimatedVfxSprite
var _pulse: Sprite2D
var _ring: Sprite2D
var _time: float = 0.0


func _ready() -> void:
	SpellVfxLibrary.ensure_loaded()
	_hold = AnimatedVfxSprite.new()
	_hold.z_index = 0
	add_child(_hold)

	_charge = AnimatedVfxSprite.new()
	_charge.z_index = 2
	add_child(_charge)

	# Soft pulse halo (reuses charge frame 0, large & transparent)
	_pulse = Sprite2D.new()
	_pulse.centered = true
	_pulse.z_index = 1
	_pulse.modulate = Color(1, 1, 1, 0.0)
	add_child(_pulse)

	_ring = Sprite2D.new()
	_ring.centered = true
	_ring.z_index = 3
	_ring.modulate = Color(1, 1, 1, 0.0)
	add_child(_ring)

	_apply_spell()
	visible = false


func set_spell(s: StringName) -> void:
	if spell == s and _hold and _hold.frames.size() > 0:
		return
	spell = s
	_apply_spell()


func sync(world_pos: Vector2, p_charge: float, p_open: float) -> void:
	global_position = world_pos
	charge = clampf(p_charge, 0.0, 1.0)
	openness = clampf(p_open, 0.0, 1.0)
	_time += get_process_delta_time()

	var power := maxf(charge, openness * 0.55)
	if power < 0.04 and charge < 0.02:
		hide_palm()
		return

	visible = true

	# Palm VFX — medium size, follows aim point (index tip when pointing)
	var hold_mul := 0.65 + openness * 0.4 + charge * 0.3
	_set_sprite_size(_hold, 70.0 * hold_mul)
	if _hold:
		_hold.visible = true
		_hold.rotation = 0.0
		_hold.modulate = Color(1, 1, 1, clampf(0.5 + openness * 0.4, 0.4, 0.95))

	var charge_alpha := 0.0
	if charge > 0.05:
		charge_alpha = clampf((charge - 0.05) / 0.75, 0.0, 1.0)
	if _charge:
		_charge.visible = charge_alpha > 0.02
		_set_sprite_size(_charge, (58.0 + charge * 40.0))
		_charge.modulate = Color(1, 1, 1, charge_alpha * 0.85)
		_charge.rotation += get_process_delta_time() * (1.0 + charge * 2.8)

	var beat := 1.0 + sin(_time * (6.0 + charge * 8.0)) * (0.06 + charge * 0.1)
	if _pulse and _pulse.texture:
		_set_raw_size(_pulse, (78.0 + charge * 48.0) * beat)
		_pulse.modulate = Color(
			GameBus.spell_accent(spell).r,
			GameBus.spell_accent(spell).g,
			GameBus.spell_accent(spell).b,
			charge_alpha * 0.32
		)
		_pulse.rotation = -_time * 0.8
	if _ring and _ring.texture:
		_set_raw_size(_ring, (48.0 + charge * 52.0) * beat)
		_ring.modulate = Color(1, 1, 1, charge_alpha * (0.22 + charge * 0.4))
		_ring.rotation = _time * 2.2

	# Whole-node punch when nearly full
	var full_punch := 1.0
	if charge > 0.75:
		full_punch = 1.0 + (charge - 0.75) * 0.5 + sin(_time * 18.0) * 0.04
	scale = Vector2(full_punch, full_punch)


func hide_palm() -> void:
	visible = false
	scale = Vector2.ONE


func _apply_spell() -> void:
	var hold_frames := SpellVfxLibrary.get_frames(spell, SpellVfxLibrary.STATE_HOLD)
	var charge_frames := SpellVfxLibrary.get_frames(spell, SpellVfxLibrary.STATE_CHARGE)
	if _hold:
		_hold.setup(hold_frames, 10.0, true, 110.0)
		_hold.rotation = 0.0
	if _charge:
		_charge.setup(charge_frames, 14.0, true, 120.0)
		_charge.rotation = 0.0
	# Pulse/ring use first charge frame if available else hold
	var halo: Texture2D = null
	if charge_frames.size() > 0:
		halo = charge_frames[0]
	elif hold_frames.size() > 0:
		halo = hold_frames[0]
	if _pulse:
		_pulse.texture = halo
	if _ring:
		_ring.texture = halo


func _set_sprite_size(spr: AnimatedVfxSprite, target_px: float) -> void:
	if spr == null or spr.texture == null:
		return
	var longest := maxf(spr.texture.get_size().x, spr.texture.get_size().y)
	var s := target_px / maxf(longest, 1.0)
	spr.scale = Vector2(s, s)
	spr.target_px = target_px


func _set_raw_size(spr: Sprite2D, target_px: float) -> void:
	if spr == null or spr.texture == null:
		return
	var longest := maxf(spr.texture.get_size().x, spr.texture.get_size().y)
	var s := target_px / maxf(longest, 1.0)
	spr.scale = Vector2(s, s)
