class_name EventRunner

#Dispatches one contract event to the competition, battle or formula resolver.


static func run(event: EventData, contract_run: ContractRun, opts: Dictionary = {}) -> Dictionary:
	if event == null or contract_run == null:
		return outcome(event)
	contract_run.emit("EVENT START: %s (%s)" % [event.event_name, event.event_type])
	if event.event_name == RespiteKidnapResolver.EVENT_NAME:
		return await RespiteKidnapResolver.resolve(event, contract_run, opts)
	if event.is_competition():
		return await CompetitionResolver.resolve(event, contract_run)
	if event.is_battle():
		return await BattleEventResolver.resolve(event, contract_run, opts)
	return FormulaEventResolver.resolve(event, contract_run)


#The empty outcome dictionary every event resolver fills in.
static func outcome(event: EventData) -> Dictionary:
	var casualties: Array[String] = []
	var enemies: Array[String] = []
	var notes: Array[String] = []
	return {
		"event": event.event_name if event != null else "",
		"event_type": event.event_type if event != null else "",
		"success": false,
		"winner": -1,
		"rounds": 0,
		"casualties": casualties,
		"enemies": enemies,
		"enemies_defeated": 0,
		"enemy_count": 0,
		"bad_luck_extra": 0,
		"log_file": "",
		"notes": notes,
	}
