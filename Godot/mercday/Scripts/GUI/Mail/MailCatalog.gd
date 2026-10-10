class_name MailCatalog

#The mail registry: the TSVs/Mail.tsv rows, their validation and the delay parse; MailSenders resolves the
#Sender cells. parse_rows replaces the live rows, so a suite can run on fixture rows.

const MAIL_TSV: String = "res://TSVs/Mail.tsv"
const VAC_REQUEST: StringName = &"R1"
const VAC_REMIND: StringName = &"R1M"
const VAC_REJECT: StringName = &"R1X"
const VAC_CANCEL: StringName = &"R1C"
const TEMPLATES: Array[StringName] = [VAC_REQUEST, VAC_REMIND, VAC_REJECT, VAC_CANCEL]
const FOLDERS: Array[StringName] = [&"inbox", &"requests", &"bills", &"news", &"spam"]
const OPTION_COUNT: int = 3

#One line per problem found by the last parse, as pushed.
static var warnings: PackedStringArray = PackedStringArray()
static var _rows: Dictionary = {}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if not _loaded:
		parse_rows(TsvReader.load_header_rows(MAIL_TSV))


#Parses and validates rows of the load_header_rows shape into the live catalog; returns the warnings.
static func parse_rows(rows: Array[Dictionary]) -> PackedStringArray:
	_loaded = true
	_rows.clear()
	warnings.clear()
	for cells: Dictionary in rows:
		var id: StringName = StringName(_cell(cells, "Id"))
		if _rows.has(id):
			_warn(id, "duplicate id")
		elif id != &"":
			_rows[id] = _parse_row(id, cells)
	for id: StringName in _rows:
		_validate(id, _rows[id] as Dictionary)
	for id: StringName in TEMPLATES:
		if not _rows.has(id):
			_warn(id, "vacation template row missing")
	return warnings.duplicate()


#The parsed row of an id; empty when there is none.
static func row(id: StringName) -> Dictionary:
	ensure_loaded()
	return _rows.get(id, {}) as Dictionary


#Each option as {label, next, fx}; fx is a PackedStringArray of tokens.
static func options(id: StringName) -> Array:
	return row(id).get("options", []) as Array


#The ids of every row with a Start Day.
static func start_rows() -> Array[StringName]:
	ensure_loaded()
	var out: Array[StringName] = []
	for id: StringName in _rows:
		if int((_rows[id] as Dictionary)["start_day"]) >= 0:
			out.append(id)
	return out


#"D|H|M" in minutes: blank is 0, anything but three non-negative ints is -1.
static func parse_delay(text: String) -> int:
	if text.strip_edges() == "":
		return 0
	var parts: PackedStringArray = text.strip_edges().split("|")
	var scale: Array[int] = [CampaignClock.MINUTES_PER_DAY, CampaignClock.MINUTES_PER_HOUR, 1]
	if parts.size() != scale.size():
		return -1
	var total: int = 0
	for i: int in range(scale.size()):
		var part: String = parts[i].strip_edges()
		if not part.is_valid_int() or int(part) < 0:
			return -1
		total += int(part) * scale[i]
	return total


static func sender(id: String, merc_uid: int = -1) -> Object:
	return MailSenders.sender(id, merc_uid)


static func _parse_row(id: StringName, cells: Dictionary) -> Dictionary:
	var out: Dictionary = {"id": id, "folder": StringName(_cell(cells, "Folder").to_lower()),
		"sender": _cell(cells, "Sender"), "subject": _cell(cells, "Subject"), "body": _cell(cells, "Body"),
		"start_day": _count(id, cells, "Start Day"), "start_minute": _clock(id, _cell(cells, "Start Time")),
		"read": _cell(cells, "Read").to_upper() == "TRUE", "bill_id": _cell(cells, "Bill Id"),
		"amount": _count(id, cells, "Amount"), "due": _count(id, cells, "Due"), "options": []}
	var low: int = parse_delay(_cell(cells, "Delay Min"))
	var high: int = low if _cell(cells, "Delay Max") == "" else parse_delay(_cell(cells, "Delay Max"))
	if low < 0 or high < low:
		_warn(id, "bad Delay Min or Max, or Max under Min; using Min")
	out["delay_min"] = maxi(low, 0)
	out["delay_max"] = high if high >= low and high >= 0 else maxi(low, 0)
	for i: int in range(1, OPTION_COUNT + 1):
		var fx: PackedStringArray = PackedStringArray()
		for token: String in _cell(cells, "Fx %d" % i).split(";", false):
			fx.append(token.strip_edges())
		if _cell(cells, "Option %d" % i) != "":
			(out["options"] as Array).append({"label": _cell(cells, "Option %d" % i),
				"next": StringName(_cell(cells, "Next %d" % i)), "fx": fx})
	return out


static func _validate(id: StringName, entry: Dictionary) -> void:
	if not FOLDERS.has(entry["folder"]):
		_warn(id, "unknown folder %s" % entry["folder"])
	if not MailSenders.is_known(String(entry["sender"])):
		_warn(id, "unknown sender %s" % entry["sender"])
	var bill_ready: bool = entry["bill_id"] != "" and int(entry["amount"]) >= 0
	for option: Dictionary in entry["options"]:
		if option["next"] != &"" and not _rows.has(option["next"]):
			_warn(id, "Next %s has no row" % option["next"])
		for token: String in option["fx"]:
			var problem: String = MailEffects.problem(token, bill_ready)
			if problem != "":
				_warn(id, "%s: %s" % [token, problem])


static func _cell(cells: Dictionary, key: String) -> String:
	return String(cells.get(key, "")).strip_edges()


#A blank cell is -1; anything but a non-negative int warns and reads -1.
static func _count(id: StringName, cells: Dictionary, key: String) -> int:
	var text: String = _cell(cells, key)
	if text != "" and (not text.is_valid_int() or int(text) < 0):
		_warn(id, "bad %s %s" % [key, text])
	return int(text) if text.is_valid_int() and int(text) >= 0 else -1


#HH:MM as a minute of the day; blank is 0, a bad cell warns and reads 0.
static func _clock(id: StringName, text: String) -> int:
	var parts: PackedStringArray = (text if text != "" else "0:0").split(":")
	var ok: bool = parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int()
	if ok and int(parts[0]) in range(24) and int(parts[1]) in range(60):
		return int(parts[0]) * CampaignClock.MINUTES_PER_HOUR + int(parts[1])
	_warn(id, "bad Start Time %s" % text)
	return 0


static func _warn(id: StringName, problem: String) -> void:
	var line: String = "MailCatalog: %s: %s" % [id, problem]
	warnings.append(line)
	push_warning(line)
