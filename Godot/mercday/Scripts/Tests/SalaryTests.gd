class_name SalaryTests

#Merc wages, guild opinion, the living roster and the contract level roll.
#Run: godot --headless --path . -- --salary-tests
#Every case clears the roster and the captive pool first, so the suite is order independent.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_rank(res)
	_case_rarity_score(res)
	_case_need_score(res)
	_case_asking_salary(res)
	_case_hire(res)
	_case_debit(res)
	_case_opinion(res)
	_case_roster(res)
	_case_contract_level(res)
	_case_multiplier(res)
	_case_generate(res)
	_case_request_pin(res)
	_case_monster(res)
	_case_header(res)
	_reset()
	return TestFixtures.summarize(res, "SALARY")


static func _reset() -> void:
	GuildRoster.reset()
	MercPool.clear()


static func _merc(name: String, level: int) -> MercenaryData:
	var merc := MercenaryData.new()
	merc.merc_name = name
	merc.stats = {"level": level, "wile": 0}
	return merc


static func _utility(name: String, rarity: String) -> UtilityTraitData:
	var u := UtilityTraitData.new()
	u.utility_name = name
	u.utility_rarity = rarity
	return u


static func _ancestry(name: String, rarity: String) -> AncestryData:
	var a := AncestryData.new()
	a.ancestry_name = name
	a.rarity = rarity
	return a


static func _tradition(name: String) -> TraditionData:
	var t := TraditionData.new()
	t.tradition_name = name
	return t


static func _heritage(name: String) -> HeritageData:
	var h := HeritageData.new()
	h.heritage_name = name
	return h


static func _weapon(name: String, rarity: String) -> WeaponData:
	var w := WeaponData.new()
	w.item_name = name
	w.item_rarity = rarity
	return w


static func _armor(name: String, rarity: String) -> ArmorData:
	var a := ArmorData.new()
	a.item_name = name
	a.item_rarity = rarity
	return a


static func _item(name: String, rarity: String) -> ItemData:
	var i := ItemData.new()
	i.item_name = name
	i.item_rarity = rarity
	return i


static func _case_rank(res: Dictionary) -> void:
	var table: Array[Array] = [["Ordinary", -1], ["Common", 0], ["Uncommon", 1], ["Rare", 2],
		["Very Rare", 3], ["Legendary", 4], ["Unique", 3], ["Heirloom", 4], ["Artifact", 5]]
	var bad: Array[String] = []
	for entry: Array in table:
		var want: int = int(entry[1])
		if RarityRank.rank(String(entry[0])) != want:
			bad.append("%s %d" % [String(entry[0]), RarityRank.rank(String(entry[0]))])
	TestFixtures.check(res, "every rarity word ranks as written", bad.is_empty(),
		TestFixtures.detail(bad, table.size(), "words"))
	TestFixtures.check(res, "the lookup ignores case and padding",
		RarityRank.rank("very rare") == 3 and RarityRank.rank("  LEGENDARY  ") == 4,
		"'very rare' %d, '  LEGENDARY  ' %d" % [RarityRank.rank("very rare"), RarityRank.rank("  LEGENDARY  ")])
	TestFixtures.check(res, "a blank or unknown word ranks Common",
		RarityRank.rank("") == 0 and RarityRank.rank("   ") == 0 and RarityRank.rank("Mythic") == 0,
		"blank %d, spaces %d, Mythic %d" % [RarityRank.rank(""), RarityRank.rank("   "),
		RarityRank.rank("Mythic")])


