class_name GuildRoster

#The guild's current merc list, kept for questions one merc cannot answer alone, such as whether
#anyone else holds a Knowledge, Tool or Circumstance. Set wherever the roster changes.
#Distinct from BeauSystem.roster, which tracks time apart and drops a merc who defects, departs or is kidnapped.

static var mercs: Array[MercenaryData] = []


static func set_roster(list: Array[MercenaryData]) -> void:
	mercs.clear()
	for merc: MercenaryData in list:
		if merc != null:
			mercs.append(merc)


static func reset() -> void:
	mercs.clear()


#Mercs the guild still pays for: alive and not held captive.
static func living() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in mercs:
		if merc != null and not merc.is_dead and not SalarySystem.is_captive(merc):
			out.append(merc)
	return out


#Mean level of the living roster; an empty roster reads as 1.0 so a new guild still draws level 1 work.
static func average_level() -> float:
	var list: Array[MercenaryData] = living()
	if list.is_empty():
		return 1.0
	var total: int = 0
	for merc: MercenaryData in list:
		total += ExperienceSystem.current_level(merc)
	return float(total) / float(list.size())


#Living mercs other than `except` holding the key: "knowledge:<name>", "tool:<name>" or "circumstance:<display>".
static func holders(key: String, except: MercenaryData) -> int:
	var count: int = 0
	for merc: MercenaryData in mercs:
		if merc == null or merc == except or merc.is_dead:
			continue
		if holds(merc, key):
			count += 1
	return count


static func holds(merc: MercenaryData, key: String) -> bool:
	if merc == null:
		return false
	var parts: PackedStringArray = key.split(":", true, 1)
	if parts.size() < 2:
		return false
	var name: String = parts[1]
	match parts[0]:
		"knowledge":
			for k: UtilityTraitData in merc.knowledges:
				if k != null and k.utility_name == name:
					return true
		"tool":
			for t: UtilityTraitData in merc.tools:
				if t != null and t.utility_name == name:
					return true
		"circumstance":
			return bool(merc.circumstance_flags.get(name, false))
	return false
