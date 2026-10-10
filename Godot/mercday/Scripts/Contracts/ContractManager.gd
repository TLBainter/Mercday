class_name ContractManager

#Runs one contract end to end: boosts on, mishaps, the primary event, verdict and reward.
#Each stage is split into the half that spends campaign time and the half that settles it, so
#ContractScheduler can drive the same code one game-clock step at a time.

const LATE_EVENT := "(arrived after the deadline)"
const LOCAL_LINE := "LOCAL CONTRACT: no travel, no field respite"


#prelude holds what happened at the tavern before departure; it prints and lands in the contract log.
static func run(contract: ContractData, team: Array[MercenaryData], line_fn: Callable,
		prelude: Array[String] = []) -> ContractRun:
	var leader: MercenaryData = MatchScore.default_leader(contract, team)
	var r := ContractRun.make(contract, team, line_fn, leader.merc_uid if leader != null else -1)
	r.emit_all(prelude)
	start(r)
	await execute(r)
	end(r)
	return r


static func start(contract_run: ContractRun) -> void:
	if not is_local(contract_run):
		CampaignClock.advance(CampaignClock.TRAVEL_MINUTES)
		contract_run.emit(CampaignClock.line("travel out", CampaignClock.TRAVEL_MINUTES))
	depart(contract_run)


#A Local contract is worked at the guild: no travel, no field respite and no trigger roll at a rest.
static func is_local(contract_run: ContractRun) -> bool:
	return contract_run != null and contract_run.contract != null and contract_run.contract.local


#What the party settles as it leaves: boosts, penalties, loadouts and the log header.
static func depart(contract_run: ContractRun) -> void:
	for merc: MercenaryData in contract_run.team:
		merc.on_contract = true
		contract_run.emit_all(RestSystem.idle_break(merc))
	BenefitsManager.book.cancel_held(contract_run.team, GameState.day())
	contract_run.expire_states(contract_run.team)
	var contract: ContractData = contract_run.contract
	if contract != null:
		contract.team_uids.clear()
		for merc: MercenaryData in contract_run.team:
			contract.team_uids.append(merc.merc_uid)
		contract.status = BoardEntry.STATUS_ACTIVE
	contract_run.modifier_record = ContractModifiers.apply(contract, contract_run.team)
	TraitRuntime.begin_contract(contract_run)
	RelationshipSystem.begin_contract(contract_run)
	LifepathTally.begin_contract(contract_run)
	LifepathProgression.begin_contract(contract_run)
	contract_run.emit_all(BeauSystem.begin_contract(contract_run))
	for merc: MercenaryData in contract_run.team:
		contract_run.penalties_by_merc[merc] = ContractPenalty.matching(contract, merc, contract_run.team.size())
	_settle_loadouts(contract_run)
	ContractLog.header(contract_run)
	if is_local(contract_run):
		contract_run.emit(LOCAL_LINE)


#What the party puts down before it marches out, once any merc is at or over its Weight Limit.
static func _settle_loadouts(contract_run: ContractRun) -> void:
	var settled: Array[String] = []
	for merc: MercenaryData in contract_run.team:
		settled.append_array(LoadoutDecision.settle(merc))
	if settled.is_empty():
		return
	contract_run.emit(LoadoutDecision.loadout_rules_line())
	contract_run.emit_all(settled)


static func execute(contract_run: ContractRun) -> void:
	var contract: ContractData = contract_run.contract
	if contract == null:
		return
	var events_run: int = 0
	for index: int in range(contract.rolled_mishaps.size()):
		var step: Dictionary = next_event(contract_run, index)
		var name: String = String(step["name"])
		if bool(step["missing"]):
			emit_missing(contract_run, name, false)
			continue
		if events_run > 0:
			await between_events(contract_run)
			if contract_run.living_team().is_empty():
				return
		if not await run_one_event(contract_run, step["event"] as EventData, name, false):
			if not is_local(contract_run):
				await party_rest(contract_run, RestSystem.KIND_RESPITE, "respite")
			return
		events_run += 1
	var last: Dictionary = next_event(contract_run, contract.rolled_mishaps.size())
	var primary_name: String = String(last["name"])
	if bool(last["missing"]):
		emit_missing(contract_run, primary_name, true)
		return
	if events_run > 0:
		await between_events(contract_run)
		if contract_run.living_team().is_empty():
			return
	await run_one_event(contract_run, last["event"] as EventData, primary_name, true)
	if not is_local(contract_run):
		await party_rest(contract_run, RestSystem.KIND_RESPITE, "respite")


