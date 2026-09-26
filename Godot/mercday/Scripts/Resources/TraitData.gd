class_name TraitData extends Resource

var trait_source: String
var trait_category: String
var trait_type: String
var trait_name: String
var description: String
var effect_dsl: String
var rarity: String
var is_bad: bool
var logline_a: String
var logline_b: String
var perk_groups: Array[String] = []  #normalized perk group words from Traits.tsv column 11
var gear_key: String = ""            #weapon type or armor type this Weapon/Armor row belongs to
