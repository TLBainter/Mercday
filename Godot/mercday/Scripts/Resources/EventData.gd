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


func is_battle() -> bool:
	return success_formula == "Battle"


func is_competition() -> bool:
	return success_formula == "Competition"
