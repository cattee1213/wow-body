class_name RunUpgrades
extends RefCounted
## Per-run stacked stats.
## multishot = serial chain; split = probabilistic side pellets (main ray fixed).

signal changed

const DMG_CAP := 3.0
const FIRE_RATE_CAP := 2.5
const ULT_CD_FLOOR := 0.40
const MS_CHANCE_CAP := 0.75
const MS_MAX_CAP := 5
const SPLIT_CHANCE_CAP := 0.75
const SPLIT_MAX_CAP := 4
const MIN_FIRE_CD := 0.18
## Side-pellet half-angle (radians) — modest so main direction stays readable (~9°).
const SPLIT_SIDE_ANGLE := 0.16

var damage_mult: float = 1.0
var fire_rate_mult: float = 1.0
var ult_cd_mult: float = 1.0
## Serial chain
var multishot_chance: float = 0.0
var multishot_max: int = 1
## Parallel side shots (main always on aim). Default: no split.
var split_chance: float = 0.0
var split_max: int = 0

var history: Array[StringName] = []
var pick_counts: Dictionary = {}


func reset() -> void:
	damage_mult = 1.0
	fire_rate_mult = 1.0
	ult_cd_mult = 1.0
	multishot_chance = 0.0
	multishot_max = 1
	split_chance = 0.0
	split_max = 0
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
	if e.has("damage_mult") and damage_mult >= DMG_CAP - 0.001 \
			and not e.has("fire_rate_mult") and not e.has("ult_cd_mult") \
			and not e.has("multishot_chance") and not e.has("multishot_max") \
			and not e.has("split_chance") and not e.has("split_max"):
		return true
	if e.has("fire_rate_mult") and fire_rate_mult >= FIRE_RATE_CAP - 0.001 \
			and not e.has("damage_mult"):
		return true
	if e.has("ult_cd_mult") and ult_cd_mult <= ULT_CD_FLOOR + 0.001 \
			and not e.has("damage_mult"):
		return true

	var ms_c := float(e.get("multishot_chance", 0.0))
	var ms_m := int(e.get("multishot_max", 0))
	if ms_c > 0.0 or ms_m > 0:
		var c_full := multishot_chance >= MS_CHANCE_CAP - 0.001
		var m_full := multishot_max >= MS_MAX_CAP
		if ms_m > 0 and m_full and (ms_c <= 0.0 or c_full):
			return true
		if ms_m <= 0 and ms_c > 0.0 and c_full:
			return true

	var sp_c := float(e.get("split_chance", 0.0))
	var sp_m := int(e.get("split_max", 0))
	if sp_c > 0.0 or sp_m > 0:
		var sc_full := split_chance >= SPLIT_CHANCE_CAP - 0.001
		var sm_full := split_max >= SPLIT_MAX_CAP
		if sp_m > 0 and sm_full and (sp_c <= 0.0 or sc_full):
			return true
		if sp_m <= 0 and sp_c > 0.0 and sc_full:
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
		multishot_max = clampi(multishot_max + int(e["multishot_max"]), 1, MS_MAX_CAP)
	if e.has("split_chance"):
		split_chance = minf(SPLIT_CHANCE_CAP, split_chance + float(e["split_chance"]))
		# Unlock at least 1 side slot when first gaining chance
		if split_max < 1:
			split_max = 1
	if e.has("split_max"):
		split_max = clampi(split_max + int(e["split_max"]), 0, SPLIT_MAX_CAP)
	history.append(id)
	pick_counts[id] = int(pick_counts.get(id, 0)) + 1
	changed.emit()
	return true


## Serial volley count (1..multishot_max).
func roll_multishot_volleys() -> int:
	var count := 1
	var limit := clampi(multishot_max, 1, MS_MAX_CAP)
	var p := clampf(multishot_chance, 0.0, MS_CHANCE_CAP)
	if limit <= 1 or p <= 0.0:
		return 1
	while count < limit and randf() < p:
		count += 1
	return count


## How many side pellets (not counting main). Geometric, capped by split_max.
func roll_split_side_count() -> int:
	var limit := clampi(split_max, 0, SPLIT_MAX_CAP)
	var p := clampf(split_chance, 0.0, SPLIT_CHANCE_CAP)
	if limit <= 0 or p <= 0.0:
		return 0
	var count := 0
	while count < limit and randf() < p:
		count += 1
	return count


## Angles for one volley: always includes 0 (main aim). Sides at ±SPLIT_SIDE_ANGLE * k.
func split_angles_for_volley() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.append(0.0) # main ray — never rotated
	var sides := roll_split_side_count()
	if sides <= 0:
		return out
	# Alternate L/R: -a, +a, -2a, +2a ...
	var k := 1
	var left := true
	for _i in sides:
		var sign := -1.0 if left else 1.0
		out.append(sign * SPLIT_SIDE_ANGLE * float(k))
		if not left:
			k += 1
		left = not left
	return out


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
	if e.has("split_chance"):
		var nxt6 := minf(SPLIT_CHANCE_CAP, split_chance + float(e["split_chance"]))
		parts.append("分裂率 %.0f%%→%.0f%%" % [split_chance * 100.0, nxt6 * 100.0])
	if e.has("split_max"):
		var cur_m := maxi(split_max, 1) if split_chance > 0.0 or e.has("split_chance") else split_max
		var nxt7 := mini(SPLIT_MAX_CAP, cur_m + int(e["split_max"]))
		parts.append("分裂上限 %d→%d" % [split_max, nxt7])
	return " · ".join(parts)


func summary_text() -> String:
	return "伤×%.2f 速×%.2f 终CD×%.2f 连发%.0f%%×%d 分裂%.0f%%×%d" % [
		damage_mult, fire_rate_mult, ult_cd_mult,
		multishot_chance * 100.0, multishot_max,
		split_chance * 100.0, split_max,
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