static func _case_rarity_score(res: Dictionary) -> void:
	_reset()
	var merc: MercenaryData = _merc("Rare Rita", 1)
	merc.ancestry = _ancestry("Vashai", "Rare")
	merc.recessive_ancestry = _ancestry("Ghulan", "Legendary")
	merc.heritage = _heritage("Highborn")
	TestFixtures.check(res, "the primary ancestry is the only ancestry counted",
		SalarySystem.rarity_score(merc) == 2, "score %d, expected 2" % SalarySystem.rarity_score(merc))
	merc.knowledges = [_utility("Tactics", "Uncommon"), _utility("Cosmos", "Legendary")] as Array[UtilityTraitData]
	merc.tools = [_utility("Tracker's", "Ordinary")] as Array[UtilityTraitData]
	TestFixtures.check(res, "knowledges and tools add their own rarity",
		SalarySystem.rarity_score(merc) == 6, "score %d, expected 6" % SalarySystem.rarity_score(merc))
	merc.equipped_weapon = _weapon("Dagger", "Common")
	merc.offhand_weapon = _weapon("Sabre", "Uncommon")
	merc.equipped_armor = _armor("Heavy", "Rare")
	TestFixtures.check(res, "the held weapons and armor count",
		SalarySystem.rarity_score(merc) == 9, "score %d, expected 9" % SalarySystem.rarity_score(merc))
	merc.inventory = [{"type": "weapon", "data": _weapon("Spare Axe", "Uncommon")}]
	merc.items = [_item("Rope", "Very Rare")]
	TestFixtures.check(res, "the inventory and the item list count",
		SalarySystem.rarity_score(merc) == 13, "score %d, expected 13" % SalarySystem.rarity_score(merc))
	var ammo_name: String = ""
	for key: Variant in DataManager.ammo:
		ammo_name = String(key)
		break
	if ammo_name == "":
		TestFixtures.check(res, "ammo in stock counts once", false, "Ammo.tsv loaded no rows")
		return
	var ammo: ItemData = DataManager.ammo[ammo_name] as ItemData
	var want: int = 13 + RarityRank.rank(ammo.item_rarity)
	merc.ammo_inventory = {ammo_name: 5, "Nothing At All": 0}
	TestFixtures.check(res, "ammo in stock counts once and an empty stack never does",
		SalarySystem.rarity_score(merc) == want,
		"score %d, expected %d with %s (%s)" % [SalarySystem.rarity_score(merc), want, ammo_name,
		ammo.item_rarity])


static func _case_need_score(res: Dictionary) -> void:
	_reset()
	var first: MercenaryData = _merc("Ada", 1)
	first.tradition = _tradition("Warrior")
	first.ancestry = _ancestry("Vashai", "Rare")
	first.heritage = _heritage("Highborn")
	first.knowledges = [_utility("Tactics", "Rare"), _utility("Cosmos", "Rare")] as Array[UtilityTraitData]
	first.tools = [_utility("Tracker's", "Rare")] as Array[UtilityTraitData]
	var none: Array[MercenaryData] = []
	TestFixtures.check(res, "the first hire of an empty guild scores every point",
		SalarySystem.need_score(first, none) == 8,
		"need %d, expected 8" % SalarySystem.need_score(first, none))
	var twin: MercenaryData = _merc("Bel", 1)
	twin.tradition = _tradition("Warrior")
	twin.ancestry = _ancestry("Vashai", "Rare")
	twin.heritage = _heritage("Highborn")
	twin.knowledges = [_utility("Tactics", "Rare")] as Array[UtilityTraitData]
	twin.tools = [_utility("Tracker's", "Rare")] as Array[UtilityTraitData]
	var earlier: Array[MercenaryData] = [first]
	TestFixtures.check(res, "a merc the guild already has brings nothing new",
		SalarySystem.need_score(twin, earlier) == 0,
		"need %d, expected 0" % SalarySystem.need_score(twin, earlier))
	var mixed: MercenaryData = _merc("Cor", 1)
	mixed.tradition = _tradition("Warrior")
	mixed.ancestry = _ancestry("Ghulan", "Rare")
	mixed.heritage = _heritage("Highborn")
	mixed.knowledges = [_utility("Tactics", "Rare"), _utility("Diplomacy", "Rare")] as Array[UtilityTraitData]
	mixed.tools = [_utility("Blacksmith's", "Rare")] as Array[UtilityTraitData]
	TestFixtures.check(res, "a shared tradition costs the 3 and each new name pays 1",
		SalarySystem.need_score(mixed, earlier) == 3,
		"need %d, expected 3" % SalarySystem.need_score(mixed, earlier))
	var plain: MercenaryData = _merc("Dev", 1)
	plain.tradition = _tradition("Brave")
	TestFixtures.check(res, "a new tradition with nothing else scores 3",
		SalarySystem.need_score(plain, earlier) == 3,
		"need %d, expected 3" % SalarySystem.need_score(plain, earlier))


