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
#stat var name -> flat amount added to the formula value before the multiplier
var stat_flat_bonuses: Dictionary
#stat var name -> summed fractional multiplier; two +5% boosts store 0.10
var stat_multipliers: Dictionary

#Last calculate_all output; refresh merges against it so direct merc.stats writes survive.
var stats_baseline: Dictionary
var odds_bonuses: Dictionary
var max_stats: Dictionary
var luck_roll: float
var blocked_circumstances: Array[String]
var passive_effects: Array[String]
var min_stats: Dictionary
var cost_modifiers: Dictionary
var items: Array  # Array[ItemData] once Godot imports ItemData.gd
var equipped_weapon: WeaponData
#Second drawn weapon held in the free hand; never the weapon used to attack.
var offhand_weapon: WeaponData = null
var equipped_armor: ArmorData
var acquired_critical_successes: Array[String] = []
var weapon_perks: Array[TraitData] = []
var armor_perks: Array[TraitData] = []
var current_hp: int = 0
#Set once a merc dies; HP stays at 0 and never goes negative.
var is_dead: bool = false
var current_ep: int = 0
var current_mp: int = 0
var current_ap: int = 0
var current_rep: int = 0
var excess_ap: int = 0
var excess_hp: int = 0
var excess_ep: int = 0
var excess_mp: int = 0
var rest_lockout_until: int = 0      #campaign minute; deployable when CampaignClock.now() >= this
var rest_lockout_kind: String = ""   #respite or furlough while a lockout runs
var on_contract: bool = false
var campaign_states: Dictionary = {}  #state_name -> expiry campaign minute, -1 when the state has no timer
var beau_together: bool = false
var beau_apart_minutes: int = 0
var beau_last_tick_minute: int = -1
var beau_last_seen_minute: int = -1
var beau_hp_ticks: int = 0
var group_perk_cells_applied: Dictionary = {}  #trait_name -> true; group perks whose cell already ran
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
var last_known_enemy_positions: Dictionary = {}  #MercenaryData -> Vector3i
var known_immunities: Dictionary = {}  #MercenaryData -> Array[String] immune/protected/susceptible tokens seen
var pending_crit_rewards: Array = []  #critical success entries rolled during an encounter, applied after it
var merc_uid: int = 0  #campaign identity; 0 = none
var xp: int = 0  #lifetime experience; level is floor(xp / 100)
var age: int = 0
var age_category: String = ""  #Young, Adult or Elder once generated; empty until then
var lifepath_pool: Array[String] = []  #event names this merc has qualified for
var lifepath_roll_step: int = 0         #levels gained since the last lifepath event
var beau_uid: int = 0                   #merc this one is In Love with; 0 = none
var buddy_uid: int = 0                  #merc this one is Buddy with; 0 = none
#Event name -> {"flat": {}, "mult": {}}; the stat change that event added, so it can be undone.
var lifepath_stat_deltas: Dictionary = {}
var last_seen_position: Vector3i = Vector3i(-1, -1, -1)  #last node of current_target before they went into full cover
var combat_idle_rounds: int = 0
var ap_debt: int = 0


#True when the merc still carries rounds of any ammo type outside the loaded weapon.
static func has_reserve_ammo(merc: MercenaryData) -> bool:
	for v in merc.ammo_inventory.values():
		if int(v) > 0:
			return true
	return false
