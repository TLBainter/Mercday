class_name EventData extends Resource

#Event definition from Events.tsv; a Battle event resolves as an encounter instead of a formula.

@export var event_name: String = ""
@export var event_type: String = ""
@export var trigger: String = ""
@export var check_stats: Array[String] = []
@export var circumstances: Array[String] = []
@export var knowledges: Array[String] = []
@export var tools: Array[String] = []
@export var success_formula: String = ""
@export var possible_contracts: Array[String] = []
@export var possible_locations: Array[String] = []
@export var enemy: String = ""
@export var enemy_counter: String = ""
@export var map_rule: String = ""
#A failed mishap ends the contract only when its row sets Fail Ends Contract.
@export var fail_ends_contract: bool = false


func is_battle() -> bool:
	return success_formula == "Battle"


func is_chase() -> bool:
	return success_formula == "Chase"


#Must match TimelineRunner.PRIMARY_PREFIX; kept literal so this Resource takes no class dependency.
const TIMELINE_PREFIX: String = "timeline:"


func is_timeline() -> bool:
	return event_name.begins_with(TIMELINE_PREFIX)


func is_competition() -> bool:
	return success_formula == "Competition"
