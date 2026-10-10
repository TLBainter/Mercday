class_name TimelineGrammar extends RefCounted

#The Contracts.tsv Completion cell of Style timeline, "<id>=<kind>:<name>[ if <id>.<outcome>][ fail][ role=<Role>]
#[ time=<minutes>][ cons=<list>][ cfg=<pairs>]", steps joined by " ; ": the builder writes it, a later stage runs it.


class Step extends RefCounted:
	var id: String = ""
	var kind: String = ""
	var name: String = ""
	var if_id: String = ""
	var if_outcome: String = ""
	var fail: bool = false
	var role: String = ""
	var time: int = 0
	var cons: String = ""
	#EventConfig "; " form, "" for the event's defaults; a check step keeps its cfg as read so the rule refuses it.
	var cfg: String = ""
	#True for an id the designer typed; derived from the id on parse and never written to the cell.
	var typed: bool = false


const SEP: String = " ; "
const KINDS: Array[String] = ["check", "event"]
const OUTCOMES: Array[String] = ["success", "failure"]
const RESERVED: Array[String] = ["if", "fail", "role", "time", "cons", "cfg", "event", "check", "success", "failure"]
const ID_MAX: int = 12
const AUTO_PATTERN: String = "^[a-z]([1-9][0-9]?)?$"
const MIN_STEPS: int = 2
const MAX_STEPS: int = 12
const TIME_MAX: int = 1438560
const ID_PATTERN: String = "^[A-Za-z][A-Za-z0-9_]{0,11}$"
const _ROLE_PATTERN: String = "^[A-Za-z]+$"
const _TIME_PATTERN: String = "^[1-9][0-9]{0,6}$"
const _CFG_KEY_PATTERN: String = "^[A-Za-z]+$"
const _CFG_VALUE_PATTERN: String = "^[A-Za-z0-9.-]+$"
#A typed id of a letter and digits that are not an automatic id ("a0", "a123") keeps that letter from auto numbering.
const _LETTER_DIGITS_PATTERN: String = "^[a-z][0-9]+$"
const _VALUE_KEYS: Array[String] = ["role=", "time=", "cons=", "cfg="]
const _LETTERS: String = "abcdefghijklmnopqrstuvwxyz"
const ID_FORM_TEXT: String = "use 1 to 12 letters, digits or _, starting with a letter"
const ID_RESERVED_TEXT: String = "%s is a reserved word"
const ID_AUTO_TEXT: String = "%s is an automatic id; leave the field blank for automatic numbering"
const ID_USED_TEXT: String = "%s is used by step %d"


#Array of Step; [] on any syntax error.
static func parse(cell: String) -> Array:
	return _read(cell)["steps"]


#The first syntax reason, "" when the cell parses.
static func syntax_error(cell: String) -> String:
	return String(_read(cell)["error"])


#The first structural reason over parsed steps, "".
static func rule_error(steps: Array) -> String:
	for i: int in range(steps.size()):
		for j: int in range(i):
			if (steps[j] as Step).id == (steps[i] as Step).id:
				return "Step id %s is used twice" % (steps[i] as Step).id
	if steps.size() < MIN_STEPS:
		return "Timeline needs at least %d steps, has %d" % [MIN_STEPS, steps.size()]
	if steps.size() > MAX_STEPS:
		return "Timeline holds %d steps; the most is %d" % [steps.size(), MAX_STEPS]
	for i: int in range(steps.size()):
		var reason: String = _step_rule(steps, i)
		if reason != "":
			return reason
	var last: Step = steps[last_index(steps)]
	if last.if_id != "":
		return "The last step %s must not wait on another step" % last.id
	if not last.fail:
		return "The last step %s must carry fail" % last.id
	return ""


#syntax_error, else rule_error(parse(cell)).
static func error(cell: String) -> String:
	var read: Dictionary = _read(cell)
	if String(read["error"]) != "":
		return String(read["error"])
	return rule_error(read["steps"])


