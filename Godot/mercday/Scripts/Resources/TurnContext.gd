class_name TurnContext
extends Resource

var merc: MercenaryData
var state: BattleState
var enemies: Array[MercenaryData] = []
var valid_targets: Array[MercenaryData] = []
var allies: Array[MercenaryData] = []
var current_target: MercenaryData
var enhancements: int = 0
var movement_blocked: bool = false
var weapon_action_taken: bool = false
var has_moved: bool = false
var seeking_failed: bool = false
var blocked_targets: Dictionary = {}
var attack_ap_reduction: int = 0
