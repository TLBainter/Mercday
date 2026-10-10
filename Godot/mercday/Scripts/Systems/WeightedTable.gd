class_name WeightedTable

const TIER_WEIGHTS: Dictionary = {
	"Common": 50.0,
	"Uncommon": 25.0,
	"Rare": 15.0,
	"Very Rare": 9.0,
	"Legendary": 1.0,
}

#Turns a data list into weighted items; fixed_rarity is used when rarity_field is empty.
static func items_from(list: Array, name_field: String, rarity_field: String = "",
		fixed_rarity: String = "") -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for entry: Object in list:
		var rarity: String = fixed_rarity
		if rarity_field != "":
			rarity = str(entry.get(rarity_field))
		items.append({"name": str(entry.get(name_field)), "rarity": rarity})
	return items


static func roll(
	items: Array[Dictionary],
	flat_boosts: Dictionary = {},
	multiplier_boosts: Dictionary = {},
	pre_allocated: Dictionary = {}
) -> String:
	var table: Array[Dictionary] = _build_table(items, flat_boosts, multiplier_boosts, pre_allocated)
	if table.is_empty():
		return ""

	var roll_value: float = randf() * 100.0
	var cumulative: float = 0.0
	for entry: Dictionary in table:
		cumulative += entry.get("pct", 0.0) as float
		if roll_value <= cumulative:
			return entry.get("name", "") as String

	return table[0].get("name", "") as String


static func _build_table(
	items: Array[Dictionary],
	flat_boosts: Dictionary,
	multiplier_boosts: Dictionary,
	pre_allocated: Dictionary
) -> Array[Dictionary]:
	var reserved_pct: float = 0.0
	for pct: float in pre_allocated.values():
		reserved_pct += pct
	var remaining_pool: float = 100.0 - reserved_pct

	var tier_counts: Dictionary = {}
	for item: Dictionary in items:
		var tier: String = str(item.get("rarity", "Common"))
		tier_counts[tier] = (tier_counts.get(tier, 0) as int) + 1

	var tier_total_weight: float = 0.0
	for tier: String in tier_counts:
		tier_total_weight += TIER_WEIGHTS.get(tier, 0.0) as float

	var working: Dictionary = {}
	for item: Dictionary in items:
		var tier: String = str(item.get("rarity", "Common"))
		var count: int = tier_counts.get(tier, 1) as int
		var tier_pct: float = 0.0
		if tier_total_weight > 0.0 and count > 0:
			tier_pct = (TIER_WEIGHTS.get(tier, 0.0) as float / tier_total_weight) * remaining_pool
		working[str(item.get("name", ""))] = tier_pct / count

	var tier_of: Dictionary = {}
	for item: Dictionary in items:
		var iname: String = str(item.get("name", ""))
		if not tier_of.has(iname):
			tier_of[iname] = str(item.get("rarity", "Common"))

	for item_name: String in flat_boosts:
		if not working.has(item_name):
			continue
		var boost: float = flat_boosts[item_name] as float
		var item_tier: String = tier_of.get(item_name, "Common")
		var raised: float = (working.get(item_name, 0.0) as float) + boost
		_redistribute(working, items, item_name, item_tier, raised, boost)

	for item_name: String in multiplier_boosts:
		if not working.has(item_name):
			continue
		var mult: float = multiplier_boosts[item_name] as float
		var item_tier: String = tier_of.get(item_name, "Common")
		var old_pct: float = working.get(item_name, 0.0) as float
		var new_pct: float = old_pct * (1.0 + mult / 100.0)
		_redistribute(working, items, item_name, item_tier, new_pct, new_pct - old_pct)

	for fixed_name: String in pre_allocated:
		working[fixed_name] = pre_allocated[fixed_name] as float

	var total: float = 0.0
	for pct: float in working.values():
		total += pct
	#A flat penalty can drive one entry far below zero and cancel the rest, which would skip the normalisation.
	if total <= 0.0:
		for key: String in working:
			working[key] = maxf(0.0, working[key] as float)
		total = 0.0
		for pct: float in working.values():
			total += pct
	if total > 0.0:
		for key: String in working:
			working[key] = (working[key] as float) / total * 100.0

	var table: Array[Dictionary] = []
	for item: Dictionary in items:
		var name: String = str(item.get("name", ""))
		if working.has(name):
			table.append({"name": name, "pct": working[name] as float, "tier": str(item.get("rarity", "Common"))})
	for fixed_name: String in pre_allocated:
		var already: bool = false
		for item: Dictionary in items:
			if str(item.get("name", "")) == fixed_name:
				already = true
				break
		if not already:
			table.append({"name": fixed_name, "pct": working.get(fixed_name, 0.0) as float, "tier": "(fixed)"})

	table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.get("pct", 0.0) as float) > (b.get("pct", 0.0) as float))
	return table


#Sets one entry to new_value and takes the taken amount back from its tier siblings in proportion.
static func _redistribute(working: Dictionary, items: Array[Dictionary], item_name: String,
		item_tier: String, new_value: float, taken: float) -> void:
	var total_others: float = 0.0
	for other: Dictionary in items:
		var other_name: String = str(other.get("name", ""))
		if other_name != item_name and str(other.get("rarity", "Common")) == item_tier:
			total_others += working.get(other_name, 0.0) as float
	working[item_name] = new_value
	if total_others <= 0.0:
		return
	for other: Dictionary in items:
		var other_name: String = str(other.get("name", ""))
		if other_name != item_name and str(other.get("rarity", "Common")) == item_tier:
			var old: float = working.get(other_name, 0.0) as float
			var share: float = (old / total_others) * taken
			working[other_name] = maxf(0.1, old - share)


#Index of a weight table drawn in proportion to its entries.
static func pick_index(weights: Array[int]) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	var drawn: int = randi_range(1, maxi(1, total))
	var cum: int = 0
	for i: int in range(weights.size()):
		cum += weights[i]
		if drawn <= cum:
			return i
	return weights.size() - 1
