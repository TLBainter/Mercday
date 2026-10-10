class_name TimelineRunner
extends RefCounted

#Runs a timeline style contract's Completion cell as its one primary event: steps in cell order, if branches, fail
#endings, and each step's own time, consequence, Event Config and role.

const PRIMARY_PREFIX: String = "timeline:"
const STEP_PREFIX: String = "STEP CONSEQUENCE:"

#Test hook only: step id to a forced success; a held step is not executed.
static var forced_results: Dictionary = {}


#A fresh Primary EventData standing in for a timeline contract's primary; never null.
static func stand_in(name: String) -> EventData:
	var event := EventData.new()
	event.event_name = name
	event.event_type = "Primary"
	event.success_formula = "Timeline"
	event.fail_ends_contract = false
	return event


#The summary outcome: success when the last step succeeded; a failed fail step or a wipe ends the walk.
static func run(contract_run: ContractRun, event: EventData) -> Dictionary:
	var out: Dictionary = EventRunner.outcome(event)
	var fired: Array[String] = []
	out["event_type"] = "Primary"
	out["success"] = false
	out["minutes"] = 0
	out["clocked"] = true
	out["steps"] = 0
	out["failed_step"] = ""
	out["consequences"] = fired
	var contract: ContractData = contract_run.contract
	var broken: String = "no contract" if contract == null else TimelineGrammar.error(contract.completion)
	if broken != "":
		contract_run.emit("TIMELINE BROKEN: %s" % broken)
		contract_run.failed_event = "timeline"
		return out
	var steps: Array = TimelineGrammar.parse(contract.completion)
	var ended: Dictionary = {}
	var ran: int = 0
	for index: int in range(steps.size()):
		var step: TimelineGrammar.Step = steps[index]
		var label: String = "%s %s" % [step.id, step.name]
		if not TimelineGrammar.runs(steps, index, ended):
			contract_run.emit("TIMELINE SKIP: %s" % label)
			continue
		var step_out: Dictionary = await _run_step(contract_run, step, label)
		ran += 1
		var ok: bool = bool(step_out.get("success", false))
		ended[step.id] = "success" if ok else "failure"
		for line: Variant in step_out.get("consequences", []):
			fired.append(String(line))
		if step.fail and not ok:
			out["failed_step"] = label
			contract_run.failed_event = label
		if contract_run.living_team().is_empty():
			out["failed_step"] = label
			contract_run.failed_event = label
			break
	var last: TimelineGrammar.Step = steps[TimelineGrammar.last_index(steps)]
	var success: bool = String(ended.get(last.id, "")) == "success"
	out["success"] = success
	out["steps"] = ran
	contract_run.emit("TIMELINE RESULT: %s, %d of %d steps ran" % ["SUCCESS" if success else "FAILED", ran, steps.size()])
	return out


#One step forced, missing or resolved, then its consequence, minutes, outcome entry and clock.
static func _run_step(contract_run: ContractRun, step: TimelineGrammar.Step, label: String) -> Dictionary:
	var lib: String = CheckStore.PREFIX + step.name if step.kind == "check" else step.name
	if step.kind == "event":
		contract_run.step_config = step.cfg
	var step_out: Dictionary = {}
	if forced_results.has(step.id):
		step_out = {"event": lib, "event_type": "Primary", "success": bool(forced_results[step.id]),
			"minutes": step.time}
	else:
		var event: EventData = ContractLibrary.event(lib) \
			if step.kind == "check" or ContractLibrary.has_event(step.name) else null
		if event == null:
			contract_run.emit("EVENT MISSING: %s" % lib)
			step_out = {"event": lib, "event_type": "Primary", "success": false, "minutes": 0}
		else:
			step_out = await EventRunner.run(event, contract_run, {"role": step.role})
	contract_run.step_config = ""
	if step.kind == "event":
		ContractManager.event_consequence(contract_run, step_out, step.cons, _cons_roller(contract_run, step.role),
			STEP_PREFIX)
	var minutes: int = step.time if step.time > 0 else int(step_out.get("minutes", 0))
	if minutes <= 0:
		minutes = CampaignClock.EVENT_MINUTES
	step_out["minutes"] = minutes
	step_out["step"] = step.id
	contract_run.outcomes.append(step_out)
	contract_run.emit("TIMELINE STEP %s: %s (%d min)" % [label,
		"success" if bool(step_out.get("success", false)) else "failure", minutes])
	ContractManager._event_elapsed(contract_run, label, minutes)
	return step_out


#A step consequence's drain target: the first role holder, else the leader, else the first living merc, else null.
static func _cons_roller(contract_run: ContractRun, role: String) -> MercenaryData:
	if role != "":
		var held: Array[MercenaryData] = contract_run.holders(role)
		if not held.is_empty():
			return held[0]
	var head: MercenaryData = contract_run.leader()
	if head != null:
		return head
	var living: Array[MercenaryData] = contract_run.living_team()
	return living[0] if not living.is_empty() else null