static func _case_asking_salary(res: Dictionary) -> void:
	_reset()
	var merc: MercenaryData = _merc("Eir", 4)
	merc.tradition = _tradition("Warrior")
	merc.ancestry = _ancestry("Vashai", "Rare")
	var none: Array[MercenaryData] = []
	var rarity: int = SalarySystem.rarity_score(merc)
	var need: int = SalarySystem.need_score(merc, none)
	var want: int = 4 + 2 * rarity + 2 * need
	TestFixtures.check(res, "the asking salary is level plus twice rarity plus twice need",
		SalarySystem.asking_salary(merc, none) == want,
		"salary %d, expected %d (level 4, rarity %d, need %d)"
		% [SalarySystem.asking_salary(merc, none), want, rarity, need])
	var cheap: MercenaryData = _merc("Fen", 0)
	cheap.ancestry = _ancestry("Ordin", "Ordinary")
	cheap.tradition = _tradition("Warrior")
	var mates: Array[MercenaryData] = [merc]
	TestFixtures.check(res, "the asking salary never drops under 1 note",
		SalarySystem.asking_salary(cheap, mates) == 1,
		"salary %d with rarity %d and need %d" % [SalarySystem.asking_salary(cheap, mates),
		SalarySystem.rarity_score(cheap), SalarySystem.need_score(cheap, mates)])


static func _case_hire(res: Dictionary) -> void:
	_reset()
	var first: MercenaryData = _merc("Gil", 3)
	first.tradition = _tradition("Warrior")
	first.stats["wile"] = 0
	var none: Array[MercenaryData] = []
	var want: int = SalarySystem.asking_salary(first, none)
	SalarySystem.hire(first, none, 1920)
	TestFixtures.check(res, "hire writes the index, the minute and the agreed wage",
		first.hire_index == 0 and first.hired_minute == 1920 and first.monthly_salary == want,
		"index %d, minute %d, salary %d of %d" % [first.hire_index, first.hired_minute,
		first.monthly_salary, want])
	TestFixtures.check(res, "Wile 0 opens the guild opinion at -1", first.guild_opinion == -1,
		"opinion %d" % first.guild_opinion)
	var second: MercenaryData = _merc("Hob", 3)
	second.tradition = _tradition("Brave")
	second.stats["wile"] = 5
	var earlier: Array[MercenaryData] = [first]
	SalarySystem.hire(second, earlier, 2000)
	TestFixtures.check(res, "the second hire takes the next index", second.hire_index == 1,
		"index %d" % second.hire_index)
	TestFixtures.check(res, "Wile 5 opens the guild opinion at 4", second.guild_opinion == 4,
		"opinion %d" % second.guild_opinion)
	var saint: MercenaryData = _merc("Iva", 1)
	saint.stats["wile"] = 40
	SalarySystem.hire(saint, earlier, 2000)
	var wretch: MercenaryData = _merc("Jor", 1)
	wretch.stats["wile"] = -40
	SalarySystem.hire(wretch, earlier, 2000)
	TestFixtures.check(res, "the opening opinion clamps to -5 and 5",
		saint.guild_opinion == 5 and wretch.guild_opinion == -5,
		"Wile 40 gives %d, Wile -40 gives %d" % [saint.guild_opinion, wretch.guild_opinion])


