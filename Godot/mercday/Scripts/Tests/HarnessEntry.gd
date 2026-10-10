class_name HarnessEntry
extends RefCounted

#Headless harness entry point: the flag block MercTest._ready used to hold.
#GUI scenes call run_if_flagged so a plain launch never builds the harness roster.

#User args that belong to the GUI and never mean "run the harness".
const GUI_FLAGS: Array[String] = HarnessHook.GUI_FLAGS

const MAP_TESTS_PATH: String = "res://Scripts/Tests/Map/MapTests.gd"
const ODDS_PROBE_PATH: String = "res://Scripts/Tests/OddsProbe.gd"
const SALARY_PROBE_PATH: String = "res://Scripts/Tests/SalaryProbe.gd"
const NPC_PREVIEW_PATH: String = "res://Scripts/Tests/NpcPreview.gd"

#Every non-suite flag the harness, its batches and the autoloads read; any other "--" arg stops the run with exit 2.
const EXTRA_FLAGS: Array[String] = ["--author-help-rows", "--auto-ambush", "--auto-building", "--auto-called-shot",
	"--auto-cavern", "--auto-city", "--auto-city-spawn-only", "--auto-competition", "--auto-contract", "--auto-difficulty",
	"--auto-dungeon", "--auto-floor-split", "--auto-forget", "--auto-immune", "--auto-inflict", "--auto-interior",
	"--auto-mercs", "--auto-perk-load", "--auto-play", "--auto-remove", "--auto-rescue", "--auto-seed", "--auto-split",
	"--auto-state", "--auto-team-mix", "--betrayal-fresh", "--building-front", "--building-gen", "--building-name",
	"--cavern-gen", "--city-gen", "--city-tier", "--contract-build", "--dungeon-difficulty", "--dungeon-gen",
	"--force-ambush", "--force-cave-in", "--force-kidnap", "--force-respite-kidnap", "--force-unsavory", "--furlough",
	"--gen-set", "--interior-gen", "--local-sim", "--map-bake",
	"--no-roofs", "--npc-preview", "--odds-probe", "--plan", "--play-level", "--play-row", "--play-team",
	"--playability-sim", "--preview-n", "--probe-levels", "--probe-n", "--probe-seed", "--probe-trials",
	"--rescue-melee", "--rescue-mode", "--rescue-no-withdraw", "--rescue-policy", "--rescue-tune", "--salary-probe",
	"--sim-out", "--tsv-report"]

#Set by BuilderTests around its ContractRebuild child so the --contract-build run builds to memory only.
const DRY_BUILD_ENV: String = "MERCDAY_DRY_BUILD"

#The 8 stock contract rows every harness run is pinned to; equals BuilderTests.TEMPLATE_NAMES.
#The rows live in TSVs/Contracts_OLD.tsv and reach DataManager.contract_rows in harness runs only.
const STOCK_CONTRACTS: Array[String] = ["Assassinate", "Entertain", "Escort", "Investigate", "Military",
	"Monster Hunt", "Rescue", "Treasure Hunt"]

#The harness roster built by run(); MercTest reads it after run() returns false.
static var mercs: Array[MercenaryData] = []


#True when any user arg asks for the harness rather than the GUI.
static func wants_harness() -> bool:
	return HarnessHook.wants_harness()


#Runs the harness only when a harness flag is present; false without touching anything otherwise.
static func run_if_flagged(host: Node) -> bool:
	if not wants_harness():
		return false
	return await run(host)


#The launch flags the HUD answers before it starts a game: true when the HUD must stop here.
static func boot(host: Node) -> bool:
	if await run_if_flagged(host):
		return true
	if OS.get_cmdline_user_args().has("--harness"):
		host.get_tree().change_scene_to_file.call_deferred("res://Scenes/GUI/testingArea.tscn")
		return true
	return false


#The sample results and metrics history the preview flags ask for, laid over a started game.
static func seed_previews() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--results-preview"):
		var seeded: Array[int] = ResultsPreview.seed_results()
		print("RESULTS PREVIEW entries=%d" % seeded.size())
	if args.has("--metrics-preview"):
		MetricsHistory.seed_preview(400, GameState.roster_uids())
		print("METRICS PREVIEW days=%d" % MetricsHistory.days())


