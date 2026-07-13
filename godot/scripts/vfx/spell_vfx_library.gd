class_name SpellVfxLibrary
extends RefCounted
## Loads sliced VFX frames from assets/vfx/{fire,frost,lightning}/
## States: hold(手持) · charge(蓄力) · projectile(发射) · impact(击中)

const STATE_HOLD := &"hold"
const STATE_CHARGE := &"charge"
const STATE_PROJECTILE := &"projectile"
const STATE_IMPACT := &"impact"

const STATES: Array[StringName] = [STATE_HOLD, STATE_CHARGE, STATE_PROJECTILE, STATE_IMPACT]

## image2 pipeline: one clean frame per state (hold/charge/projectile/impact).
const FRAME_COUNTS := {
	STATE_HOLD: 1,
	STATE_CHARGE: 1,
	STATE_PROJECTILE: 1,
	STATE_IMPACT: 1,
}

## spell_folder -> state -> Array[Texture2D]
static var _cache: Dictionary = {}
static var _loaded: bool = false


static func reload() -> void:
	_cache.clear()
	_loaded = false
	ensure_loaded()


static func _folder_for(spell: StringName) -> String:
	match spell:
		&"frost":
			return "frost"
		&"lightning":
			return "lightning"
		_:
			return "fire"


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for spell_name in ["fire", "frost", "lightning"]:
		_cache[spell_name] = {}
		for state in STATES:
			_cache[spell_name][state] = _load_state_frames(
				spell_name, str(state), int(FRAME_COUNTS[state])
			)


static func get_frames(spell: StringName, state: StringName) -> Array:
	ensure_loaded()
	var key := _folder_for(spell)
	if not _cache.has(key):
		key = "fire"
	var by_state: Dictionary = _cache[key]
	if not by_state.has(state):
		return []
	return by_state[state]


static func get_frame(spell: StringName, state: StringName, index: int) -> Texture2D:
	var frames: Array = get_frames(spell, state)
	if frames.is_empty():
		return null
	return frames[posmod(index, frames.size())]


static func frame_count(spell: StringName, state: StringName) -> int:
	return get_frames(spell, state).size()


static func _load_state_frames(folder: String, state: String, count: int) -> Array:
	var out: Array = []
	for i in count:
		var res_path := "res://assets/vfx/%s/%s_%d.png" % [folder, state, i]
		var tex := _load_texture(res_path)
		if tex:
			out.append(tex)
	if out.is_empty():
		push_warning("SpellVfxLibrary: no frames for %s/%s" % [folder, state])
	else:
		print("SpellVfxLibrary: %s/%s x%d" % [folder, state, out.size()])
	return out


static func _load_texture(res_path: String) -> Texture2D:
	# Always load raw PNG so re-sliced files update without reimport.
	var abs_path := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	if img.load(abs_path) != OK:
		return null
	# Skip nearly empty frames
	if img.get_used_rect().size.x < 8:
		return null
	var tex := ImageTexture.create_from_image(img)
	return tex
