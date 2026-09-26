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
#Terrain Odds entries {"area": String, "percent": int}; each is rolled in cell order before the
#location draw and the first success forces that Area row.
@export var terrain_odds: Array[Dictionary] = []
@export var reward_notes: int = 0
@export var max_mercs: int = 0
#0 means unset; ContractGenerator rolls 1 to 5 in halves when the instance is generated.
@export var difficulty: float = 0.0
#The guild level this contract was written for; 0 means unset, so every Contracts.tsv type row stays 0.
@export var contract_level: int = 0
#Marked by the Contracts.tsv Unsavory column; a merc with 0% Unsavory may betray on such a contract.
@export var unsavory: bool = false
@export var assigned_primary_event: String = ""
@export var rolled_mishaps: Array[String] = []
@export var location_a: String = ""
@export var location_b: String = ""
@export var description: String = ""
@export var team_uids: Array[int] = []
@export var status: String = "Type"
#Rescue instances only: the missing merc the contract goes after; kind is "kidnapped" or "fled".
@export var rescue_merc_uid: int = 0
@export var rescue_kind: String = ""
@export var rescue_merc_name: String = ""
