class_name HarnessEntry
extends RefCounted

#Headless harness entry point: the flag block MercTest._ready used to hold.
#GUI scenes call run_if_flagged so a plain launch never builds the harness roster.

#User args that belong to the GUI and never mean "run the harness".
const GUI_FLAGS: Array[String] = ["--metrics-preview", "--results-preview", "--harness"]

#The harness roster built by run(); MercTest reads it after run() returns false.
static var mercs: Array[MercenaryData] = []


#True when any user arg asks for the harness rather than the GUI.
static func wants_harness() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and not GUI_FLAGS.has(arg):
			return true
	return false


#Runs the harness only when a harness flag is present; false without touching anything otherwise.
static func run_if_flagged(host: Node) -> bool:
	if not wants_harness():
		return false
	return await run(host)


#True when a flag quit the tree or a batch took the process; false after a plain roster build.
static func run(host: Node) -> bool:
	var args := OS.get_cmdline_user_args()
	RoofBuilder.enabled = not args.has("--no-roofs")
	var rescue_mode := HarnessFlags.auto_spec("--rescue-mode")
	if rescue_mode != "":
		ContractLibrary.config().rescue_mode = rescue_mode
	var rescue_policy := HarnessFlags.auto_spec("--rescue-policy")
	if [RescueTactics.POLICY_SMART, RescueTactics.POLICY_ALWAYS, RescueTactics.POLICY_NEVER].has(rescue_policy):
		RescueTactics.policy = rescue_policy
	var rescue_melee := HarnessFlags.auto_spec("--rescue-melee")
	if [RescueTactics.MELEE_SMART, RescueTactics.MELEE_PICK, RescueTactics.MELEE_FIGHT].has(rescue_melee):
		RescueTactics.melee_rule = rescue_melee
	if args.has("--rescue-no-withdraw"):
		RescueTactics.withdraw_enabled = false
	for pair: String in HarnessFlags.auto_spec("--rescue-tune").split(",", false):
		var kv: PackedStringArray = pair.split(":", false)
		if kv.size() != 2 or not RescueTactics.set_tune(kv[0].strip_edges(), kv[1].to_float()):
			push_warning("RESCUE TUNE: cannot read '%s'" % pair)
	for entry: Array in _suite_flags():
		if args.has(str(entry[0])):
			var runner: Callable = entry[1]
			host.get_tree().quit(0 if bool(runner.call()) else 1)
			return true
	if args.has("--contract-tests"):
		host.get_tree().quit(0 if await ContractTests.run() else 1)
		return true
	if args.has("--betrayal-tests"):
		host.get_tree().quit(0 if await BetrayalTests.run() else 1)
		return true
	if args.has("--competition-tests"):
		host.get_tree().quit(0 if await CompetitionTests.run() else 1)
		return true
	if args.has("--rescue-tests"):
		host.get_tree().quit(0 if await RescueTests.run() else 1)
		return true
	if args.has("--rescue-probe"):
		host.get_tree().quit(0 if await RescueProbe.run() else 1)
		return true
	if args.has("--scheduler-tests"):
		host.get_tree().quit(0 if await SchedulerTests.run() else 1)
		return true
	if args.has("--gamestate-tests"):
		host.get_tree().quit(0 if await GameStateTests.run() else 1)
		return true
	if args.has("--gui-meter-tests"):
		host.get_tree().quit(0 if await GuiMeterTests.run(host) else 1)
		return true
	if args.has("--gui-frame-tests"):
		host.get_tree().quit(0 if await GuiFrameTests.run(host) else 1)
		return true
	if args.has("--gui-widget-tests"):
		host.get_tree().quit(0 if await GuiWidgetTests.run(host) else 1)
		return true
	if args.has("--gui-hud-tests"):
		host.get_tree().quit(0 if await GuiHudTests.run(host) else 1)
		return true
	if args.has("--gui-metrics-tests"):
		host.get_tree().quit(0 if await GuiMetricsTests.run(host) else 1)
		return true
	if args.has("--gui-merc-tests"):
		host.get_tree().quit(0 if await GuiMercTests.run(host) else 1)
		return true
	if args.has("--gui-contract-tests"):
		host.get_tree().quit(0 if await GuiContractTests.run(host) else 1)
		return true
	if args.has("--gui-flow-tests"):
		host.get_tree().quit(0 if await GuiFlowTests.run(host) else 1)
		return true
	if args.has("--gui-plan-tests"):
		host.get_tree().quit(0 if await GuiPlanTests.run(host) else 1)
		return true
	if args.has("--gui-lock-tests"):
		host.get_tree().quit(0 if await GuiLockTests.run(host) else 1)
		return true
	if args.has("--gui-loan-tests"):
		host.get_tree().quit(0 if await GuiLoanTests.run(host) else 1)
		return true
	if args.has("--gui-manager-tests"):
		host.get_tree().quit(0 if await GuiManagerTests.run(host) else 1)
		return true
	if args.has("--gui-atom-tests"):
		host.get_tree().quit(0 if await GuiAtomTests.run(host) else 1)
		return true
	if args.has("--gui-icon-tests"):
		host.get_tree().quit(0 if await GuiIconTests.run(host) else 1)
		return true
	if args.has("--gui-promo-tests"):
		host.get_tree().quit(0 if await GuiPromoTests.run(host) else 1)
		return true
	if args.has("--gui-notice-tests"):
		host.get_tree().quit(0 if await GuiNoticeTests.run(host) else 1)
		return true
	if args.has("--gui-subs-tests"):
		host.get_tree().quit(0 if await GuiSubsTests.run(host) else 1)
		return true
	if args.has("--gui-tree-tests"):
		host.get_tree().quit(0 if await GuiTreeTests.run(host) else 1)
		return true
	if args.has("--gui-coach-tests"):
		host.get_tree().quit(0 if await GuiCoachTests.run(host) else 1)
		return true
	if args.has("--gui-crew-tests"):
		host.get_tree().quit(0 if await GuiCrewTests.run(host) else 1)
		return true
	if args.has("--gui-results-tests"):
		host.get_tree().quit(0 if await GuiResultsTests.run(host) else 1)
		return true
	if args.has("--gui-kit-tests"):
		host.get_tree().quit(0 if await GuiKitTests.run(host) else 1)
		return true
	if args.has("--gui-payroll-tests"):
		host.get_tree().quit(0 if await GuiPayrollTests.run(host) else 1)
		return true
	if args.has("--gui-stock-tests"):
		host.get_tree().quit(0 if await GuiStockTests.run(host) else 1)
		return true
	if args.has("--gui-notify-tests"):
		host.get_tree().quit(0 if await GuiNotifyTests.run(host) else 1)
		return true
	if args.has("--gui-filter-tests"):
		host.get_tree().quit(0 if await GuiFilterTests.run(host) else 1)
		return true
	if args.has("--gui-findata-tests"):
		host.get_tree().quit(0 if await GuiFinanceDataTests.run(host) else 1)
		return true
	if args.has("--gui-bazaar-tests"):
		host.get_tree().quit(0 if await GuiBazaarTests.run(host) else 1)
		return true
	if args.has("--gui-legal-tests"):
		host.get_tree().quit(0 if await GuiLegalTests.run(host) else 1)
		return true
	if args.has("--gui-ads-tests"):
		host.get_tree().quit(0 if await GuiAdsTests.run(host) else 1)
		return true
	if args.has("--gui-finance-tests"):
		host.get_tree().quit(0 if await GuiFinanceTests.run(host) else 1)
		return true
	if args.has("--gui-loanview-tests"):
		host.get_tree().quit(0 if await GuiLoanViewTests.run(host) else 1)
		return true
	if args.has("--gui-payview-tests"):
		host.get_tree().quit(0 if await GuiPayViewTests.run(host) else 1)
		return true
	if args.has("--gui-invest-tests"):
		host.get_tree().quit(0 if await GuiInvestTests.run(host) else 1)
		return true
	if args.has("--gui-hiring-tests"):
		host.get_tree().quit(0 if await GuiHiringTests.run(host) else 1)
		return true
	if args.has("--gui-client-tests"):
		host.get_tree().quit(0 if await GuiClientTests.run(host) else 1)
		return true
	if args.has("--gui-click-d-tests"):
		host.get_tree().quit(0 if await GuiClickDTests.run(host) else 1)
		return true
	if args.has("--gui-click-h-tests"):
		host.get_tree().quit(0 if await GuiClickHTests.run(host) else 1)
		return true
	if args.has("--gui-click-ja-tests"):
		host.get_tree().quit(0 if await GuiClickJATests.run(host) else 1)
		return true
	if args.has("--gui-click-jb-tests"):
		host.get_tree().quit(0 if await GuiClickJBTests.run(host) else 1)
		return true
	if args.has("--gui-sort-tests"):
		host.get_tree().quit(0 if await GuiSortTests.run(host) else 1)
		return true
	if args.has("--gui-accept-tests"):
		host.get_tree().quit(0 if await GuiAcceptTests.run(host) else 1)
		return true
	var odds_probe_n := _count_flag("--odds-probe")
	if odds_probe_n > 0:
		host.get_tree().quit(0 if await OddsProbe.run(odds_probe_n) else 1)
		return true
	var salary_probe_n := _count_flag("--salary-probe")
	if salary_probe_n > 0:
		host.get_tree().quit(0 if SalaryProbe.run(salary_probe_n) else 1)
		return true
	var built: Dictionary = ContractResourceBuilder.build_all()
	print("CONTRACT BUILDER: %d contracts, %d events, %d warnings"
		% [int(built["contracts"]), int(built["events"]), int(built["warnings"])])
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--auto-seed="):
			seed(int(a.substr(12)))
	BattleHarness.betrayal_fresh = OS.get_cmdline_user_args().has("--betrayal-fresh")
	CaveInSystem.force_every = OS.get_cmdline_user_args().has("--force-cave-in")
	KidnapSystem.force_every = OS.get_cmdline_user_args().has("--force-kidnap")
	CalledShotSystem.force_option = HarnessFlags.auto_spec("--auto-called-shot")
	CalledShotSystem.force_every = OS.get_cmdline_user_args().has("--auto-called-shot") \
		or CalledShotSystem.force_option != ""
	MercGenerator.force_perk_load = maxi(0, HarnessFlags.auto_spec("--auto-perk-load").to_int())
	var cavern_gen_n := _count_flag("--cavern-gen")
	if cavern_gen_n > 0:
		await CavernBatch.run(host, cavern_gen_n)
		return true
	var dungeon_gen_n := _count_flag("--dungeon-gen")
	if dungeon_gen_n > 0:
		await DungeonBatch.run(host, dungeon_gen_n, _dungeon_difficulty())
		return true
	var interior_gen_n := _count_flag("--interior-gen")
	if interior_gen_n > 0:
		await InteriorBatch.run(host, interior_gen_n)
		return true
	var building_gen_n := _count_flag("--building-gen")
	if building_gen_n > 0:
		await BuildingBatch.run(host, building_gen_n, HarnessFlags.auto_spec("--building-name"),
			HarnessFlags.auto_spec("--building-front"))
		return true
	var city_gen_n := _count_flag("--city-gen")
	if city_gen_n > 0:
		await CityBatch.run(host, city_gen_n, HarnessFlags.auto_spec("--city-tier"), _auto_seed_base())
		return true
	var ambush_n := _count_flag("--auto-ambush")
	if ambush_n > 0:
		await AmbushBatch.run(host, ambush_n)
		return true
	var competition_n := _count_flag("--auto-competition")
	if competition_n > 0:
		await CompetitionBatch.run(host, competition_n)
		return true
	BattleHarness.team_mix = OS.get_cmdline_user_args().has("--auto-team-mix")
	SpawnPlacer.spawn_floor_split = OS.get_cmdline_user_args().has("--auto-floor-split")
	mercs.clear()
	if BattleHarness.team_mix:
		HarnessRoster.generate_mixed_mercs(mercs, _auto_merc_count())
	else:
		for i: int in range(_auto_merc_count()):
			var merc := HarnessRoster.roster_merc(i)
			mercs.append(merc)
			HarnessRoster.grant_auto_immunity(merc, i, _auto_merc_count())
			MercSheetPrinter.print_merc(merc)
	HarnessRoster.force_unsavory(mercs)
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)
	if _force_ambush():
		ContractLibrary.config().force_trigger_event = "Ambush"
	elif OS.get_cmdline_user_args().has("--force-respite-kidnap"):
		ContractLibrary.config().force_trigger_event = "Kidnapping"
	var auto_n := _count_flag("--auto-interior")
	var contract_n := _count_flag("--auto-contract")
	var cavern_n := _count_flag("--auto-cavern")
	var dungeon_n := _count_flag("--auto-dungeon")
	var rescue_n := _count_flag("--auto-rescue")
	var city_n := _count_flag("--auto-city")
	if auto_n > 0:
		HarnessBatches.run_auto_interior(host, mercs, auto_n)
	elif contract_n > 0:
		HarnessBatches.run_auto_contract(host, mercs, contract_n)
	elif cavern_n > 0:
		HarnessBatches.run_auto_cavern(host, mercs, cavern_n)
	elif dungeon_n > 0:
		HarnessBatches.run_auto_dungeon(host, mercs, dungeon_n)
	elif rescue_n > 0:
		HarnessBatches.run_auto_rescue(host, mercs, rescue_n)
	elif city_n > 0:
		HarnessBatches.run_auto_city(host, mercs, city_n, HarnessFlags.auto_spec("--city-tier"),
			_auto_seed_base())
	else:
		return false
	return true


