extends Node

@export var reroll_mercs: NodePath
@export var add_merc: NodePath
@export var remove_merc: NodePath
@export var reroll_names: NodePath
@export var add_taverngoer: NodePath
@export var defend_check: NodePath
@export var urban_check: NodePath
@export var monster_hunt_check: NodePath
@export var social_check: NodePath
@export var poison_check: NodePath
@export var put_on_a_show_check: NodePath
@export var batch_analysis: NodePath
@export var attack_check: NodePath
@export var damage_check: NodePath
@export var start_battle: NodePath
@export var drop_mercs: NodePath
@export var gen_outhouse_map: NodePath
@export var gen_terrain_batch: NodePath
@export var start_interior_battle: NodePath
@export var run_test_contract: NodePath

var mercs: Array[MercenaryData] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for entry: Array in _suite_flags():
		if args.has(str(entry[0])):
			var runner: Callable = entry[1]
			get_tree().quit(0 if bool(runner.call()) else 1)
			return
	if args.has("--contract-tests"):
		get_tree().quit(0 if await ContractTests.run() else 1)
		return
	_connect_buttons()
	var built: Dictionary = ContractResourceBuilder.build_all()
	print("CONTRACT BUILDER: %d contracts, %d events, %d warnings" % [int(built["contracts"]), int(built["events"]), int(built["warnings"])])
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--auto-seed="):
			seed(int(a.substr(12)))
	BattleHarness.team_mix = OS.get_cmdline_user_args().has("--auto-team-mix")
	SpawnPlacer.spawn_floor_split = OS.get_cmdline_user_args().has("--auto-floor-split")
	if BattleHarness.team_mix:
		BattleHarness.generate_mixed_mercs(mercs, _auto_merc_count())
	else:
		for i: int in range(_auto_merc_count()):
			var merc := BattleHarness.roster_merc(i)
			mercs.append(merc)
			BattleHarness.grant_auto_immunity(merc, i, _auto_merc_count())
			MercSheetPrinter.print_merc(merc)
	var auto_n := _auto_interior_count()
	var contract_n := _auto_contract_count()
	if auto_n > 0:
		BattleHarness.run_auto_interior(self, mercs, auto_n)
	elif contract_n > 0:
		BattleHarness.run_auto_contract(self, mercs, contract_n)


#Suite flag to runner pairs; --contract-tests is awaited separately in _ready.
func _suite_flags() -> Array:
	return [
		["--los-tests", LosTests.run],
		["--fly-tests", FlyTests.run],
		["--immune-tests", ImmuneTests.run],
		["--check-tests", CheckTests.run],
		["--trait-tests", TraitTests.run],
		["--relationship-tests", RelationshipTests.run],
		["--lifepath-tests", LifepathTests.run],
		["--lifepath-audit", _run_lifepath_audit],
		["--age-tests", AgeTests.run],
		["--xp-tests", XpTests.run],
		["--clock-tests", ClockTests.run],
		["--excess-tests", ExcessTests.run],
		["--rest-tests", RestTests.run],
		["--beau-tests", BeauTests.run],
	]


#Prints the full lifepath audit; always reports success so the engine exits with 0.
func _run_lifepath_audit() -> bool:
	LifepathTests.audit_full()
	return true



