extends Node
## Global signals / helpers for WoW Body client.

signal spell_changed(spell: StringName)
signal message(text: String, ttl: float)
signal game_over(score: int, kills: int)
signal restarted
signal ultimate_cds_changed

# --- Basic school (pick one at start) ---
const SPELL_FIRE := &"fire"
const SPELL_FROST := &"frost"
const SPELL_LIGHTNING := &"lightning"

# --- Ultimates (all available, independent CD) ---
const ULT_BLIZZARD := &"blizzard"
const ULT_FIRESTORM := &"firestorm"
const ULT_CHAIN := &"chain"

const SPELL_ORDER: Array[StringName] = [SPELL_FIRE, SPELL_FROST, SPELL_LIGHTNING]
const ULTIMATE_ORDER: Array[StringName] = [ULT_BLIZZARD, ULT_FIRESTORM, ULT_CHAIN]

const SPELL_META := {
	SPELL_FIRE: {
		"name": "火球",
		"cast": "火球术！",
		"kind": "basic",
		"color": Color(1.0, 0.42, 0.05),
		"accent": Color(1.0, 0.7, 0.28),
		"core": Color(1.0, 0.96, 0.78),
		"badge": "🔥",
	},
	SPELL_FROST: {
		"name": "寒冰箭",
		"cast": "寒冰箭！",
		"kind": "basic",
		"color": Color(0.24, 0.73, 1.0),
		"accent": Color(0.6, 0.9, 1.0),
		"core": Color(0.91, 0.98, 1.0),
		"badge": "❄",
	},
	SPELL_LIGHTNING: {
		"name": "雷击",
		"cast": "雷击！",
		"kind": "basic",
		"color": Color(0.66, 0.55, 0.98),
		"accent": Color(0.99, 0.88, 0.28),
		"core": Color(0.96, 0.95, 1.0),
		"badge": "⚡",
	},
	ULT_BLIZZARD: {
		"name": "暴风雪",
		"cast": "暴风雪！",
		"kind": "ultimate",
		"color": Color(0.35, 0.78, 1.0),
		"accent": Color(0.75, 0.95, 1.0),
		"core": Color(0.95, 0.99, 1.0),
		"badge": "🌨",
		"cooldown": 20.0,
		"duration": 3.6,
		"tick": 0.28,
		"damage": 0.55,
		"hint": "双手高举开掌",
	},
	ULT_FIRESTORM: {
		"name": "火风暴",
		"cast": "火风暴！",
		"kind": "ultimate",
		"color": Color(1.0, 0.35, 0.08),
		"accent": Color(1.0, 0.65, 0.2),
		"core": Color(1.0, 0.92, 0.55),
		"badge": "🌪",
		"cooldown": 20.0,
		"duration": 2.6,
		"tick": 0.32,
		"damage": 1.15,
		"hint": "双手合掌聚能",
	},
	ULT_CHAIN: {
		"name": "闪电链",
		"cast": "闪电链！",
		"kind": "ultimate",
		"color": Color(0.72, 0.5, 1.0),
		"accent": Color(1.0, 0.9, 0.35),
		"core": Color(0.98, 0.96, 1.0),
		"badge": "⛓",
		"cooldown": 16.0,
		"duration": 0.0,
		"tick": 0.0,
		"damage": 1.65,
		"hint": "双手握拳引雷",
	},
}

## Locked basic school for the current run (set at select screen).
var basic_spell: StringName = SPELL_FIRE

## Remaining cooldown seconds per ultimate id.
var ultimate_cd: Dictionary = {
	ULT_BLIZZARD: 0.0,
	ULT_FIRESTORM: 0.0,
	ULT_CHAIN: 0.0,
}


func reset_run_state(spell: StringName = SPELL_FIRE) -> void:
	basic_spell = spell if is_basic(spell) else SPELL_FIRE
	for u in ULTIMATE_ORDER:
		ultimate_cd[u] = 0.0
	spell_changed.emit(basic_spell)
	ultimate_cds_changed.emit()


func tick_cooldowns(dt: float) -> void:
	var changed := false
	for u in ULTIMATE_ORDER:
		var left: float = float(ultimate_cd.get(u, 0.0))
		if left > 0.0:
			ultimate_cd[u] = maxf(0.0, left - dt)
			changed = true
	if changed:
		ultimate_cds_changed.emit()


func can_cast_ultimate(ult: StringName) -> bool:
	if not is_ultimate(ult):
		return false
	return float(ultimate_cd.get(ult, 0.0)) <= 0.001


func start_ultimate_cooldown(ult: StringName) -> void:
	if not is_ultimate(ult):
		return
	ultimate_cd[ult] = float(SPELL_META[ult].get("cooldown", 18.0))
	ultimate_cds_changed.emit()


func ultimate_cd_ratio(ult: StringName) -> float:
	## 0 = ready, 1 = just cast / full CD remaining.
	if not is_ultimate(ult):
		return 1.0
	var max_cd := float(SPELL_META[ult].get("cooldown", 18.0))
	if max_cd <= 0.001:
		return 0.0
	return clampf(float(ultimate_cd.get(ult, 0.0)) / max_cd, 0.0, 1.0)


func is_basic(spell: StringName) -> bool:
	return SPELL_ORDER.has(spell)


func is_ultimate(spell: StringName) -> bool:
	return ULTIMATE_ORDER.has(spell)


func next_spell(current: StringName) -> StringName:
	var i := SPELL_ORDER.find(current)
	if i < 0:
		return SPELL_FIRE
	return SPELL_ORDER[(i + 1) % SPELL_ORDER.size()]


func spell_name(spell: StringName) -> String:
	return str(_meta(spell).get("name", "未知"))


func spell_color(spell: StringName) -> Color:
	return _meta(spell).get("color", SPELL_META[SPELL_FIRE]["color"])


func spell_accent(spell: StringName) -> Color:
	return _meta(spell).get("accent", SPELL_META[SPELL_FIRE]["accent"])


func spell_core(spell: StringName) -> Color:
	return _meta(spell).get("core", SPELL_META[SPELL_FIRE]["core"])


func spell_cast_text(spell: StringName) -> String:
	return str(_meta(spell).get("cast", ""))


func spell_badge(spell: StringName) -> String:
	return str(_meta(spell).get("badge", "✦"))


func spell_hint(spell: StringName) -> String:
	return str(_meta(spell).get("hint", ""))


func element_for(spell: StringName) -> StringName:
	## Map ultimate → status element for on-hit effects.
	match spell:
		ULT_BLIZZARD:
			return SPELL_FROST
		ULT_FIRESTORM:
			return SPELL_FIRE
		ULT_CHAIN:
			return SPELL_LIGHTNING
		_:
			return spell if is_basic(spell) else SPELL_FIRE


func _meta(spell: StringName) -> Dictionary:
	return SPELL_META.get(spell, SPELL_META[SPELL_FIRE])
