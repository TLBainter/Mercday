class_name TurnOrderSystem

#Random rank assigned per sort so the comparator stays a strict weak ordering.
static var _rank: Dictionary = {}
const _TIEBREAK_KEYS: Array[String] = ["speed", "dexterity", "max_dexterity", "luck"]


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
	for key: String in _TIEBREAK_KEYS:
		var a_val := float(_tiebreak_stat(a, key))
		var b_val := float(_tiebreak_stat(b, key))
		if not is_equal_approx(a_val, b_val):
			return a_val > b_val
	return int(_rank.get(a, 0)) < int(_rank.get(b, 0))


static func _tiebreak_stat(merc: MercenaryData, key: String) -> Variant:
	if key == "max_dexterity":
		return merc.max_stats.get(key, 0)
	return merc.stats.get(key, 0)
