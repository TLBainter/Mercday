class_name ContractManager

#Runs one contract end to end: boosts on, mishaps, the primary event, verdict and reward.


static func run(contract: ContractData, team: Array[MercenaryData], line_fn: Callable) -> ContractRun:
	var r := ContractRun.new()
	r.contract = contract
	r.team.assign(team)
	r.line_fn = line_fn
	if contract != null and contract.location_a != "":
		r.location = DataManager.locations.get(contract.location_a, null) as LocationData
	start(r)
	await execute(r)
	end(r)
	return r


static func start(run: ContractRun) -> void:
	CampaignClock.advance(CampaignClock.TRAVEL_MINUTES)
	run.emit(CampaignClock.line("travel out", CampaignClock.TRAVEL_MINUTES))
	for merc: MercenaryData in run.team:
		merc.on_contract = true
		for line: String in ConstStates.expire_campaign_states(merc, CampaignClock.now()):
			run.emit(line)
	var contract: ContractData = run.contract
	if contract != null:
		contract.team_uids.clear()
		for merc: MercenaryData in run.team:
			contract.team_uids.append(merc.merc_uid)
		contract.status = "Active"
	run.modifier_record = ContractModifiers.apply(contract, run.team)
	TraitRuntime.begin_contract(run)
	RelationshipSystem.begin_contract(run)
	LifepathTally.begin_contract(run)
	LifepathProgression.begin_contract(run)
	for line: String in BeauSystem.begin_contract(run):
		run.emit(line)
	for merc: MercenaryData in run.team:
		run.penalties_by_merc[merc] = ContractPenalty.matching(contract, merc, run.team.size())
	ContractLog.header(run)


static func execute(run: ContractRun) -> void:
	var contract: ContractData = run.contract
	if contract == null:
		return
	var events_run: int = 0
	for name: String in contract.rolled_mishaps:
		var mishap: EventData = ContractLibrary.event(name)
		if mishap == null:
			run.emit("EVENT MISSING: %s" % name)
			continue
		if events_run > 0:
			_between_events(run)
		var outcome: Dictionary = await EventRunner.run(mishap, run)
		run.outcomes.append(outcome)
		events_run += 1
		_event_elapsed(run, name)
		if not bool(outcome.get("success", false)):
			run.emit("MISHAP FAILED: %s" % name)
		if run.living_team().is_empty():
			run.failed_event = name
			run.emit("CONTRACT ABORTED: no mercs left after %s" % name)
			return
	var primary_name: String = contract.assigned_primary_event
	var primary: EventData = ContractLibrary.event(primary_name) if primary_name != "" else null
	if primary == null:
		run.failed_event = primary_name if primary_name != "" else "(no primary event)"
		run.emit("EVENT MISSING: %s" % run.failed_event)
		return
	if events_run > 0:
		_between_events(run)
	var primary_outcome: Dictionary = await EventRunner.run(primary, run)
	run.outcomes.append(primary_outcome)
	_event_elapsed(run, primary_name)
	if not bool(primary_outcome.get("success", false)):
		run.failed_event = primary_name
	for line: String in RestSystem.respite(run.living_team(), run, false):
		run.emit(line)


#One contract event costs an hour of campaign time.
static func _event_elapsed(run: ContractRun, event_name: String) -> void:
	CampaignClock.advance(CampaignClock.EVENT_MINUTES)
	run.emit(CampaignClock.line(event_name, CampaignClock.EVENT_MINUTES))


#Six hours pass between two events; the party takes the rest its wounds call for.
static func _between_events(run: ContractRun) -> void:
	CampaignClock.advance(CampaignClock.EVENT_GAP_MINUTES)
	run.emit(CampaignClock.line("between events", CampaignClock.EVENT_GAP_MINUTES))
	var party: Array[MercenaryData] = run.living_team()
	if party.is_empty():
		return
	var config: ContractConfig = ContractLibrary.config()
	var lines: Array[String] = []
	if RestSystem.party_lost_hp(party):
		if config.respite_between_events:
			lines = RestSystem.respite(party, run, false)
	elif config.breather_between_events:
		lines = RestSystem.breather_party(party, urgency_for(run), run)
	for line: String in lines:
		run.emit(line)


#Zero until a deadline system supplies the pressure the party is under.
static func urgency_for(_run: ContractRun) -> float:
	return 0.0


static func end(run: ContractRun) -> void:
	CampaignClock.advance(CampaignClock.TRAVEL_MINUTES)
	run.emit(CampaignClock.line("travel back", CampaignClock.TRAVEL_MINUTES))
	for line: String in ContractModifiers.revert(run.modifier_record):
		run.emit(line)
	var contract: ContractData = run.contract
	var primary_ok: bool = false
	if contract != null:
		for outcome: Dictionary in run.outcomes:
			if String(outcome.get("event", "")) != contract.assigned_primary_event:
				continue
			if String(outcome.get("event_type", "")) != "Primary":
				continue
			if bool(outcome.get("success", false)):
				primary_ok = true
	run.verdict = "Succeeded" if primary_ok else "Failed"
	run.reward_paid = contract.reward_notes if primary_ok else 0
	if contract != null:
		contract.status = run.verdict
	TraitRuntime.end_contract(run)
	TraitRuntime.revert_contract(run)
	for line: String in RelationshipSystem.end_contract(run):
		run.emit(line)
	for line: String in LifepathProgression.end_contract(run):
		run.emit(line)
	for line: String in ExperienceSystem.award_contract(run):
		run.emit(line)
	for merc: MercenaryData in run.living_team():
		for line: String in ExperienceSystem.resolve_level_ups(merc):
			run.emit(line)
	#Excess pools expire once, on the return, before any post-return grant.
	for merc: MercenaryData in run.team:
		for line: String in ExcessPool.clear(merc, "contract return"):
			run.emit(line)
	for merc: MercenaryData in run.casualties:
		for line: String in ExcessPool.clear(merc, "contract return"):
			run.emit(line)
	for line: String in RestSystem.respite(run.living_team(), run, true):
		run.emit(line)
	for merc: MercenaryData in run.team:
		merc.on_contract = false
	for line: String in BeauSystem.tick(CampaignClock.now()):
		run.emit(line)
	ContractLog.verdict(run)
	var path: String = ContractLog.write(run)
	if path != "":
		run.emit("CONTRACT LOG: %s" % path)
