class_name PartyStats

#Team-wide aggregates used by contract checks and enemy scaling.



static func top_level(team: Array[MercenaryData]) -> int:
	var best: int = 0
	for merc: MercenaryData in team:
		if merc == null:
			continue
		best = maxi(best, int(merc.stats.get("level", 0)))
	return best


static func average_stat(team: Array[MercenaryData], key: String) -> float:
	var total: float = 0.0
	var count: int = 0
	for merc: MercenaryData in team:
		if merc == null:
			continue
		total += float(merc.stats.get(key, 0.0))
		count += 1
	if count == 0:
		return 0.0
	return total / float(count)


static func context(team: Array[MercenaryData]) -> Dictionary:
	var count: int = 0
	for merc: MercenaryData in team:
		if merc != null:
			count += 1
	return {"average_level": average_stat(team, "level"), "merc_count": count}
