class_name AgeSystem

const AGE_YOUNG := "Young"
const AGE_ADULT := "Adult"
const AGE_ELDER := "Elder"
const ELDER_XP_PERCENT := 115
const YOUNG_XP_PERCENT := 50
const AGE_PHYSICAL: Array[String] = ["vigor", "dexterity"]
const AGE_MENTAL: Array[String] = ["cognition", "wile"]
const AGE_PHYSICAL_MAX: Array[String] = ["max_vigor", "max_dexterity"]
const AGE_MENTAL_MAX: Array[String] = ["max_cognition", "max_wile"]
const AGELESS_MIN_AGE := 3
const AGELESS_MAX_AGE := 150


#Band edges for one life expectancy; young runs from 0, elder ends on the expectancy itself.
static func age_bands(le: int) -> Dictionary:
	var adult_lo: int = floori(float(le) / 3.0)
	var adult_hi: int = floori(float(le) * 4.0 / 5.0)
	return {
		"young_lo": 0, "young_hi": adult_lo - 1,
		"adult_lo": adult_lo, "adult_hi": adult_hi,
		"elder_lo": adult_hi + 1, "elder_hi": le,
	}


#Category one age falls in under one life expectancy; a missing expectancy reads as Adult.
static func age_category_for(age: int, le: int) -> String:
	if le <= 0:
		return AGE_ADULT
	var bands: Dictionary = age_bands(le)
	if age < int(bands["adult_lo"]):
		return AGE_YOUNG
	if age <= int(bands["adult_hi"]):
		return AGE_ADULT
	return AGE_ELDER


#Inclusive [lo, hi] of one third of a band; third is 0 Low, 1 Mid, 2 High.
static func age_third(lo: int, hi: int, third: int) -> Array[int]:
	var span: int = hi - lo + 1
	if span <= 0:
		return [lo, lo]
	var a: int = lo + int(float(span * third) / 3.0)
	var b: int = lo + int(float(span * (third + 1)) / 3.0) - 1
	return [a, maxi(a, b)]


#Rolls the designer's band table and returns a uniform age inside the third it picked.
static func roll_age(le: int) -> int:
	var bands: Dictionary = age_bands(le)
	var r: float = randf() * 100.0
	var pick: Array[int] = []
	if r < 10.0:
		pick = age_third(int(bands["young_lo"]), int(bands["young_hi"]), 1)
	elif r < 15.0:
		pick = age_third(int(bands["elder_lo"]), int(bands["elder_hi"]), 0)
	elif r < 25.0:
		pick = age_third(int(bands["elder_lo"]), int(bands["elder_hi"]), 1)
	elif r < 37.0:
		pick = age_third(int(bands["adult_lo"]), int(bands["adult_hi"]), 0)
	elif r < 52.0:
		pick = age_third(int(bands["adult_lo"]), int(bands["adult_hi"]), 2)
	else:
		pick = age_third(int(bands["adult_lo"]), int(bands["adult_hi"]), 1)
	return clampi(randi_range(pick[0], pick[1]), 0, le)


#The higher life expectancy of a hybrid's two ancestries; -1 when neither ancestry has one.
static func life_expectancy_for(merc: MercenaryData) -> int:
	var primary: int = merc.ancestry.life_expectancy if merc.ancestry != null else -1
	var secondary: int = -1
	if merc.is_hybrid and merc.recessive_ancestry != null:
		secondary = merc.recessive_ancestry.life_expectancy
	return maxi(primary, secondary)


static func step_age(merc: MercenaryData) -> void:
	var le: int = life_expectancy_for(merc)
	if le <= 0:
		merc.age = randi_range(AGELESS_MIN_AGE, AGELESS_MAX_AGE)
		merc.age_category = AGE_ADULT
		return
	merc.age = roll_age(le)
	merc.age_category = age_category_for(merc.age, le)
	apply_age_effects(merc, merc.age_category)


#Generation only stat, maximum, xp and lifepath changes for one category; a forced level keeps its xp.
static func apply_age_effects(merc: MercenaryData, category: String) -> void:
	if merc == null:
		return
	match category:
		AGE_ELDER:
			_shift_core_stat(merc, AGE_PHYSICAL, -1, 1)
			_shift_core_stat(merc, AGE_MENTAL, 1, 0)
			_shift_max_stats(merc, AGE_PHYSICAL_MAX, -1)
			_shift_max_stats(merc, AGE_MENTAL_MAX, 1)
			if MercGenerator.forced_level < 0:
				merc.xp = floori(float(merc.xp * ELDER_XP_PERCENT) / 100.0)
				ExperienceSystem.set_level_from_xp(merc)
			_grant_age_lifepath(merc)
		AGE_YOUNG:
			_shift_core_stat(merc, AGE_PHYSICAL, 1, 0)
			_shift_core_stat(merc, AGE_MENTAL, -1, 0)
			_shift_max_stats(merc, AGE_PHYSICAL_MAX, 1)
			if MercGenerator.forced_level < 0:
				merc.xp = floori(float(merc.xp * YOUNG_XP_PERCENT) / 100.0)
				ExperienceSystem.set_level_from_xp(merc)


#Moves one named core stat by delta; a stat that would break the floor or its maximum is skipped.
static func _shift_core_stat(merc: MercenaryData, keys: Array[String], delta: int, floor_value: int) -> String:
	var order: Array[String] = keys.duplicate()
	order.shuffle()
	for key: String in order:
		var cur: int = int(merc.stats.get(key, 0))
		var cap: int = int(merc.max_stats.get("max_" + key, 0))
		if delta < 0 and cur + delta < floor_value:
			continue
		if delta > 0 and cur + delta > cap:
			continue
		merc.stat_bonuses[key] = float(merc.stat_bonuses.get(key, 0.0)) + float(delta)
		StatCalculator.refresh(merc)
		return key
	return ""


static func _shift_max_stats(merc: MercenaryData, keys: Array[String], delta: int) -> void:
	for key: String in keys:
		merc.max_stats[key] = maxi(1, int(merc.max_stats.get(key, 0)) + delta)
	StatCalculator.refresh(merc)


#Every Experienced row with a real trait payoff that the merc does not hold yet; no requirement gate.
static func elder_event_pool(merc: MercenaryData) -> Array[String]:
	var names: Array[String] = []
	for lp: LifepathData in DataManager.lifepaths_by_category.get("Experienced", []) as Array:
		if lp == null or LifepathProgression.has_event(merc, lp.event_name):
			continue
		if LifepathProgression.CODED_EVENTS.has(lp.event_name):
			continue
		if LifepathProgression.has_payoff(lp):
			names.append(lp.event_name)
	return names


#One extra Elder event: paying Experienced rows except Buddy and In Love, by rarity, no requirement gate; else Starting.
static func _grant_age_lifepath(merc: MercenaryData) -> String:
	var names: Array[String] = elder_event_pool(merc)
	var pick: String = LifepathProgression.draw(names) if not names.is_empty() else ""
	if pick == "":
		var items: Array[Dictionary] = []
		for lp: LifepathData in LifepathRequirements.filter(merc, DataManager.starting_lifepaths.values()):
			if not LifepathProgression.has_event(merc, lp.event_name):
				items.append({"name": lp.event_name, "rarity": lp.rarity})
		if not items.is_empty():
			pick = WeightedTable.roll(items)
	if pick == "":
		return ""
	var lines: Array[String] = LifepathProgression.grant(merc, pick)
	return pick if not lines.is_empty() else ""