static func format(steps: Array) -> String:
	var parts: PackedStringArray = []
	for item: Variant in steps:
		var step: Step = item
		var text: String = "%s=%s:%s" % [step.id, step.kind, step.name]
		if step.if_id != "":
			text += " if %s.%s" % [step.if_id, step.if_outcome]
		if step.fail:
			text += " fail"
		if step.role != "":
			text += " role=" + step.role
		if step.time > 0:
			text += " time=%d" % step.time
		if step.cons != "":
			text += " cons=" + step.cons
		var cfg: String = step.cfg.replace("; ", ",") if step.kind == "check" else cfg_token(step.cfg, step.name)
		if cfg != "":
			text += " cfg=" + cfg
		parts.append(text)
	return SEP.join(parts)


#Why name cannot be a step name, "" when it can (D140).
static func name_reason(name: String) -> String:
	if name.contains(";"):
		return "holds ;"
	if name.contains("="):
		return "holds ="
	var words: PackedStringArray = name.split(" ", false)
	if words.has("if"):
		return "holds the word if"
	if words.has("fail"):
		return "holds the word fail"
	return ""


#The typed-id check: "" or the form, reserved word or automatic id reason.
static func id_reason(id: String) -> String:
	if not _matches(ID_PATTERN, id):
		return ID_FORM_TEXT
	if RESERVED.has(id):
		return ID_RESERVED_TEXT % id
	if is_auto_id(id):
		return ID_AUTO_TEXT % id
	return ""


static func is_auto_id(id: String) -> bool:
	return _matches(AUTO_PATTERN, id)


#Gives the untyped steps their automatic ids: one letter per step without if or per run of steps with if, digits
#inside a run; letters a typed "<letter><digits>" id holds are skipped. Every if naming a changed id follows it.
static func renumber(steps: Array) -> void:
	var skipped: Array[String] = []
	for item: Variant in steps:
		var step: Step = item
		if step.typed and _matches(_LETTER_DIGITS_PATTERN, step.id):
			skipped.append(step.id.left(1))
	var groups: Array = []
	for i: int in range(steps.size()):
		var branch: bool = (steps[i] as Step).if_id != ""
		if branch and i > 0 and (steps[i - 1] as Step).if_id != "":
			(groups.back() as Array).append(i)
		else:
			groups.append([i])
	var old_ids: Array[String] = []
	for item: Variant in steps:
		old_ids.append((item as Step).id)
	var letter: int = 0
	for group: Array in groups:
		var untyped: Array[int] = []
		for index: int in group:
			if not (steps[index] as Step).typed:
				untyped.append(index)
		if untyped.is_empty():
			continue
		while letter < _LETTERS.length() and skipped.has(_LETTERS[letter]):
			letter += 1
		if letter >= _LETTERS.length():
			break
		var base: String = _LETTERS[letter]
		letter += 1
		if group.size() == 1:
			(steps[untyped[0]] as Step).id = base
			continue
		for n: int in range(untyped.size()):
			(steps[untyped[n]] as Step).id = "%s%d" % [base, n + 1]
	var renamed: Dictionary = {}
	for i: int in range(steps.size()):
		var now: String = (steps[i] as Step).id
		if now != old_ids[i] and not renamed.has(old_ids[i]):
			renamed[old_ids[i]] = now
	_rewrite(steps, renamed)


#Sets the id of step index: blank text returns it to its automatic id, other text must pass id_reason and be free.
#Returns the refusal reason, which changes nothing, or "" after renumbering and rewriting every reference.
static func set_id(steps: Array, index: int, text: String) -> String:
	var step: Step = steps[index]
	var wanted: String = text.strip_edges()
	if wanted == "":
		step.typed = false
		renumber(steps)
		return ""
	var reason: String = id_reason(wanted)
	if reason != "":
		return reason
	for i: int in range(steps.size()):
		if i != index and (steps[i] as Step).id == wanted:
			return ID_USED_TEXT % [wanted, i + 1]
	var renamed: Dictionary = {step.id: wanted}
	step.id = wanted
	step.typed = true
	_rewrite(steps, renamed)
	renumber(steps)
	return ""


static func last_index(steps: Array) -> int:
	return steps.size() - 1


#Whether step index runs, given the outcomes ("success" or "failure") of the steps that ran, keyed by id: not after
#a step carrying fail failed; a step with if only when its awaited step ended with that outcome.
static func runs(steps: Array, index: int, ended: Dictionary) -> bool:
	for i: int in range(index):
		var earlier: Step = steps[i]
		if earlier.fail and String(ended.get(earlier.id, "")) == "failure":
			return false
	var step: Step = steps[index]
	if step.if_id == "":
		return true
	return String(ended.get(step.if_id, "")) == step.if_outcome


