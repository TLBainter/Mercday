class_name AgeTests

#Age bands, the generation effects each band applies and the Age requirement subject.
#Run: godot --headless --path . -- --age-tests
#Every test merc starts at level 5 with 500 xp and 8 in every core maximum.


static func run() -> bool:
	seed(4242)
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_bands(res)
	_case_thirds(res)
	_case_distribution(res)
	_case_elder_effects(res)
	_case_elder_floor(res)
	_case_elder_cap(res)
	_case_young_effects(res)
	_case_adult_effects(res)
	_case_age_subject(res)
	_case_generated_roster(res)
	_case_hybrid_le(res)
	_case_ageless(res)
	_case_npc_adult(res)
	_case_elder_pool(res)
	var total: int = int(res["pass"]) + int(res["fail"])
	print("AGE TESTS SUMMARY: %d/%d passed, %d failed" % [int(res["pass"]), total, int(res["fail"])])
	return int(res["fail"]) == 0


static func _check(res: Dictionary, label: String, ok: bool, detail: String) -> void:
	if ok:
		res["pass"] = int(res["pass"]) + 1
		print("PASS %s | %s" % [label, detail])
	else:
		res["fail"] = int(res["fail"]) + 1
		print("FAIL %s | %s" % [label, detail])


static func _reset() -> void:
	CampaignKnowledge.clear()
	RelationshipSystem.clear_tallies()
	LifepathTally.clear()
	LifepathProgression.clear()
	CheckSystem.forced_rolls.clear()


static func _merc(name: String) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = name
	m.merc_uid = CampaignKnowledge.next_uid()
	m.max_stats = {"max_vigor": 8, "max_dexterity": 8, "max_cognition": 8, "max_wile": 8, "size": 1}
	m.luck_roll = 5.0
	m.stats = {"level": 5}
	m.stats = StatCalculator.calculate_all(m)
	m.stats["pain_limit"] = 0
	m.stats_baseline = StatCalculator.calculate_all(m)
	m.current_hp = int(m.stats.get("maximum_hit_points", 1))
	m.current_ep = 0
	m.xp = ExperienceSystem.xp_for_level(5)
	return m


#Rebuilds merc.stats after a direct max_stats or stat_bonuses write, the way _merc does.
static func _recalc(m: MercenaryData) -> void:
	m.stats = StatCalculator.calculate_all(m)
	m.stats["pain_limit"] = 0
	m.stats_baseline = StatCalculator.calculate_all(m)


#Fills the event list so the Elder grant finds no room and leaves the stats untouched.
static func _fill_lifepaths(m: MercenaryData) -> void:
	for i: int in range(LifepathProgression.MAX_EVENTS):
		var filler := LifepathData.new()
		filler.event_type = "Starting"
		filler.event_name = "Filler %d" % i
		filler.rarity = "Common"
		m.lifepaths.append(filler)


static func _lp(op: String, value: String) -> LifepathData:
	var lp := LifepathData.new()
	lp.event_type = "Experienced"
	lp.event_name = "Age Probe"
	lp.rarity = "Common"
	lp.requirements.assign([{"subject": "Age", "op": op, "value": value, "conj": ""}])
	return lp


static func _core(m: MercenaryData, key: String) -> int:
	return int(m.stats.get(key, 0))


static func _cap(m: MercenaryData, key: String) -> int:
	return int(m.max_stats.get(key, 0))