#The event at this place in the chain: the rolled mishaps in order, then the assigned primary.
#A chain a failed event already ended reads as a missing primary, so a stepped run heads home.
static func next_event(contract_run: ContractRun, index: int) -> Dictionary:
	var out: Dictionary = {"event": null, "name": "", "is_primary": false, "missing": true}
	var contract: ContractData = contract_run.contract
	if contract == null:
		return out
	if contract_run.failed_event != "":
		out["name"] = contract_run.failed_event
		out["is_primary"] = true
		return out
	var name: String = ""
	if index < contract.rolled_mishaps.size():
		name = contract.rolled_mishaps[index]
	else:
		out["is_primary"] = true
		name = contract.assigned_primary_event
	out["name"] = name
	var event: EventData = ContractLibrary.event(name) if name != "" else null
	out["event"] = event
	out["missing"] = event == null
	return out


#Reports an event the library lacks; a missing primary also fails the run.
static func emit_missing(contract_run: ContractRun, name: String, is_primary: bool) -> void:
	if contract_run.failed_event != "":
		return
	if is_primary:
		contract_run.failed_event = name if name != "" else "(no primary event)"
		name = contract_run.failed_event
	contract_run.emit("EVENT MISSING: %s" % name)


#A party that arrives too late to finish by the deadline fails the run without starting the work.
static func fail_late(contract_run: ContractRun) -> void:
	contract_run.failed_event = LATE_EVENT
	contract_run.emit("LATE: arrived after the deadline")


#One event and the hour it costs; false once the event left nobody standing or a flagged mishap failed.
static func run_one_event(contract_run: ContractRun, event: EventData, name: String, is_primary: bool) -> bool:
	var outcome: Dictionary = await EventRunner.run(event, contract_run)
	contract_run.outcomes.append(outcome)
	if is_primary and event != null and contract_run.contract != null and contract_run.contract.style == "event" \
			and event.event_name == contract_run.contract.assigned_primary_event \
			and not CheckStore.is_check_name(event.event_name):
		_event_style_primary(contract_run, outcome)
	var minutes: int = int(outcome.get("minutes", 0))
	if not bool(outcome.get("clocked", false)):
		_event_elapsed(contract_run, name, minutes if minutes > 0 else CampaignClock.EVENT_MINUTES)
	var failed: bool = not bool(outcome.get("success", false))
	if is_primary:
		if failed and contract_run.failed_event == "":
			contract_run.failed_event = name
		return not contract_run.living_team().is_empty()
	var wiped: bool = contract_run.living_team().is_empty()
	if failed and not wiped and event != null and event.fail_ends_contract:
		contract_run.failed_event = name
		contract_run.emit("CONTRACT FAILED: %s ended the contract" % name)
		return false
	if failed:
		contract_run.emit("MISHAP FAILED: %s" % name)
	if wiped:
		contract_run.failed_event = name
		contract_run.emit("CONTRACT ABORTED: no mercs left after %s" % name)
		return false
	return true


#Event style primaries take the row's Time and fire the row's Consequence on failure; check rows fire their own.
static func _event_style_primary(contract_run: ContractRun, outcome: Dictionary) -> void:
	var contract: ContractData = contract_run.contract
	if contract.time_minutes > 0 and int(outcome.get("minutes", 0)) <= 0:
		outcome["minutes"] = contract.time_minutes
	var roller: MercenaryData = contract_run.leader()
	if roller == null and not contract_run.living_team().is_empty():
		roller = contract_run.living_team()[0]
	event_consequence(contract_run, outcome, contract.consequence, roller, "CONTRACT CONSEQUENCE:")