#True when a flag quit the tree or a batch took the process; false after a plain roster build.
static func run(host: Node) -> bool:
	var unknown: Array[String] = unknown_flags(host)
	if not unknown.is_empty():
		for flag: String in unknown:
			print("HARNESS: unknown flag %s" % flag)
		print("HARNESS: known flags are listed in HarnessEntry._suite_flags and EXTRA_FLAGS")
		host.get_tree().quit(2)
		return true
	var args := OS.get_cmdline_user_args()
	#Only the Contract Builder rebuild child writes the tracked .tres files; every other harness run builds to memory.
	ContractResourceBuilder.write_enabled = args.has(ContractRebuild.BUILD_FLAG) \
		and OS.get_environment(DRY_BUILD_ENV) == ""
	ContractLibrary.pinned_names = STOCK_CONTRACTS.duplicate()
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
		if kv.size() != 2 or not RescueTune.set_tune(kv[0].strip_edges(), kv[1].to_float()):
			push_warning("RESCUE TUNE: cannot read '%s'" % pair)
	var gen_errors: Array[String] = GenTune.apply_spec(HarnessFlags.auto_spec("--gen-set"))
	if not gen_errors.is_empty():
		for line: String in gen_errors:
			print(line)
		host.get_tree().quit(2)
		return true
	for line: String in GenTune.report_lines():
		print(line)
	var map_bake: String = HarnessFlags.auto_spec("--map-bake")
	if map_bake != "":
		var bake_runner: GDScript = load("res://addons/map_baker/MapBakeRunner.gd") as GDScript
		var bake_ok: bool = bake_runner != null and bool(bake_runner.call("run_headless", map_bake.to_int()))
		host.get_tree().quit(0 if bake_ok else 1)
		return true
	for entry: Array in _suite_flags(host):
		if args.has(str(entry[0])):
			var runner: Callable = entry[1]
			host.get_tree().quit(0 if bool(await runner.call()) else 1)
			return true
	var odds_probe_n := _count_flag("--odds-probe")
	if odds_probe_n > 0:
		var odds_probe: GDScript = _load_script(ODDS_PROBE_PATH)
		host.get_tree().quit(0 if odds_probe != null and bool(await odds_probe.call("run", odds_probe_n)) else 1)
		return true
	var salary_probe_n := _count_flag("--salary-probe")
	if salary_probe_n > 0:
		var salary_probe: GDScript = _load_script(SALARY_PROBE_PATH)
		host.get_tree().quit(0 if salary_probe != null and bool(salary_probe.call("run", salary_probe_n)) else 1)
		return true
	if args.has("--npc-preview"):
		var preview_n := _count_flag("--preview-n")
		var npc_preview: GDScript = _load_script(NPC_PREVIEW_PATH)
		host.get_tree().quit(0 if npc_preview != null and bool(npc_preview.call("run", preview_n)) else 1)
		return true
	if args.has("--playability-sim") or _count_flag("--playability-sim") > 0:
		var sim_days: int = _count_flag("--playability-sim")
		if sim_days <= 0:
			sim_days = SimThresholds.DEFAULT_DAYS
		var sim_seed: int = HarnessFlags.auto_seed(SimThresholds.DEFAULT_SEED)
		host.get_tree().quit(0 if await PlaySim.run(host, sim_days, sim_seed) else 1)
		return true
	var built: Dictionary = ContractResourceBuilder.build_all()
	print("CONTRACT BUILDER: %d contracts, %d events, %d warnings"
		% [int(built["contracts"]), int(built["events"]), int(built["warnings"])])
	if HarnessFlags.auto_spec("--auto-seed") != "":
		seed(_auto_seed_base())
	BattleHarness.betrayal_fresh = args.has("--betrayal-fresh")
	CaveInSystem.force_every = args.has("--force-cave-in")
	KidnapSystem.force_every = args.has("--force-kidnap")
	CalledShotSystem.force_option = HarnessFlags.auto_spec("--auto-called-shot")
	CalledShotSystem.force_every = args.has("--auto-called-shot") \
		or CalledShotSystem.force_option != ""
	WeaponArmorPerkLibrary.force_perk_load = maxi(0, HarnessFlags.auto_spec("--auto-perk-load").to_int())
	var cavern_gen_n := _count_flag("--cavern-gen")
	if cavern_gen_n > 0:
		await CavernBatch.run(host, cavern_gen_n)
		return true
	var dungeon_gen_n := _count_flag("--dungeon-gen")
	if dungeon_gen_n > 0:
		await DungeonBatch.run(host, dungeon_gen_n, HarnessFlags.auto_difficulty("--dungeon-difficulty"))
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
	if args.has("--author-help-rows"):
		for record: Dictionary in HelpRowsAuthor.author():
			print(_author_line(record))
		host.get_tree().quit()
		return true
	var local_sim_n := _count_flag("--local-sim")
	if local_sim_n > 0:
		await HarnessLocalSim.run(host, local_sim_n, _auto_seed_base(), HarnessFlags.auto_spec("--sim-out"))
		return true
	var play_n := _count_flag("--auto-play")
	if play_n > 0:
		var row := HarnessFlags.auto_spec("--play-row")
		await HarnessPlays.run_auto_play(host, play_n, row if row != "" else HarnessPlays.default_row(),
			HarnessFlags.arg_int("--play-level", 1), HarnessFlags.arg_int("--play-team", 1), _auto_seed_base())
		return true
	BattleHarness.team_mix = args.has("--auto-team-mix")
	SpawnPlacer.spawn_floor_split = args.has("--auto-floor-split")
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
	TestFixtures.set_roster(mercs)
	if args.has("--force-ambush"):
		ContractLibrary.config().force_trigger_event = "Ambush"
	elif args.has("--force-respite-kidnap"):
		ContractLibrary.config().force_trigger_event = "Kidnapping"
	var auto_n := _count_flag("--auto-interior")
	var contract_n := _count_flag("--auto-contract")
	var cavern_n := _count_flag("--auto-cavern")
	var dungeon_n := _count_flag("--auto-dungeon")
	var rescue_n := _count_flag("--auto-rescue")
	var city_n := _count_flag("--auto-city")
	if auto_n > 0:
		HarnessBatches.run_auto_kind(host, mercs, auto_n, "Interior")
	elif contract_n > 0:
		HarnessBatches.run_auto_contract(host, mercs, contract_n)
	elif cavern_n > 0:
		HarnessBatches.run_auto_kind(host, mercs, cavern_n, "Cavern")
	elif dungeon_n > 0:
		HarnessBatches.run_auto_kind(host, mercs, dungeon_n, "Dungeon")
	elif rescue_n > 0:
		HarnessBatches.run_auto_rescue(host, mercs, rescue_n)
	elif city_n > 0:
		HarnessBatches.run_auto_city(host, mercs, city_n, HarnessFlags.auto_spec("--city-tier"),
			_auto_seed_base())
	else:
		return false
	return true


