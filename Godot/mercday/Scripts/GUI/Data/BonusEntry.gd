class_name BonusEntry extends Resource

#One recommended knowledge, tool or tradition and the hidden value it is worth (threshold points for Checks.tsv rows).
#The value is never shown; it only sorts the list.

@export var name: String = ""
@export var hidden_bonus: int = 0


static func make(entry_name: String, bonus: int) -> BonusEntry:
	var e := BonusEntry.new()
	e.name = entry_name
	e.hidden_bonus = bonus
	return e


#Highest bonus first; equal bonuses keep alphabetical order so the list is stable.
static func sort_desc(entries: Array[BonusEntry]) -> Array[BonusEntry]:
	entries.sort_custom(func(a: BonusEntry, b: BonusEntry) -> bool:
		if a.hidden_bonus == b.hidden_bonus:
			return a.name < b.name
		return a.hidden_bonus > b.hidden_bonus)
	return entries


#Reads a boost dictionary of name -> percent into the sorted array the viewer shows.
static func from_boosts(boosts: Dictionary) -> Array[BonusEntry]:
	var out: Array[BonusEntry] = []
	for key: Variant in boosts:
		out.append(make(str(key), int(boosts[key])))
	return sort_desc(out)


#Reads CheckStore.parse entries of {"name", key}; positive_only drops entries worth 0 or less.
static func from_parsed(entries: Array, key: String, positive_only: bool) -> Array[BonusEntry]:
	var out: Array[BonusEntry] = []
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		var bonus: int = int(d.get(key, 0))
		if positive_only and bonus <= 0:
			continue
		out.append(make(str(d.get("name", "")), bonus))
	return sort_desc(out)


#Reads the sample_data.json rows of {"name", "hidden_bonus"} into the same sorted array.
static func from_samples(rows: Array) -> Array[BonusEntry]:
	var out: Array[BonusEntry] = []
	for row: Variant in rows:
		if not (row is Dictionary):
			continue
		var d: Dictionary = row
		out.append(make(str(d.get("name", "")), int(d.get("hidden_bonus", 0))))
	return sort_desc(out)
