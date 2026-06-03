class_name NPCTemplate extends Resource

var npc_type: String
var name_mode: String
var origin_pool: Array[String] = []
var ancestry_any: bool = false
var ancestry_constraints: Dictionary = {}
var heritage_any: bool = false
var heritage_pool: Array[String] = []
var tradition_any: bool = false
var tradition_none: bool = false
var tradition_pool: Array[String] = []
var level_formula: String = ""
var sle_name: String = "None"
var ele_any: bool = false
var ele_pool: Array[String] = []
var le_count_str: String = "0"
var weapon_pool: Array[String] = []
var armor_pool: Array[String] = []
var loadout_pool: Array[String] = []