static func _case_bands(res: Dictionary) -> void:
	var b110: Dictionary = MercGenerator.age_bands(110)
	_check(res, "bands le 110",
		int(b110["young_lo"]) == 0 and int(b110["young_hi"]) == 35
		and int(b110["adult_lo"]) == 36 and int(b110["adult_hi"]) == 88
		and int(b110["elder_lo"]) == 89 and int(b110["elder_hi"]) == 110,
		"expected young 0..35 adult 36..88 elder 89..110, got young %d..%d adult %d..%d elder %d..%d"
		% [int(b110["young_lo"]), int(b110["young_hi"]), int(b110["adult_lo"]),
			int(b110["adult_hi"]), int(b110["elder_lo"]), int(b110["elder_hi"])])
	var cases110: Array = [[0, "Young"], [35, "Young"], [36, "Adult"], [88, "Adult"],
		[89, "Elder"], [110, "Elder"]]
	for c: Array in cases110:
		var got: String = MercGenerator.age_category_for(int(c[0]), 110)
		_check(res, "category le 110 age %d" % int(c[0]), got == str(c[1]),
			"expected %s, got %s" % [str(c[1]), got])
	var b20: Dictionary = MercGenerator.age_bands(20)
	_check(res, "bands le 20",
		int(b20["young_lo"]) == 0 and int(b20["young_hi"]) == 5
		and int(b20["adult_lo"]) == 6 and int(b20["adult_hi"]) == 16
		and int(b20["elder_lo"]) == 17 and int(b20["elder_hi"]) == 20,
		"expected young 0..5 adult 6..16 elder 17..20, got young %d..%d adult %d..%d elder %d..%d"
		% [int(b20["young_lo"]), int(b20["young_hi"]), int(b20["adult_lo"]),
			int(b20["adult_hi"]), int(b20["elder_lo"]), int(b20["elder_hi"])])
	var cases20: Array = [[0, "Young"], [5, "Young"], [6, "Adult"], [16, "Adult"],
		[17, "Elder"], [20, "Elder"]]
	for c: Array in cases20:
		var got: String = MercGenerator.age_category_for(int(c[0]), 20)
		_check(res, "category le 20 age %d" % int(c[0]), got == str(c[1]),
			"expected %s, got %s" % [str(c[1]), got])
	var zero_ok: bool = true
	for age: int in [0, 5, 500]:
		if MercGenerator.age_category_for(age, 0) != "Adult":
			zero_ok = false
	_check(res, "category le 0", zero_ok, "ages 0, 5 and 500 all read Adult without a life expectancy")


static func _case_thirds(res: Dictionary) -> void:
	var cases: Array = [
		[0, 35, 0, 0, 11], [0, 35, 1, 12, 23], [0, 35, 2, 24, 35],
		[17, 20, 1, 18, 18], [5, 4, 2, 5, 5],
	]
	for c: Array in cases:
		var got: Array[int] = MercGenerator.age_third(int(c[0]), int(c[1]), int(c[2]))
		_check(res, "third %d..%d part %d" % [int(c[0]), int(c[1]), int(c[2])],
			got[0] == int(c[3]) and got[1] == int(c[4]),
			"expected [%d, %d], got [%d, %d]" % [int(c[3]), int(c[4]), got[0], got[1]])


