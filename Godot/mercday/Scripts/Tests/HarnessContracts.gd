class_name HarnessContracts
extends RefCounted

#Runs the harness test contracts and settles the roster after each one.


#The roster mercs ready to deploy, topped up to `need` and shuffled; rest wait lines go to `prelude`.
static func _deploy_team(mercs: Array[MercenaryData], need: int,
		prelude: Array[String]) -> Array[MercenaryData]:
	var deployable: Array[MercenaryData] = _wait_for_rested(mercs, need, prelude)
	var topped_up: bool = false
	while deployable.size() < need:
		if not topped_up:
			topped_up = true
			print("\n====== ROSTER TOP-UP ======\n")
		var extra: MercenaryData = HarnessRoster.roster_merc(mercs.size())
		mercs.append(extra)
		HarnessRoster.grant_auto_immunity(extra, mercs.size() - 1, mercs.size())
		deployable.append(extra)
		MercSheetPrinter.print_merc(extra)
	if topped_up:
		BeauSystem.set_roster(mercs)
		GuildRoster.set_roster(mercs)
	deployable.shuffle()
	return deployable


#Restores the kept team and replaces every casualty, defector and departed merc; a live captive is kept.
static func _settle_roster(mercs: Array[MercenaryData], team: Array[MercenaryData], run: ContractRun,
		captive: MercenaryData) -> void:
	var kept: Array[MercenaryData] = []
	for merc: MercenaryData in team:
		if not run.defectors.has(merc) and not run.departed.has(merc):
			kept.append(merc)
	if captive != null and not captive.is_dead:
		kept.append(captive)
	HarnessRoster.harness_restore(kept)
	for merc: MercenaryData in run.rescued:
		if merc != null and not mercs.has(merc):
			mercs.append(merc)
	for merc: MercenaryData in mercs:
		if merc == null:
			continue
		for line: String in ConstStates.expire_campaign_states(merc, CampaignClock.now()):
			print(line)
	for line: String in RestSystem.complete_due_rests(mercs, CampaignClock.now()):
		print(line)
	for dead: MercenaryData in run.casualties:
		_replace_slot(mercs, dead, true, "")
	for merc: MercenaryData in run.defectors:
		_replace_slot(mercs, merc, true, "DEFECTED")
	for merc: MercenaryData in run.departed:
		_replace_slot(mercs, merc, false, "DEPARTED")
	if not run.casualties.is_empty() or not run.defectors.is_empty() or not run.departed.is_empty():
		BeauSystem.set_roster(mercs)
		GuildRoster.set_roster(mercs)


#One Rescue contract: the deployed team plus one roster merc held in the dungeon as the captive.
static func run_rescue_contract(mercs: Array[MercenaryData]) -> void:
	if BattleHarness._battle_state != null:
		print("Battle already in progress.")
		return
	if BattleHarness._contract_running:
		print("Contract already in progress.")
		return
	BattleHarness._contract_running = true
	if BattleHarness.betrayal_fresh:
		BetrayalSystem.reset()
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)
	var config: ContractConfig = ContractLibrary.config()
	var need: int = maxi(1, config.default_max_mercs) + 1
	var prelude: Array[String] = []
	var deployable: Array[MercenaryData] = _deploy_team(mercs, need, prelude)
	var team: Array[MercenaryData] = []
	team.assign(deployable.slice(0, need - 1))
	var captive: MercenaryData = deployable[need - 1]
	if config.test_merc_level > 0:
		for merc: MercenaryData in team:
			ContractModifiers.set_level(merc, config.test_merc_level)
			LevelUpSystem.catch_up(merc)
		ContractModifiers.set_level(captive, config.test_merc_level)
		LevelUpSystem.catch_up(captive)
	var record: Dictionary = RescueContractBuilder.record_for(captive, RescueContractBuilder.KIND_FLED)
	var contract: ContractData = RescueContractBuilder.build(record)
	if contract == null:
		print("RESCUE CONTRACT: generation failed")
		for line: String in prelude:
			print(line)
		BattleHarness._contract_running = false
		return
	var saved: String = ContractGenerator.save_instance(contract)
	if saved != "":
		print("CONTRACT SAVED: %s" % saved)
	print("\n====== RESCUE CONTRACT ======\n")
	var line_fn := func(s: String) -> void: print_rich(s)
	var run: ContractRun = await ContractManager.run(contract, team, line_fn, prelude)
	if saved != "":
		ContractGenerator.save_instance(contract, saved)
	_print_rescue_line(run, contract)
	var captive_lost: bool = captive.is_dead
	_settle_roster(mercs, team, run, captive)
	if captive_lost:
		_replace_slot(mercs, captive, true, "LOST")
		BeauSystem.set_roster(mercs)
		GuildRoster.set_roster(mercs)
	RescueContractBuilder.pending_records.clear()
	BattleHarness._contract_running = false


