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

const CHECK_LABELS := {
	"defend_check": "DEFEND CHECK (Dexterity)",
	"urban_check": "URBAN CHECK (Cognition)",
	"monster_hunt_check": "MONSTER HUNT CHECK (Vigor)",
	"social_check": "SOCIAL CHECK (Wile)",
	"poison_check": "POISON CHECK (Dexterity / Wile)",
	"put_on_a_show_check": "PUT ON A SHOW CHECK (Wile / Dexterity)",
}

var mercs: Array[MercenaryData] = []


#Every harness flag and the roster build live in HarnessEntry; see its _suite_flags for the list.
func _ready() -> void:
	if await HarnessEntry.run(self):
		return
	mercs = HarnessEntry.mercs
	_connect_buttons()


func _connect_buttons() -> void:
	var actions: Dictionary = _button_actions()
	for key: String in actions:
		(get_node(get(key) as NodePath) as Button).pressed.connect(actions[key] as Callable)


#Each NodePath export by name, paired with what its button runs.
func _button_actions() -> Dictionary:
	var actions: Dictionary = {
		"reroll_mercs": _on_reroll_mercs,
		"add_merc": _on_add_merc,
		"remove_merc": _on_remove_merc,
		"reroll_names": _on_reroll_names,
		"add_taverngoer": _on_add_taverngoer,
		"batch_analysis": func() -> void: MercSheetPrinter.batch_analysis(),
		"attack_check": func() -> void: CheckDemos.attack_check(mercs),
		"damage_check": func() -> void: CheckDemos.damage_check(mercs),
		"start_battle": func() -> void: BattleHarness.start_battle(mercs),
		"drop_mercs": func() -> void: CheckDemos.drop_mercs(mercs),
		"gen_outhouse_map": func() -> void: BuildingMapWriter.gen_outhouse_map(),
		"gen_terrain_batch": func() -> void: TerrainBatchWriter.gen_terrain_batch(),
		"start_interior_battle": func() -> void: BattleHarness.start_battle(mercs, "Interior"),
		"run_test_contract": func() -> void: HarnessContracts.run_test_contract(mercs),
	}
	for key: String in CHECK_LABELS:
		actions[key] = CheckDemos.named_check.bind(String(CHECK_LABELS[key]), mercs)
	return actions


func _on_reroll_mercs() -> void:
	for merc: MercenaryData in mercs:
		CampaignKnowledge.forget(merc.merc_uid)
	mercs.clear()
	print("\n====== REROLLING MERCS ======\n")
	for i: int in range(3):
		var merc := HarnessRoster.roster_merc(i)
		mercs.append(merc)
		MercSheetPrinter.print_merc(merc)
	TestFixtures.set_roster(mercs)


func _on_add_merc() -> void:
	var merc := HarnessRoster.roster_merc(mercs.size())
	_add_and_sync(merc)
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
	TestFixtures.set_roster(mercs)
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
	var template: NPCTemplate = DataManager.npc_templates.get("Taverngoer", null) as NPCTemplate
	if template == null:
		print("ERROR: no Taverngoer NPC template.")
		return
	var npc: Array[MercenaryData] = [NPCGenerator.generate(template, party)]
	_add_and_sync(npc[0])
	MercSheetPrinter.print_merc(npc[0])


func _add_and_sync(merc: MercenaryData) -> void:
	mercs.append(merc)
	TestFixtures.set_roster(mercs)
