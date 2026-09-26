class_name TurnOrderSystem

#Random rank assigned per sort so the comparator stays a strict weak ordering.
static var _rank: Dictionary = {}


#Tiebreakers: Speed -> Dexterity -> Max Dexterity -> Luck -> random rank.
static func sort_initiative(mercs: Array[MercenaryData]) -> Array[MercenaryData]:
	var result := mercs.duplicate()
	var shuffled := mercs.duplicate()
	shuffled.shuffle()
	_rank.clear()
	for i: int in range(shuffled.size()):
		_rank[shuffled[i]] = i
	result.sort_custom(_cmp)
	_rank.clear()
	return result


static func _cmp(a: MercenaryData, b: MercenaryData) -> bool:
	var a_speed := float(a.stats.get("speed", 0))
	var b_speed := float(b.stats.get("speed", 0))
	if not is_equal_approx(a_speed, b_speed):
		return a_speed > b_speed

	var a_dex := float(a.stats.get("dexterity", 0))
	var b_dex := float(b.stats.get("dexterity", 0))
	if not is_equal_approx(a_dex, b_dex):
		return a_dex > b_dex

	var a_max_dex := float(a.max_stats.get("max_dexterity", 0))
	var b_max_dex := float(b.max_stats.get("max_dexterity", 0))
	if not is_equal_approx(a_max_dex, b_max_dex):
		return a_max_dex > b_max_dex

	var a_luck := float(a.stats.get("luck", 0))
	var b_luck := float(b.stats.get("luck", 0))
	if not is_equal_approx(a_luck, b_luck):
		return a_luck > b_luck

	return int(_rank.get(a, 0)) < int(_rank.get(b, 0))