static func _case_debit(res: Dictionary) -> void:
	_reset()
	var paid: MercenaryData = _merc("Kal", 1)
	paid.monthly_salary = 4
	paid.merc_uid = 501
	var dead: MercenaryData = _merc("Lis", 1)
	dead.monthly_salary = 9
	dead.merc_uid = 502
	dead.is_dead = true
	var held: MercenaryData = _merc("Mox", 1)
	held.monthly_salary = 7
	held.merc_uid = 503
	MercPool.add_captive(held, "Rescue", "Aerdis", "D1 08:00")
	var mercs: Array[MercenaryData] = [paid, dead, held]
	TestFixtures.check(res, "the month expenses skip the dead and the captive",
		SalarySystem.month_expenses(mercs) == 4, "expenses %d, expected 4" % SalarySystem.month_expenses(mercs))
	var out: Dictionary = SalarySystem.monthly_debit(mercs, "")
	var lines: Array[String] = out["lines"] as Array[String]
	TestFixtures.check(res, "the debit totals the paid mercs only", int(out["total"]) == 4,
		"total %d, expected 4" % int(out["total"]))
	TestFixtures.check(res, "a captive accrues backpay instead of a payment",
		int(out["backpay"]) == 7 and held.backpay == 7,
		"backpay %d, merc backpay %d" % [int(out["backpay"]), held.backpay])
	TestFixtures.check(res, "the debit writes one line per living merc", lines.size() == 2,
		"lines %s" % str(lines))
	TestFixtures.check(res, "the paid line and the backpay line read as written",
		lines.has("SALARY: Kal 4 notes") and lines.has("BACKPAY: Mox 7 notes (captive)"),
		"lines %s" % str(lines))
	var stamped: Dictionary = SalarySystem.monthly_debit([paid] as Array[MercenaryData], "D31 08:00")
	TestFixtures.check(res, "a stamp leads every line",
		(stamped["lines"] as Array[String])[0] == "D31 08:00 SALARY: Kal 4 notes",
		"line %s" % (stamped["lines"] as Array[String])[0])
	TestFixtures.check(res, "a debit the captive is not listed in adds nothing", held.backpay == 7,
		"backpay %d, expected 7" % held.backpay)
	SalarySystem.monthly_debit(mercs, "")
	TestFixtures.check(res, "each debit adds one more month of backpay", held.backpay == 14,
		"backpay %d, expected 14" % held.backpay)
	MercPool.clear()


static func _case_opinion(res: Dictionary) -> void:
	_reset()
	var table: Array[Array] = [[100, 114, 0], [100, 115, 1], [100, 124, 1], [100, 125, 2],
		[100, 149, 2], [100, 150, 3], [100, 199, 3], [100, 200, 4], [100, 249, 4], [100, 250, 5],
		[100, 300, 6], [100, 99, -1], [100, 96, -1], [100, 95, -2], [100, 91, -2], [100, 90, -3],
		[100, 86, -3], [100, 85, -4], [100, 81, -4], [100, 80, -5], [100, 76, -5], [100, 75, -6],
		[100, 71, -6], [100, 70, -7], [100, 1, -7], [100, 100, 0]]
	var bad: Array[String] = []
	for row: Array in table:
		var got: int = SalarySystem.opinion_delta(int(row[0]), int(row[1]))
		if got != int(row[2]):
			bad.append("%d to %d gave %d, wanted %d" % [int(row[0]), int(row[1]), got, int(row[2])])
	TestFixtures.check(res, "every raise and cut breakpoint maps as written", bad.is_empty(),
		TestFixtures.detail(bad, table.size(), "steps"))
	TestFixtures.check(res, "a salary of 0 has no percent to measure",
		SalarySystem.opinion_delta(0, 50) == 0, "delta %d" % SalarySystem.opinion_delta(0, 50))
	var merc: MercenaryData = _merc("Nid", 1)
	merc.monthly_salary = 10
	merc.guild_opinion = 0
	var opinion: int = SalarySystem.apply_salary_change(merc, 15)
	TestFixtures.check(res, "a 50% raise writes the new wage and lifts the opinion by 3",
		merc.monthly_salary == 15 and opinion == 3 and merc.guild_opinion == 3,
		"salary %d, opinion %d" % [merc.monthly_salary, merc.guild_opinion])
	SalarySystem.apply_salary_change(merc, 30)
	TestFixtures.check(res, "the opinion clamps at 5", merc.guild_opinion == 5,
		"opinion %d after a second doubling" % merc.guild_opinion)
	merc.guild_opinion = -3
	SalarySystem.apply_salary_change(merc, 0)
	TestFixtures.check(res, "a cut to nothing floors the wage at 1 and the opinion at -5",
		merc.monthly_salary == 1 and merc.guild_opinion == -5,
		"salary %d, opinion %d" % [merc.monthly_salary, merc.guild_opinion])


