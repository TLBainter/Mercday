class_name LevelUpTests

#Level-up schedule, pool building and pick application. Run with --levelup-tests.

static func run() -> bool:
	seed(4242)
	var res := {"pass": 0, "fail": 0}
	_case_schedule(res)
	_case_sheet(res)
	_case_marks(res)
	_case_attribute_pool(res)
	_case_magic_pool(res)
	_case_apply(res)
	_case_gear_perk(res)
	_case_gear_weight(res)
	_case_lifepath(res)
	_case_bank(res)
	_case_catch_up(res)
	_case_resolve(res)
	_case_generation(res)
	_case_sheet_printer(res)
	return TestFixtures.summarize(res, "LEVELUP")


static func _case_schedule(res: Dictionary) -> void:
	var exp_ok: bool = true
	for level: int in [0, 1, 2, 4, 40]:
		exp_ok = exp_ok and LevelUpSystem.is_experience_level(level)
	TestFixtures.check(res, "even levels and 0 and 1 spend an experience point", exp_ok,
		"0, 1, 2, 4 and 40")
	var exp_off: bool = true
	for level: int in [3, 5, 41, 42]:
		exp_off = exp_off and not LevelUpSystem.is_experience_level(level)
	TestFixtures.check(res, "odd levels and levels past the cap spend none", exp_off,
		"3, 5, 41 and 42")
	var skill_ok: bool = true
	for level: int in [3, 5, 39]:
		skill_ok = skill_ok and LevelUpSystem.is_skill_level(level)
	TestFixtures.check(res, "odd levels from 3 to 39 give a skill point", skill_ok, "3, 5 and 39")
	var skill_off: bool = true
	for level: int in [0, 1, 2, 40, 41]:
		skill_off = skill_off and not LevelUpSystem.is_skill_level(level)
	TestFixtures.check(res, "even levels and levels past 39 give none", skill_off,
		"0, 1, 2, 40 and 41")


static func _case_sheet(res: Dictionary) -> void:
	TestFixtures.check(res, "Level Ups.tsv loads its 46 option rows",
		DataManager.level_up_rows.size() == 46, "%d rows" % DataManager.level_up_rows.size())
	var expected: Array = [[0, 7], [1, 6], [2, 8], [8, 8], [10, 8], [18, 8], [20, 7], [28, 7],
		[30, 10], [40, 10], [3, 0], [41, 0]]
	for pair: Array in expected:
		var level: int = int(pair[0])
		var want: int = int(pair[1])
		var got: int = LevelUpSystem.tier_rows(level).size()
		TestFixtures.check(res, "level %d offers %d rows" % [level, want], got == want,
			"%d rows" % got)
	var ordinals: Array[int] = []
	for row: Dictionary in LevelUpSystem.tier_rows(30):
		if str(row.get("option", "")) == "lifepath_event":
			ordinals.append(int(row.get("ordinal", 0)))
	TestFixtures.check(res, "the duplicated lifepath rows get separate ordinals",
		ordinals.size() == 2 and ordinals[0] == 1 and ordinals[1] == 2, "ordinals %s" % str(ordinals))


static func _case_marks(res: Dictionary) -> void:
	var merc := TestFixtures.sheet_merc("Marks")
	var before: int = _count_option(LevelUpSystem.build_pool(merc, 30), "skill_point")
	TestFixtures.check(res, "both duplicated skill point rows are offered", before == 2,
		"%d offered" % before)
	for row: Dictionary in LevelUpSystem.tier_rows(30):
		if str(row.get("option", "")) == "skill_point" and int(row.get("ordinal", 0)) == 1:
			merc.level_up_marks[LevelUpSystem.mark_key(row)] = true
	var pool: Array[Dictionary] = LevelUpSystem.build_pool(merc, 30)
	var left: int = _count_option(pool, "skill_point")
	var left_ordinal: int = 0
	for entry: Dictionary in pool:
		var row: Dictionary = entry.get("row", {}) as Dictionary
		if str(row.get("option", "")) == "skill_point":
			left_ordinal = int(row.get("ordinal", 0))
	TestFixtures.check(res, "a marked row leaves its duplicate in the pool",
		left == 1 and left_ordinal == 2, "%d left, ordinal %d" % [left, left_ordinal])


