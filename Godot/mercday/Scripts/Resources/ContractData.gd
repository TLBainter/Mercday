class_name ContractData extends Resource

#Type fields come from Contracts.tsv; instance fields are filled by ContractGenerator
#(status Type, Draft, Active, Succeeded, Failed).

@export var contract_type: String = ""
@export var primary_event_pool: Array[String] = []
@export var mishap_pool: Array[String] = []
@export var stat_boosts: Dictionary = {}
@export var circumstance_boosts: Dictionary = {}
@export var tool_boosts: Dictionary = {}
@export var knowledge_boosts: Dictionary = {}
@export var tradition_boosts: Dictionary = {}
@export var penalties: Array[Dictionary] = []
@export var description_template: String = ""
@export var target_categories: Array[String] = []
@export var possible_traits: Array[String] = []
@export var possible_locations: Array[String] = []
@export var reward_notes: int = 0
@export var max_mercs: int = 0
#0 means unset; ContractGenerator rolls 1 to 5 in halves when the instance is generated.
@export var difficulty: float = 0.0
@export var assigned_primary_event: String = ""
@export var rolled_mishaps: Array[String] = []
@export var location_a: String = ""
@export var location_b: String = ""
@export var description: String = ""
@export var team_uids: Array[int] = []
@export var status: String = "Type"