#User args starting with "--" that name no GUI, extra or suite flag, in command line order.
static func unknown_flags(host: Node) -> Array[String]:
	var known: Dictionary = {}
	for flag: String in GUI_FLAGS + EXTRA_FLAGS:
		known[flag] = true
	for entry: Array in _suite_flags(host):
		known[str(entry[0])] = true
	var out: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and not known.has(HarnessFlags.flag_name(arg)):
			out.append(arg)
	return out


#Suite flag to runner pairs; run awaits each runner, so coroutine suites sit here beside the plain ones.
static func _suite_flags(host: Node) -> Array:
	var flags: Array = [
		["--launch-tests", "res://Scripts/Tests/LaunchCouplingTests.gd", false],
		["--los-tests", "res://Scripts/Tests/LosTests.gd", false],
		["--fly-tests", "res://Scripts/Tests/FlyTests.gd", false],
		["--immune-tests", "res://Scripts/Tests/ImmuneTests.gd", false],
		["--check-tests", "res://Scripts/Tests/CheckTests.gd", false],
		["--trait-tests", "res://Scripts/Tests/TraitTests.gd", false],
		["--relationship-tests", "res://Scripts/Tests/RelationshipTests.gd", false],
		["--lifepath-tests", "res://Scripts/Tests/LifepathTests.gd", false],
		["--lifepath-audit", HarnessEntry._run_lifepath_audit],
		["--age-tests", "res://Scripts/Tests/AgeTests.gd", false],
		["--xp-tests", "res://Scripts/Tests/XpTests.gd", false],
		["--clock-tests", "res://Scripts/Tests/ClockTests.gd", false],
		["--map-tests", "res://Scripts/Tests/Map/MapTests.gd", true],
		["--excess-tests", "res://Scripts/Tests/ExcessTests.gd", false],
		["--rest-tests", "res://Scripts/Tests/RestTests.gd", false],
		["--beau-tests", "res://Scripts/Tests/BeauTests.gd", false],
		["--inventory-tests", "res://Scripts/Tests/InventoryTests.gd", false],
		["--ambush-tests", "res://Scripts/Tests/AmbushTests.gd", false],
		["--opponent-tests", "res://Scripts/Tests/OpponentTests.gd", false],
		["--flee-tests", "res://Scripts/Tests/FleeTests.gd", false],
		["--cavern-tests", "res://Scripts/Tests/CavernTests.gd", false],
		["--cavein-tests", "res://Scripts/Tests/CaveInTests.gd", false],
		["--kidnap-tests", "res://Scripts/Tests/KidnapTests.gd", false],
		["--levelup-tests", "res://Scripts/Tests/LevelUpTests.gd", false],
		["--perk-tests", "res://Scripts/Tests/PerkTests.gd", false],
		["--calledshot-tests", "res://Scripts/Tests/CalledShotTests.gd", false],
		["--calledshot-probe", "res://Scripts/Tests/CalledShotProbe.gd", false],
		["--dungeon-tests", "res://Scripts/Tests/DungeonTests.gd", false],
		["--interior-tests", "res://Scripts/Tests/InteriorTests.gd", false],
		["--building-tests", "res://Scripts/Tests/BuildingTests.gd", false],
		["--city-tests", "res://Scripts/Tests/CityTests.gd", false],
		["--roof-tests", "res://Scripts/Tests/RoofTests.gd", false],
		["--salary-tests", "res://Scripts/Tests/SalaryTests.gd", false],
		["--gui-view-tests", "res://Scripts/Tests/GuiViewTests.gd", false],
		["--calendar-tests", "res://Scripts/Tests/CalendarTests.gd", false],
		["--gui-tests", "res://Scripts/Tests/GuiTests.gd", false],
		["--board-tests", "res://Scripts/Tests/BoardTests.gd", false],
		["--builder-tests", "res://Scripts/Tests/BuilderTests.gd", false],
		["--builder-page-tests", "res://Scripts/Tests/BuilderPageTests.gd", false],
		["--odds-tests", "res://Scripts/Tests/OddsTests.gd", false],
		["--contract-tests", "res://Scripts/Tests/ContractTests.gd", false],
		["--checkcontract-tests", "res://Scripts/Tests/CheckContractTests.gd", false],
		["--eventcontract-tests", "res://Scripts/Tests/EventContractTests.gd", false],
		["--timelinecontract-tests", "res://Scripts/Tests/TimelineContractTests.gd", false],
		["--contract-gate-tests", "res://Scripts/Tests/ContractGateTests.gd", true],
		["--betrayal-tests", "res://Scripts/Tests/BetrayalTests.gd", false],
		["--competition-tests", "res://Scripts/Tests/CompetitionTests.gd", false],
		["--rescue-tests", "res://Scripts/Tests/RescueTests.gd", false],
		["--rescue-probe", "res://Scripts/Tests/RescueProbe.gd", false],
		["--scheduler-tests", "res://Scripts/Tests/SchedulerTests.gd", false],
		["--gamestate-tests", "res://Scripts/Tests/GameStateTests.gd", false],
		["--gui-meter-tests", "res://Scripts/Tests/GuiMeterTests.gd", true],
		["--gui-frame-tests", "res://Scripts/Tests/GuiFrameTests.gd", true],
		["--gui-widget-tests", "res://Scripts/Tests/GuiWidgetTests.gd", true],
		["--gui-hud-tests", "res://Scripts/Tests/GuiHudTests.gd", true],
		["--main-menu-toggle-tests", "res://Scripts/Tests/MainMenuToggleTests.gd", true],
		["--gui-metrics-tests", "res://Scripts/Tests/GuiMetricsTests.gd", true],
		["--gui-merc-tests", "res://Scripts/Tests/GuiMercTests.gd", true],
		["--gui-contract-tests", "res://Scripts/Tests/GuiContractTests.gd", true],
		["--gui-flow-tests", "res://Scripts/Tests/GuiFlowTests.gd", true],
		["--gui-plan-tests", "res://Scripts/Tests/GuiPlanTests.gd", true],
		["--gui-lock-tests", "res://Scripts/Tests/GuiLockTests.gd", true],
		["--gui-loan-tests", "res://Scripts/Tests/GuiLoanTests.gd", true],
		["--gui-manager-tests", "res://Scripts/Tests/GuiManagerTests.gd", true],
		["--gui-atom-tests", "res://Scripts/Tests/GuiAtomTests.gd", true],
		["--button-fx-tests", "res://Scripts/Tests/ButtonFxTests.gd", true],
		["--gui-icon-tests", "res://Scripts/Tests/GuiIconTests.gd", true],
		["--status-badge-tests", "res://Scripts/Tests/StatusBadgeTests.gd", true],
		["--gui-cursor-tests", "res://Scripts/Tests/GuiCursorTests.gd", true],
		["--character-tests", "res://Scripts/Tests/CharacterTests.gd", true],
		["--appearance-pool-tests", "res://Scripts/Tests/AppearancePoolTests.gd", true],
		["--sound-tests", "res://Scripts/Tests/SoundTests.gd", true],
		["--gui-promo-tests", "res://Scripts/Tests/GuiPromoTests.gd", true],
		["--gui-notice-tests", "res://Scripts/Tests/GuiNoticeTests.gd", true],
		["--gui-subs-tests", "res://Scripts/Tests/GuiSubsTests.gd", true],
		["--gui-tree-tests", "res://Scripts/Tests/GuiTreeTests.gd", true],
		["--gui-coach-tests", "res://Scripts/Tests/GuiCoachTests.gd", true],
		["--gui-crew-tests", "res://Scripts/Tests/GuiCrewTests.gd", true],
		["--gui-results-tests", "res://Scripts/Tests/GuiResultsTests.gd", true],
		["--gui-kit-tests", "res://Scripts/Tests/GuiKitTests.gd", true],
		["--gui-payroll-tests", "res://Scripts/Tests/GuiPayrollTests.gd", true],
		["--gui-stock-tests", "res://Scripts/Tests/GuiStockTests.gd", true],
		["--gui-notify-tests", "res://Scripts/Tests/GuiNotifyTests.gd", true],
		["--gui-filter-tests", "res://Scripts/Tests/GuiFilterTests.gd", true],
		["--gui-findata-tests", "res://Scripts/Tests/GuiFinanceDataTests.gd", true],
		["--forecast-tests", "res://Scripts/Tests/ForecastTests.gd", true],
		["--gui-bazaar-tests", "res://Scripts/Tests/GuiBazaarTests.gd", true],
		["--gui-legal-tests", "res://Scripts/Tests/GuiLegalTests.gd", true],
		["--gui-ads-tests", "res://Scripts/Tests/GuiAdsTests.gd", true],
		["--gui-finance-tests", "res://Scripts/Tests/GuiFinanceTests.gd", true],
		["--gui-loanview-tests", "res://Scripts/Tests/GuiLoanViewTests.gd", true],
		["--gui-payview-tests", "res://Scripts/Tests/GuiPayViewTests.gd", true],
		["--gui-invest-tests", "res://Scripts/Tests/GuiInvestTests.gd", true],
		["--gui-hiring-tests", "res://Scripts/Tests/GuiHiringTests.gd", true],
		["--gui-client-tests", "res://Scripts/Tests/GuiClientTests.gd", true],
		["--gui-click-d-tests", "res://Scripts/Tests/GuiClickDTests.gd", true],
		["--gui-click-h-tests", "res://Scripts/Tests/GuiClickHTests.gd", true],
		["--gui-click-ja-tests", "res://Scripts/Tests/GuiClickJATests.gd", true],
		["--gui-click-jb-tests", "res://Scripts/Tests/GuiClickJbTests.gd", true],
		["--gui-sort-tests", "res://Scripts/Tests/GuiSortTests.gd", true],
		["--gui-accept-tests", "res://Scripts/Tests/GuiAcceptTests.gd", true],
		["--mercdave-tests", "res://Scripts/Tests/MercdaveTests.gd", true],
		["--mercdave-ui-tests", "res://Scripts/Tests/MercdaveUiTests.gd", true],
		["--gui-calsource-tests", "res://Scripts/Tests/GuiCalendarSourceTests.gd", true],
		["--gui-calendar-tests", "res://Scripts/Tests/GuiCalendarTests.gd", true],
		["--gui-mail-tests", "res://Scripts/Tests/GuiMailTests.gd", true],
		["--gen-tests", "res://Scripts/Tests/GenTests.gd", false],
		["--reach-tests", "res://Scripts/Tests/ReachTests.gd", false],
		["--sim-tests", "res://Scripts/Tests/SimTests.gd", true],
		["--play-tests", "res://Scripts/Tests/PlayTests.gd", false],
		["--localsim-tests", "res://Scripts/Tests/LocalSimTests.gd", false],
	]
	var out: Array = []
	var listed: Dictionary = {}
	for entry: Array in flags:
		listed[str(entry[0])] = true
		if entry[1] is Callable:
			out.append(entry)
		else:
			out.append([entry[0], HarnessEntry._run_suite_path.bind(str(entry[1]), host, bool(entry[2]))])
	#Map suites reach editor-only addon classes; their rows come from the MapTests SUITES constant, read by path.
	#A map flag also listed above keeps that row only.
	var map_script: GDScript = _load_script(MAP_TESTS_PATH)
	var map_suites: Array = []
	if map_script != null:
		map_suites = map_script.get_script_constant_map().get("SUITES", [])
	for entry: Array in map_suites:
		if listed.has(str(entry[0])):
			continue
		out.append([entry[0], HarnessEntry._run_suite_path.bind(str(entry[1]), host, true)])
	return out


