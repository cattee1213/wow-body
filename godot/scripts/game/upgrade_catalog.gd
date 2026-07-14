class_name UpgradeCatalog
extends RefCounted
## Static roguelike upgrade definitions (wave 3-pick-1).

const RARITY_COMMON := &"common"
const RARITY_RARE := &"rare"
const RARITY_EPIC := &"epic"

const RARITY_COLOR := {
	RARITY_COMMON: Color(0.82, 0.84, 0.88),
	RARITY_RARE: Color(0.30, 0.62, 1.0),
	RARITY_EPIC: Color(0.71, 0.48, 1.0),
}

const RARITY_LABEL := {
	RARITY_COMMON: "普通",
	RARITY_RARE: "稀有",
	RARITY_EPIC: "史诗",
}

## id -> definition
const ENTRIES := {
	&"dmg_c": {
		"name": "锐化咒文",
		"rarity": RARITY_COMMON,
		"kind": &"damage",
		"desc": "伤害 +12%",
		"weight": 1.0,
		"damage_mult": 1.12,
	},
	&"dmg_r": {
		"name": "奥术锋刃",
		"rarity": RARITY_RARE,
		"kind": &"damage",
		"desc": "伤害 +22%",
		"weight": 1.0,
		"damage_mult": 1.22,
	},
	&"dmg_e": {
		"name": "灭法之触",
		"rarity": RARITY_EPIC,
		"kind": &"damage",
		"desc": "伤害 +40%",
		"weight": 1.0,
		"damage_mult": 1.40,
	},
	&"spd_c": {
		"name": "迅捷指法",
		"rarity": RARITY_COMMON,
		"kind": &"atkspd",
		"desc": "攻速 +10%",
		"weight": 1.0,
		"fire_rate_mult": 1.10,
	},
	&"spd_r": {
		"name": "连续咏唱",
		"rarity": RARITY_RARE,
		"kind": &"atkspd",
		"desc": "攻速 +18%",
		"weight": 1.0,
		"fire_rate_mult": 1.18,
	},
	&"spd_e": {
		"name": "超载连射",
		"rarity": RARITY_EPIC,
		"kind": &"atkspd",
		"desc": "攻速 +30%",
		"weight": 1.0,
		"fire_rate_mult": 1.30,
	},
	&"cd_c": {
		"name": "回响结晶",
		"rarity": RARITY_COMMON,
		"kind": &"ult_cd",
		"desc": "终极 CD -8%",
		"weight": 1.0,
		"ult_cd_mult": 0.92,
	},
	&"cd_r": {
		"name": "时砂怀表",
		"rarity": RARITY_RARE,
		"kind": &"ult_cd",
		"desc": "终极 CD -15%",
		"weight": 1.0,
		"ult_cd_mult": 0.85,
	},
	&"cd_e": {
		"name": "永恒沙漏",
		"rarity": RARITY_EPIC,
		"kind": &"ult_cd",
		"desc": "终极 CD -25%",
		"weight": 1.0,
		"ult_cd_mult": 0.75,
	},
	&"ms_chance_c": {
		"name": "回声火花",
		"rarity": RARITY_COMMON,
		"kind": &"multishot",
		"desc": "连发概率 +8%",
		"weight": 1.1,
		"multishot_chance": 0.08,
	},
	&"ms_chance_r": {
		"name": "二重咏唱",
		"rarity": RARITY_RARE,
		"kind": &"multishot",
		"desc": "连发概率 +14%",
		"weight": 1.1,
		"multishot_chance": 0.14,
	},
	&"ms_chance_e": {
		"name": "五重魔律",
		"rarity": RARITY_EPIC,
		"kind": &"multishot",
		"desc": "连发概率 +22%",
		"weight": 1.1,
		"multishot_chance": 0.22,
	},
	&"ms_max_c": {
		"name": "分叉咒",
		"rarity": RARITY_COMMON,
		"kind": &"multishot",
		"desc": "连发上限 +1",
		"weight": 0.85,
		"multishot_max": 1,
	},
	&"ms_max_r": {
		"name": "分裂核心",
		"rarity": RARITY_RARE,
		"kind": &"multishot",
		"desc": "连发上限 +1，概率 +6%",
		"weight": 0.85,
		"multishot_max": 1,
		"multishot_chance": 0.06,
	},
	&"ms_max_e": {
		"name": "连珠圣典",
		"rarity": RARITY_EPIC,
		"kind": &"multishot",
		"desc": "连发上限 +2，概率 +10%",
		"weight": 0.85,
		"multishot_max": 2,
		"multishot_chance": 0.10,
	},
}


static func get_entry(id: StringName) -> Dictionary:
	return ENTRIES.get(id, {})


static func rarity_color(rarity: StringName) -> Color:
	return RARITY_COLOR.get(rarity, RARITY_COLOR[RARITY_COMMON])


static func rarity_label(rarity: StringName) -> String:
	return str(RARITY_LABEL.get(rarity, "普通"))


static func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in ENTRIES.keys():
		out.append(k)
	return out


static func ids_for_rarity(rarity: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for k in ENTRIES.keys():
		var e: Dictionary = ENTRIES[k]
		if e.get("rarity", RARITY_COMMON) == rarity:
			out.append(k)
	return out
