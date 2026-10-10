class_name HintBook

#The MercDave hint registry: the TSVs/Mercdave.tsv rows, the Resources/Mercdave/Hints/<id>.tres of each
#help row, their validation, the text lookups and the trigger wiring. Every row but sys_* is a help row,
#and help row order is marker priority.

const TSV_PATH: String = "res://TSVs/Mercdave.tsv"
const HINT_DIR: String = "res://Resources/Mercdave/Hints/"
const SYS_PREFIX: String = "sys_"
const SYS_NONE: StringName = &"sys_none"

#One line per problem found by the last load, as pushed.
static var warnings: PackedStringArray = PackedStringArray()
static var _rows: Dictionary = {}
static var _order: Array[StringName] = []
static var _hints: Dictionary = {}
static var _loaded: bool = false


#Loads the TSV and the hint files once; Mercdave calls it at boot.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_rows.clear()
	_order.clear()
	_hints.clear()
	warnings.clear()
	for entry: Dictionary in TsvReader.load_header_rows(TSV_PATH):
		var id: StringName = StringName(String(entry.get("id", "")).strip_edges())
		_rows[id] = entry
		if not String(id).begins_with(SYS_PREFIX):
			_order.append(id)
			_hints[id] = _load_hint(id)
	for id: StringName in _order:
		for problem: String in problems(_hints[id] as MercdaveHint, _rows[id] as Dictionary):
			var line: String = "HintBook: %s: %s" % [id, problem]
			warnings.append(line)
			push_warning(line)
	_wire_triggers()


#The help ids in priority order.
static func ids() -> Array[StringName]:
	ensure_loaded()
	return _order.duplicate()


#The priority index of a help id; -1 when the TSV has no such help row.
static func priority(id: StringName) -> int:
	ensure_loaded()
	return _order.find(id)


static func hint(id: StringName) -> MercdaveHint:
	ensure_loaded()
	return _hints.get(id, null) as MercdaveHint


#The TSV row of an id (help or sys_); empty when there is none.
static func row(id: StringName) -> Dictionary:
	ensure_loaded()
	return _rows.get(id, {}) as Dictionary


static func label(id: StringName) -> String:
	return String(row(id).get("label", ""))


static func text(id: StringName) -> String:
	return String(row(id).get("text", ""))


static func more(id: StringName) -> String:
	return String(row(id).get("more", ""))


#True when the card offers Tell Me More for this id.
static func has_more(id: StringName) -> bool:
	return more(id).strip_edges() != ""


#A help id whose row and hint pass validation.
static func is_valid(id: StringName) -> bool:
	return priority(id) >= 0 and problems(hint(id), row(id)).is_empty()


#Every reason a hint cannot show. Empty `more` and an unset more_face are not problems.
static func problems(p_hint: MercdaveHint, p_row: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if p_hint == null:
		out.append("no hint .tres")
	elif p_hint.trigger == null:
		out.append("no trigger")
	else:
		out.append_array(p_hint.trigger.problems())
	if p_hint != null and p_hint.face == MercdaveHint.FACE_UNSET:
		out.append("no face")
	if String(p_row.get("label", "")).strip_edges() == "":
		out.append("empty label")
	if String(p_row.get("text", "")).strip_edges() == "":
		out.append("empty text")
	return out


static func _load_hint(id: StringName) -> MercdaveHint:
	var path: String = HINT_DIR + String(id) + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MercdaveHint


#Each valid hint's trigger asks Mercdave for a rescan whenever its answer can change.
static func _wire_triggers() -> void:
	for id: StringName in _order:
		if is_valid(id):
			hint(id).trigger.watch(Mercdave.request_scan)
