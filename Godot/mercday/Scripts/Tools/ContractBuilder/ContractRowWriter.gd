@tool
class_name ContractRowWriter extends RefCounted

#Writes a ContractDraft as its Contracts.tsv row, then the Types.tsv CONTRACT cell of a new type, the
#Organizations.tsv row of a new organization, the Descriptions.tsv rows, which mirror draft.descriptions, and the
#Checks.tsv rows of pending checks. check() runs first, so a refused draft writes nothing.

const KEY_COLUMN: int = 0
const ORG_ISSUER: String = "org"
const STEP_CONTRACTS: String = "Contracts.tsv row"
const STEP_TYPES: String = "Types.tsv CONTRACT cell"
const STEP_ORGANIZATIONS: String = "Organizations.tsv row"
const STEP_DESCRIPTIONS: String = "Descriptions.tsv rows"
const STEP_CHECK: String = "Checks.tsv row"
const NAME_EMPTY: String = "Contract Name is empty"
const TYPE_EMPTY: String = "Contract Type is empty"
const ISSUER_EMPTY: String = "Issuer is empty"
const CHECK_STYLE: String = "check"
const CHECK_PREFIX: String = "check:"
const COMPLETION_EMPTY: String = "Completion is empty: Style check needs a check"
const CHECK_NAME_EMPTY: String = "Check Name is empty"
const CHECK_COMPLETION_EXPECTED: String = "Completion: expected check:<name> under Style check, got %s"
const EVENT_STYLE: String = "event"
const EVENT_PREFIX: String = "event:"
const EVENT_COMPLETION_EMPTY: String = "Completion is empty: Style event needs an event"
const EVENT_COMPLETION_EXPECTED: String = "Completion: expected event:<name> under Style event, got %s"
const TIME_NEGATIVE: String = "Time must be 0 or more minutes"
const TIMELINE_STYLE: String = "timeline"
const TIMELINE_COMPLETION_EMPTY: String = "Completion is empty: Style timeline needs at least 2 steps"
const TIMELINE_ROLE: String = "Completion: step %s role %s is not a role of this contract"
const TIMELINE_TIME: String = "Time is set but Style is timeline"
const TIMELINE_CONSEQUENCE: String = "Consequence is set but Style is timeline"
const CHECK_BUILT_TWICE: String = "Check %s is built twice"
#Every contract may name these two roles; the others come from draft.roles.
const IMPLIED_ROLES: Array[String] = ["Leader", "Support"]
#The contract .tres takes the name's file stem, and Windows refuses these characters and these device names in it.
const FILE_NAME_FORBIDDEN: String = "\\/:*?<>|"
const RESERVED_STEM: String = "(?i)^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])$"