#A failed event's consequence cell fired on the roller; the fired lines join outcome consequences and return.
static func event_consequence(contract_run: ContractRun, outcome: Dictionary, cell: String,
		roller: MercenaryData, prefix: String) -> Array[String]:
	var fired: Array[String] = []
	if bool(outcome.get("success", false)) or cell == "":
		return fired
	var values: Dictionary = CheckSheet.parse_consequence(cell)
	if int(values.get("retry", 0)) != 0:
		contract_run.emit("%s retry has no meaning for an event, ignored" % prefix)
	CheckEventResolver.fire_consequences(contract_run, roller, values, prefix, fired)
	var all: Array[String] = []
	all.assign(outcome.get("consequences", []))
	all.append_array(fired)
	outcome["consequences"] = all
	return fired


#One contract event costs an hour of campaign time unless the caller passes its own minutes.
static func _event_elapsed(contract_run: ContractRun, event_name: String,
		minutes: int = CampaignClock.EVENT_MINUTES) -> void:
	CampaignClock.advance(minutes)
	contract_run.emit(CampaignClock.line(event_name, minutes))


#The gap between two events is the rest the party's wounds call for, at the slowest merc's pace; no rest, six flat hours.
static func between_events(contract_run: ContractRun) -> void:
	var gap: Dictionary = gap_minutes(contract_run)
	var kind: String = String(gap["kind"])
	var minutes: int = int(gap["minutes"])
	CampaignClock.advance(minutes)
	contract_run.emit(CampaignClock.line(gap_tag(kind), minutes))
	await settle_gap(contract_run, kind)


#The rest kind the gap calls for and the minutes it costs; a blank kind is the flat six-hour gap.
static func gap_minutes(contract_run: ContractRun) -> Dictionary:
	var party: Array[MercenaryData] = contract_run.living_team()
	var config: ContractConfig = ContractLibrary.config()
	var kind: String = ""
	if not party.is_empty():
		if RestSystem.party_lost_hp(party):
			if config.respite_between_events:
				kind = RestSystem.KIND_RESPITE
		elif config.breather_between_events:
			kind = RestSystem.KIND_BREATHER
	var minutes: int = CampaignClock.EVENT_GAP_MINUTES
	if kind != "":
		minutes = RestSystem.party_rest_minutes(party, _rest_base(kind))
	return {"kind": kind, "minutes": minutes}


static func gap_tag(kind: String) -> String:
	return "between events" if kind == "" else "between events (%s)" % kind


#What lands once the gap's minutes have passed.
static func settle_gap(contract_run: ContractRun, kind: String) -> void:
	if kind == "":
		contract_run.expire_states(contract_run.living_team())
		return
	await settle_rest(contract_run, kind, _rest_base(kind), not is_local(contract_run))


#One party rest: the slowest merc's time passes, due campaign states end, then the rest lands.
static func party_rest(contract_run: ContractRun, kind: String, tag: String, allow_trigger: bool = true) -> void:
	var minutes: int = rest_minutes(contract_run, kind)
	if minutes <= 0:
		return
	CampaignClock.advance(minutes)
	contract_run.emit(CampaignClock.line(tag, minutes))
	await settle_rest(contract_run, kind, _rest_base(kind), allow_trigger)


#Minutes this rest costs the party; 0 when nobody is left to rest.
static func rest_minutes(contract_run: ContractRun, kind: String) -> int:
	var party: Array[MercenaryData] = contract_run.living_team()
	if party.is_empty():
		return 0
	return RestSystem.party_rest_minutes(party, _rest_base(kind))