static func _case_attribute_pool(res: Dictionary) -> void:
	var even := TestFixtures.sheet_merc("Even")
	TestFixtures.check(res, "cores already at 4 are offered no 2 to 3 step",
		not _has_option(LevelUpSystem.build_pool(even, 2), "attribute:2:3"),
		"dexterity %d" % int(even.stats.get("dexterity", 0)))
	var low := TestFixtures.sheet_merc("Low", 5.0, {"max_dexterity": 4})
	TestFixtures.check(res, "a core at 2 with room to grow is offered the step",
		_has_option(LevelUpSystem.build_pool(low, 2), "attribute:2:3"),
		"dexterity %d of %d" % [int(low.stats.get("dexterity", 0)),
			int(low.max_stats.get("max_dexterity", 0))])
	low.max_stats["max_dexterity"] = 2
	TestFixtures.check(res, "a core with no room to grow is not offered the step",
		not _has_option(LevelUpSystem.build_pool(low, 2), "attribute:2:3"),
		"dexterity %d of %d" % [int(low.stats.get("dexterity", 0)),
			int(low.max_stats.get("max_dexterity", 0))])


static func _case_magic_pool(res: Dictionary) -> void:
	var warrior := TestFixtures.sheet_merc("Warrior")
	warrior.tradition = DataManager.traditions.get("Warrior", null) as TraditionData
	var mage := TestFixtures.sheet_merc("Mage")
	mage.tradition = DataManager.traditions.get("Mage", null) as TraditionData
	if warrior.tradition == null or mage.tradition == null:
		TestFixtures.check(res, "the Warrior and Mage traditions load", false,
			"Traditions.tsv is missing one of them")
		return
	TestFixtures.check(res, "a non-caster is offered no magic points",
		not _has_option(LevelUpSystem.build_pool(warrior, 2), "max_mp"), "Warrior")
	TestFixtures.check(res, "a casting tradition is offered magic points",
		_has_option(LevelUpSystem.build_pool(mage, 2), "max_mp"), "Mage")
	warrior.circumstance_flags["Spellcast (Vigor)"] = true
	TestFixtures.check(res, "a Spellcast circumstance opens magic points",
		_has_option(LevelUpSystem.build_pool(warrior, 2), "max_mp"), "Warrior with Spellcast (Vigor)")


#The detail text of one pick, for the checks that report it.
static func _apply_detail(merc: MercenaryData, row: Dictionary) -> String:
	return str(LevelUpSystem._apply(merc, row).get("detail", ""))