#"" when the draft can be written, else the first reason. Names, types and issuers are read trimmed, as TsvReader
#reads the cells back.
static func check(draft: ContractDraft) -> String:
	var title: String = draft.contract_name.strip_edges()
	if title == "":
		return NAME_EMPTY
	var length: int = ContractDraft.name_length(title)
	if length > ContractDraft.NAME_MAX:
		return "Contract Name is %d characters; the limit is %d" % [length, ContractDraft.NAME_MAX]
	var file_reason: String = _file_name_reason(title)
	if file_reason != "":
		return file_reason
	if draft.contract_type.strip_edges() == "":
		return TYPE_EMPTY
	if not ContractBuilderData.ISSUER_TYPES.has(draft.issuer_type):
		return "Issuer Type must be %s" % _choices(ContractBuilderData.ISSUER_TYPES)
	if draft.issuer.strip_edges() == "":
		return ISSUER_EMPTY
	if not ContractDataValidator.STYLES.has(draft.style):
		return "Style must be %s" % _choices(ContractDataValidator.STYLES)
	if draft.level_min > draft.level_max:
		return "Level Min %d is above Level Max %d" % [draft.level_min, draft.level_max]
	if draft.difficulty_min > draft.difficulty_max:
		return "Difficulty Min %.1f is above Difficulty Max %.1f" % [draft.difficulty_min, draft.difficulty_max]
	var merc_reason: String = _merc_reason(draft)
	if merc_reason != "":
		return merc_reason
	var other: String = collision(draft)
	if other != "":
		return "Contract Name %s has the same file name as the row %s" % [title, other]
	var header: Array[String] = ContractBuilderData.header()
	if header.is_empty():
		return "cannot read the header of %s" % ContractBuilderData.contracts_path
	var cells: Array[String] = draft.row_cells(header)
	for i: int in range(cells.size()):
		var one: Array[String] = [cells[i]]
		var bad: String = TsvRowWriter.check_cells(one, 1)
		if bad != "":
			return "%s %s" % [header[i], bad.trim_prefix("cell 0 ")]
	for i: int in range(draft.descriptions.size()):
		var text: String = draft.descriptions[i]
		if text.strip_edges() == "":
			continue
		var pair: Array[String] = [title, text]
		var bad: String = TsvRowWriter.check_cells(pair, 2)
		if bad != "":
			return "Description %d %s" % [i + 1, bad.trim_prefix("cell 1 ")]
	var sheet_reason: String = _sheet_reason(ContractBuilderData.descriptions_path,
		ContractBuilderData.DESCRIPTIONS_HEADER)
	if sheet_reason == "" and (pending_check(draft) or not pending_timeline_checks(draft).is_empty()):
		sheet_reason = _sheet_reason(ContractBuilderData.checks_path, CheckSheet.HEADER)
	if sheet_reason != "":
		return sheet_reason
	var rule_reason: String = _check_reason(draft)
	if rule_reason != "":
		return rule_reason
	rule_reason = _event_reason(draft)
	if rule_reason != "" or draft.style != TIMELINE_STYLE:
		return rule_reason
	return _timeline_reason(draft)


#A set Min Mercs or Max Mercs must be 1..MERC_CAP, and min may not pass max when both are set; 0 is blank.
static func _merc_reason(draft: ContractDraft) -> String:
	var cap: int = ContractDataValidator.MERC_CAP
	var ends: Dictionary = {"Min Mercs": draft.merc_min, "Max Mercs": draft.merc_max}
	for column: String in ends:
		var value: int = int(ends[column])
		if value != 0 and (value < 1 or value > cap):
			return "%s must be 1 to %d, got %d" % [column, cap, value]
	var high: int = draft.merc_max if draft.merc_max > 0 else ContractLibrary.config().default_max_mercs
	if draft.merc_min > high:
		return "Min Mercs %d is above Max Mercs %d" % [draft.merc_min, high]
	return ""


#The first row other than the source row whose file stem matches the draft name's, compared without case as
#ContractResourceBuilder.build_all compares them; "" when there is none.
static func collision(draft: ContractDraft) -> String:
	var stem: String = _stem(draft.contract_name)
	var skipped: bool = draft.source_name == ""
	for row: Dictionary in ContractBuilderData.contract_rows():
		if not skipped and String(row.get("Contract Name", "")) == draft.source_name:
			skipped = true
			continue
		var other: String = ContractResourceBuilder.row_name(row)
		if _stem(other) == stem:
			return other
	return ""


#True when Confirm replaces the row named source_name; a source row gone from the sheet makes the write an append.
static func replaces(draft: ContractDraft) -> bool:
	return draft.source_name != "" and TsvRowWriter.find_row(ContractBuilderData.contracts_path, KEY_COLUMN,
		draft.source_name) >= 0


static func adds_type(draft: ContractDraft) -> bool:
	var type_name: String = draft.contract_type.strip_edges()
	return type_name != "" and not ContractBuilderData.type_exists(type_name)


static func adds_org(draft: ContractDraft) -> bool:
	var org: String = draft.issuer.strip_edges()
	return draft.issuer_type == ORG_ISSUER and org != "" and not ContractBuilderData.organization_exists(org)


#True when Confirm appends draft.check_row to Checks.tsv: Style check, a full row and a Completion naming that row.
static func pending_check(draft: ContractDraft) -> bool:
	if draft.style != CHECK_STYLE or draft.check_row.size() != CheckSheet.WIDTH:
		return false
	return draft.completion.strip_edges() == CHECK_PREFIX + draft.check_row[CheckSheet.NAME].strip_edges()