static func _case_distribution(res: Dictionary) -> void:
	seed(7)
	var labels: Array[String] = ["Low-Young", "Mid-Young", "High-Young",
		"Low-Adult", "Mid-Adult", "High-Adult", "Low-Elder", "Mid-Elder", "High-Elder"]
	var ranges: Array = [[0, 11], [12, 23], [24, 35], [36, 52], [53, 70], [71, 88],
		[89, 95], [96, 102], [103, 110]]
	var hits: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var counts: Dictionary = {"Young": 0, "Adult": 0, "Elder": 0}
	var out_of_range: int = 0
	var rolls: int = 4000
	for i: int in range(rolls):
		var age: int = MercGenerator.roll_age(110)
		if age < 0 or age > 110:
			out_of_range += 1
			continue
		var cat: String = MercGenerator.age_category_for(age, 110)
		counts[cat] = int(counts[cat]) + 1
		for j: int in range(ranges.size()):
			var band: Array = ranges[j]
			if age >= int(band[0]) and age <= int(band[1]):
				hits[j] += 1
				break
	var young_pct: float = 100.0 * float(counts["Young"]) / float(rolls)
	var adult_pct: float = 100.0 * float(counts["Adult"]) / float(rolls)
	var elder_pct: float = 100.0 * float(counts["Elder"]) / float(rolls)
	_check(res, "roll_age stays in range", out_of_range == 0,
		"%d of %d rolls fell outside 0..110" % [out_of_range, rolls])
	_check(res, "roll_age young share", young_pct >= 7.0 and young_pct <= 13.0,
		"expected 7%% to 13%%, got %.1f%% over %d rolls" % [young_pct, rolls])
	_check(res, "roll_age elder share", elder_pct >= 12.0 and elder_pct <= 18.0,
		"expected 12%% to 18%%, got %.1f%% over %d rolls" % [elder_pct, rolls])
	_check(res, "roll_age adult share", adult_pct >= 70.0 and adult_pct <= 80.0,
		"expected 70%% to 80%%, got %.1f%% over %d rolls" % [adult_pct, rolls])
	var picked: Array[int] = [1, 3, 4, 5, 6, 7]
	var picked_ok: bool = true
	var picked_detail: Array[String] = []
	for j: int in picked:
		picked_detail.append("%s %d" % [labels[j], hits[j]])
		if hits[j] <= 0:
			picked_ok = false
	_check(res, "roll_age covers six thirds", picked_ok, ", ".join(picked_detail))
	var unpicked: Array[int] = [0, 2, 8]
	var unpicked_ok: bool = true
	var unpicked_detail: Array[String] = []
	for j: int in unpicked:
		unpicked_detail.append("%s %d" % [labels[j], hits[j]])
		if hits[j] != 0:
			unpicked_ok = false
	_check(res, "roll_age skips three thirds", unpicked_ok, ", ".join(unpicked_detail))


static func _case_elder_effects(res: Dictionary) -> void:
	_reset()
	var m := _merc("Elda")
	_fill_lifepaths(m)
	var v0: int = _core(m, "vigor")
	var d0: int = _core(m, "dexterity")
	var c0: int = _core(m, "cognition")
	var w0: int = _core(m, "wile")
	MercGenerator.apply_age_effects(m, "Elder")
	var v1: int = _core(m, "vigor")
	var d1: int = _core(m, "dexterity")
	var c1: int = _core(m, "cognition")
	var w1: int = _core(m, "wile")
	_check(res, "elder physical stats",
		(v0 + d0) - (v1 + d1) == 3 and mini(v1, d1) == 2 and maxi(v1, d1) == 3,
		"expected %d and %d to become 2 and 3, a fall of 3 (one -1 bonus, both -1 as the maximum goes 8 to 7), got %d and %d"
		% [v0, d0, v1, d1])
	_check(res, "elder physical maxima",
		_cap(m, "max_vigor") == 7 and _cap(m, "max_dexterity") == 7,
		"expected 7 and 7, got %d and %d" % [_cap(m, "max_vigor"), _cap(m, "max_dexterity")])
	_check(res, "elder mental stats", mini(c1, w1) == 4 and maxi(c1, w1) == 5,
		"expected %d and %d to become 4 and 5 (floor(9 / 2) with one +1 bonus), got %d and %d"
		% [c0, w0, c1, w1])
	_check(res, "elder mental maxima",
		_cap(m, "max_cognition") == 9 and _cap(m, "max_wile") == 9,
		"expected 9 and 9, got %d and %d" % [_cap(m, "max_cognition"), _cap(m, "max_wile")])
	_check(res, "elder xp and level", m.xp == 575 and _core(m, "level") == 5,
		"expected 575 xp at level 5, got %d xp at level %d" % [m.xp, _core(m, "level")])
	_reset()
	var g := _merc("Elder Two")
	var before: int = g.lifepaths.size()
	MercGenerator.apply_age_effects(g, "Elder")
	_check(res, "elder extra lifepath", g.lifepaths.size() == before + 1,
		"expected %d events, got %d" % [before + 1, g.lifepaths.size()])