#Loads one suite script by path at run time and awaits its run, passing host when takes_host; a missing file fails.
static func _run_suite_path(path: String, host: Node, takes_host: bool) -> bool:
	var suite: GDScript = _load_script(path)
	if suite == null:
		return false
	if takes_host:
		return bool(await suite.call("run", host))
	return bool(await suite.call("run"))


#Loads a test script by path; null and a printed line when the file is missing.
static func _load_script(path: String) -> GDScript:
	var script: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else null
	if script == null:
		print("HARNESS: cannot load %s" % path)
	return script


#Prints the full lifepath audit; always reports success so the engine exits with 0.
static func _run_lifepath_audit() -> bool:
	LifepathAudit.audit_full()
	return true


#One AUTHOR line per HelpRowsAuthor record.
static func _author_line(record: Dictionary) -> String:
	var name: String = String(record["name"])
	if bool(record["exists"]):
		return "AUTHOR: %s exists" % name
	if bool(record["ok"]):
		return "AUTHOR: %s ok line %d check %s" % [name, int(record["line"]), str(bool(record["check"])).to_lower()]
	return "AUTHOR: %s FAILED %s" % [name, String(record["error"])]


#Mercs generated at start: N from an "--auto-mercs=N" user arg, 3 when the flag is absent.
static func _auto_merc_count() -> int:
	var spec := HarnessFlags.auto_spec("--auto-mercs")
	return 3 if spec == "" else maxi(2, spec.to_int())


#Reads N from a "<flag>=N" user arg; 0 when the flag is absent.
static func _count_flag(flag: String) -> int:
	return maxi(0, HarnessFlags.arg_int(flag, 0))


#Reads S from an "--auto-seed=S" user arg; -1 when the flag is absent, so a batch keeps its own seed.
static func _auto_seed_base() -> int:
	return HarnessFlags.auto_seed(-1)