#The draft.timeline_checks rows Confirm appends under Style timeline: per distinct name a check step names, in
#first-step order, the first row of that name (exact compare, names trimmed).
static func pending_timeline_checks(draft: ContractDraft) -> Array:
	var out: Array = []
	if draft.style != TIMELINE_STYLE or draft.timeline_checks.is_empty():
		return out
	for check_name: String in _step_check_names(draft):
		for row: Variant in draft.timeline_checks:
			if _pending_name(row) == check_name:
				out.append(row)
				break
	return out


#{"ok", "error", "name", "replaced", "new_type", "new_org", "line", "descriptions", "descriptions_removed", "check",
#"timeline_checks"}: the flags, the Contracts.tsv line (0-based), the Descriptions.tsv rows written and removed,
#whether the Style check row was appended and the pending timeline check rows appended report what was written. A
#failed step keeps the steps before it and its error names them.
static func write(draft: ContractDraft) -> Dictionary:
	var out: Dictionary = {"ok": false, "error": "", "name": draft.contract_name.strip_edges(), "replaced": false,
		"new_type": false, "new_org": false, "line": -1, "descriptions": 0, "descriptions_removed": 0, "check": false,
		"timeline_checks": 0}
	var reason: String = check(draft)
	if reason != "":
		out["error"] = reason
		return out
	var replacing: bool = replaces(draft)
	var new_type: bool = adds_type(draft)
	var new_org: bool = adds_org(draft)
	var done: Array[String] = []
	var cells: Array[String] = draft.row_cells(ContractBuilderData.header())
	var row: Dictionary = {}
	if replacing:
		row = TsvRowWriter.replace_row(ContractBuilderData.contracts_path, KEY_COLUMN, draft.source_name, cells)
	else:
		row = TsvRowWriter.append_row(ContractBuilderData.contracts_path, cells)
	if not bool(row["ok"]):
		return _failed(out, STEP_CONTRACTS, String(row["error"]), done)
	out["replaced"] = replacing
	out["line"] = int(row["line"])
	done.append(STEP_CONTRACTS)
	if new_type:
		var cell: Dictionary = TsvRowWriter.set_column_cell(ContractBuilderData.types_path,
			ContractBuilderData.TYPES_COLUMN, draft.contract_type)
		if not bool(cell["ok"]):
			return _failed(out, STEP_TYPES, String(cell["error"]), done)
		out["new_type"] = true
		done.append(STEP_TYPES)
	if new_org:
		var org_cells: Array[String] = [draft.issuer.strip_edges()]
		while org_cells.size() < ContractBuilderData.ORGANIZATIONS_WIDTH:
			org_cells.append("")
		var org: Dictionary = TsvRowWriter.append_row(ContractBuilderData.organizations_path, org_cells)
		if not bool(org["ok"]):
			return _failed(out, STEP_ORGANIZATIONS, String(org["error"]), done)
		out["new_org"] = true
		done.append(STEP_ORGANIZATIONS)
	var rows: Array[PackedStringArray] = _description_rows(draft)
	var described: Dictionary = TsvRowWriter.replace_rows(ContractBuilderData.descriptions_path,
		ContractBuilderData.DESCRIPTIONS_KEY_COLUMN, _description_keys(draft), rows)
	if not bool(described["ok"]):
		return _failed(out, STEP_DESCRIPTIONS, String(described["error"]), done)
	out["descriptions"] = rows.size()
	out["descriptions_removed"] = int(described["removed"])
	#replace_rows writes nothing when it has no rows and removes none.
	if rows.size() > 0 or int(described["removed"]) > 0:
		done.append(STEP_DESCRIPTIONS)
	if pending_check(draft):
		var appended: Dictionary = TsvRowWriter.append_row(ContractBuilderData.checks_path, draft.check_row)
		if not bool(appended["ok"]):
			return _failed(out, STEP_CHECK, String(appended["error"]), done)
		out["check"] = true
		done.append(STEP_CHECK)
	var timeline_rows: Array = pending_timeline_checks(draft)
	for pending: Variant in timeline_rows:
		var check_cells: Array[String] = []
		check_cells.assign(pending)
		var added: Dictionary = TsvRowWriter.append_row(ContractBuilderData.checks_path, check_cells)
		if not bool(added["ok"]):
			return _failed(out, STEP_CHECK + " " + _pending_name(pending), String(added["error"]), done)
		out["timeline_checks"] = int(out["timeline_checks"]) + 1
	if not timeline_rows.is_empty():
		done.append(STEP_CHECK)
	out["ok"] = true
	return out


