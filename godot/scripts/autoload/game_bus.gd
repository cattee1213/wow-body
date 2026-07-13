extends Node
## Global signals / helpers for WoW Body client.

signal spell_changed(spell: StringName)
signal message(text: String, ttl: float)
signal game_over(score: int, kills: int)
signal restarted

const SPELL_FIRE := &"fire"
const SPELL_FROST := &"frost"
const SPELL_LIGHTNING := &"lightning"

const SPELL_ORDER: Array[StringName] = [SPELL_FIRE, SPELL_FROST, SPELL_LIGHTNING]

const SPELL_META := {
	SPELL_FIRE: {
		"name": "火球",
		"cast": "火球术！",
		"color": Color(1.0, 0.42, 0.05),
		"accent": Color(1.0, 0.7, 0.28),
		"core": Color(1.0, 0.96, 0.78),
	},
	SPELL_FROST: {
		"name": "寒冰",
		"cast": "寒冰箭！",
		"color": Color(0.24, 0.73, 1.0),
		"accent": Color(0.6, 0.9, 1.0),
		"core": Color(0.91, 0.98, 1.0),
	},
	SPELL_LIGHTNING: {
		"name": "雷电",
		"cast": "闪电链！",
		"color": Color(0.66, 0.55, 0.98),
		"accent": Color(0.99, 0.88, 0.28),
		"core": Color(0.96, 0.95, 1.0),
	},
}


func next_spell(current: StringName) -> StringName:
	var i := SPELL_ORDER.find(current)
	if i < 0:
		return SPELL_FIRE
	return SPELL_ORDER[(i + 1) % SPELL_ORDER.size()]


func spell_name(spell: StringName) -> String:
	return str(SPELL_META.get(spell, SPELL_META[SPELL_FIRE])["name"])


func spell_color(spell: StringName) -> Color:
	return SPELL_META.get(spell, SPELL_META[SPELL_FIRE])["color"]


func spell_accent(spell: StringName) -> Color:
	return SPELL_META.get(spell, SPELL_META[SPELL_FIRE])["accent"]


func spell_core(spell: StringName) -> Color:
	return SPELL_META.get(spell, SPELL_META[SPELL_FIRE])["core"]


func spell_cast_text(spell: StringName) -> String:
	return str(SPELL_META.get(spell, SPELL_META[SPELL_FIRE])["cast"])
