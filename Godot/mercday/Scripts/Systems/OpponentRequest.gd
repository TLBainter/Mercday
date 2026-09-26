class_name OpponentRequest extends RefCounted

#hooks, stat_skew, level_min and level_max have no production caller yet; they are reserved for authored contracts.
#What OpponentGenerator.generate builds and the outputs it writes back.

#Mercs, an NPCs.tsv template key, or a comma crew cell whose first term leads.
var source: String = "Mercs"
#A count of 0 or more wins; -1 reads count_formula in the Enemy Counter grammar, where a blank formula gives 1.
var count: int = -1
var count_formula: String = ""
#The party the opponents scale against and the contract difficulty.
var party: Array[MercenaryData] = []
var difficulty: float = 0.0
#The contract's own level; 1 or more pins the context average_level so enemies scale to the contract.
var contract_level: int = -1
#The request formula beats the template and config ones; fixed_level skips every formula; -1 turns a clamp off.
var level_formula: String = ""
var fixed_level: int = -1
var level_min: int = -1
var level_max: int = -1
#Mercs only: forced tradition per index with the last repeating, percent multipliers, and rolls with no batch balancing.
var traditions: Array[String] = []
var tradition_odds: Dictionary = {}
var independent_traditions: bool = false
#Lowercase core stat key, such as "vigor", to the core points added after generation.
var stat_skew: Dictionary = {}
#Written over the built context last.
var extra_ctx: Dictionary = {}
#Each is called as hook.call(merc, index, request) per opponent, after the skew.
var hooks: Array[Callable] = []
#Caller name used in warnings and errors.
var tag: String = ""
#Outputs: the context the formulas saw, the count used and each opponent's final level in spawn order.
var resolved_ctx: Dictionary = {}
var resolved_count: int = 0
var rolled_levels: Array[int] = []