static func _case_elder_floor(res: Dictionary) -> void:
	_reset()
	var m := _merc("Frail")
	_fill_lifepaths(m)
	m.max_stats["max_vigor"] = 2
	m.max_stats["max_dexterity"] = 2
	_recalc(m)
	var v0: int = _core(m, "vigor")
	var d0: int = _core(m, "dexterity")
	MercGenerator.apply_age_effects(m, "Elder")
	var vb: float = float(m.stat_bonuses.get("vigor", 0.0))
	var db: float = float(m.stat_bonuses.get("dexterity", 0.0))
	_check(res, "elder floor skips the physical -1", vb >= 0.0 and db >= 0.0,
		"vigor and dexterity started at %d and %d so neither could take the -1; bonuses %.1f and %.1f, maxima now %d and %d"
		% [v0, d0, vb, db, _cap(m, "max_vigor"), _cap(m, "max_dexterity")])


static func _case_elder_cap(res: Dictionary) -> void:
	_reset()
	var m := _merc("Sage")
	_fill_lifepaths(m)
	m.stat_bonuses["cognition"] = 4.0
	m.stat_bonuses["wile"] = 4.0
	_recalc(m)
	var c0: int = _core(m, "cognition")
	var w0: int = _core(m, "wile")
	MercGenerator.apply_age_effects(m, "Elder")
	var c1: int = _core(m, "cognition")
	var w1: int = _core(m, "wile")
	_check(res, "elder cap holds",
		c0 == 8 and w0 == 8 and c1 <= _cap(m, "max_cognition") and w1 <= _cap(m, "max_wile"),
		"started at %d and %d on maximum 8, now %d and %d on maxima %d and %d"
		% [c0, w0, c1, w1, _cap(m, "max_cognition"), _cap(m, "max_wile")])


static func _case_young_effects(res: Dictionary) -> void:
	_reset()
	var m := _merc("Kit")
	ContractModifiers.set_level(m, 10)
	var v0: int = _core(m, "vigor")
	var d0: int = _core(m, "dexterity")
	var c0: int = _core(m, "cognition")
	var w0: int = _core(m, "wile")
	MercGenerator.apply_age_effects(m, "Young")
	var v1: int = _core(m, "vigor")
	var d1: int = _core(m, "dexterity")
	var c1: int = _core(m, "cognition")
	var w1: int = _core(m, "wile")
	_check(res, "young xp and level", m.xp == 500 and _core(m, "level") == 5,
		"expected 500 xp at level 5 from 1000 xp at level 10, got %d xp at level %d"
		% [m.xp, _core(m, "level")])
	_check(res, "young physical stats", mini(v1, d1) == 4 and maxi(v1, d1) == 5,
		"expected %d and %d to become 4 and 5 (floor(9 / 2) with one +1 bonus), got %d and %d"
		% [v0, d0, v1, d1])
	_check(res, "young physical maxima",
		_cap(m, "max_vigor") == 9 and _cap(m, "max_dexterity") == 9,
		"expected 9 and 9, got %d and %d" % [_cap(m, "max_vigor"), _cap(m, "max_dexterity")])
	_check(res, "young mental stats", mini(c1, w1) == 3 and maxi(c1, w1) == 4,
		"expected %d and %d to become 3 and 4 (one -1 bonus), got %d and %d" % [c0, w0, c1, w1])
	_check(res, "young mental maxima",
		_cap(m, "max_cognition") == 8 and _cap(m, "max_wile") == 8,
		"expected 8 and 8, got %d and %d" % [_cap(m, "max_cognition"), _cap(m, "max_wile")])


static func _case_adult_effects(res: Dictionary) -> void:
	_reset()
	var m := _merc("Even")
	var xp0: int = m.xp
	var level0: int = _core(m, "level")
	var stats0: Array[int] = [_core(m, "vigor"), _core(m, "dexterity"),
		_core(m, "cognition"), _core(m, "wile")]
	var max0: Array[int] = [_cap(m, "max_vigor"), _cap(m, "max_dexterity"),
		_cap(m, "max_cognition"), _cap(m, "max_wile")]
	var lp0: int = m.lifepaths.size()
	MercGenerator.apply_age_effects(m, "Adult")
	var stats1: Array[int] = [_core(m, "vigor"), _core(m, "dexterity"),
		_core(m, "cognition"), _core(m, "wile")]
	var max1: Array[int] = [_cap(m, "max_vigor"), _cap(m, "max_dexterity"),
		_cap(m, "max_cognition"), _cap(m, "max_wile")]
	_check(res, "adult changes nothing",
		m.xp == xp0 and _core(m, "level") == level0 and stats1 == stats0
		and max1 == max0 and m.lifepaths.size() == lp0,
		"xp %d to %d, level %d to %d, stats %s to %s, maxima %s to %s, events %d to %d"
		% [xp0, m.xp, level0, _core(m, "level"), str(stats0), str(stats1),
			str(max0), str(max1), lp0, m.lifepaths.size()])