static func _case_roster(res: Dictionary) -> void:
	_reset()
	var alive: MercenaryData = _merc("Ost", 4)
	alive.merc_uid = 601
	var dead: MercenaryData = _merc("Pel", 10)
	dead.merc_uid = 602
	dead.is_dead = true
	var held: MercenaryData = _merc("Qui", 10)
	held.merc_uid = 603
	var other: MercenaryData = _merc("Rho", 6)
	other.merc_uid = 604
	GuildRoster.set_roster([alive, dead, held, other] as Array[MercenaryData])
	MercPool.add_captive(held, "Rescue", "Aerdis", "D1 08:00")
	var living: Array[MercenaryData] = GuildRoster.living()
	TestFixtures.check(res, "the living roster leaves out the dead and the captive",
		living.size() == 2 and living.has(alive) and living.has(other),
		"living %d of 4" % living.size())
	TestFixtures.check(res, "the average level is the mean over the living",
		is_equal_approx(GuildRoster.average_level(), 5.0),
		"average %.3f, expected 5.000" % GuildRoster.average_level())
	MercPool.clear()
	GuildRoster.reset()
	TestFixtures.check(res, "an empty roster averages to 1.0",
		is_equal_approx(GuildRoster.average_level(), 1.0),
		"average %.3f" % GuildRoster.average_level())
	GuildRoster.set_roster([dead] as Array[MercenaryData])
	TestFixtures.check(res, "a roster of nobody living averages to 1.0",
		is_equal_approx(GuildRoster.average_level(), 1.0),
		"average %.3f" % GuildRoster.average_level())
	_reset()


static func _case_contract_level(res: Dictionary) -> void:
	_reset()
	var bad: Array[String] = []
	for average: float in [1.0, 4.0, 9.0]:
		var lo: int = maxi(1, int(roundf(average * 0.75)))
		var hi: int = int(roundf(average * 1.25))
		for _i: int in range(1000):
			var level: int = ContractGenerator.roll_contract_level(average)
			if level < 1 or level < lo or level > hi:
				bad.append("avg %.0f gave %d outside %d to %d" % [average, level, lo, hi])
				break
	TestFixtures.check(res, "the contract level stays within a quarter of the average and over 0",
		bad.is_empty(), TestFixtures.detail(bad, 3000, "draws"))
	var ones: bool = true
	for _i: int in range(200):
		if ContractGenerator.roll_contract_level(1.0) != 1:
			ones = false
	TestFixtures.check(res, "a level 1 guild always draws level 1 work", ones,
		"200 draws at an average of 1.0")


