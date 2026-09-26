class_name ContractConfig extends Resource

#Tunable values for contract generation, mishaps, bad luck and enemy scaling.

@export var mishap_chance: float = 100.0
@export var max_mishaps: int = 1
@export var default_reward_notes: int = 300
@export var default_max_mercs: int = 3
@export var default_contract_type: String = "Military"
@export var mishap_relevance_bonus_percent: float = 15.0
@export var bad_luck_step: int = 10
#A wilderness Respite ambush: its base percent, the weight Luck buys it down by, its floor and the per-miss climb.
@export var ambush_base_chance: float = 25.0
@export var ambush_luck_weight: float = 0.25
@export var ambush_chance_floor: float = 5.0
@export var ambush_escalation: float = 5.0
#Respite kidnapping: crew members that act as kidnappers; the rest wait in the wings.
@export var kidnap_pair_size: int = 2
#Betrayal: the Unsavory bar that qualifies anyone, the clean ceiling on an unsavory contract, the campaign gate start and cap.
@export var betrayal_unsavory_bar: float = 50.0
@export var betrayal_clean_max: float = 0.005
@export var betrayal_gate_start: float = 1.0
@export var betrayal_gate_cap: float = 100.0
@export var save_generated_contracts: bool = true
@export var test_merc_level: int = 0
@export var test_primary_event: String = ""
#Rescue battles: auto picks stealth when the enemies outnumber the party; combat and stealth force one.
@export var rescue_mode: String = "auto"
#Names the triggered event that fires at the next Respite, skipping its place test and its roll.
@export var force_trigger_event: String = ""
@export var enemy_tradition: String = "Warrior"
@export var enemy_odd_tradition: String = "Brave"
#Level of an opponent whose template names no formula, Mercs included; the bandit Level cell of NPCs.tsv.
@export var opponent_level_formula: String = "min(40, max(1, party.average_level * level_band))"
#Slay the Monster: one placeholder beast at twice the contract level, which pins party.average_level.
@export var monster_level_formula: String = "max(1, party.average_level * 2)"
#Rival mercenary companies: tradition name to percent multiplier boost, and how many of them turn up.
@export var rival_tradition_odds: Dictionary = {"Performer": 25.0, "Warrior": 25.0}
@export var rival_count_formula: String = "max(1, party.merc_count * difficulty_factor)"

#Rests taken between two contract events; off means the team runs the next event as it stands.
@export var respite_between_events: bool = true
@export var breather_between_events: bool = true

#The posting board: open postings kept, the refill hour, the expiry and distance ranges, the gap and the merc floor.
@export var board_target: int = 12
@export var board_refill_hour: int = 8
@export var board_expiry_min_hours: int = 24
@export var board_expiry_max_hours: int = 168
@export var board_distance_min_km: int = 5
@export var board_distance_max_km: int = 120
@export var board_gap_hours: int = 6
@export var board_merc_min: int = 1
@export var board_issuer_types: int = 4