static func _case_age_subject(res: Dictionary) -> void:
	_reset()
	var m := _merc("Grey")
	m.age_category = "Elder"
	var is_elder: LifepathData = _lp("IS", "Elder")
	var is_young: LifepathData = _lp("IS", "Young")
	var not_young: LifepathData = _lp("IS NOT", "Young")
	var bad: LifepathData = _lp("IS", "Old")
	_check(res, "age IS Elder", LifepathRequirements.allows(m, is_elder, null),
		"category %s against IS Elder" % m.age_category)
	_check(res, "age IS Young", not LifepathRequirements.allows(m, is_young, null),
		"category %s against IS Young" % m.age_category)
	_check(res, "age IS NOT Young", LifepathRequirements.allows(m, not_young, null),
		"category %s against IS NOT Young" % m.age_category)
	_check(res, "age subject supported",
		LifepathRequirements.is_supported(is_elder) and LifepathRequirements.is_supported(not_young),
		"IS Elder and IS NOT Young both read as supported")
	_check(res, "age value Old unsupported", not LifepathRequirements.is_supported(bad),
		"IS Old names no band and must not be supported")


static func _case_generated_roster(res: Dictionary) -> void:
	_reset()
	MercGenerator.forced_level = 6
	var counts: Dictionary = {"Young": 0, "Adult": 0, "Elder": 0}
	var bad_category: int = 0
	var bad_age: int = 0
	var bad_zero: int = 0
	var bad_level: int = 0
	var bad_band_level: int = 0
	var zero_le: int = 0
	for i: int in range(60):
		var merc: MercenaryData = MercGenerator.generate(i)
		var cat: String = merc.age_category
		if not counts.has(cat):
			bad_category += 1
			continue
		counts[cat] = int(counts[cat]) + 1
		var le: int = MercGenerator.life_expectancy_for(merc)
		if le > 0:
			if merc.age < 0 or merc.age > le or MercGenerator.age_category_for(merc.age, le) != cat:
				bad_age += 1
		else:
			zero_le += 1
			var lo: int = MercGenerator.AGELESS_MIN_AGE
			var hi: int = MercGenerator.AGELESS_MAX_AGE
			if cat != "Adult" or merc.age < lo or merc.age > hi:
				bad_zero += 1
		var level: int = int(merc.stats.get("level", 0))
		if ExperienceSystem.level_for(merc.xp) != level:
			bad_level += 1
		if level != 6 or merc.xp != ExperienceSystem.xp_for_level(6):
			bad_band_level += 1
	MercGenerator.forced_level = -1
	var spread: String = "Young %d, Adult %d, Elder %d of 60 at forced level 6, %d without a life expectancy" \
		% [int(counts["Young"]), int(counts["Adult"]), int(counts["Elder"]), zero_le]
	_check(res, "roster category names", bad_category == 0,
		"%d mercs held a category outside Young, Adult and Elder" % bad_category)
	_check(res, "roster age matches band", bad_age == 0,
		"%d mercs sat outside their band; %s" % [bad_age, spread])
	_check(res, "roster no life expectancy", bad_zero == 0,
		"%d of %d mercs without a life expectancy were not Adult with an age from %d to %d"
		% [bad_zero, zero_le, MercGenerator.AGELESS_MIN_AGE, MercGenerator.AGELESS_MAX_AGE])
	_check(res, "roster xp matches level", bad_level == 0,
		"%d mercs carried xp the level does not match" % bad_level)
	_check(res, "roster forced level kept", bad_band_level == 0,
		"%d mercs left forced level 6 or 600 xp; age xp multipliers are skipped under forced_level"
		% bad_band_level)
	_check(res, "roster adult appeared", int(counts["Adult"]) > 0, spread)


