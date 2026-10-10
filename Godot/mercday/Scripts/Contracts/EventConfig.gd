class_name EventConfig

#The Contracts.tsv Event Config cell grammar, "key=value; key=value": the builder writes it and stage 6 reads it.

const _PAIR_SEP := ";"
const _KEY_SEP := "="
const _JOIN_SEP := "; "
#Plain decimal text: an optional "-", digits, then digits after a point; no "+", exponent or bare point.
const _NUMBER := "^-?[0-9]+([.][0-9]+)?$"
#Float noise only, so "1.000001" stays off a step grid.
const _GRID_TOLERANCE := 1e-9
const KIND_MULTIPLIER := "multiplier"
const KIND_CHOICE := "choice"
#Every field holds all eight keys; a choice leaves min, max and step at 0 and a multiplier leaves options empty.
const FIELDS: Dictionary = {
	"Fight Bandits": [
		{"key": "bandits", "kind": KIND_MULTIPLIER, "label": "Bandit multiplier", "default": "1", "min": 0.5,
			"max": 4.0, "step": 0.5, "options": []},
	],
	"Military Battle": [
		{"key": "soldiers", "kind": KIND_MULTIPLIER, "label": "Soldier multiplier", "default": "1", "min": 0.5,
			"max": 4.0, "step": 0.5, "options": []},
	],
	"Chase": [
		{"key": "chase", "kind": KIND_CHOICE, "label": "Chase mode", "default": "foot", "min": 0.0, "max": 0.0,
			"step": 0.0, "options": ["foot", "vehicle"]},
		{"key": "chasing", "kind": KIND_CHOICE, "label": "Who chases", "default": "mercs", "min": 0.0, "max": 0.0,
			"step": 0.0, "options": ["mercs", "target"]},
	],
	"Prison Break": [],
}
#The four event rows stage 6 added to Events.tsv; the builder fixture sheet still lacks them.
const PLANNED: Array[String] = ["Fight Bandits", "Military Battle", "Prison Break", "Chase"]


#Pairs in cell order with keys lowered; a pair without "=" maps its text to "", and a blank pair or key is skipped.
static func parse(cell: String) -> Dictionary:
	var out: Dictionary = {}
	for pair: String in cell.split(_PAIR_SEP):
		var text: String = pair.strip_edges()
		if text == "" or text.begins_with(_KEY_SEP):
			continue
		var at: int = text.find(_KEY_SEP)
		if at < 0:
			out[text.to_lower()] = ""
		else:
			out[text.substr(0, at).strip_edges().to_lower()] = text.substr(at + 1).strip_edges()
	return out


#"key=value" joined by "; ", the keys of order first and the rest after in Dictionary order; blank values left out.
static func compose(values: Dictionary, order: Array[String]) -> String:
	var picked: Array = []
	for key: String in order:
		if values.has(key) and not picked.has(key):
			picked.append(key)
	for key: Variant in values:
		if not order.has(str(key)):
			picked.append(key)
	var parts: PackedStringArray = []
	for key: Variant in picked:
		var value: String = str(values[key]).strip_edges()
		if value != "":
			parts.append("%s=%s" % [str(key), value])
	return _JOIN_SEP.join(parts)