static func _case_apply(res: Dictionary) -> void:
	_check_pool_gain(res, "max_hp", "maximum_hit_points", "current_hp")
	_check_pool_gain(res, "max_ep", "maximum_endurance_points", "current_ep")
	_check_pool_gain(res, "max_mp", "maximum_magic_points", "current_mp")
	_check_pool_gain(res, "action_points", "action_points", "current_ap")
	var pacer := TestFixtures.sheet_merc("Pace")
	var before_pace: int = int(pacer.stats.get("pace", 0))
	LevelUpSystem._apply(pacer, _row("Test", [0], "pace"))
	StatCalculator.refresh(pacer)
	TestFixtures.check(res, "a pace pick raises pace by one",
		int(pacer.stats.get("pace", 0)) == before_pace + 1,
		"pace %d to %d" % [before_pace, int(pacer.stats.get("pace", 0))])
	var att := TestFixtures.sheet_merc("Attribute", 5.0, {"max_dexterity": 4})
	var att_detail: String = _apply_detail(att, _row("Test", [2], "attribute:2:3"))
	TestFixtures.check(res, "an attribute pick raises the bonus and the core",
		int(att.stat_bonuses.get("dexterity", 0)) == 1 and int(att.stats.get("dexterity", 0)) == 3,
		"bonus %s, dexterity %d, %s" % [str(att.stat_bonuses.get("dexterity", 0)),
			int(att.stats.get("dexterity", 0)), att_detail])
	var circ := TestFixtures.sheet_merc("Circumstance")
	var flags_before: int = TestFixtures.true_flags(circ).size()
	var circ_detail: String = _apply_detail(circ, _row("Test", [0], "circumstance"))
	TestFixtures.check(res, "a circumstance pick sets exactly one new flag",
		TestFixtures.true_flags(circ).size() == flags_before + 1 and ConstCircumstances.DATA.has(circ_detail)
			and not circ.blocked_circumstances.has(circ_detail),
		"%d to %d flags, %s" % [flags_before, TestFixtures.true_flags(circ).size(), circ_detail])
	var kno := TestFixtures.sheet_merc("Knowledge")
	var kno_detail: String = _apply_detail(kno, _row("Test", [0], "knowledge"))
	TestFixtures.check(res, "a knowledge pick appends one knowledge",
		kno.knowledges.size() == 1 and kno.tools.is_empty(), kno_detail)
	var tool := TestFixtures.sheet_merc("Tool")
	var tool_detail: String = _apply_detail(tool, _row("Test", [0], "tool"))
	TestFixtures.check(res, "a tool pick appends one tool",
		tool.tools.size() == 1 and tool.knowledges.is_empty(), tool_detail)
	var either := TestFixtures.sheet_merc("Either")
	var either_detail: String = _apply_detail(either, _row("Test", [1], "knowledge_or_tool"))
	TestFixtures.check(res, "a knowledge or tool pick fills exactly one of the two lists",
		either.knowledges.size() + either.tools.size() == 1, either_detail)
	var pts := TestFixtures.sheet_merc("Points")
	LevelUpSystem._apply(pts, _row("Test", [1], "skill_point"))
	LevelUpSystem._apply(pts, _row("Test", [2], "tradition_skill_point"))
	LevelUpSystem._apply(pts, _row("Test", [10], "class_skill_tree"))
	TestFixtures.check(res, "the three point counters each rise by one",
		pts.skill_points == 1 and pts.tradition_skill_points == 1 and pts.class_skill_trees == 1,
		LevelUpSystem.counters(pts))
	LevelUpSystem._apply(pts, _row("Test", [0], "bank"))
	TestFixtures.check(res, "a bank pick banks the point", pts.banked_experience_points == 1,
		LevelUpSystem.counters(pts))


static func _case_gear_perk(res: Dictionary) -> void:
	var bare := TestFixtures.sheet_merc("Bare")
	TestFixtures.check(res, "a merc with no gear is offered no gear perk",
		not _has_option(LevelUpSystem.build_pool(bare, 1), "armor_or_weapon_perk"), "no gear held")
	var weapon_keys: Array[String] = _weapon_library_keys(1)
	var armor_key: String = _armor_library_key()
	if weapon_keys.is_empty() or armor_key == "":
		TestFixtures.check(res, "the gear perk libraries load", false,
			"weapon keys %d, armor key '%s'" % [weapon_keys.size(), armor_key])
		return
	var armed := TestFixtures.sheet_merc("Armed")
	armed.equipped_weapon = TestFixtures.weapon(weapon_keys[0])
	TestFixtures.check(res, "an owned weapon type offers its perks",
		_has_option(LevelUpSystem.build_pool(armed, 1), "armor_or_weapon_perk"),
		"weapon key %s" % weapon_keys[0])
	var had: int = WeaponArmorPerkLibrary.owned_for_key(armed.weapon_perks, weapon_keys[0]).size()
	var weapon_detail: String = _apply_detail(armed, _row("Test", [1], "armor_or_weapon_perk"))
	var gained: int = WeaponArmorPerkLibrary.owned_for_key(armed.weapon_perks, weapon_keys[0]).size()
	TestFixtures.check(res, "a weapon perk lands under the weapon type key",
		had == 0 and gained == 1, "%s: %s" % [weapon_keys[0], weapon_detail])
	var clad := TestFixtures.sheet_merc("Clad")
	clad.equipped_armor = _armor(armor_key)
	var armor_detail: String = _apply_detail(clad, _row("Test", [1], "armor_or_weapon_perk"))
	var armor_gained: int = WeaponArmorPerkLibrary.owned_for_key(clad.armor_perks, armor_key).size()
	TestFixtures.check(res, "an armor perk lands under the armor type",
		armor_gained == 1, "%s: %s" % [armor_key, armor_detail])


