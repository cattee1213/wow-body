class_name RunUpgrades
extends RefCounted
## Per-run stacked stats for roguelike upgrades.

signal changed

const DMG_CAP := 3.0
const FIRE_RATE_CAP := 2.5
const ULT_CD_FLOOR := 0.40
const MS_CHANCE_CAP := 0.75
const MS_MAX_CAP := 5
const MIN_FIRE_CD := 0.12

var damage_mult: float = 1.0
var fire_rate_mult: float = 1.0
var ult_cd_mult: float = 1.0
var multishot_chance: float = 0.0
var multishot_max: int = 1

## Chosen upgrade ids this run (order).
var history: Array[StringName] = []
## Count per id.
var pick_counts: Dictionary = {}


func reset() -> void:
	damage_mult = 1.0
	fire_rate_mult = 1.0
	ult_cd_mult = 1.0
	multishot_chance = 0.0
	multishot_max = 1
	history.clear()
	pick_counts.clear()
	changed.emit()


func fire_cooldown(base_cd: float) -> float:
	return maxf(MIN_FIRE_CD, base_cd / maxf(fire_rate_mult, 0.01))


func scale_damage(base: float) -> float:
	return base * damage_mult


func scale_ult_cooldown(base_cd: float) -> float:
	return maxf(0.5, base_cd * ult_cd_mult)


func is_capped(id: StringName) -> bool:
	var e: Dictionary = UpgradeCatalog.get_entry(id)
	if e.is_empty():
		return true
	var only_dmg := e.has("damage_mult") and not e.has("fire_rate_mult") and not e.has("ult_cd_mult") and not e.has("multishot_chance") and not e.has("multishot_max")
	if only_dmg and damage_mult >= DMG_CAP - 0.001:
		return true
	var only_spd := e.has("fire_rate_mult") and not e.has("damage_mult")
	if only_spd and fire_rate_mult >= FIRE_RATE_CAP - 0.001:
		return true
	var only_cd := e.has("ult_cd_mult") and not e.has("damage_mult")
	if only_cd and ult_cd_mult <= ULT_CD_FLOOR + 0.001:
		return true
	# Multishot: useless if nothing would change
	var chance_add := float(e.get("multishot_chance", 0.0))
	var max_add := int(e.get("multishot_max", 0))
	if chance_add > 0.0 or max_add > 0:
		var chance_full := multishot_chance >= MS_CHANCE_CAP - 0.001
		var max_full := multishot_max >= MS_MAX_CAP
		if max_add > 0 and max_full and (chance_add <= 0.0 or chance_full):
			return true
		if max_add <= 0 and chance_add > 0.0 and chance_full:
			return true
	return false


func apply(id: StringName) -> bool:
	var e: Dictionary = UpgradeCatalog.get_entry(id)
	if e.is_empty():
		return false
	if e.has("damage_mult"):
		damage_mult = minf(DMG_CAP, damage_mult * float(e["damage_mult"]))
	if e.has("fire_rate_mult"):
		fire_rate_mult = minf(FIRE_RATE_CAP, fire_rate_mult * float(e["fire_rate_mult"]))
	if e.has("ult_cd_mult"):
		ult_cd_mult = maxf(ULT_CD_FLOOR, ult_cd_mult * float(e["ult_cd_mult"]))
	if e.has("multishot_chance"):
		multishot_chance = minf(MS_CHANCE_CAP, multishot_chance + float(e["multishot_chance"]))
	if e.has("multishot_max"):
		multishot_max = mini(MS_MAX_CAP, multishot_max + int(e["multishot_max"]))
		# First time unlocking multishot chain needs max>=2
		multishot_max = clampi(multishot_max, 1, MS_MAX_CAP)
	history.append(id)
	pick_counts[id] = int(pick_counts.get(id, 0)) + 1
	changed.emit()
	return true


## Returns total shots in this volley (1..multishot_max), geometric chain.
func roll_shot_count() -> int:
	var count := 1
	var limit := clampi(multishot_max, 1, MS_MAX_CAP)
	var p := clampf(multishot_chance, 0.0, MS_CHANCE_CAP)
	if limit <= 1 or p <= 0.0:
		return 1
	while count < limit and randf() < p:
		count += 1
	return count


