class_name FormulaEventResolver

#Stub resolver for non-battle events: target and location terms read as zero until those systems exist.


static var _team_rx: RegEx = null
static var _other_rx: RegEx = null


static func _ensure_rx() -> void:
	if _team_rx != null:
		return
	_team_rx = RegEx.new()
	_team_rx.compile(r"team\.([a-z_]+)")
	_other_rx = RegEx.new()
	_other_rx.compile(r"(target|location)\.([a-z_]+)")


#Every team.<stat> the formula names, in order of appearance; these are the event's check kinds.
static func check_kinds(formula: String) -> Array[String]:
	var out: Array[String] = []
	if formula.strip_edges() == "":
		return out
	_ensure_rx()
	for m: RegExMatch in _team_rx.search_all(formula):
		var kind: String = m.get_string(1)
		if not out.has(kind):
			out.append(kind)
	return out


static func evaluate(formula: String, merc: MercenaryData) -> float:
	if formula.strip_edges() == "":
		return 0.0
	_ensure_rx()
	var team_value := func(m: RegExMatch) -> String:
		var value: float = float(merc.stats.get(m.get_string(1), 0.0)) if merc != null else 0.0
		return "%.4f" % value
	var zero_value := func(_m: RegExMatch) -> String:
		return "0.0"
	var processed: String = _substitute(formula, _team_rx, team_value)
	processed = _substitute(processed, _other_rx, zero_value)
	var result: Variant = ContractLibrary.eval_expression(processed,
		"FormulaEventResolver: bad formula '%s'" % formula)
	if result == null:
		return 0.0
	return float(result)


#Replaces every match of rx in text, last match first, with what text_for returns for it.
static func _substitute(text: String, rx: RegEx, text_for: Callable) -> String:
	var out: String = text
	var matches: Array[RegExMatch] = rx.search_all(out)
	for i: int in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		out = out.substr(0, m.get_start()) + str(text_for.call(m)) + out.substr(m.get_end())
	return out


static func resolve(event: EventData, run: ContractRun) -> Dictionary:
	if event == null or run == null:
		return EventRunner.outcome(event)
	var out: Dictionary = EventRunner.outcome(event)
	var living: Array[MercenaryData] = run.living_team()
	run.emit("FORMULA STUB: target.<stat> and location.difficulty read as 0")
	var notes: Array[String] = ["formula stub"]
	out["notes"] = notes
	var parts: Array[String] = []
	var total: float = 0.0
	var leader: MercenaryData = run.leader()
	for merc: MercenaryData in living:
		var value: float = float(OverallSuccess.for_merc(run.contract, living, merc, event, leader)["value"]) \
			+ evaluate(event.success_formula, merc)
		total += value
		parts.append("%s %.1f" % [merc.merc_name, value])
	var target: float = total / float(living.size()) if not living.is_empty() else 0.0
	if not parts.is_empty():
		run.emit("EVENT VALUES: %s" % ", ".join(parts))
	var roll: int = randi_range(1, 100)
	var success: bool = float(roll) <= target
	out["success"] = success
	run.emit("GROUP CHECK: %s target %.1f roll %d -> %s" % [event.event_name, target, roll, "success" if success else "failure"])
	var kinds: Array[String] = check_kinds(event.success_formula)
	if not kinds.is_empty():
		for merc: MercenaryData in living:
			for kind: String in kinds:
				LifepathTally.record_check(merc, kind, 1 if success else 0, success, kind == kinds[0])
		run.emit("CONTRACT CHECK: %s recorded %s as %s for %d mercs"
			% [event.event_name, ", ".join(kinds), "success" if success else "failure", living.size()])
	return out
