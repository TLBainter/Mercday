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
var acquired_critical_successes: Array[String] = []
