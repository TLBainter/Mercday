class_name ContractData extends Resource

#Type fields come from Contracts.tsv; instance fields are filled by ContractGenerator
#(status Type, Draft, Active, Succeeded, Failed).

@export var contract_type: String = ""
#The Contracts.tsv row key; several rows may share one contract_type.
@export var contract_name: String = ""
#Level range of the row; 0 at either end means no bound at that end.
@export var level_min: int = 0
@export var level_max: int = 0
#person, place or org; issuer is then a person class, a Locations.tsv name or an Organizations.tsv Name.
@export var issuer_type: String = ""
@export var issuer: String = ""
#Authored difficulty range in half steps; 0.0 means unset. The rolled instance value stays in difficulty.
@export var difficulty_min: float = 0.0
@export var difficulty_max: float = 0.0
@export var story: bool = false
#check, event or timeline; blank means unset.
@export var style: String = ""
@export var roles: Array[String] = []
#Raw Target, Completion and Event Config cells; later stages read them.
@export var target: String = ""
@export var completion: String = ""
@export var event_config: String = ""
#Time limit in minutes; 0 means unset.
@export var time_minutes: int = 0
#Raw Consequence cell: "<kind> <n>" entries with kind retry, hp, ep, mp or guild.
@export var consequence: String = ""
#Descriptions.tsv texts of this contract_name, in file order.
@export var descriptions: Array[String] = []
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
#Terrain Odds entries {"area": String, "percent": int}; one roll 1..100 walks them in cell order,
#each taking its percent of the range; a roll on no drawable entry falls to the location draw.
@export var terrain_odds: Array[Dictionary] = []
@export var reward_notes: int = 0
#Max Mercs and Min Mercs; 0 is a blank cell, and ContractGenerator sets both on the instance.
@export var max_mercs: int = 0
@export var min_mercs: int = 0
#Local TRUE: the job is at the guild; distance 0, no travel and no field respite.
@export var local: bool = false
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
#Filled at generation: the %target% and %requestor% names the description used.
@export var target_name: String = ""
@export var requestor_name: String = ""
@export var team_uids: Array[int] = []
@export var status: String = "Type"
#Rescue instances only: the missing merc the contract goes after; kind is "kidnapped" or "fled".
@export var rescue_merc_uid: int = 0
@export var rescue_kind: String = ""
@export var rescue_merc_name: String = ""
