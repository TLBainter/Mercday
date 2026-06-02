class_name BattleConfig extends Resource

@export var attack_base_ap: int = 3
@export var move_base_ap: int = 2
@export var draw_base_ap: int = 0
@export var melee_range: int = 1
@export var max_rounds: int = 100
@export var penalty_threatened: float = -30.0
@export var penalty_partial_cover: float = -15.0
@export var rand_factor_min: float = 0.1
@export var rand_factor_max: float = 4.9
@export var base_success_chance_stat: String = "base_success_chance"
@export var reroll_stat: String = "reroll"
@export var fragility_success_threshold: int = 6  # d6 must roll >= this to count as a survival success (default 6 = only a 6 survives)
