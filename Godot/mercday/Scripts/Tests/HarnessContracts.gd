class_name HarnessContracts
extends RefCounted

#Runs the harness test contracts and settles the roster after each one.

#Rescue tallies of the "--auto-rescue" batch.
static var rescue_runs: int = 0
static var rescue_stealth: int = 0
static var rescue_combat: int = 0
static var rescue_failed: int = 0


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
		TestFixtures.set_roster(mercs)
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
		for line: String in StateCampaign.expire_campaign_states(merc, CampaignClock.now()):
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
		TestFixtures.set_roster(mercs)


#Claims the harness for one contract; false with a printed reason when a battle or contract already runs.
static func _begin(mercs: Array[MercenaryData]) -> bool:
	if BattleHarness.battle_state != null:
		print("Battle already in progress.")
		return false
	if BattleHarness.contract_running:
		print("Contract already in progress.")
		return false
	BattleHarness.contract_running = true
	if BattleHarness.betrayal_fresh:
		BetrayalSystem.reset()
	TestFixtures.set_roster(mercs)
	return true


#Raises each merc to the configured test level; 0 leaves them as they are.
static func _level_team(team: Array[MercenaryData], level: int) -> void:
	if level <= 0:
		return
	for merc: MercenaryData in team:
		TestFixtures.set_level(merc, level)
		LevelUpSystem.catch_up(merc)


#Prints the generation failure and the prelude, then frees the harness.
static func _abort(label: String, prelude: Array[String]) -> void:
	print("%s: generation failed" % label)
	for line: String in prelude:
		print(line)
	BattleHarness.contract_running = false


#Saves the instance (unless save is false), runs the contract under header and saves it again with its results.
static func _run_saved(contract: ContractData, team: Array[MercenaryData], prelude: Array[String],
		header: String, save: bool = true) -> ContractRun:
	var saved: String = save_instance(contract) if save else ""
	if saved != "":
		print("CONTRACT SAVED: %s" % saved)
	print("\n====== %s ======\n" % header)
	var line_fn := func(s: String) -> void: print_rich(s)
	var run: ContractRun = await ContractManager.run(contract, team, line_fn, prelude)
	if saved != "":
		save_instance(contract, saved)
	return run


#One contract on the given team with no roster top-up or settling; null when the harness is busy.
static func run_on_team(contract: ContractData, team: Array[MercenaryData], header: String) -> ContractRun:
	if not _begin(team):
		return null
	var run: ContractRun = await _run_saved(contract, team, [], header, false)
	BattleHarness.contract_running = false
	return run


#One Rescue contract: the deployed team plus one roster merc held in the dungeon as the captive.
static func run_rescue_contract(mercs: Array[MercenaryData]) -> void:
	if not _begin(mercs):
		return
	var config: ContractConfig = ContractLibrary.config()
	var need: int = maxi(1, config.default_max_mercs) + 1
	var prelude: Array[String] = []
	var deployable: Array[MercenaryData] = _deploy_team(mercs, need, prelude)
	var team: Array[MercenaryData] = []
	team.assign(deployable.slice(0, need - 1))
	var captive: MercenaryData = deployable[need - 1]
	var leveled: Array[MercenaryData] = team.duplicate()
	leveled.append(captive)
	_level_team(leveled, config.test_merc_level)
	var record: Dictionary = RescueContractBuilder.record_for(captive, RescueContractBuilder.KIND_FLED)
	var contract: ContractData = RescueContractBuilder.build(record)
	if contract == null:
		_abort("RESCUE CONTRACT", prelude)
		return
	var run: ContractRun = await _run_saved(contract, team, prelude, "RESCUE CONTRACT")
	_print_rescue_line(run, contract)
	var captive_lost: bool = captive.is_dead
	_settle_roster(mercs, team, run, captive)
	if captive_lost:
		_replace_slot(mercs, captive, true, "LOST")
		TestFixtures.set_roster(mercs)
	RescueContractBuilder.pending_records.clear()
	BattleHarness.contract_running = false


