class_name BattleConfig extends Resource

@export var attack_base_ap: int = 3
@export var move_base_ap: int = 2
@export var draw_base_ap: int = 0
@export var melee_range: int = 1
@export var max_rounds: int = 100
@export var battle_yield_msec: int = 16  #wall time ms between frame yields in an auto battle; 0 yields at every turn and slot
@export var rand_factor_min: float = 0.1
@export var rand_factor_max: float = 4.9
#These two stat names are fixed: no resource overrides them and the sheets never rename the keys.
@export var base_success_chance_stat: String = "base_success_chance"
@export var reroll_stat: String = "reroll"
@export var fragility_success_threshold: int = 6  #d6 must roll at least this to count as a survival success; default 6
@export var flee_gate: float = 51.0  #flee value (sheet plus battle swing) at or above which a merc rolls to flee each turn
@export var flee_escape_paces: int = 15  #paces a merc on the map edge must bank off-map before it has fled
@export var flee_pursuit_paces: float = 8.0  #distance credit per point of escaping_bonus when picking a Move target
#Kidnapping: the flee average that opens kidnap rolls, the bonus ceiling, and the reach a kidnapper will close.
@export var kidnap_flee_average: float = 50.0
@export var kidnap_bonus_max: float = 50.0
@export var kidnap_reach_paces: int = 4
@export var kidnap_escape_paces: int = 5  #paces a captor on the map edge must bank before it carries its captive off
