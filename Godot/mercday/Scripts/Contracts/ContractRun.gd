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
#Event names already fired through EventTrigger this run; one firing per event.
var triggered_events: Array[String] = []
#Living betrayers that left the party.
var defectors: Array[MercenaryData] = []
#Every merc that switched sides this contract, alive or dead.
var betrayers: Array[MercenaryData] = []
#Mercs that fled and abandoned the party.
var departed: Array[MercenaryData] = []
#Mercs carried off by kidnappers.
var kidnapped: Array[MercenaryData] = []
#Captives a Rescue contract brought home, and the missing-pool record its battle uses.
var rescued: Array[MercenaryData] = []
var rescue_record: Dictionary = {}
#Team-wide event names that happened without an outcome of their own; never appended to outcomes.
var event_marks: Array[String] = []
#MercenaryData to Array[String]: marks that belong to one merc.
var merc_marks: Dictionary = {}


func living_team() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in team:
		if merc != null and not merc.is_dead:
			out.append(merc)
	return out


func difficulty() -> float:
	return contract.difficulty if contract != null else 0.0


func remove_dead(dead: Array[MercenaryData]) -> Array[MercenaryData]:
	return _move_out(dead, casualties)


func remove_departed(mercs: Array[MercenaryData]) -> Array[MercenaryData]:
	return _move_out(mercs, departed)


func remove_kidnapped(mercs: Array[MercenaryData]) -> Array[MercenaryData]:
	return _move_out(mercs, kidnapped)


func _move_out(mercs: Array[MercenaryData], into: Array[MercenaryData]) -> Array[MercenaryData]:
	var moved: Array[MercenaryData] = []
	for merc: MercenaryData in mercs:
		if merc == null or not team.has(merc):
			continue
		team.erase(merc)
		if not into.has(merc):
			into.append(merc)
		moved.append(merc)
	return moved


func add_event_mark(mark: String) -> void:
	if not event_marks.has(mark):
		event_marks.append(mark)


func add_merc_mark(merc: MercenaryData, mark: String) -> void:
	if merc == null:
		return
	if not merc_marks.has(merc):
		var fresh: Array[String] = []
		merc_marks[merc] = fresh
	var marks: Array = merc_marks[merc]
	if not marks.has(mark):
		marks.append(mark)


func emit(line: String) -> void:
	log_lines.append(line)
	if line_fn.is_valid():
		line_fn.call(line)


func emit_all(lines: Array[String]) -> void:
	for line: String in lines:
		emit(line)


#Campaign states whose end time has passed, one merc at a time, in list order.
func expire_states(mercs: Array[MercenaryData]) -> void:
	for merc: MercenaryData in mercs:
		emit_all(StateCampaign.expire_campaign_states(merc, CampaignClock.now()))


func merc_names(mercs: Array[MercenaryData]) -> Array[String]:
	var out: Array[String] = []
	for merc: MercenaryData in mercs:
		if merc != null:
			out.append(merc.merc_name)
	return out