static func _case_multiplier(res: Dictionary) -> void:
	var lo: float = ContractGenerator.difficulty_multiplier(0.75)
	var mid: float = ContractGenerator.difficulty_multiplier(1.0)
	var hi: float = ContractGenerator.difficulty_multiplier(1.25)
	TestFixtures.check(res, "a quarter under halves, level halves and a quarter over doubles",
		is_equal_approx(lo, 0.5) and is_equal_approx(mid, 1.0) and is_equal_approx(hi, 2.0),
		"0.75 gives %.4f, 1.00 gives %.4f, 1.25 gives %.4f" % [lo, mid, hi])
	var snaps: Array[Array] = [[0.4, 0.5], [0.6, 0.5], [1.24, 1.0], [1.26, 1.5], [3.75, 4.0], [5.0, 5.0]]
	var bad: Array[String] = []
	for row: Array in snaps:
		var got: float = ContractGenerator.snap_half(float(row[0]))
		if not is_equal_approx(got, float(row[1])):
			bad.append("%.2f gave %.2f, wanted %.2f" % [float(row[0]), got, float(row[1])])
	TestFixtures.check(res, "snap_half lands on the nearest half", bad.is_empty(),
		TestFixtures.detail(bad, snaps.size(), "values"))
	var off: int = 0
	var seen: Dictionary = {}
	for _i: int in range(500):
		var d: float = ContractGenerator.roll_difficulty()
		var steps: float = d * 2.0
		if steps != floorf(steps) or d < 0.5 or d > 5.0:
			off += 1
		seen[d] = true
	TestFixtures.check(res, "the difficulty roll is 0.5 to 5.0 in halves", off == 0,
		"%d of 500 off the grid, %d distinct values of 10" % [off, seen.size()])


static func _case_generate(res: Dictionary) -> void:
	_reset()
	var team: Array[MercenaryData] = []
	for i: int in range(3):
		var merc: MercenaryData = _merc("Roster %d" % i, 4)
		merc.merc_uid = 700 + i
		team.append(merc)
	GuildRoster.set_roster(team)
	var levels: Array[int] = []
	var off_level: int = 0
	var off_difficulty: int = 0
	for _i: int in range(50):
		var c: ContractData = ContractGenerator.generate("Military")
		if c == null:
			off_level += 1
			continue
		levels.append(c.contract_level)
		if c.contract_level < 1:
			off_level += 1
		if c.difficulty < 0.5 or c.difficulty > 5.0 or c.difficulty * 2.0 != floorf(c.difficulty * 2.0):
			off_difficulty += 1
	TestFixtures.check(res, "generate writes a contract level of 1 or more", off_level == 0,
		"%d of 50 unset, levels %s" % [off_level, str(levels.slice(0, 5))])
	TestFixtures.check(res, "the rolled difficulty stays on the 0.5 to 5.0 grid", off_difficulty == 0,
		"%d of 50 off the grid" % off_difficulty)
	var authored: ContractData = ContractLibrary.contract_type("Military")
	TestFixtures.check(res, "a contract type row carries no level of its own",
		authored != null and authored.contract_level == 0,
		"type level %d" % (-1 if authored == null else authored.contract_level))
	var want_bent: float = ContractGenerator.snap_half(clampf(
		2.5 * ContractGenerator.difficulty_multiplier(0.75),
		ContractGenerator.MIN_DIFFICULTY, ContractGenerator.MAX_DIFFICULTY))
	var bent: int = 0
	for _i: int in range(20):
		var c: ContractData = ContractLibrary.contract_type("Military")
		c.difficulty = 2.5
		c.contract_level = 3
		ContractGenerator.apply_difficulty(c, 4.0)
		if is_equal_approx(c.difficulty, want_bent):
			bent += 1
	TestFixtures.check(res, "an authored difficulty takes the level multiplier", bent == 20,
		"%d of 20 read %.2f" % [bent, want_bent])
	var kept: int = 0
	for _i: int in range(20):
		var c: ContractData = ContractLibrary.contract_type("Military")
		c.difficulty = 2.5
		c.contract_level = 4
		ContractGenerator.apply_difficulty(c, 4.0)
		if is_equal_approx(c.difficulty, 2.5):
			kept += 1
	TestFixtures.check(res, "an authored difficulty at the guild level is unchanged", kept == 20,
		"%d of 20 kept 2.5" % kept)
	var rolled: ContractData = ContractLibrary.contract_type("Military")
	rolled.contract_level = 4
	ContractGenerator.apply_difficulty(rolled, 4.0)
	TestFixtures.check(res, "an unset difficulty is rolled onto the grid",
		rolled.difficulty >= 0.5 and rolled.difficulty <= 5.0
		and rolled.difficulty * 2.0 == floorf(rolled.difficulty * 2.0),
		"difficulty %.2f" % rolled.difficulty)
	_reset()