#Suite flag to runner pairs; the awaited suites (contract, betrayal, competition, rescue) sit in run.
static func _suite_flags() -> Array:
	return [
		["--los-tests", LosTests.run],
		["--fly-tests", FlyTests.run],
		["--immune-tests", ImmuneTests.run],
		["--check-tests", CheckTests.run],
		["--trait-tests", TraitTests.run],
		["--relationship-tests", RelationshipTests.run],
		["--lifepath-tests", LifepathTests.run],
		["--lifepath-audit", HarnessEntry._run_lifepath_audit],
		["--age-tests", AgeTests.run],
		["--xp-tests", XpTests.run],
		["--clock-tests", ClockTests.run],
		["--excess-tests", ExcessTests.run],
		["--rest-tests", RestTests.run],
		["--beau-tests", BeauTests.run],
		["--inventory-tests", InventoryTests.run],
		["--ambush-tests", AmbushTests.run],
		["--opponent-tests", OpponentTests.run],
		["--flee-tests", FleeTests.run],
		["--cavern-tests", CavernTests.run],
		["--cavein-tests", CaveInTests.run],
		["--kidnap-tests", KidnapTests.run],
		["--levelup-tests", LevelUpTests.run],
		["--perk-tests", PerkTests.run],
		["--calledshot-tests", CalledShotTests.run],
		["--calledshot-probe", CalledShotProbe.run],
		["--dungeon-tests", DungeonTests.run],
		["--interior-tests", InteriorTests.run],
		["--building-tests", BuildingTests.run],
		["--city-tests", CityTests.run],
		["--roof-tests", RoofTests.run],
		["--salary-tests", SalaryTests.run],
		["--gui-view-tests", GuiViewTests.run],
		["--calendar-tests", CalendarTests.run],
		["--gui-tests", GuiTests.run],
		["--board-tests", BoardTests.run],
		["--odds-tests", OddsTests.run],
	]


