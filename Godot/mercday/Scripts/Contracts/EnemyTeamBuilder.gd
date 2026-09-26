class_name EnemyTeamBuilder

#Builds the opposing team for a battle event from the event's Enemy and Enemy Counter cells.

const MONSTER_EVENT := "Slay the Monster"


static func build(event: EventData, run: ContractRun, bad_luck_extra: int) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if event == null or run == null:
		return out
	var req := OpponentRequest.new()
	req.source = event.enemy
	req.count_formula = event.enemy_counter
	req.party = run.living_team()
	req.difficulty = run.difficulty()
	if run.contract != null:
		req.contract_level = run.contract.contract_level
	req.extra_ctx = {"bad_luck_roll": bad_luck_extra}
	req.tag = event.event_name
	var config: ContractConfig = ContractLibrary.config()
	if event.enemy == "Mercs":
		req.traditions.assign([config.enemy_odd_tradition, config.enemy_tradition])
	#The monster is a placeholder merc, so its level comes from the config formula, not the band.
	if event.event_name == MONSTER_EVENT:
		req.level_formula = config.monster_level_formula
	out.assign(OpponentGenerator.generate(req))
	return out