#Copies of the event's fields in table order; [] for an event FIELDS does not list.
static func fields(event: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for field: Dictionary in FIELDS.get(event, []):
		out.append(field.duplicate(true))
	return out


static func keys(event: String) -> Array[String]:
	var out: Array[String] = []
	for field: Dictionary in FIELDS.get(event, []):
		out.append(String(field["key"]))
	return out


static func defaults(event: String) -> Dictionary:
	var out: Dictionary = {}
	for field: Dictionary in FIELDS.get(event, []):
		out[String(field["key"])] = String(field["default"])
	return out


static func default_cell(event: String) -> String:
	return compose(defaults(event), keys(event))


#"" when cell suits event, else the first reason in cell order; blank pairs are skipped and a missing key reads as its default.
static func validate(event: String, cell: String) -> String:
	var pairs: Array[String] = []
	for pair: String in cell.split(_PAIR_SEP):
		if pair.strip_edges() != "":
			pairs.append(pair.strip_edges())
	if pairs.is_empty():
		return ""
	if not FIELDS.has(event):
		return "%s takes no Event Config" % event
	var table: Array = FIELDS[event]
	var seen: Array[String] = []
	for text: String in pairs:
		var at: int = text.find(_KEY_SEP)
		if at <= 0:
			return "bad pair %s" % text
		if table.is_empty():
			return "%s takes no Event Config" % event
		var key: String = text.substr(0, at).strip_edges().to_lower()
		if seen.has(key):
			return "repeated option %s" % key
		seen.append(key)
		var field: Dictionary = _field(event, key)
		if field.is_empty():
			return "%s has no option %s" % [event, key]
		var reason: String = _value_reason(field, text.substr(at + 1).strip_edges())
		if reason != "":
			return reason
	return ""


#Whole values print without a decimal ("2"), others with one ("1.5").
static func format_number(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	return "%.1f" % v


#The number plain decimal text holds ("2", "1.5", "-1"), else NAN.
static func parse_number(text: String) -> float:
	var t: String = text.strip_edges()
	if RegEx.create_from_string(_NUMBER).search(t) == null:
		return NAN
	var value: float = t.to_float()
	return value if is_finite(value) else NAN


#The cell's valid value for key, set on its step grid, else the field default; NAN when event has no multiplier key.
static func multiplier_value(event: String, key: String, cell: String) -> float:
	var field: Dictionary = _field(event, key.to_lower())
	if field.is_empty() or String(field["kind"]) != KIND_MULTIPLIER:
		return NAN
	var value: float = _grid_value(field, parse_number(String(parse(cell).get(key.to_lower(), ""))))
	return parse_number(String(field["default"])) if is_nan(value) else value


#The first multiplier field's value for the cell (blank or off grid gives the default); NAN when the event has none.
static func counter_factor(event_name: String, cell: String) -> float:
	for field: Dictionary in FIELDS.get(event_name, []):
		if String(field["kind"]) == KIND_MULTIPLIER:
			return multiplier_value(event_name, String(field["key"]), cell)
	return NAN


#The cell's valid option for key, else the field default; "" when event has no choice key.
static func choice_value(event: String, key: String, cell: String) -> String:
	var field: Dictionary = _field(event, key.to_lower())
	if field.is_empty() or String(field["kind"]) != KIND_CHOICE:
		return ""
	var value: String = String(parse(cell).get(key.to_lower(), ""))
	var options: Array = field["options"]
	return value if options.has(value) else String(field["default"])


static func _field(event: String, key: String) -> Dictionary:
	for field: Dictionary in FIELDS.get(event, []):
		if String(field["key"]) == key:
			return field
	return {}


static func _value_reason(field: Dictionary, value: String) -> String:
	var key: String = String(field["key"])
	if String(field["kind"]) == KIND_CHOICE:
		var options: Array = field["options"]
		if options.has(value):
			return ""
		return "%s must be %s" % [key, " or ".join(PackedStringArray(options))]
	if not is_nan(_grid_value(field, parse_number(value))):
		return ""
	return "%s must be %s to %s in steps of %s" % [key, format_number(float(field["min"])),
		format_number(float(field["max"])), format_number(float(field["step"]))]


#value set on the grid of whole steps above min when it lies inside min..max and on that grid, else NAN.
static func _grid_value(field: Dictionary, value: float) -> float:
	var low: float = float(field["min"])
	var step: float = float(field["step"])
	if is_nan(value) or value < low or value > float(field["max"]):
		return NAN
	if step <= 0.0:
		return value
	var on_grid: float = low + roundf((value - low) / step) * step
	return on_grid if absf(value - on_grid) < _GRID_TOLERANCE else NAN
