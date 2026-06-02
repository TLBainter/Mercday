class_name MercenaryData extends Resource

var merc_name: String
var tradition: TraditionData
var ancestry: AncestryData
var bloodline: AncestryData
var is_hybrid: bool = false
var recessive_ancestry: AncestryData
var recessive_bloodline: AncestryData
var creature_types: Array[String]
var heritage: HeritageData
var starting_location: LocationData
var lifepaths: Array[LifepathData]
var circumstance_flags: Dictionary
var circumstance_additional_bonus: Dictionary
var knowledges: Array[UtilityTraitData]
var tools: Array[UtilityTraitData]
var perks: Array[TraitData]
var drawbacks: Array[TraitData]
var descriptors: Array[TraitData]
var stats: Dictionary
var stat_bonuses: Dictionary
var odds_bonuses: Dictionary
var max_stats: Dictionary
var luck_roll: float
var blocked_circumstances: Array[String]
var passive_effects: Array[String]
var min_stats: Dictionary
var cost_modifiers: Dictionary
var items: Array  # Array[ItemData] once Godot imports ItemData.gd
var equipped_weapon: WeaponData
var equipped_armor: ArmorData
var acquired_critical_successes: Array[String] = []
var weapon_perks: Array[TraitData] = []
var armor_perks: Array[TraitData] = []
var current_hp: int = 0
var current_ep: int = 0
var current_mp: int = 0
var current_ap: int = 0
var current_rep: int = 0
var excess_ap: int = 0
var active_states: Dictionary = {}   # state_name -> int or {count, source}
var death_test_hp_loss: int = 0      # accumulated max HP loss from failed death tests this combat
var rot_hp_loss: int = 0             # accumulated max HP loss from Rot damage; recovered at end of battle
var ammo_inventory: Dictionary = {}  # ammo_name -> int (rounds remaining)
var ammo_loaded: int = 0
var ammo_loaded_type: String = ""
var weapon_misfired: bool = false
var aim_active: bool = false    # cleared at start of each turn
var weapon_drawn: bool = false       # true = weapon in hand; toggled by _randomize_starting_draw and Draw action
var inventory: Array = []            # Array of {"type": String, "data": Resource}, e.g. {"type": "weapon", "data": WeaponData}
var deferred_effects: Array = []  # Array of {target: MercenaryData, damage: int, type: String, timing: String}
var action_set: MercActionSet
var last_known_enemy_positions: Dictionary = {}  # MercenaryData -> Vector2i
var last_seen_position: Vector2i = Vector2i(-1, -1)  # last grid pos of current_target before they went into full cover
var combat_idle_rounds: int = 0
var ap_debt: int = 0
