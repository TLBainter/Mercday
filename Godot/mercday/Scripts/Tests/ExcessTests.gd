class_name ExcessTests

#Deterministic excess HP, EP and MP pool cases. Run: godot --headless --path . -- --excess-tests
#Damage cases use direct types (Sonic, Will) so no defence roll is drawn and nothing depends on luck.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_add(res)
	_case_take_hp(res)
	_case_pay_ep(res)
	_case_clear(res)
	_case_choose_pool(res)
	_case_defense(res)
	_case_dot(res)
	_case_trait_grant(res)
	_case_contract_grants(res)
	return TestFixtures.summarize(res, "EXCESS")


#Stats come from the real Stats.tsv formulas so BattleState.create can order the merc.
static func _merc(name: String) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = name
	m.max_stats = {"max_vigor": 8, "max_dexterity": 8, "max_cognition": 8, "max_wile": 8, "size": 1}
	m.luck_roll = 5.0
	m.stats = {"level": 5}
	m.stats = StatCalculator.calculate_all(m)
	m.stats["pain_limit"] = 0
	m.stats_baseline = StatCalculator.calculate_all(m)
	m.current_hp = int(m.stats.get("maximum_hit_points", 1))
	m.current_ep = int(m.stats.get("maximum_endurance_points", 0))
	return m


#Trait names must be unique: TraitRuntime caches parsed clauses by trait name.
static func _trait(name: String, cell: String) -> TraitData:
	var td := TraitData.new()
	td.trait_name = name
	td.trait_type = "Perk"
	td.effect_dsl = cell
	return td


static func _has(lines: Array[String], text: String) -> bool:
	for line: String in lines:
		if line.contains(text):
			return true
	return false


static func _case_add(res: Dictionary) -> void:
	var m := _merc("Ada")
	var first: int = ExcessPool.add(m, "hp", 2)
	TestFixtures.check(res, "add returns the delta", first == 2 and m.excess_hp == 2,
		"delta %d, pool %d" % [first, m.excess_hp])
	var capped: int = ExcessPool.add(m, "hp", 5)
	TestFixtures.check(res, "add clamps at CAP", capped == 1 and m.excess_hp == ExcessPool.CAP,
		"delta %d, pool %d of cap %d" % [capped, m.excess_hp, ExcessPool.CAP])
	var full: int = ExcessPool.add(m, "hp", 1)
	TestFixtures.check(res, "add at cap returns zero", full == 0 and m.excess_hp == ExcessPool.CAP,
		"delta %d, pool %d" % [full, m.excess_hp])
	var down: int = ExcessPool.add(m, "hp", -5)
	TestFixtures.check(res, "add floors at zero", down == -ExcessPool.CAP and m.excess_hp == 0,
		"delta %d, pool %d" % [down, m.excess_hp])
	ExcessPool.add(m, "ep", 2)
	ExcessPool.add(m, "mp", 1)
	TestFixtures.check(res, "amount reads each pool",
		ExcessPool.amount(m, "hp") == 0 and ExcessPool.amount(m, "ep") == 2
		and ExcessPool.amount(m, "mp") == 1,
		"hp %d ep %d mp %d" % [ExcessPool.amount(m, "hp"), ExcessPool.amount(m, "ep"),
		ExcessPool.amount(m, "mp")])
	var unknown: int = ExcessPool.add(m, "rep", 1)
	TestFixtures.check(res, "unknown pool ignored", unknown == 0 and ExcessPool.amount(m, "rep") == 0,
		"delta %d, amount %d" % [unknown, ExcessPool.amount(m, "rep")])


static func _case_take_hp(res: Dictionary) -> void:
	var m := _merc("Bran")
	m.current_hp = 10
	m.excess_hp = 2
	var taken: Dictionary = ExcessPool.take_hp(m, 5)
	TestFixtures.check(res, "take_hp drains excess first",
		int(taken["from_excess"]) == 2 and int(taken["from_hp"]) == 3 and int(taken["total"]) == 5
		and m.excess_hp == 0 and m.current_hp == 7,
		"split %d/%d total %d, pools %d/%d" % [int(taken["from_excess"]), int(taken["from_hp"]),
		int(taken["total"]), m.excess_hp, m.current_hp])
	ExcessPool.refund_hp(m, int(taken["from_excess"]), int(taken["from_hp"]))
	TestFixtures.check(res, "refund_hp restores the split", m.excess_hp == 2 and m.current_hp == 10,
		"excess %d hp %d" % [m.excess_hp, m.current_hp])
	TestFixtures.check(res, "hp_cap_for_floor counts excess", ExcessPool.hp_cap_for_floor(m) == 11,
		"expected 11, got %d" % ExcessPool.hp_cap_for_floor(m))
	m.current_hp = 1
	m.excess_hp = 2
	var floored: Dictionary = ExcessPool.take_hp(m, 9, 1)
	TestFixtures.check(res, "take_hp stops at the hp floor",
		int(floored["from_excess"]) == 2 and int(floored["from_hp"]) == 0
		and m.excess_hp == 0 and m.current_hp == 1,
		"split %d/%d, pools %d/%d" % [int(floored["from_excess"]), int(floored["from_hp"]),
		m.excess_hp, m.current_hp])


