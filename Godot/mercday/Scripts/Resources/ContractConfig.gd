class_name ContractConfig extends Resource

#Tunable values for contract generation, mishaps, bad luck and enemy scaling.

@export var mishap_chance: float = 100.0
@export var max_mishaps: int = 1
@export var default_reward_notes: int = 300
@export var default_max_mercs: int = 3
@export var default_contract_type: String = "Military"
@export var mishap_relevance_bonus_percent: float = 15.0
@export var bad_luck_step: int = 10
@export var save_generated_contracts: bool = true
@export var test_merc_level: int = 0
@export var test_primary_event: String = "Assist with the Skirmish"
@export var enemy_level_min: int = 1
@export var enemy_level_divisor: int = 2
@export var enemy_tradition: String = "Warrior"
@export var enemy_odd_tradition: String = "Brave"

#Rests taken between two contract events; off means the team runs the next event as it stands.
@export var respite_between_events: bool = true
@export var breather_between_events: bool = true