#Prints the full lifepath audit; always reports success so the engine exits with 0.
static func _run_lifepath_audit() -> bool:
	LifepathAudit.audit_full()
	return true


#Mercs generated at start: N from an "--auto-mercs=N" user arg, 3 when the flag is absent.
static func _auto_merc_count() -> int:
	var spec := HarnessFlags.auto_spec("--auto-mercs")
	return 3 if spec == "" else maxi(2, spec.to_int())


#Reads N from a "<flag>=N" user arg; 0 when the flag is absent.
static func _count_flag(flag: String) -> int:
	return maxi(0, HarnessFlags.auto_spec(flag).to_int())


#Reads S from an "--auto-seed=S" user arg; -1 when the flag is absent, so a batch keeps its own seed.
static func _auto_seed_base() -> int:
	var spec: String = HarnessFlags.auto_spec("--auto-seed")
	return -1 if spec == "" else int(spec)


#Reads D from a "--dungeon-difficulty=D" user arg; 0 cycles 1.0 to 5.0 over the batch.
static func _dungeon_difficulty() -> float:
	var spec: String = HarnessFlags.auto_spec("--dungeon-difficulty")
	return float(spec) if spec.is_valid_float() else 0.0


#"--force-ambush": the contract batch springs the Ambush trigger at its next Respite.
static func _force_ambush() -> bool:
	return OS.get_cmdline_user_args().has("--force-ambush")