static func _case_gear_weight(res: Dictionary) -> void:
	var keys: Array[String] = _weapon_library_keys(2)
	if keys.size() < 2:
		TestFixtures.check(res, "two weapon types carry perks", false, "%d found" % keys.size())
		return
	var merc := TestFixtures.sheet_merc("Gear")
	merc.equipped_weapon = TestFixtures.weapon(keys[0])
	merc.inventory.append({"type": "weapon", "data": TestFixtures.weapon(keys[1])})
	var weights: Dictionary = _gear_weights(merc)
	TestFixtures.check(res, "the equipped weapon weighs three times the stowed one",
		is_equal_approx(float(weights.get(keys[0], 0.0)), 3.0)
			and is_equal_approx(float(weights.get(keys[1], 0.0)), 1.0),
		"%s %s against %s %s" % [keys[0], str(weights.get(keys[0], 0.0)), keys[1],
			str(weights.get(keys[1], 0.0))])
	merc.gear_use_counts["weapon:" + keys[1]] = 9
	weights = _gear_weights(merc)
	TestFixtures.check(res, "nine swings outweigh the equipped bonus",
		is_equal_approx(float(weights.get(keys[1], 0.0)), 10.0)
			and is_equal_approx(float(weights.get(keys[0], 0.0)), 3.0),
		"%s %s against %s %s" % [keys[1], str(weights.get(keys[1], 0.0)), keys[0],
			str(weights.get(keys[0], 0.0))])
	var user := TestFixtures.sheet_merc("Uses")
	LevelUpSystem.note_weapon_use(user, TestFixtures.weapon(keys[0]))
	LevelUpSystem.note_weapon_use(user, TestFixtures.weapon(keys[0]))
	TestFixtures.check(res, "note_weapon_use counts every swing",
		int(user.gear_use_counts.get("weapon:" + keys[0], 0)) == 2, str(user.gear_use_counts))
	var virtual_weapon: WeaponData = TestFixtures.weapon(keys[0])
	virtual_weapon.is_virtual = true
	LevelUpSystem.note_weapon_use(user, virtual_weapon)
	TestFixtures.check(res, "a virtual weapon is never counted",
		int(user.gear_use_counts.get("weapon:" + keys[0], 0)) == 2, str(user.gear_use_counts))
	var armor_key: String = _armor_library_key()
	if armor_key == "":
		TestFixtures.check(res, "an armor type carries perks", false, "no armor library key")
		return
	user.equipped_armor = _armor(armor_key)
	LevelUpSystem.note_armor_use(user)
	TestFixtures.check(res, "note_armor_use counts the battle",
		int(user.gear_use_counts.get("armor:" + armor_key, 0)) == 1, str(user.gear_use_counts))


static func _case_lifepath(res: Dictionary) -> void:
	var common := TestFixtures.register_stub(TestFixtures.lifepath_stub("Levelup Test Common", "Common"))
	var rare := TestFixtures.register_stub(TestFixtures.lifepath_stub("Levelup Test Rare", "Rare"))
	var very_rare := TestFixtures.register_stub(TestFixtures.lifepath_stub("Levelup Test Very Rare", "Very Rare"))
	var merc := TestFixtures.sheet_merc("Lifepath")
	merc.lifepath_pool.append(common.event_name)
	merc.lifepath_pool.append(rare.event_name)
	merc.lifepath_pool.append(very_rare.event_name)
	var detail: String = _apply_detail(merc, _row("Test", [2], "lifepath_event"))
	var taken: String = ""
	if not merc.lifepaths.is_empty():
		taken = merc.lifepaths[0].event_name
	TestFixtures.check(res, "the highest scored event is the one taken",
		taken == very_rare.event_name, "took '%s', %s" % [taken, detail])
	var full := TestFixtures.sheet_merc("Full")
	for i: int in range(LifepathProgression.MAX_EVENTS):
		full.lifepaths.append(TestFixtures.lifepath_stub("Levelup Test Filler %d" % i, "Common"))
	full.lifepath_pool.append(very_rare.event_name)
	TestFixtures.check(res, "eight events close the lifepath option",
		not _has_option(LevelUpSystem.build_pool(full, 2), "lifepath_event"),
		"%d events held" % full.lifepaths.size())
	TestFixtures.unregister_stub(common)
	TestFixtures.unregister_stub(rare)
	TestFixtures.unregister_stub(very_rare)


