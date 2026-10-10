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
#Aura entries {"state": String, "paces": int, "gate": String} granted to allies in range.
var auras: Array[Dictionary] = []
var min_stats: Dictionary
var cost_modifiers: Dictionary
var items: Array  #ItemData entries; the array itself stays untyped for the Godot import order
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
var rest_lockout_start: int = -1     #campaign minute the running lockout began; -1 none
var rest_lockout_kind: String = ""   #respite, furlough or vacation while a lockout runs
var furlough_pressure: float = 0.0   #effective days since the last completed Furlough
var deficit_pressure: float = 0.0    #effective days spent at a pool deficit
var fail_stress: float = 0.0         #survived failed contracts, decaying
var idle_since_minute: int = -1      #minute the idle window began; -1 working, -2 idle but its Furlough is spent
var last_furlough_minute: int = -1   #minute the last Furlough completed; -1 none
var on_contract: bool = false
var campaign_states: Dictionary = {}  #state_name -> expiry campaign minute, -1 when the state has no timer
var beau_together: bool = false
var beau_apart_minutes: int = 0
var beau_last_tick_minute: int = -1
var beau_last_seen_minute: int = -1
var beau_hp_ticks: int = 0
var group_perk_cells_applied: Dictionary = {}  #trait_name -> true; group perks whose cell already ran
var active_states: Dictionary = {}  #state_name -> int or {count, source}
var death_test_hp_loss: int = 0  #accumulated max HP loss from failed death tests this combat
var rot_hp_loss: int = 0  #accumulated max HP loss from Rot damage; recovered at end of battle
var crawling: bool = false           #moving prone through a cell too low for the merc's Size
var suffocate_rounds: int = 0        #rounds held with Suffocating or Drowning; the breath countdown
var breath_clear_rounds: int = 0     #rounds since the last breathless round; clears the loss at Vigor
var suffocation_hp_loss: int = 0     #accumulated max HP loss from the breath countdown
var ammo_inventory: Dictionary = {}  #ammo_name -> int (rounds remaining)
var ammo_loaded: int = 0
var ammo_loaded_type: String = ""
var max_ammo: int = -1               #cap on the rounds carried into a battle; -1 = uncapped
var weapon_misfired: bool = false
var aim_active: bool = false  #cleared at start of each turn
var weapon_drawn: bool = false  #true = weapon in hand; toggled by _randomize_starting_draw and Draw action
var inventory: Array = []  #Array of {"type": String, "data": Resource}, e.g. {"type": "weapon", "data": WeaponData}
var deferred_effects: Array = []  #Array of {target: MercenaryData, damage: int, type: String, timing: String}
var action_set: MercActionSet
var last_known_enemy_positions: Dictionary = {}  #MercenaryData -> Vector3i
var known_immunities: Dictionary = {}  #MercenaryData -> Array[String] immune/protected/susceptible tokens seen
var pending_crit_rewards: Array = []  #critical success entries rolled during an encounter, applied after it
var merc_uid: int = 0  #campaign identity; 0 = none
var xp: int = 0  #lifetime experience; level is floor(xp / 100)
var age: int = 0
var age_category: String = ""  #Young, Adult or Elder once generated; empty until then
var appearance_seed: int = 0  #CharacterAppearance.roll seed stamped at generation; 0 = none
var appearance: CharacterAppearance = null  #rolled from appearance_seed at generation; null = none
var lifepath_pool: Array[String] = []  #event names this merc has qualified for
var lifepath_roll_step: int = 0         #levels gained since the last lifepath event
var beau_uid: int = 0                   #merc this one is In Love with; 0 = none
var buddy_uid: int = 0                  #merc this one is Buddy with; 0 = none
#Event name -> {"flat": {}, "mult": {}}; the stat change that event added, so it can be undone.
var lifepath_stat_deltas: Dictionary = {}
#Level-up picks: marks are "<tier>|<option>|<ordinal>"; level_ups_resolved is the last level whose picks ran.
var level_up_marks: Dictionary = {}
var level_up_log: Array[Dictionary] = []
var level_ups_resolved: int = -1
#Guild employment: the hire order, the minute of the hire, the flat wage and the guild's standing.
var hire_index: int = -1     #order of hire from 0; -1 never hired
var hired_minute: int = -1   #CampaignClock minute of the hire; -1 never hired
var missing_since: int = -1  #CampaignClock minute the merc abandoned a contract and went missing; -1 not missing
var monthly_salary: int = 0
var salary_ask: int = 0      #solo asking salary stamped at generation
var guild_opinion: int = 0   #-5..5
var backpay: int = 0         #salary withheld while captive
var bonus_owed: int = 0      #contract bonus share withheld while away
var action_uses: Dictionary = {}  #action name -> times used in battle, read by the Merc Viewer
var banked_experience_points: int = 0
var skill_points: int = 0
var tradition_skill_points: int = 0
var class_skill_trees: int = 0
var gear_use_counts: Dictionary = {}
var last_seen_position: Vector3i = Vector3i(-1, -1, -1)  #last node of current_target before they went into full cover
var combat_idle_rounds: int = 0
var ap_debt: int = 0
#Per-battle flags BattleState.create resets: left the field alive, flight state, Withdraw immunity.
var off_field: bool = false
var flee_intent: bool = false
var flee_abandons: bool = false
var flee_escape_paces: int = 0
var advantage_immune: bool = false
#Gear perk grants parked until gear exists; entries are {"dsl": String, "source": String}.
var deferred_gear_grants: Array[Dictionary] = []
#Set once generation has equipped gear; later grants with no matching gear are skipped, never parked.
var gear_grants_resolved: bool = false
#Armor Bonus lost to Armor Break; a furlough repairs the armor and clears it.
var armor_break: int = 0
#Maximum HP a perk removed until the next furlough restores it.
var max_hp_penalty: int = 0
#Maximum EP and MP removed the same way; Push Onward and Realign move them, a furlough restores them.
var max_ep_penalty: int = 0
var max_mp_penalty: int = 0
#Furlough training: "knowledge:<name>", "tool:<name>" or "circumstance:<display>" -> 1 die or 7.0 percent.
var trained_bonus: Dictionary = {}
#The same keys -> the number of real checks that used them; never reset.
var use_counts: Dictionary = {}
#Attacks made this turn: target -> count, the running total, and weapon type key -> count.
var turn_attacks: Dictionary = {}
var turn_attack_total: int = 0
var turn_weapon_attacks: Dictionary = {}
#ReP a perk granted for the rest of the turn; cleared when the turn ends.
var temp_rep: int = 0


#Footprint side in cells; never below 1.
func unit_size() -> int:
	return maxi(1, int(stats.get("size", 1)))


#Current hp over max hp, with max hp floored at 1.
func hp_ratio() -> float:
	return float(current_hp) / maxf(1.0, float(stats.get("maximum_hit_points", 1)))


#Salary and bonus withheld while the merc was away; nothing pays it out yet.
func back_owed() -> int:
	return backpay + bonus_owed


#Weapons carried in the inventory, in inventory order; entries with no data are skipped.
func inventory_weapons() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for entry: Dictionary in inventory:
		if entry.get("type") == "weapon":
			var w := entry.get("data") as WeaponData
			if w != null:
				out.append(w)
	return out


#True when the merc still carries rounds of any ammo type outside the loaded weapon.
static func has_reserve_ammo(merc: MercenaryData) -> bool:
	for v in merc.ammo_inventory.values():
		if int(v) > 0:
			return true
	return false