static func _case_pay_ep(res: Dictionary) -> void:
	var m := _merc("Cass")
	m.current_ep = 0
	m.excess_ep = 1
	TestFixtures.check(res, "available_ep counts excess", ExcessPool.available_ep(m) == 1,
		"expected 1, got %d" % ExcessPool.available_ep(m))
	m.current_ep = 4
	m.excess_ep = 2
	var paid: Dictionary = ExcessPool.pay_ep(m, 3)
	TestFixtures.check(res, "pay_ep spends excess first",
		int(paid["from_excess"]) == 2 and int(paid["from_ep"]) == 1
		and m.excess_ep == 0 and m.current_ep == 3,
		"split %d/%d, pools %d/%d" % [int(paid["from_excess"]), int(paid["from_ep"]),
		m.excess_ep, m.current_ep])
	ExcessPool.refund_ep(m, int(paid["from_excess"]), int(paid["from_ep"]))
	TestFixtures.check(res, "refund_ep restores the split", m.excess_ep == 2 and m.current_ep == 4,
		"excess %d ep %d" % [m.excess_ep, m.current_ep])


static func _case_clear(res: Dictionary) -> void:
	var m := _merc("Dree")
	m.excess_hp = 2
	m.excess_ep = 1
	TestFixtures.check(res, "header lists the held pools", ExcessPool.header(m) == "  ExHP:2  ExEP:1",
		"got '%s'" % ExcessPool.header(m))
	var lines: Array[String] = ExcessPool.clear(m, "contract return")
	var first: String = "" if lines.is_empty() else lines[0]
	TestFixtures.check(res, "clear returns one line",
		lines.size() == 1 and first == "EXCESS LOST: Dree 2 ExHP, 1 ExEP (contract return)",
		"%d lines, first '%s'" % [lines.size(), first])
	TestFixtures.check(res, "clear zeroes every pool",
		m.excess_hp == 0 and m.excess_ep == 0 and m.excess_mp == 0,
		"hp %d ep %d mp %d" % [m.excess_hp, m.excess_ep, m.excess_mp])
	TestFixtures.check(res, "header of empty pools is blank", ExcessPool.header(m) == "",
		"got '%s'" % ExcessPool.header(m))
	var again: Array[String] = ExcessPool.clear(m, "contract return")
	TestFixtures.check(res, "clear of empty pools is silent", again.is_empty(),
		"%d lines" % again.size())


static func _case_choose_pool(res: Dictionary) -> void:
	var m := _merc("Enna")
	TestFixtures.check(res, "no mp feature picks ep",
		not ExcessPool.uses_mp(m) and ExcessPool.choose_ep_or_mp(m) == "ep",
		"uses_mp %s, chose %s" % [str(ExcessPool.uses_mp(m)), ExcessPool.choose_ep_or_mp(m)])
	var caster := _merc("Fenn")
	caster.passive_effects.append("spend:mp:cast")
	caster.stats["maximum_endurance_points"] = 8
	caster.stats["maximum_magic_points"] = 8
	caster.current_ep = 8
	caster.current_mp = 2
	TestFixtures.check(res, "mp feature picks the deeper deficit",
		ExcessPool.uses_mp(caster) and ExcessPool.choose_ep_or_mp(caster) == "mp",
		"uses_mp %s, chose %s" % [str(ExcessPool.uses_mp(caster)), ExcessPool.choose_ep_or_mp(caster)])