static func _case_request_pin(res: Dictionary) -> void:
	var party: Array[MercenaryData] = []
	for i: int in range(2):
		party.append(_merc("Party %d" % i, 2))
	var req := OpponentRequest.new()
	req.party.assign(party)
	var plain: Dictionary = OpponentGenerator.context(req)
	TestFixtures.check(res, "an unset contract level leaves the party average alone",
		is_equal_approx(float(plain["average_level"]), 2.0),
		"average_level %.3f" % float(plain["average_level"]))
	req.contract_level = 7
	var pinned: Dictionary = OpponentGenerator.context(req)
	TestFixtures.check(res, "a contract level pins the context average level",
		is_equal_approx(float(pinned["average_level"]), 7.0),
		"average_level %.3f, merc_count %d" % [float(pinned["average_level"]),
		int(pinned["merc_count"])])


static func _case_monster(res: Dictionary) -> void:
	_reset()
	var event: EventData = ContractLibrary.event("Slay the Monster")
	if event == null:
		TestFixtures.check(res, "Slay the Monster has an event resource", false, "event not found")
		return
	TestFixtures.check(res, "the Slay the Monster row names one merc on a Location map",
		event.enemy == "Mercs" and event.enemy_counter == "1" and event.map_rule == "Location",
		"enemy '%s', counter '%s', map '%s'" % [event.enemy, event.enemy_counter, event.map_rule])
	var contract_run := ContractRun.new()
	contract_run.contract = ContractLibrary.contract_type("Monster Hunt")
	if contract_run.contract == null:
		TestFixtures.check(res, "the Monster Hunt contract type loads", false, "type not found")
		return
	contract_run.contract.contract_level = 4
	contract_run.contract.difficulty = 3.0
	for i: int in range(3):
		var merc: MercenaryData = _merc("Hunter %d" % i, 2)
		merc.merc_uid = 800 + i
		contract_run.team.append(merc)
	var total: int = 0
	var counts: Dictionary = {}
	var levels: Dictionary = {}
	var builds: int = 25
	for _i: int in range(builds):
		var monsters: Array[MercenaryData] = EnemyTeamBuilder.build(event, contract_run, 0)
		counts[monsters.size()] = true
		for m: MercenaryData in monsters:
			var level: int = int(m.stats.get("level", 0))
			levels[level] = true
			total += level
	TestFixtures.check(res, "a Slay the Monster event builds exactly one enemy",
		counts.size() == 1 and counts.has(1), "sizes %s over %d builds" % [str(counts.keys()), builds])
	TestFixtures.check(res, "the monster stands at twice the contract level",
		levels.size() == 1 and levels.has(8),
		"levels %s over %d builds, mean %.2f" % [str(levels.keys()), builds, float(total) / float(builds)])
	_reset()


static func _case_header(res: Dictionary) -> void:
	_reset()
	var contract_run := ContractRun.new()
	contract_run.contract = ContractLibrary.contract_type("Military")
	if contract_run.contract == null:
		TestFixtures.check(res, "the Military contract type loads", false, "type not found")
		return
	contract_run.contract.contract_level = 6
	contract_run.contract.difficulty = 2.5
	contract_run.team.append(_merc("Sig", 3))
	ContractLog.header(contract_run)
	var found: String = ""
	for line: String in contract_run.log_lines:
		if line.begins_with("CONTRACT LEVEL:"):
			found = line
	TestFixtures.check(res, "the contract header prints the level and the difficulty",
		found == "CONTRACT LEVEL: level 6 difficulty 2.5", "line '%s'" % found)