static func _case_hybrid_le(res: Dictionary) -> void:
	_reset()
	var m := _merc("Hy")
	var short_lived := AncestryData.new()
	short_lived.ancestry_name = "Short"
	short_lived.life_expectancy = 40
	var long_lived := AncestryData.new()
	long_lived.ancestry_name = "Long"
	long_lived.life_expectancy = 500
	m.is_hybrid = true
	m.ancestry = short_lived
	m.recessive_ancestry = long_lived
	var le_dom_short: int = MercGenerator.life_expectancy_for(m)
	m.ancestry = long_lived
	m.recessive_ancestry = short_lived
	var le_dom_long: int = MercGenerator.life_expectancy_for(m)
	_check(res, "hybrid takes the higher expectancy",
		le_dom_short == 500 and le_dom_long == 500,
		"expected 500 either way, got %d with 40 dominant and %d with 500 dominant"
		% [le_dom_short, le_dom_long])
	m.is_hybrid = false
	m.ancestry = short_lived
	m.recessive_ancestry = long_lived
	var le_no_flag: int = MercGenerator.life_expectancy_for(m)
	_check(res, "recessive ignored without the hybrid flag", le_no_flag == 40,
		"expected 40 from the dominant ancestry alone, got %d" % le_no_flag)
	var ageless := AncestryData.new()
	ageless.ancestry_name = "Steeljoint"
	ageless.life_expectancy = -1
	var mixed := AncestryData.new()
	mixed.ancestry_name = "Mixed"
	mixed.life_expectancy = 60
	m.is_hybrid = true
	m.ancestry = ageless
	m.recessive_ancestry = mixed
	var le_one_side: int = MercGenerator.life_expectancy_for(m)
	_check(res, "hybrid with one ageless side", le_one_side == 60,
		"expected 60 from the recessive side, got %d" % le_one_side)
	m.ancestry = null
	m.recessive_ancestry = null
	var le_none: int = MercGenerator.life_expectancy_for(m)
	_check(res, "no ancestry reads -1", le_none == -1, "expected -1, got %d" % le_none)


static func _case_ageless(res: Dictionary) -> void:
	_reset()
	var m := _merc("Steel")
	var steel := AncestryData.new()
	steel.ancestry_name = "Steeljoint"
	steel.life_expectancy = -1
	m.ancestry = steel
	m.is_hybrid = false
	var xp0: int = m.xp
	var lp0: int = m.lifepaths.size()
	var stats0: Array[int] = [_core(m, "vigor"), _core(m, "dexterity"),
		_core(m, "cognition"), _core(m, "wile")]
	var max0: Array[int] = [_cap(m, "max_vigor"), _cap(m, "max_dexterity"),
		_cap(m, "max_cognition"), _cap(m, "max_wile")]
	var rolls: int = 200
	var bad_category: int = 0
	var bad_age: int = 0
	var low_age: int = MercGenerator.AGELESS_MAX_AGE
	var high_age: int = MercGenerator.AGELESS_MIN_AGE
	for i: int in range(rolls):
		m.age = 0
		m.age_category = ""
		MercGenerator._step_age(m)
		if m.age_category != "Adult":
			bad_category += 1
		if m.age < MercGenerator.AGELESS_MIN_AGE or m.age > MercGenerator.AGELESS_MAX_AGE:
			bad_age += 1
		low_age = mini(low_age, m.age)
		high_age = maxi(high_age, m.age)
	var stats1: Array[int] = [_core(m, "vigor"), _core(m, "dexterity"),
		_core(m, "cognition"), _core(m, "wile")]
	var max1: Array[int] = [_cap(m, "max_vigor"), _cap(m, "max_dexterity"),
		_cap(m, "max_cognition"), _cap(m, "max_wile")]
	_check(res, "ageless is always Adult", bad_category == 0,
		"%d of %d rolls left a category other than Adult" % [bad_category, rolls])
	_check(res, "ageless age range", bad_age == 0,
		"%d of %d rolls fell outside %d..%d"
		% [bad_age, rolls, MercGenerator.AGELESS_MIN_AGE, MercGenerator.AGELESS_MAX_AGE])
	_check(res, "ageless age spread", low_age < 40 and high_age > 110,
		"expected a low below 40 and a high above 110 over %d rolls, got %d and %d"
		% [rolls, low_age, high_age])
	_check(res, "ageless takes no age effects",
		m.xp == xp0 and m.lifepaths.size() == lp0 and stats1 == stats0 and max1 == max0,
		"xp %d to %d, events %d to %d, stats %s to %s, maxima %s to %s"
		% [xp0, m.xp, lp0, m.lifepaths.size(), str(stats0), str(stats1), str(max0), str(max1)])


