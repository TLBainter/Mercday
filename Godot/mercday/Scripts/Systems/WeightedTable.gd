class_name WeightedTable

const TIER_WEIGHTS: Dictionary = {
	"Common": 50.0,
	"Uncommon": 25.0,
	"Rare": 15.0,
	"Very Rare": 9.0,
	"Legendary": 1.0,
}

# Returns the name of the selected item.
# items: Array[Dictionary], each dict must have "name": String and "rarity": String.
static func roll(
	items: Array[Dictionary],
	flat_boosts: Dictionary = {},
	multiplier_boosts: Dictionary = {},
	pre_allocated: Dictionary = {},
	debug: bool = false,
	table_label: String = "Table"
) -> String:
	var table: Array[Dictionary] = _build_table(items, flat_boosts, multiplier_boosts, pre_allocated)
	if table.is_empty():
		return ""

	if debug:
		_print_debug(table, table_label)

	var roll_value: float = randf() * 100.0
	var cumulative: float = 0.0
	for entry: Dictionary in table:
		cumulative += entry.get("pct", 0.0) as float
		if roll_value <= cumulative:
			if debug:
				print("→ ROLLED %.2f → SELECTED: %s (%.2f%%)" % [roll_value, entry.get("name", ""), entry.get("pct", 0.0)])
			return entry.get("name", "") as String

	return table[-1].get("name", "") as String


static func _build_table(
	items: Array[Dictionary],
	flat_boosts: Dictionary,
	multiplier_boosts: Dictionary,
	pre_allocated: Dictionary
) -> Array[Dictionary]:
	# Step 1: reserved pool
	var reserved_pct: float = 0.0
	for pct: float in pre_allocated.values():
		reserved_pct += pct
	var remaining_pool: float = 100.0 - reserved_pct

	# Step 2: count items per tier and sum tier weights
	var tier_counts: Dictionary = {}
	for item: Dictionary in items:
		var tier: String = str(item.get("rarity", "Common"))
		tier_counts[tier] = (tier_counts.get(tier, 0) as int) + 1

	var tier_total_weight: float = 0.0
	for tier: String in tier_counts:
		tier_total_weight += TIER_WEIGHTS.get(tier, 0.0) as float

	# Step 3: assign base per-item weight
	var working: Dictionary = {}
	for item: Dictionary in items:
		var tier: String = str(item.get("rarity", "Common"))
		var count: int = tier_counts.get(tier, 1) as int
		var tier_pct: float = 0.0
		if tier_total_weight > 0.0 and count > 0:
			tier_pct = (TIER_WEIGHTS.get(tier, 0.0) as float / tier_total_weight) * remaining_pool
		working[str(item.get("name", ""))] = tier_pct / count

	# Step 4: apply flat_boosts within each tier
	for item_name: String in flat_boosts:
		if not working.has(item_name):
			continue
		var boost: float = flat_boosts[item_name] as float
		var item_tier: String = _get_tier(item_name, items)
		var total_others: float = 0.0
		for other: Dictionary in items:
			var other_name: String = str(other.get("name", ""))
			if other_name != item_name and str(other.get("rarity", "Common")) == item_tier:
				total_others += working.get(other_name, 0.0) as float
		working[item_name] = (working.get(item_name, 0.0) as float) + boost
		if total_others > 0.0:
			for other: Dictionary in items:
				var other_name: String = str(other.get("name", ""))
				if other_name != item_name and str(other.get("rarity", "Common")) == item_tier:
					var old: float = working.get(other_name, 0.0) as float
					var share: float = (old / total_others) * boost
					working[other_name] = maxf(0.1, old - share)

	# Step 5: apply multiplier_boosts
	for item_name: String in multiplier_boosts:
		if not working.has(item_name):
			continue
		var mult: float = multiplier_boosts[item_name] as float
		var item_tier: String = _get_tier(item_name, items)
		var old_pct: float = working.get(item_name, 0.0) as float
		var new_pct: float = old_pct * (1.0 + mult / 100.0)
		var excess: float = new_pct - old_pct
		working[item_name] = new_pct
		var total_others: float = 0.0
		for other: Dictionary in items:
			var other_name: String = str(other.get("name", ""))
			if other_name != item_name and str(other.get("rarity", "Common")) == item_tier:
				total_others += working.get(other_name, 0.0) as float
		if total_others > 0.0:
			for other: Dictionary in items:
				var other_name: String = str(other.get("name", ""))
				if other_name != item_name and str(other.get("rarity", "Common")) == item_tier:
					var old: float = working.get(other_name, 0.0) as float
					var share: float = (old / total_others) * excess
					working[other_name] = maxf(0.1, old - share)

	# Step 6: insert pre_allocated at fixed percentages
	for fixed_name: String in pre_allocated:
		working[fixed_name] = pre_allocated[fixed_name] as float

	# Step 7: normalize to 100%
	var total: float = 0.0
	for pct: float in working.values():
		total += pct
	if total > 0.0:
		for key: String in working:
			working[key] = (working[key] as float) / total * 100.0

	# Step 8: build sorted table
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


static func _get_tier(item_name: String, items: Array[Dictionary]) -> String:
	for item: Dictionary in items:
		if str(item.get("name", "")) == item_name:
			return str(item.get("rarity", "Common"))
	return "Common"


static func _print_debug(table: Array[Dictionary], label: String) -> void:
	print("=== ROLLING: %s ===" % label)
	print("  %-30s %-15s %s" % ["Item Name", "Tier", "%"])
	for entry: Dictionary in table:
		print("  %-30s %-15s %.2f%%" % [entry.get("name", ""), entry.get("tier", ""), entry.get("pct", 0.0)])
