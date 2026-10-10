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


#Mercs other than `except` holding the key: "knowledge:<name>", "tool:<name>" or "circumstance:<display>".
#With no pool the living roster is searched; a pool is searched as given, dead mercs included.
static func holders(key: String, except: MercenaryData, pool: Variant = null) -> int:
	var roster: bool = not (pool is Array)
	var list: Array = mercs
	if not roster:
		list = pool as Array
	var count: int = 0
	for merc: MercenaryData in list:
		if merc == null or merc == except or (roster and merc.is_dead):
			continue
		if holds(merc, key):
			count += 1
	return count


static func holds(merc: MercenaryData, key: String) -> bool:
	if merc == null:
		return false
	var parts: PackedStringArray = split_key(key)
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


#A "kind:name" key as [kind, name]; a key with no colon comes back as ["", key].
static func split_key(key: String) -> PackedStringArray:
	var parts: PackedStringArray = key.split(":", true, 1)
	if parts.size() > 1:
		return parts
	return PackedStringArray(["", key])


#First merc in the list with this uid; null for a uid of 0 or below, or when none matches.
static func by_uid(pool: Array, uid: int) -> MercenaryData:
	if uid <= 0:
		return null
	for entry: Variant in pool:
		var merc: MercenaryData = entry as MercenaryData
		if merc != null and merc.merc_uid == uid:
			return merc
	return null