static func _case_npc_adult(res: Dictionary) -> void:
	_reset()
	if DataManager.npc_templates.is_empty():
		_check(res, "npc templates loaded", false, "no NPC templates loaded")
		return
	var template: NPCTemplate = DataManager.npc_templates.values()[0] as NPCTemplate
	var npc: MercenaryData = NPCGenerator.generate(template)
	_check(res, "npc age category", npc.age_category == "Adult" and npc.age == 0,
		"expected Adult at age 0 for %s, got %s at age %d"
		% [template.npc_type, npc.age_category, npc.age])
	var is_adult: bool = LifepathRequirements.allows(npc, _lp("IS", "Adult"), null)
	var is_elder: bool = LifepathRequirements.allows(npc, _lp("IS", "Elder"), null)
	var not_young: bool = LifepathRequirements.allows(npc, _lp("IS NOT", "Young"), null)
	_check(res, "npc age requirements", is_adult and not is_elder and not_young,
		"IS Adult %s, IS Elder %s, IS NOT Young %s" % [str(is_adult), str(is_elder), str(not_young)])


static func _case_elder_pool(res: Dictionary) -> void:
	_reset()
	var m := _merc("Pool")
	var pool: Array[String] = MercGenerator.elder_event_pool(m)
	var expected: Array[String] = []
	var unsupported: String = ""
	for lp: LifepathData in DataManager.lifepaths_by_category.get("Experienced", []) as Array:
		if lp == null or not LifepathProgression.has_payoff(lp):
			continue
		if LifepathProgression.CODED_EVENTS.has(lp.event_name):
			continue
		expected.append(lp.event_name)
		if unsupported == "" and not LifepathRequirements.is_supported(lp):
			unsupported = lp.event_name
	var missing: int = 0
	for event_name: String in expected:
		if not pool.has(event_name):
			missing += 1
	_check(res, "elder pool holds every paying Experienced row",
		pool.size() == expected.size() and missing == 0,
		"expected %d rows, got %d with %d missing" % [expected.size(), pool.size(), missing])
	_check(res, "elder pool skips coded events",
		not pool.has(LifepathProgression.BUDDY) and not pool.has(LifepathProgression.IN_LOVE),
		"Buddy and In Love need a partner and stay out of the Elder draw")
	_check(res, "elder pool ignores requirements",
		unsupported != "" and pool.has(unsupported),
		"an unsupported row must still be drawable; unsupported row found: %s"
		% ("none" if unsupported == "" else unsupported))
	if pool.is_empty():
		_check(res, "elder pool not empty", false, "no Experienced row carries a payoff")
		return
	var taken: String = pool[0]
	LifepathProgression.grant(m, taken)
	var after: Array[String] = MercGenerator.elder_event_pool(m)
	_check(res, "elder pool drops a held row",
		not after.has(taken) and after.size() == pool.size() - 1,
		"expected %d rows without %s, got %d" % [pool.size() - 1, taken, after.size()])