#What lands once the rest's minutes have passed: the respite trigger, the rest itself and state expiry.
static func settle_rest(contract_run: ContractRun, kind: String, base: int,
		allow_trigger: bool = true) -> void:
	var party: Array[MercenaryData] = contract_run.living_team()
	if party.is_empty():
		return
	if kind == RestSystem.KIND_RESPITE and allow_trigger:
		var triggered: EventData = EventTrigger.pick(kind, contract_run)
		if triggered != null:
			if EventTrigger.last_line != "":
				contract_run.emit(EventTrigger.last_line)
			var outcome: Dictionary = await EventRunner.run(triggered, contract_run)
			contract_run.outcomes.append(outcome)
			contract_run.triggered_events.append(triggered.event_name)
			_event_elapsed(contract_run, triggered.event_name)
			party = contract_run.living_team()
			if party.is_empty():
				contract_run.failed_event = triggered.event_name
				contract_run.emit("CONTRACT ABORTED: no mercs left after %s" % triggered.event_name)
				return
	contract_run.emit(RestSystem.party_line(kind, party, base))
	contract_run.expire_states(party)
	var lines: Array[String] = []
	if kind == RestSystem.KIND_RESPITE:
		lines = RestSystem.respite(party, contract_run)
	else:
		lines = RestSystem.breather_party(party, urgency_for(contract_run), contract_run)
	contract_run.emit_all(lines)


static func _rest_base(kind: String) -> int:
	return RestSystem.RESPITE_MINUTES if kind == RestSystem.KIND_RESPITE else RestSystem.BREATHER_MINUTES


#Zero until a deadline system supplies the pressure the party is under.
static func urgency_for(_run: ContractRun) -> float:
	return 0.0


#One list of every merc the given rosters name, first appearance order, no repeats.
static func _gathered(pools: Array) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for pool: Array in pools:
		for merc: MercenaryData in pool:
			if merc != null and not out.has(merc):
				out.append(merc)
	return out


static func end(contract_run: ContractRun) -> void:
	if not is_local(contract_run):
		CampaignClock.advance(CampaignClock.TRAVEL_MINUTES)
		contract_run.emit(CampaignClock.line("travel back", CampaignClock.TRAVEL_MINUTES))
	arrive_home(contract_run)


#Everything the return settles: boosts off, the verdict, experience, the respite and the log file.
static func arrive_home(contract_run: ContractRun) -> void:
	contract_run.expire_states(contract_run.team)
	contract_run.emit_all(ContractModifiers.revert(contract_run.modifier_record))
	var contract: ContractData = contract_run.contract
	var primary_ok: bool = false
	if contract != null:
		for outcome: Dictionary in contract_run.outcomes:
			if String(outcome.get("event", "")) != contract.assigned_primary_event:
				continue
			if String(outcome.get("event_type", "")) != "Primary":
				continue
			if bool(outcome.get("success", false)):
				primary_ok = true
	contract_run.verdict = BoardEntry.STATUS_SUCCEEDED if primary_ok else BoardEntry.STATUS_FAILED
	contract_run.reward_paid = contract.reward_notes if primary_ok else 0
	if contract != null:
		contract.status = contract_run.verdict
	TraitRuntime.end_contract(contract_run)
	TraitRuntime.revert_contract(contract_run)
	contract_run.emit_all(RelationshipSystem.end_contract(contract_run))
	contract_run.emit_all(LifepathProgression.end_contract(contract_run))
	contract_run.emit_all(ExperienceSystem.award_contract(contract_run))
	for merc: MercenaryData in contract_run.living_team():
		contract_run.emit_all(ExperienceSystem.resolve_level_ups(merc))
	#Excess pools expire once, on the return, before any post-return grant.
	var pools: Array = [contract_run.team, contract_run.casualties, contract_run.defectors,
		contract_run.departed, contract_run.kidnapped, contract_run.rescued]
	for merc: MercenaryData in _gathered(pools):
		contract_run.emit_all(ExcessPool.clear(merc, "contract return"))
	contract_run.emit_all(RestSystem.respite_start(contract_run.living_team(), contract_run))
	for merc: MercenaryData in _gathered(pools):
		merc.on_contract = false
		RestSystem.idle_restart(merc, CampaignClock.now())
	contract_run.emit_all(BeauSystem.tick(CampaignClock.now()))
	ContractLog.verdict(contract_run)
	var path: String = ContractLog.write(contract_run)
	if path != "":
		contract_run.emit("CONTRACT LOG: %s" % path)