#The Descriptions.tsv keys a write replaces: source_name and the trimmed name, blank entries dropped.
static func _description_keys(draft: ContractDraft) -> Array[String]:
	var out: Array[String] = []
	for key: String in [draft.source_name, draft.contract_name.strip_edges()]:
		if key.strip_edges() != "":
			out.append(key)
	return out


#One [trimmed name, text] row per non-blank description, in draft order.
static func _description_rows(draft: ContractDraft) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var title: String = draft.contract_name.strip_edges()
	for text: String in draft.descriptions:
		if text.strip_edges() != "":
			out.append(PackedStringArray([title, text]))
	return out


#Step 4 (every write) and step 5 (a pending check) place cells by column position, so check() refuses a sheet either
#step cannot write, or one whose trimmed header is not exactly header, before the Contracts.tsv row is written.
static func _sheet_reason(path: String, header: Array[String]) -> String:
	var table: Dictionary = TsvRowWriter.read_table(path)
	if not bool(table["ok"]):
		return "cannot write %s: %s" % [path.get_file(), String(table["error"])]
	var lines: PackedStringArray = table["lines"]
	var titles: Array[String] = []
	for cell: String in lines[0].split(TsvRowWriter.TAB):
		titles.append(cell.strip_edges())
	if titles != header:
		return "cannot write %s: its header must be exactly %s" % [path.get_file(), ", ".join(PackedStringArray(header))]
	return ""


#The check rules after the others: Style check needs a Completion, a check Completion needs Style check, and a
#check row needs CheckSheet.WIDTH writable cells and a name Checks.tsv does not hold yet, compared without letter case.
static func _check_reason(draft: ContractDraft) -> String:
	var completion: String = draft.completion.strip_edges()
	if draft.style == CHECK_STYLE and completion == "":
		return COMPLETION_EMPTY
	#An event: Completion under Style check is left to the event rules.
	if draft.style == CHECK_STYLE and not completion.begins_with(EVENT_PREFIX):
		if not completion.begins_with(CHECK_PREFIX):
			return CHECK_COMPLETION_EXPECTED % completion
		if completion.trim_prefix(CHECK_PREFIX).strip_edges() == "":
			return COMPLETION_EMPTY
	if completion.begins_with(CHECK_PREFIX) and draft.style != CHECK_STYLE:
		return "Completion names a check but Style is %s" % (draft.style if draft.style != "" else "blank")
	if draft.check_row.is_empty():
		return ""
	var bad: String = TsvRowWriter.check_cells(draft.check_row, CheckSheet.WIDTH)
	if bad != "":
		return "Check row: %s" % bad
	var check_name: String = draft.check_row[CheckSheet.NAME].strip_edges()
	if check_name == "":
		return CHECK_NAME_EMPTY
	for known: String in ContractBuilderData.check_names():
		if known.to_lower() == check_name.to_lower():
			return "Check %s already exists in Checks.tsv" % check_name
	return ""


#The event rules after the check rules: Style event needs an event:<name> Completion, an event Completion needs Style
#event, and Event Config must suit the event; an event name Events.tsv does not hold yet passes.
static func _event_reason(draft: ContractDraft) -> String:
	var completion: String = draft.completion.strip_edges()
	var style: String = draft.style if draft.style != "" else "blank"
	if draft.style == EVENT_STYLE:
		if completion != "" and not completion.begins_with(EVENT_PREFIX):
			return EVENT_COMPLETION_EXPECTED % completion
		var event: String = completion.trim_prefix(EVENT_PREFIX).strip_edges()
		if event == "":
			return EVENT_COMPLETION_EMPTY
		var config_reason: String = EventConfig.validate(event, draft.event_config)
		if config_reason != "":
			return "Event Config: %s" % config_reason
	elif completion.begins_with(EVENT_PREFIX):
		return "Completion names an event but Style is %s" % style
	elif draft.event_config.strip_edges() != "":
		return "Event Config is set but Style is %s" % style
	if draft.time < 0:
		return TIME_NEGATIVE
	for token: String in TsvReader.split_field(draft.consequence):
		if not ContractDataValidator.consequence_token_ok(token):
			return "Consequence: bad token %s" % token
	return ""


