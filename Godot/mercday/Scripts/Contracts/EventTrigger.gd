class_name EventTrigger

#Contract events that arrive through their Trigger cell instead of a pool roll, tested at a party rest.

const WILDERNESS := "wilderness"
const SETTLEMENT_TYPE := "Settlement"
const URBAN_ENVIRONMENT := "Urban"

static var forced_d100: int = -1
#Respite rolls that came up empty; only a firing clears it, so the streak crosses contract boundaries.
static var missed_respites: int = 0
#The roll line from the last pick, empty when that pick made no roll.
static var last_line: String = ""


#Wilderness is both tests: not a settlement, and no Urban environment anywhere up the parent chain.
static func is_wilderness(loc: LocationData) -> bool:
	if loc == null:
		return false
	if loc.location_type.strip_edges() == SETTLEMENT_TYPE:
		return false
	return LifepathRequirements.environment_of(loc).strip_edges() != URBAN_ENVIRONMENT


#A Trigger cell reads "<rest kind>:<place>"; the place half is optional.
static func matches(event: EventData, kind: String, run: ContractRun) -> bool:
	if event == null or run == null:
		return false
	var trigger_kind: String = _trigger_part(event, 0)
	if trigger_kind == "" or trigger_kind != StateTokens.normalize_token(kind):
		return false
	var place: String = _trigger_part(event, 1)
	if place == "":
		return true
	if place != WILDERNESS:
		return false
	return is_wilderness(run.location)


#Percent chance at this rest: Luck buys it down, every Respite that passed quietly pushes it up.
static func chance(team: Array[MercenaryData]) -> float:
	var config: ContractConfig = ContractLibrary.config()
	var pct: float = config.ambush_base_chance - PartyStats.average_stat(team, "luck") * config.ambush_luck_weight
	pct += float(missed_respites) * config.ambush_escalation
	return clampf(pct, config.ambush_chance_floor, 100.0)


static func roll(team: Array[MercenaryData]) -> Dictionary:
	var d100: int = Dice.forced_or_d100(forced_d100)
	forced_d100 = -1
	var pct: float = chance(team)
	var avg: float = PartyStats.average_stat(team, "luck")
	return {
		"d100": d100,
		"chance": pct,
		"average_luck": avg,
		"streak": missed_respites,
		"fired": float(d100) <= pct,
		"line": "AMBUSH ROLL: d100 %d vs %.1f%% (Luck %.1f, streak %d)" % [d100, pct, avg, missed_respites],
	}


#The event this rest springs, or null; one firing per event per run, and only a Respite triggers today.
static func pick(kind: String, run: ContractRun) -> EventData:
	last_line = ""
	if run == null or kind != RestSystem.KIND_RESPITE:
		return null
	#A Local run rests at the guild: no roll and no streak move.
	if run.contract != null and run.contract.local:
		return null
	if _forced_name() != "":
		var forced: EventData = _forced_event(kind, run)
		if forced != null:
			missed_respites = 0
		return forced
	var list: Array[EventData] = _candidates(kind, run)
	if list.is_empty():
		return null
	var result: Dictionary = roll(run.living_team())
	last_line = String(result.get("line", ""))
	if not bool(result.get("fired", false)):
		missed_respites += 1
		return null
	missed_respites = 0
	var chosen: EventData = list[randi() % list.size()]
	last_line += "\nTRIGGER PICK: %s of %d candidates" % [chosen.event_name, list.size()]
	return chosen


static func _forced_name() -> String:
	return ContractLibrary.config().force_trigger_event.strip_edges()


#The forced event skips the place test and the roll, never the one firing per run.
static func _forced_event(kind: String, run: ContractRun) -> EventData:
	var event: EventData = ContractLibrary.event(_forced_name())
	if event == null or run.triggered_events.has(event.event_name):
		return null
	if _trigger_part(event, 0) != StateTokens.normalize_token(kind):
		return null
	return event


#Every event whose Trigger cell answers this rest, lists the run's contract type (blank lists all) and has not fired yet.
static func _candidates(kind: String, run: ContractRun) -> Array[EventData]:
	var out: Array[EventData] = []
	for row: Dictionary in DataManager.event_rows:
		if String(row.get("Trigger", "")).strip_edges() == "":
			continue
		var name: String = String(row.get("Event Name", ""))
		if name == "" or run.triggered_events.has(name):
			continue
		var event: EventData = ContractLibrary.event(name)
		if event != null and matches(event, kind, run) and type_allowed(event, run):
			out.append(event)
	return out


#A blank Possible Contracts cell, or a run with no contract, allows every type.
static func type_allowed(event: EventData, run: ContractRun) -> bool:
	if event.possible_contracts.is_empty() or run.contract == null:
		return true
	return event.possible_contracts.has(run.contract.contract_type)


static func _trigger_part(event: EventData, index: int) -> String:
	if event == null:
		return ""
	var parts: PackedStringArray = event.trigger.split(":", false)
	if index >= parts.size():
		return ""
	return StateTokens.normalize_token(parts[index])
