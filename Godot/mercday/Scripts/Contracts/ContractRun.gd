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
#Complete-by minute copied from the entry at dispatch (0 = unbounded); the scheduler fails a late arrival from it.
var deadline_minute: int = 0
#Minutes the job takes after arrival, copied from the entry at dispatch; arrival plus these must land by the deadline.
var completion_minutes: int = 0
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
#The dispatch Leader slot's merc uid; -1 = no leader.
var leader_uid: int = -1
#The dispatch travel mode key (GuiTypes); a vehicle chase reads its speed.
var travel_mode: String = "foot"
#Dispatch roles, merc_uid to role label; not persisted.
var roles: Dictionary = {}
#The running timeline step's normalized Event Config cell; "" outside a timeline event step.
var step_config: String = ""


#A fresh run for this contract and team, with the contract's start location looked up.
static func make(source: ContractData, party: Array[MercenaryData], narrate: Callable,
		leader_id: int = -1) -> ContractRun:
	var fresh := ContractRun.new()
	fresh.contract = source
	fresh.team.assign(party)
	fresh.line_fn = narrate
	fresh.leader_uid = leader_id
	if source != null and source.location_a != "":
		fresh.location = DataManager.locations.get(source.location_a, null) as LocationData
	return fresh


func living_team() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for merc: MercenaryData in team:
		if merc != null and not merc.is_dead:
			out.append(merc)
	return out


#The living team member holding the leader uid; null once the leader is dead, taken, fled or defected.
func leader() -> MercenaryData:
	if leader_uid < 0:
		return null
	for merc: MercenaryData in living_team():
		if merc.merc_uid == leader_uid:
			return merc
	return null


#Living members holding a role, team order; "Leader" is the living leader alone.
func holders(role: String) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if role == "Leader":
		var head: MercenaryData = leader()
		if head != null:
			out.append(head)
		return out
	for merc: MercenaryData in living_team():
		if String(roles.get(merc.merc_uid, "")) == role:
			out.append(merc)
	return out


#The Event Config cell events read: the running step's cell, else the contract's own.
func event_config() -> String:
	if step_config != "":
		return step_config
	return contract.event_config if contract != null else ""


func difficulty() -> float:
	return contract.difficulty if contract != null else 0.0


func remove_dead(dead: Array[MercenaryData]) -> Array[MercenaryData]:
	return _move_out(dead, casualties)


func remove_departed(mercs: Array[MercenaryData]) -> Array[MercenaryData]:
	return _move_out(mercs, departed)


func remove_kidnapped(mercs: Array[MercenaryData]) -> Array[MercenaryData]:
	return _move_out(mercs, kidnapped)


#Takes one merc off the team into a roster list and returns the campaign state expiry lines.
func depart(merc: MercenaryData, into: Array[MercenaryData]) -> Array[String]:
	var gone: Array[MercenaryData] = [merc]
	_move_out(gone, into)
	var lines: Array[String] = StateCampaign.expire_campaign_states(merc, CampaignClock.now())
	TraitRuntime.revert_scope(merc, TraitRuntime.SCOPE_CONTRACT)
	BeauSystem.roster.erase(merc)
	return lines


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