#The timeline rules after the event rules: a Completion that TimelineGrammar accepts, step roles of this contract,
#blank row Time and Consequence, and pending rows a step names that are writable, new to Checks.tsv and built once.
#Unknown event and check names pass, as under Style event.
static func _timeline_reason(draft: ContractDraft) -> String:
	if draft.completion.strip_edges() == "":
		return TIMELINE_COMPLETION_EMPTY
	var grammar: String = TimelineGrammar.error(draft.completion)
	if grammar != "":
		return "Completion: %s" % grammar
	var allowed: Array[String] = IMPLIED_ROLES.duplicate()
	for role: String in draft.roles:
		if ContractDataValidator.ROLES.has(role) and not allowed.has(role):
			allowed.append(role)
	for item: Variant in TimelineGrammar.parse(draft.completion):
		var step: TimelineGrammar.Step = item
		if step.role != "" and not allowed.has(step.role):
			return TIMELINE_ROLE % [step.id, step.role]
	if draft.time > 0:
		return TIMELINE_TIME
	if draft.consequence.strip_edges() != "":
		return TIMELINE_CONSEQUENCE
	var named: Array[String] = _step_check_names(draft)
	var sheet: Array[String] = []
	for known: String in ContractBuilderData.check_names():
		sheet.append(known.to_lower())
	var built: Array[String] = []
	for row: Variant in draft.timeline_checks:
		var check_name: String = _pending_name(row)
		if not named.has(check_name):
			continue
		var cells: Array[String] = []
		cells.assign(row)
		var bad: String = TsvRowWriter.check_cells(cells, CheckSheet.WIDTH)
		if bad != "":
			return "Check row %s: %s" % [check_name, bad]
		if sheet.has(check_name.to_lower()):
			return "Check %s already exists in Checks.tsv" % check_name
		if built.has(check_name.to_lower()):
			return CHECK_BUILT_TWICE % check_name
		built.append(check_name.to_lower())
	return ""


#The distinct names of the check steps of a parsed Completion, in step order; [] for a cell that does not parse.
static func _step_check_names(draft: ContractDraft) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in TimelineGrammar.parse(draft.completion):
		var step: TimelineGrammar.Step = item
		if step.kind == CHECK_STYLE and step.name != "" and not out.has(step.name):
			out.append(step.name)
	return out


#The trimmed first cell of a pending row; "" for an entry that is not a non-empty Array.
static func _pending_name(row: Variant) -> String:
	if not (row is Array) or (row as Array).is_empty():
		return ""
	return str((row as Array)[CheckSheet.NAME]).strip_edges()


static func _failed(out: Dictionary, step: String, error: String, done: Array[String]) -> Dictionary:
	var text: String = "%s: %s" % [step, error]
	if not done.is_empty():
		text += "; already written, not rolled back: %s" % ", ".join(PackedStringArray(done))
	out["error"] = text
	return out


static func _stem(title: String) -> String:
	return ContractResourceBuilder.file_stem(title.strip_edges()).to_lower()


#Windows reads the part of a file name before its first dot as the device name.
static func _file_name_reason(title: String) -> String:
	for i: int in range(title.length()):
		if FILE_NAME_FORBIDDEN.contains(title[i]):
			return "Contract Name holds %s, which a file name cannot hold" % title[i]
	var stem: String = ContractResourceBuilder.file_stem(title)
	if RegEx.create_from_string(RESERVED_STEM).search(stem.get_slice(".", 0)) != null:
		return "Contract Name %s gives the file name %s, which Windows reserves" % [title, stem]
	return ""


#"a, b or c".
static func _choices(options: Array[String]) -> String:
	if options.size() < 2:
		return ", ".join(PackedStringArray(options))
	return "%s or %s" % [", ".join(PackedStringArray(options.slice(0, options.size() - 1))), options.back()]
