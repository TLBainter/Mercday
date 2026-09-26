class_name OddsModel
extends RefCounted

#Everything OddsEstimator.odds needs as plain numbers, built once per contract and roster.
#Opaque to callers: only OddsEstimator reads these fields.

const KIND_BATTLE := "battle"
const KIND_FORMULA := "formula"
const KIND_COMPETITION := "competition"
const KIND_MISSING := "missing"

var contract: ContractData = null

#Roster order; the levels and every per-merc cache are keyed by merc_uid.
var uids: Array[int] = []
var levels: Dictionary = {}

#The team sizes the caches cover, 1 to max_team.
var max_team: int = 1

#The recommended band floor of 11.4; 0 or less means no band penalty.
var band_lo: float = 0.0

#One entry per chained event, the rolled mishaps in order then the primary.
var events: Array[Dictionary] = []


func level_of(uid: int) -> float:
	return float(levels.get(uid, 0.0))
