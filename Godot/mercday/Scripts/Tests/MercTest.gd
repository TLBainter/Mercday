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


#Every harness flag and the roster build live in HarnessEntry; see its _suite_flags for the list.
func _ready() -> void:
	if await HarnessEntry.run(self):
		return
	mercs = HarnessEntry.mercs
	_connect_buttons()


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
	(get_node(gen_outhouse_map) as Button).pressed.connect(func() -> void: BuildingMapWriter.gen_outhouse_map())
	(get_node(gen_terrain_batch) as Button).pressed.connect(func() -> void: TerrainBatchWriter.gen_terrain_batch())
	(get_node(start_interior_battle) as Button).pressed.connect(func() -> void: BattleHarness.start_interior_battle(mercs))
	(get_node(run_test_contract) as Button).pressed.connect(func() -> void: HarnessContracts.run_test_contract(mercs))


func _on_reroll_mercs() -> void:
	for merc: MercenaryData in mercs:
		CampaignKnowledge.forget(merc.merc_uid)
	mercs.clear()
	print("\n====== REROLLING MERCS ======\n")
	for i: int in range(3):
		var merc := HarnessRoster.roster_merc(i)
		mercs.append(merc)
		MercSheetPrinter.print_merc(merc)
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)


func _on_add_merc() -> void:
	var merc := HarnessRoster.roster_merc(mercs.size())
	mercs.append(merc)
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)
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
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)
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
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)
	MercSheetPrinter.print_merc(npc[0])
