class_name ContractRun extends RefCounted

#Mutable state of one contract playthrough: the team, its dead, per-event outcomes and the narration log.

var contract: ContractData = null
var team: Array[MercenaryData] = []
var line_fn: Callable = Callable()
var casualties: Array[MercenaryData] = []
var outcomes: Array[Dictionary] = []
var verdict: String = ""
var reward_paid: int = 0
var failed_event: String = ""
var modifier_record: Dictionary = {}
var penalties_by_merc: Dictionary = {}
var encounter_logs: Array[String] = []
var location: LocationData = null
var log_lines: Array[String] = []
#Facts about the assigned primary event's enemies: tags, count, speed, max_hp, failed.
var target_record: Dictionary = {}


func living_team() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in team:
		if merc != null and not merc.is_dead:
			out.append(merc)
	return out


func remove_dead(dead: Array[MercenaryData]) -> Array[MercenaryData]:
	var moved: Array[MercenaryData] = []
	for merc: MercenaryData in dead:
		if merc == null or not team.has(merc):
			continue
		team.erase(merc)
		if not casualties.has(merc):
			casualties.append(merc)
		moved.append(merc)
	return moved


func emit(line: String) -> void:
	log_lines.append(line)
	if line_fn.is_valid():
		line_fn.call(line)


func merc_names(mercs: Array[MercenaryData]) -> Array[String]:
	var out: Array[String] = []
	for merc: MercenaryData in mercs:
		if merc != null:
			out.append(merc.merc_name)
	return out