static func _case_defense(res: Dictionary) -> void:
	var m := _merc("Gale")
	m.current_hp = 10
	m.excess_hp = 2
	var hit: Dictionary = DefenseSystem.resolve(m, 4, "Sonic")
	TestFixtures.check(res, "direct hit drains excess before hp",
		int(hit["excess_hp_absorbed"]) == 2 and int(hit["hp_absorbed"]) == 2
		and m.excess_hp == 0 and m.current_hp == 8,
		"absorbed %d/%d, pools %d/%d" % [int(hit["excess_hp_absorbed"]), int(hit["hp_absorbed"]),
		m.excess_hp, m.current_hp])
	var w := _merc("Hale")
	w.current_hp = 1
	w.excess_hp = 2
	var will: Dictionary = DefenseSystem.resolve(w, 5, "Will")
	TestFixtures.check(res, "will floor spends excess and leaves 1 hp",
		int(will["final_damage"]) == 2 and int(will["excess_hp_absorbed"]) == 2
		and int(will["hp_absorbed"]) == 0 and w.excess_hp == 0 and w.current_hp == 1,
		"final %d, absorbed %d/%d, pools %d/%d" % [int(will["final_damage"]),
		int(will["excess_hp_absorbed"]), int(will["hp_absorbed"]), w.excess_hp, w.current_hp])


static func _case_dot(res: Dictionary) -> void:
	var a := _merc("Iris")
	var b := _merc("Foe")
	var team_a: Array[MercenaryData] = [a]
	var team_b: Array[MercenaryData] = [b]
	var state: BattleState = BattleState.create(team_a, team_b, null, true)
	a.current_hp = 10
	a.excess_hp = 2
	ConstStates.apply_state(a, ConstStates.BURNING)
	var lines: Array[String] = BattleStateUpdater.apply_dot_effects(a, state)
	TestFixtures.check(res, "dot drains excess before hp",
		a.excess_hp == 1 and a.current_hp == 10 and lines.size() == 1,
		"excess %d hp %d, %d lines" % [a.excess_hp, a.current_hp, lines.size()])
	TestFixtures.check(res, "dot line notes the excess spent", _has(lines, "(1 ExHP)"),
		"lines: %s" % ", ".join(lines))


static func _case_trait_grant(res: Dictionary) -> void:
	var m := _merc("Jorn")
	m.perks.append(_trait("Excess Probe Grant", "on:contract_start:always:resource:excess_hp:+1"))
	var lines: Array[String] = []
	TraitRuntime.fire("contract_start", m, {"lines": lines})
	TestFixtures.check(res, "resource leaf grants one excess hp",
		m.excess_hp == 1 and _has(lines, "gains 1 Excess HP (Excess Probe Grant)"),
		"pool %d, lines: %s" % [m.excess_hp, ", ".join(lines)])
	m.excess_hp = ExcessPool.CAP
	var full: Array[String] = []
	TraitRuntime.fire("contract_start", m, {"lines": full})
	TestFixtures.check(res, "resource leaf at cap reports the full pool",
		m.excess_hp == ExcessPool.CAP
		and _has(full, "already holds %d Excess HP" % ExcessPool.CAP),
		"pool %d, lines: %s" % [m.excess_hp, ", ".join(full)])


static func _case_contract_grants(res: Dictionary) -> void:
	var owner := _merc("Kael")
	var ally := _merc("Mira")
	owner.perks.append(_trait("Excess Probe Ally",
		"on:contract_start:always:to:random_ally:resource:excess_ep:+1"))
	var run := ContractRun.new()
	var team: Array[MercenaryData] = [owner, ally]
	run.team.assign(team)
	TraitRuntime.begin_contract(run)
	TestFixtures.check(res, "random_ally grants to the ally, not the owner",
		ally.excess_ep == 1 and owner.excess_ep == 0,
		"owner %d, ally %d" % [owner.excess_ep, ally.excess_ep])
	TestFixtures.check(res, "grant line reaches the run log",
		_has(run.log_lines, "Mira gains 1 Excess EP"),
		"%d log lines: %s" % [run.log_lines.size(), ", ".join(run.log_lines)])
	var vet := _merc("Nils")
	vet.perks.append(_trait("Excess Probe Combat",
		"on:contract_complete_combat:always:resource:excess_hp:+1"))
	var solo_run := ContractRun.new()
	var solo: Array[MercenaryData] = [vet]
	solo_run.team.assign(solo)
	TraitRuntime.on_combat_complete(solo_run, "Skirmish")
	TestFixtures.check(res, "contract_complete_combat grants excess",
		vet.excess_hp == 1 and _has(solo_run.log_lines, "Nils gains 1 Excess HP"),
		"pool %d, %d log lines" % [vet.excess_hp, solo_run.log_lines.size()])