func _connect_buttons() -> void:
	(get_node(reroll_mercs) as Button).pressed.connect(_on_reroll_mercs)
	(get_node(add_merc) as Button).pressed.connect(_on_add_merc)
	(get_node(remove_merc) as Button).pressed.connect(_on_remove_merc)
	(get_node(reroll_names) as Button).pressed.connect(_on_reroll_names)
	(get_node(add_taverngoer) as Button).pressed.connect(_on_add_taverngoer)
	(get_node(defend_check) as Button).pressed.connect(func() -> void: CheckDemos.named_check("DEFEND CHECK (Dexterity)", mercs))
	(get_node(urban_check) as Button).pressed.connect(func() -> void: CheckDemos.named_check("URBAN CHECK (Cognition)", mercs))
	(get_node(monster_hunt_check) as Button).pressed.connect(func() -> void: CheckDemos.named_check("MONSTER HUNT CHECK (Vigor)", mercs))
	(get_node(social_check) as Button).pressed.connect(func() -> void: CheckDemos.named_check("SOCIAL CHECK (Wile)", mercs))
	(get_node(poison_check) as Button).pressed.connect(func() -> void: CheckDemos.named_check("POISON CHECK (Dexterity / Wile)", mercs))
	(get_node(put_on_a_show_check) as Button).pressed.connect(func() -> void: CheckDemos.named_check("PUT ON A SHOW CHECK (Wile / Dexterity)", mercs))
	(get_node(batch_analysis) as Button).pressed.connect(func() -> void: MercSheetPrinter.batch_analysis())
	(get_node(attack_check) as Button).pressed.connect(func() -> void: CheckDemos.attack_check(mercs))
	(get_node(damage_check) as Button).pressed.connect(func() -> void: CheckDemos.damage_check(mercs))
	(get_node(start_battle) as Button).pressed.connect(func() -> void: BattleHarness.start_battle(mercs))
	(get_node(drop_mercs) as Button).pressed.connect(func() -> void: CheckDemos.drop_mercs(mercs))
	(get_node(gen_outhouse_map) as Button).pressed.connect(func() -> void: FieldMapWriter.gen_outhouse_map())
	(get_node(gen_terrain_batch) as Button).pressed.connect(func() -> void: FieldMapWriter.gen_terrain_batch())
	(get_node(start_interior_battle) as Button).pressed.connect(func() -> void: BattleHarness.start_interior_battle(mercs))
	(get_node(run_test_contract) as Button).pressed.connect(func() -> void: BattleHarness.run_test_contract(mercs))


#Mercs generated at start: N from an "--auto-mercs=N" user arg, 3 when the flag is absent.
func _auto_merc_count() -> int:
	var spec := BattleHarness._auto_spec("--auto-mercs")
	return 3 if spec == "" else maxi(2, spec.to_int())


#Reads N from an "--auto-interior=N" user arg; 0 when the flag is absent.
func _auto_interior_count() -> int:
	return maxi(0, BattleHarness._auto_spec("--auto-interior").to_int())


#Reads N from an "--auto-contract=N" user arg; 0 when the flag is absent.
func _auto_contract_count() -> int:
	return maxi(0, BattleHarness._auto_spec("--auto-contract").to_int())


func _on_reroll_mercs() -> void:
	for merc: MercenaryData in mercs:
		CampaignKnowledge.forget(merc.merc_uid)
	mercs.clear()
	print("\n====== REROLLING MERCS ======\n")
	for i: int in range(3):
		var merc := BattleHarness.roster_merc(i)
		mercs.append(merc)
		MercSheetPrinter.print_merc(merc)


func _on_add_merc() -> void:
	var merc := BattleHarness.roster_merc(mercs.size())
	mercs.append(merc)
	print("\n====== ADDED MERC ======\n")
	MercSheetPrinter.print_merc(merc)


func _on_remove_merc() -> void:
	if mercs.is_empty():
		print("No mercs to remove.")
		return
	var idx := randi() % mercs.size()
	var removed := mercs[idx]
	CampaignKnowledge.forget(removed.merc_uid)
	mercs.remove_at(idx)
	print("\n====== REMOVED MERC: %s ======\n" % removed.merc_name)


func _on_reroll_names() -> void:
	MercSheetPrinter.print_regional_names()


func _on_add_taverngoer() -> void:
	var avg_level: float = 0.0
	for m: MercenaryData in mercs:
		avg_level += float(m.stats.get("level", 0))
	if mercs.size() > 0:
		avg_level /= float(mercs.size())
	var party := {"average_level": avg_level, "merc_count": mercs.size()}
	print("\n====== TAVERNGOER ======\n")
	var npc := NPCGenerator.generate_batch("Taverngoer", 1, party)
	if npc.is_empty():
		print("ERROR: NPCGenerator returned no results.")
		return
	mercs.append(npc[0])
	MercSheetPrinter.print_merc(npc[0])
