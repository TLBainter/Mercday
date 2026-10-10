class_name ContractPenalty

#Parses and evaluates a contract penalty expression such as "tradition = mage" or "2 >= cognition".

const _OPS: PackedStringArray = [">=", "<=", "==", ">", "<", "="]

const _MIRROR: Dictionary = {
	">=": "<=",
	"<=": ">=",
	">": "<",
	"<": ">",
	"=": "=",
	"==": "==",
}


static func parse(expr: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "kind": "", "operand": "", "op": "", "value": 0.0, "error": ""}
	var text: String = expr.strip_edges()
	if text == "":
		out["error"] = "empty expression"
		return out
	var op: String = ""
	var at: int = -1
	for candidate: String in _OPS:
		var idx: int = text.find(candidate)
		if idx >= 0 and (at < 0 or idx < at or (idx == at and candidate.length() > op.length())):
			op = candidate
			at = idx
	if at < 0:
		out["error"] = "no operator in '%s'" % text
		return out
	var left: String = text.substr(0, at).strip_edges()
	var right: String = text.substr(at + op.length()).strip_edges()
	if left == "" or right == "":
		out["error"] = "missing operand in '%s'" % text
		return out
	var left_tradition: bool = left.to_lower() == "tradition"
	if left_tradition or right.to_lower() == "tradition":
		if op != "=" and op != "==":
			out["error"] = "tradition needs = in '%s'" % text
			return out
		out["ok"] = true
		out["kind"] = "tradition"
		out["operand"] = "tradition"
		out["op"] = op
		out["value"] = right.to_lower() if left_tradition else left.to_lower()
		return out
	var operand: String = ""
	var number: String = ""
	if _is_number(left) and not _is_number(right):
		operand = right
		number = left
		op = String(_MIRROR[op])
	elif _is_number(right) and not _is_number(left):
		operand = left
		number = right
	else:
		out["error"] = "expected one number and one operand in '%s'" % text
		return out
	if not _is_identifier(operand):
		out["error"] = "bad operand '%s'" % operand
		return out
	out["ok"] = true
	out["kind"] = "team" if operand.to_lower() == "team.merc_count" else "stat"
	out["operand"] = operand.to_lower()
	out["op"] = op
	out["value"] = float(number)
	return out


static func matches(parsed: Dictionary, merc: MercenaryData, team_size: int) -> bool:
	if not bool(parsed.get("ok", false)):
		return false
	var kind: String = String(parsed.get("kind", ""))
	var op: String = String(parsed.get("op", ""))
	if kind == "tradition":
		return ContractModifiers.tradition_matches(merc, String(parsed.get("value", "")))
	var target: float = float(parsed.get("value", 0.0))
	var actual: float = 0.0
	if kind == "team":
		actual = float(team_size)
	else:
		if merc == null:
			return false
		var key: String = String(parsed.get("operand", ""))
		if merc.stats.has(key):
			actual = float(merc.stats[key])
		elif key == "size" and merc.max_stats.has(key):
			actual = float(merc.max_stats[key])
		else:
			return false
	return _compare(actual, op, target)


static func matching(contract: ContractData, merc: MercenaryData, team_size: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if contract == null:
		return out
	for entry: Dictionary in contract.penalties:
		var parsed: Dictionary = parse(String(entry.get("expr", "")))
		if not bool(parsed["ok"]):
			continue
		if matches(parsed, merc, team_size):
			out.append({"expr": String(entry.get("expr", "")), "percent": float(entry.get("percent", 0.0))})
	return out


static func percent_for(contract: ContractData, merc: MercenaryData, team_size: int) -> float:
	var total: float = 0.0
	for entry: Dictionary in matching(contract, merc, team_size):
		total += float(entry["percent"])
	return total


static func _compare(actual: float, op: String, target: float) -> bool:
	match op:
		">=":
			return actual >= target
		"<=":
			return actual <= target
		">":
			return actual > target
		"<":
			return actual < target
		"=", "==":
			return is_equal_approx(actual, target)
	return false


static func _is_number(text: String) -> bool:
	return text.is_valid_float() or text.is_valid_int()


static func _is_identifier(text: String) -> bool:
	if text == "":
		return false
	for i: int in range(text.length()):
		var c: String = text[i]
		if c == "_" or c == "." or c.is_valid_identifier() or (c >= "0" and c <= "9"):
			continue
		return false
	return true