#One tally line per rescue, read off the primary event's outcome.
static func _print_rescue_line(run: ContractRun, contract: ContractData) -> void:
	BattleHarness.rescue_runs += 1
	var found: Dictionary = {}
	for outcome: Dictionary in run.outcomes:
		if String(outcome.get("event", "")) == RescueSystem.EVENT_NAME:
			found = outcome
	var ro: Dictionary = found.get("rescue", {})
	var result: String = String(ro.get("result", ""))
	if result == RescueSystem.RESULT_STEALTH:
		BattleHarness.rescue_stealth += 1
	elif result == RescueSystem.RESULT_COMBAT:
		BattleHarness.rescue_combat += 1
	else:
		BattleHarness.rescue_failed += 1
	print("RESCUE: %s kind=%s mode=%s result=%s rounds=%d" % [contract.rescue_merc_name,
		contract.rescue_kind, String(ro.get("mode", "none")),
		result if result != "" else "none", int(found.get("rounds", 0))])


#Builds a test contract, deploys a shuffled slice of the roster and replaces every casualty.
static func run_test_contract(mercs: Array[MercenaryData]) -> void:
	if BattleHarness._battle_state != null:
		print("Battle already in progress.")
		return
	if BattleHarness._contract_running:
		print("Contract already in progress.")
		return
	BattleHarness._contract_running = true
	if BattleHarness.betrayal_fresh:
		BetrayalSystem.reset()
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)
	var config: ContractConfig = ContractLibrary.config()
	var need: int = maxi(1, config.default_max_mercs)
	var prelude: Array[String] = []
	if HarnessFlags.furlough_flag():
		prelude.append_array(furlough_first(mercs))
	var deployable: Array[MercenaryData] = _deploy_team(mercs, need, prelude)
	var team: Array[MercenaryData] = []
	team.assign(deployable.slice(0, need))
	if config.test_merc_level > 0:
		for merc: MercenaryData in team:
			ContractModifiers.set_level(merc, config.test_merc_level)
			LevelUpSystem.catch_up(merc)
	var contract: ContractData = ContractGenerator.generate(config.default_contract_type)
	if contract == null:
		print("CONTRACT: generation failed")
		for line: String in prelude:
			print(line)
		BattleHarness._contract_running = false
		return
	var saved: String = ContractGenerator.save_instance(contract)
	if saved != "":
		print("CONTRACT SAVED: %s" % saved)
	print("\n====== TEST CONTRACT ======\n")
	var line_fn := func(s: String) -> void: print_rich(s)
	var run: ContractRun = await ContractManager.run(contract, team, line_fn, prelude)
	if saved != "":
		ContractGenerator.save_instance(contract, saved)
	_settle_roster(mercs, team, run, null)
	BattleHarness._contract_running = false


#One leaver's roster slot takes a fresh merc; an empty label prints no leave line.
static func _replace_slot(mercs: Array[MercenaryData], merc: MercenaryData, forget: bool,
		label: String) -> void:
	var slot: int = mercs.find(merc)
	if forget:
		CampaignKnowledge.forget(merc.merc_uid)
	var replacement: MercenaryData = HarnessRoster.roster_merc(mercs.size())
	if slot < 0:
		mercs.append(replacement)
		slot = mercs.size() - 1
	else:
		mercs[slot] = replacement
	HarnessRoster.grant_auto_immunity(replacement, slot, mercs.size())
	if label != "":
		print("%s: %s leaves the roster" % [label, merc.merc_name])
	print("\n====== REPLACEMENT MERC (at the tavern) ======\n")
	MercSheetPrinter.print_merc(replacement)


static func _deployable(mercs: Array[MercenaryData]) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in mercs:
		if merc != null and merc.merc_uid > 0 and RestSystem.is_deployable(merc):
			out.append(merc)
	return out


#A rest lockout holds the roster back, so the harness skips ahead to the first merc who comes free; lines go to the prelude.
static func _wait_for_rested(mercs: Array[MercenaryData], need: int, lines: Array[String]) -> Array[MercenaryData]:
	var deployable: Array[MercenaryData] = _deployable(mercs)
	while deployable.size() < need:
		var next: int = -1
		for merc: MercenaryData in mercs:
			if merc == null or merc.merc_uid <= 0 or merc.is_dead or not RestSystem.is_resting(merc):
				continue
			if next < 0 or merc.rest_lockout_until < next:
				next = merc.rest_lockout_until
		if next < 0:
			break
		var delta: int = next - CampaignClock.now()
		CampaignClock.advance_to(next)
		lines.append(CampaignClock.line("rest wait", delta))
		for merc: MercenaryData in mercs:
			if merc != null:
				lines.append_array(ConstStates.expire_campaign_states(merc, CampaignClock.now()))
		lines.append_array(RestSystem.complete_due_rests(mercs, CampaignClock.now()))
		lines.append_array(BeauSystem.tick(CampaignClock.now()))
		deployable = _deployable(mercs)
	return deployable


static func furlough_first(mercs: Array[MercenaryData]) -> Array[String]:
	var lines: Array[String] = []
	for merc: MercenaryData in mercs:
		if merc != null and merc.merc_uid > 0 and RestSystem.is_deployable(merc):
			lines.append_array(RestSystem.furlough_start(merc))
			return lines
	return lines