func preview_line(id: StringName) -> String:
	var e: Dictionary = UpgradeCatalog.get_entry(id)
	if e.is_empty():
		return ""
	var parts: PackedStringArray = []
	if e.has("damage_mult"):
		var nxt := minf(DMG_CAP, damage_mult * float(e["damage_mult"]))
		parts.append("伤害 %.0f%%→%.0f%%" % [damage_mult * 100.0, nxt * 100.0])
	if e.has("fire_rate_mult"):
		var nxt2 := minf(FIRE_RATE_CAP, fire_rate_mult * float(e["fire_rate_mult"]))
		parts.append("攻速 %.0f%%→%.0f%%" % [fire_rate_mult * 100.0, nxt2 * 100.0])
	if e.has("ult_cd_mult"):
		var nxt3 := maxf(ULT_CD_FLOOR, ult_cd_mult * float(e["ult_cd_mult"]))
		parts.append("终CD ×%.2f→×%.2f" % [ult_cd_mult, nxt3])
	if e.has("multishot_chance"):
		var nxt4 := minf(MS_CHANCE_CAP, multishot_chance + float(e["multishot_chance"]))
		parts.append("连发率 %.0f%%→%.0f%%" % [multishot_chance * 100.0, nxt4 * 100.0])
	if e.has("multishot_max"):
		var nxt5 := mini(MS_MAX_CAP, multishot_max + int(e["multishot_max"]))
		parts.append("连发上限 %d→%d" % [multishot_max, nxt5])
	return " · ".join(parts)


func summary_text() -> String:
	return "伤×%.2f  速×%.2f  终CD×%.2f  连发%.0f%%%d发" % [
		damage_mult, fire_rate_mult, ult_cd_mult, multishot_chance * 100.0, multishot_max
	]


func roll_offer(wave: int, count: int = 3) -> Array[StringName]:
	var offer: Array[StringName] = []
	var used: Dictionary = {}
	var guard := 0
	while offer.size() < count and guard < 40:
		guard += 1
		var rarity := _roll_rarity(wave)
		var id := _pick_from_rarity(rarity, used)
		if id == &"":
			# fallback any uncapped
			id = _pick_any(used)
		if id == &"":
			break
		used[id] = true
		offer.append(id)
	return offer


func _roll_rarity(wave: int) -> StringName:
	var common_w := 0.75
	var rare_w := 0.22
	var epic_w := 0.03
	if wave >= 9:
		common_w = 0.38
		rare_w = 0.42
		epic_w = 0.20
	elif wave >= 6:
		common_w = 0.48
		rare_w = 0.38
		epic_w = 0.14
	elif wave >= 3:
		common_w = 0.60
		rare_w = 0.32
		epic_w = 0.08
	var r := randf()
	if r < epic_w:
		return UpgradeCatalog.RARITY_EPIC
	if r < epic_w + rare_w:
		return UpgradeCatalog.RARITY_RARE
	return UpgradeCatalog.RARITY_COMMON


func _pick_from_rarity(rarity: StringName, used: Dictionary) -> StringName:
	var pool: Array[StringName] = []
	var weights: Array[float] = []
	for id in UpgradeCatalog.ids_for_rarity(rarity):
		if used.has(id):
			continue
		if is_capped(id):
			continue
		var e: Dictionary = UpgradeCatalog.get_entry(id)
		pool.append(id)
		weights.append(float(e.get("weight", 1.0)))
	return _weighted_pick(pool, weights)


func _pick_any(used: Dictionary) -> StringName:
	var pool: Array[StringName] = []
	var weights: Array[float] = []
	for id in UpgradeCatalog.all_ids():
		if used.has(id):
			continue
		if is_capped(id):
			continue
		var e: Dictionary = UpgradeCatalog.get_entry(id)
		pool.append(id)
		weights.append(float(e.get("weight", 1.0)))
	return _weighted_pick(pool, weights)


func _weighted_pick(pool: Array[StringName], weights: Array[float]) -> StringName:
	if pool.is_empty():
		return &""
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return pool[randi() % pool.size()]
	var r := randf() * total
	var acc := 0.0
	for i in pool.size():
		acc += weights[i]
		if r <= acc:
			return pool[i]
	return pool[pool.size() - 1]
