class_name ContractLog

#Contract-level narration: the header before the events, the verdict block and the log file on disk.

const LOG_DIR := "user://encounter_logs"


static func merc_line(merc: MercenaryData) -> String:
	if merc == null:
		return "?"
	var level: int = int(merc.stats.get("level", 0))
	var tradition: String = merc.tradition.tradition_name if merc.tradition != null else "NPC"
	return "%s L%d %s" % [merc.merc_name, level, tradition]


static func header(run: ContractRun) -> void:
	if run == null or run.contract == null:
		return
	var contract: ContractData = run.contract
	run.emit("====== CONTRACT: %s ======" % contract.contract_type)
	run.emit("CLOCK: %s" % CampaignClock.stamp())
	if run.location == null:
		run.emit("CONTRACT LOCATION: none")
	else:
		var parent_name: String = run.location.parent.location_name if run.location.parent != null else "none"
		var terrain: String = ContractTerrain.area_name_for(run.location)
		run.emit("CONTRACT LOCATION: %s (%s, parent %s) terrain %s" % [
			run.location.location_name, run.location.location_type, parent_name,
			terrain if terrain != "" else "none"])
	run.emit("CONTRACT OPPONENT: %s" % (contract.location_b if contract.location_b != "" else "none"))
	run.emit("CONTRACT DESCRIPTION: %s" % contract.description)
	run.emit("CONTRACT REWARD: %d notes, max mercs %d" % [contract.reward_notes, contract.max_mercs])
	run.emit("CONTRACT TEAM: %d mercs" % run.team.size())
	for merc: MercenaryData in run.team:
		run.emit("TEAM: %s" % merc_line(merc))
	run.emit("CONTRACT MISHAPS: %s" % (", ".join(contract.rolled_mishaps) if not contract.rolled_mishaps.is_empty() else "none"))
	run.emit("CONTRACT PRIMARY: %s" % (contract.assigned_primary_event if contract.assigned_primary_event != "" else "none"))
	for line: String in (run.modifier_record.get("lines", []) as Array):
		run.emit(line)
	for merc: MercenaryData in run.team:
		var entries: Array = run.penalties_by_merc.get(merc, []) as Array
		if entries.is_empty():
			run.emit("CONTRACT PENALTY: %s none" % merc.merc_name)
			continue
		for entry: Dictionary in entries:
			run.emit("CONTRACT PENALTY: %s %s -%.0f%%" % [
				merc.merc_name, String(entry.get("expr", "")), float(entry.get("percent", 0.0))])
	for merc: MercenaryData in run.team:
		run.emit(OverallSuccess.describe(merc, OverallSuccess.for_merc(run.contract, run.team, merc, null)))


static func verdict(run: ContractRun) -> void:
	if run == null or run.contract == null:
		return
	var contract: ContractData = run.contract
	var where: String = contract.location_a if contract.location_a != "" else "none"
	if run.verdict == "Succeeded":
		run.emit("CONTRACT SUCCESS: %s at %s" % [contract.contract_type, where])
	else:
		run.emit("CONTRACT FAILED: %s at %s (failed event: %s)" % [
			contract.contract_type, where, run.failed_event if run.failed_event != "" else "none"])
	for outcome: Dictionary in run.outcomes:
		run.emit("CONTRACT EVENT: %s %s rounds %d casualties %d enemies defeated %d/%d" % [
			String(outcome.get("event", "")),
			"SUCCESS" if bool(outcome.get("success", false)) else "FAILED",
			int(outcome.get("rounds", 0)),
			(outcome.get("casualties", []) as Array).size(),
			int(outcome.get("enemies_defeated", 0)),
			int(outcome.get("enemy_count", 0))])
	var names: Array[String] = run.merc_names(run.casualties)
	run.emit("CONTRACT CASUALTIES: %s" % (", ".join(names) if not names.is_empty() else "none"))
	for merc: MercenaryData in run.living_team():
		if merc.rest_lockout_until <= CampaignClock.now():
			run.emit("CONTRACT LOCKOUT: %s none" % merc.merc_name)
			continue
		run.emit("CONTRACT LOCKOUT: %s %s until %s" % [
			merc.merc_name, merc.rest_lockout_kind, CampaignClock.stamp(merc.rest_lockout_until)])
	run.emit("CONTRACT REWARD PAID: %d notes" % run.reward_paid)
	var log_paths: Array[String] = []
	for entry: String in run.encounter_logs:
		log_paths.append(ProjectSettings.globalize_path(entry))
	run.emit("CONTRACT ENCOUNTER LOGS: %s" % (", ".join(log_paths) if not log_paths.is_empty() else "none"))


static func write(run: ContractRun) -> String:
	if run == null:
		return ""
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(LOG_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	var dt := Time.get_datetime_dict_from_system()
	var session := "%06x" % randi()
	var date_str := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	var time_str := "%02d-%02d-%02d" % [dt["hour"], dt["minute"], dt["second"]]
	var filename := "contract_log_%s_%s_%s.txt" % [session, date_str, time_str]
	var file: FileAccess = FileAccess.open(LOG_DIR + "/" + filename, FileAccess.WRITE)
	if file == null:
		push_warning("ContractLog: could not open %s" % filename)
		return ""
	file.store_string("\n".join(run.log_lines) + "\n")
	file.close()
	return ProjectSettings.globalize_path(LOG_DIR + "/" + filename)