#An EventConfig "; " cell as the "," token value; "" when it holds the event's defaults.
static func cfg_token(config_cell: String, event: String) -> String:
	var cell: String = _normalized(EventConfig.parse(config_cell), event)
	if cell == EventConfig.default_cell(event):
		return ""
	return cell.replace("; ", ",")


#A "," token value as the normalized EventConfig "; " cell; "" when it holds the event's defaults.
static func cfg_cell(token_value: String, event: String) -> String:
	var cell: String = _normalized(EventConfig.parse(token_value.replace(",", ";")), event)
	return "" if cell == EventConfig.default_cell(event) else cell


static func _normalized(values: Dictionary, event: String) -> String:
	var merged: Dictionary = EventConfig.defaults(event)
	merged.merge(values, true)
	return EventConfig.compose(merged, EventConfig.keys(event))


static func _rewrite(steps: Array, renamed: Dictionary) -> void:
	if renamed.is_empty():
		return
	for item: Variant in steps:
		var step: Step = item
		if renamed.has(step.if_id):
			step.if_id = String(renamed[step.if_id])


static func _step_rule(steps: Array, index: int) -> String:
	var step: Step = steps[index]
	if step.name == "":
		return "Step %s: pick an event or a check" % step.id
	var reason: String = name_reason(step.name)
	if reason != "":
		return "Step %s: name %s cannot be a step (%s)" % [step.id, step.name, reason]
	var awaited: Step = null
	if step.if_id != "":
		for i: int in range(index):
			if (steps[i] as Step).id == step.if_id:
				awaited = steps[i]
				break
		if awaited == null:
			return "Step %s: if names %s, which is not an earlier step" % [step.id, step.if_id]
	if step.kind == "check":
		if step.time > 0:
			return "Step %s: a check step takes no time (the check row carries it)" % step.id
		if step.cons != "":
			return "Step %s: a check step takes no cons (the check row carries it)" % step.id
		if step.cfg != "":
			return "Step %s: a check step takes no cfg" % step.id
	elif step.cfg != "":
		var config_reason: String = EventConfig.validate(step.name, step.cfg)
		if config_reason != "":
			return "Step %s: Event Config: %s" % [step.id, config_reason]
	if awaited != null and awaited.fail and step.if_outcome == "failure":
		return "Step %s waits on %s.failure, but %s fails the contract" % [step.id, awaited.id, awaited.id]
	return ""


#{"steps": Array of Step, "error": String}; steps is [] when error is set.
static func _read(cell: String) -> Dictionary:
	var out: Dictionary = {"steps": [], "error": ""}
	if cell.strip_edges() == "":
		out["error"] = "Timeline is empty"
		return out
	var steps: Array = []
	var parts: PackedStringArray = cell.split(";")
	for i: int in range(parts.size()):
		var step: Step = Step.new()
		var reason: String = _read_step(parts[i].strip_edges(), i + 1, step)
		if reason != "":
			out["error"] = reason
			return out
		steps.append(step)
	out["steps"] = steps
	return out