#One tally line per rescue, read off the primary event's outcome.
static func _print_rescue_line(run: ContractRun, contract: ContractData) -> void:
	rescue_runs += 1
	var found: Dictionary = {}
	for outcome: Dictionary in run.outcomes:
		if String(outcome.get("event", "")) == RescueSystem.EVENT_NAME:
			found = outcome
	var ro: Dictionary = found.get("rescue", {})
	var result: String = String(ro.get("result", ""))
	if result == RescueSystem.RESULT_STEALTH:
		rescue_stealth += 1
	elif result == RescueSystem.RESULT_COMBAT:
		rescue_combat += 1
	else:
		rescue_failed += 1
	print("RESCUE: %s kind=%s mode=%s result=%s rounds=%d" % [contract.rescue_merc_name,
		contract.rescue_kind, String(ro.get("mode", "none")),
		result if result != "" else "none", int(found.get("rounds", 0))])


#Builds a test contract, deploys a shuffled slice of the roster and replaces every casualty.
#"--furlough": the guild idles until the first deployable roster merc's Furlough completes before the contract.
#"--play-row=<name>" builds that contract row instead of the default contract type.
static func run_test_contract(mercs: Array[MercenaryData]) -> void:
	if not _begin(mercs):
		return
	var config: ContractConfig = ContractLibrary.config()
	var row_name: String = HarnessFlags.auto_spec("--play-row")
	var need: int = _team_size(config, row_name)
	var prelude: Array[String] = []
	if OS.get_cmdline_user_args().has("--furlough"):
		var ready: Array[MercenaryData] = _deployable(mercs)
		if not ready.is_empty():
			prelude.append_array(_idle_furlough(mercs, ready[0]))
	var deployable: Array[MercenaryData] = _deploy_team(mercs, need, prelude)
	var team: Array[MercenaryData] = []
	team.assign(deployable.slice(0, need))
	_level_team(team, config.test_merc_level)
	var contract: ContractData = ContractGenerator.generate_named(row_name) if row_name != "" \
		else ContractGenerator.generate(config.default_contract_type)
	if contract == null:
		_abort("CONTRACT", prelude)
		return
	var run: ContractRun = await _run_saved(contract, team, prelude, "TEST CONTRACT")
	_settle_roster(mercs, team, run, null)
	BattleHarness.contract_running = false


#The Max Mercs the named row (else the default contract type's row) resolves to, read before the team levels so the
#level draw is unchanged.
static func _team_size(config: ContractConfig, row_name: String = "") -> int:
	var row: ContractData = ContractLibrary.contract(row_name) if row_name != "" \
		else ContractLibrary.contract_type(config.default_contract_type)
	if row == null:
		return maxi(1, config.default_max_mercs)
	var probe: ContractData = row.duplicate() as ContractData
	ContractGenerator.set_merc_range(config, probe)
	return maxi(1, probe.max_mercs)


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


#Opens an idle window for the merc and moves the clock through its Furlough time; lines go to the prelude.
static func _idle_furlough(mercs: Array[MercenaryData], merc: MercenaryData) -> Array[String]:
	var lines: Array[String] = []
	merc.idle_since_minute = CampaignClock.now()
	var span: int = RestSystem.rest_minutes(merc, RestSystem.FURLOUGH_MINUTES)
	CampaignClock.advance(span)
	lines.append(CampaignClock.line("furlough wait", span))
	for each: MercenaryData in mercs:
		if each != null:
			lines.append_array(StateCampaign.expire_campaign_states(each, CampaignClock.now()))
	lines.append_array(RestSystem.complete_due_rests(mercs, CampaignClock.now()))
	return lines


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
				lines.append_array(StateCampaign.expire_campaign_states(merc, CampaignClock.now()))
		lines.append_array(RestSystem.complete_due_rests(mercs, CampaignClock.now()))
		lines.append_array(BeauSystem.tick(CampaignClock.now()))
		deployable = _deployable(mercs)
	return deployable


const SAVE_DIR := "user://contracts"


#Writes the instance to path, or to the first free user://contracts/contract_<n>.tres when path is empty.
static func save_instance(contract: ContractData, path: String = "") -> String:
	if contract == null or not ContractLibrary.config().save_generated_contracts:
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var target: String = path
	if target == "":
		var n: int = 1
		while FileAccess.file_exists("%s/contract_%d.tres" % [SAVE_DIR, n]):
			n += 1
		target = "%s/contract_%d.tres" % [SAVE_DIR, n]
	var err: int = ResourceSaver.save(contract, target)
	if err != OK:
		push_warning("ContractGenerator: could not save %s (error %d)" % [target, err])
		return ""
	return ProjectSettings.globalize_path(target)