static func _case_bank(res: Dictionary) -> void:
	var saved: Array[Dictionary] = DataManager.level_up_rows
	var rows: Array[Dictionary] = []
	rows.append(_row("Bank Tier", [0], "bank"))
	rows.append(_row("Point Tier", [1], "skill_point", 1))
	rows.append(_row("Point Tier", [1], "skill_point", 2))
	DataManager.level_up_rows = rows
	var merc := TestFixtures.sheet_merc("Banker")
	var first: Array[String] = LevelUpSystem.on_level(merc, 0)
	TestFixtures.check(res, "a bank pick stores the point for later",
		first.size() == 1 and merc.banked_experience_points == 1,
		"%d lines, banked %d" % [first.size(), merc.banked_experience_points])
	var second: Array[String] = LevelUpSystem.on_level(merc, 1)
	var picks: int = TestFixtures.count_lines(second, "LEVEL UP PICK:", true)
	TestFixtures.check(res, "the banked point buys a second pick",
		picks == 2 and merc.banked_experience_points == 0 and merc.skill_points == 2,
		"%d picks, banked %d, %d skill points" % [picks, merc.banked_experience_points,
			merc.skill_points])
	var third: Array[String] = LevelUpSystem.on_level(merc, 1)
	TestFixtures.check(res, "an empty pool banks the point",
		TestFixtures.count_lines(third, "EXPERIENCE POINT BANKED:", true) == 1 and merc.banked_experience_points == 1,
		"%d lines, banked %d" % [third.size(), merc.banked_experience_points])
	DataManager.level_up_rows = saved


static func _case_catch_up(res: Dictionary) -> void:
	var merc := TestFixtures.sheet_merc("Ladder")
	StatCalculator.prime(merc)
	merc.stats["level"] = 9.0
	StatCalculator.refresh(merc)
	var lines: Array[String] = LevelUpSystem.catch_up(merc)
	TestFixtures.check(res, "catch_up resolves every level to date",
		merc.level_ups_resolved == 9, "resolved %d over %d lines" % [merc.level_ups_resolved,
			lines.size()])
	var schedule: int = 0
	var spent: int = 0
	var bank_picks: int = 0
	for entry: Dictionary in merc.level_up_log:
		if str(entry.get("option", "")) == "schedule_skill_point":
			schedule += 1
			continue
		spent += 1
		if str(entry.get("option", "")) == "bank":
			bank_picks += 1
	TestFixtures.check(res, "the four odd levels each give a skill point",
		schedule == 4 and merc.skill_points >= 4,
		"%d schedule entries, %d skill points" % [schedule, merc.skill_points])
	TestFixtures.check(res, "every experience point is spent or banked",
		6 + bank_picks == spent + merc.banked_experience_points,
		"%d points, %d spent, %d banked" % [6 + bank_picks, spent, merc.banked_experience_points])
	TestFixtures.check(res, "a second catch_up does nothing",
		LevelUpSystem.catch_up(merc).is_empty(), "resolved %d" % merc.level_ups_resolved)


static func _case_resolve(res: Dictionary) -> void:
	var merc := TestFixtures.sheet_merc("Resolver")
	merc.level_ups_resolved = 5
	merc.xp = ExperienceSystem.xp_for_level(6)
	var lines: Array[String] = ExperienceSystem.resolve_level_ups(merc)
	TestFixtures.check(res, "a level gained prints its level line",
		TestFixtures.count_lines(lines, "LEVEL UP:", true) == 1, "%d lines" % lines.size())
	TestFixtures.check(res, "a level gained spends or banks its point",
		TestFixtures.count_lines(lines, "LEVEL UP PICK:", true)
			+ TestFixtures.count_lines(lines, "EXPERIENCE POINT BANKED:", true) >= 1,
		" | ".join(lines))
	TestFixtures.check(res, "resolve_level_ups records the level it ran",
		merc.level_ups_resolved == 6, "resolved %d" % merc.level_ups_resolved)