static func _read_step(text: String, number: int, step: Step) -> String:
	if text == "":
		return "Step %d is empty" % number
	var eq: int = text.find("=")
	var colon: int = text.find(":", eq + 1) if eq >= 0 else -1
	var shape: String = "Step %d: expected <id>=<kind>:<name>, got %s" % [number, text]
	if eq < 0 or colon < 0:
		return shape
	var id: String = text.left(eq)
	var kind: String = text.substr(eq + 1, colon - eq - 1)
	if id.contains(" ") or kind.contains(" "):
		return shape
	if not _matches(ID_PATTERN, id):
		return "Step %d: bad id %s (1 to 12 letters, digits or _, starting with a letter)" % [number, id]
	if RESERVED.has(id):
		return "Step %d: id %s is a reserved word" % [number, id]
	step.id = id
	step.typed = not is_auto_id(id)
	if not KINDS.has(kind):
		return "Step %s: kind must be check or event, got %s" % [id, kind]
	step.kind = kind
	var rest: String = text.substr(colon + 1)
	var words: Array[String] = []
	var starts: Array[int] = []
	var at: int = 0
	while at < rest.length():
		if rest[at] == " ":
			at += 1
			continue
		var end: int = rest.find(" ", at)
		if end < 0:
			end = rest.length()
		words.append(rest.substr(at, end - at))
		starts.append(at)
		at = end
	var first: int = words.size()
	for k: int in range(words.size()):
		if _is_keyword(words[k]):
			first = k
			break
	step.name = (rest if first == words.size() else rest.left(starts[first])).strip_edges()
	var seen: Array[String] = []
	var w: int = first
	while w < words.size():
		var word: String = words[w]
		if not _is_keyword(word):
			return "Step %s: unknown token %s" % [id, word]
		var key: String = word if word == "if" or word == "fail" else word.left(word.find("="))
		if seen.has(key):
			return "Step %s: repeated token %s" % [id, key]
		seen.append(key)
		var value: String = word.substr(key.length() + 1)
		w += 1
		match key:
			"if":
				if w >= words.size():
					return "Step %s: if must be <id>.success or <id>.failure, got nothing" % id
				var target: String = words[w]
				w += 1
				var pieces: PackedStringArray = target.split(".")
				if pieces.size() != 2 or not _matches(ID_PATTERN, pieces[0]) or not OUTCOMES.has(pieces[1]):
					return "Step %s: if must be <id>.success or <id>.failure, got %s" % [id, target]
				step.if_id = pieces[0]
				step.if_outcome = pieces[1]
			"fail":
				step.fail = true
			"role":
				if not _matches(_ROLE_PATTERN, value):
					return "Step %s: role must be one word of letters, got %s" % [id, value]
				step.role = value
			"time":
				if not _matches(_TIME_PATTERN, value) or int(value) > TIME_MAX:
					return "Step %s: time must be whole minutes from 1 to %d, got %s" % [id, TIME_MAX, value]
				step.time = int(value)
			"cons":
				var cons_words: PackedStringArray = [value]
				while w < words.size() and not _is_keyword(words[w]):
					cons_words.append(words[w])
					w += 1
				var reason: String = _cons_reason(id, " ".join(cons_words).strip_edges())
				if reason != "":
					return reason
				step.cons = CheckSheet.format_consequence(CheckSheet.parse_consequence(" ".join(cons_words)))
			"cfg":
				if not _cfg_ok(value):
					return "Step %s: bad cfg %s" % [id, value]
				step.cfg = value.replace(",", "; ") if kind == "check" else cfg_cell(value, step.name)
	return ""


static func _is_keyword(word: String) -> bool:
	if word == "if" or word == "fail":
		return true
	for key: String in _VALUE_KEYS:
		if word.begins_with(key):
			return true
	return false


static func _cons_reason(id: String, value: String) -> String:
	var kinds: Array[String] = []
	for piece: String in value.split(","):
		var token: String = piece.strip_edges()
		if not _cons_token_ok(token):
			return "Step %s: bad consequence token %s" % [id, token]
		var kind: String = token.split(" ", false)[0]
		if kinds.has(kind):
			return "Step %s: repeated consequence kind %s" % [id, kind]
		kinds.append(kind)
	return ""


#A kind of CheckSheet.CONSEQUENCE_KINDS alone, or a kind and an int from CONSEQUENCE_MIN to -1.
static func _cons_token_ok(token: String) -> bool:
	var parts: PackedStringArray = token.split(" ", false)
	if parts.is_empty() or parts.size() > 2 or not CheckSheet.CONSEQUENCE_KINDS.has(parts[0]):
		return false
	if parts.size() == 1:
		return true
	return parts[1].is_valid_int() and int(parts[1]) >= CheckSheet.CONSEQUENCE_MIN and int(parts[1]) <= -1


#Pairs "key=value" joined by ",", each key once (letter case ignored, as EventConfig.parse lowers keys).
static func _cfg_ok(value: String) -> bool:
	var keys: Array[String] = []
	for pair: String in value.split(","):
		var at: int = pair.find("=")
		if at < 0:
			return false
		var key: String = pair.left(at)
		if not _matches(_CFG_KEY_PATTERN, key) or not _matches(_CFG_VALUE_PATTERN, pair.substr(at + 1)):
			return false
		if keys.has(key.to_lower()):
			return false
		keys.append(key.to_lower())
	return true


static func _matches(pattern: String, text: String) -> bool:
	return RegEx.create_from_string(pattern).search(text) != null