static func _case_generation(res: Dictionary) -> void:
	MercGenerator.forced_level = 9
	var merc: MercenaryData = MercGenerator.generate()
	MercGenerator.forced_level = -1
	if merc == null:
		TestFixtures.check(res, "merc generation returns a merc", false, "null merc")
		return
	TestFixtures.check(res, "a generated merc arrives with its levels resolved",
		merc.level_ups_resolved == 9 and merc.skill_points >= 4,
		"resolved %d, %d skill points" % [merc.level_ups_resolved, merc.skill_points])
	var template: NPCTemplate = DataManager.npc_templates.get("Bandit Melee", null) as NPCTemplate
	if template == null:
		TestFixtures.check(res, "an NPC template loads", false, "Bandit Melee is missing")
		return
	var npc: MercenaryData = NPCGenerator.generate(template, {}, 5)
	if npc == null:
		TestFixtures.check(res, "NPC generation returns a merc", false, "null NPC")
		return
	TestFixtures.check(res, "a generated NPC arrives with its levels resolved",
		npc.level_ups_resolved == 5 and npc.skill_points >= 2,
		"resolved %d, %d skill points" % [npc.level_ups_resolved, npc.skill_points])


static func _case_sheet_printer(res: Dictionary) -> void:
	var merc := TestFixtures.sheet_merc("Printed")
	merc.skill_points = 2
	merc.level_up_log.append({"level": 2, "tier": "Levels 2-8", "option": "skill_point",
		"detail": "skill points 1"})
	var text: String = MercSheetPrinter.merc_to_string(merc)
	TestFixtures.check(res, "the sheet prints the level-up picks",
		text.contains("Level Ups:") and text.contains("L2 skill_point"), "Level Ups line")
	TestFixtures.check(res, "the sheet prints the point counters",
		text.contains("Skill Points:") and text.contains("skill 2"), "Skill Points line")


static func _row(tier: String, levels: Array, option: String, ordinal: int = 1) -> Dictionary:
	return {"tier": tier, "levels": levels, "option": option, "weight": 1.0,
		"description": "", "ordinal": ordinal}


static func _armor(armor_type: String) -> ArmorData:
	var a := ArmorData.new()
	a.item_name = armor_type + " (test)"
	a.armor_type = armor_type
	return a


#Raises one pool stat through _apply and reports the stat and its current counterpart.
static func _check_pool_gain(res: Dictionary, option: String, stat_key: String,
		current_field: String) -> void:
	var merc := TestFixtures.sheet_merc("Pool " + option)
	var before_stat: int = int(merc.stats.get(stat_key, 0))
	var before_current: int = int(merc.get(current_field))
	LevelUpSystem._apply(merc, _row("Test", [0], option))
	StatCalculator.refresh(merc)
	var after_stat: int = int(merc.stats.get(stat_key, 0))
	var after_current: int = int(merc.get(current_field))
	TestFixtures.check(res, "%s raises %s and survives a refresh" % [option, stat_key],
		after_stat == before_stat + 1 and after_current == before_current + 1,
		"%s %d to %d, %s %d to %d" % [stat_key, before_stat, after_stat, current_field,
			before_current, after_current])


static func _has_option(pool: Array[Dictionary], option: String) -> bool:
	return _count_option(pool, option) > 0


static func _count_option(pool: Array[Dictionary], option: String) -> int:
	var total: int = 0
	for entry: Dictionary in pool:
		var row: Dictionary = entry.get("row", {}) as Dictionary
		if str(row.get("option", "")) == option:
			total += 1
	return total


static func _gear_weights(merc: MercenaryData) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in LevelUpSystem._gear_candidates(merc):
		out[str(entry.get("key", ""))] = float(entry.get("weight", 0.0))
	return out


static func _weapon_library_keys(wanted: int) -> Array[String]:
	var keys: Array[String] = []
	for key: String in DataManager.weapon_trait_library:
		if (DataManager.weapon_trait_library[key] as Array).is_empty():
			continue
		keys.append(key)
		if keys.size() >= wanted:
			break
	return keys


static func _armor_library_key() -> String:
	for key: String in DataManager.armor_trait_library:
		for entry: Variant in (DataManager.armor_trait_library[key] as Array):
			var td: TraitData = entry as TraitData
			if td != null and td.trait_type == "Perk":
				return key
	return ""
