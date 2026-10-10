class_name CheckSheet

#The Checks.tsv cell grammar: the contract builder writes the rows and the stage 5 check consumer reads them.

const NAME := 0
const ATTRIBUTES := 1
const CIRCUMSTANCES := 2
const KNOWLEDGES := 3
const TOOLS := 4
const TRADITIONS := 5
const MULTIPLIER := 6
const TIME := 7
const OPPOSED := 8
const OPPOSED_CHECK := 9
const CONSEQUENCE := 10
const WIDTH := 11
const HEADER: Array[String] = ["Check Name", "Attributes", "Circumstances", "Knowledges", "Tools", "Traditions",
	"Multiplier", "Time", "Opposed", "Opposed Check", "Consequence"]
const LIST_SEP := ", "
const PERCENT_STOPS: Array[int] = [0, 5, 10, 15]
const TRADITION_MIN := -15
const TRADITION_MAX := 15
const TRADITION_STEP := 5
const SIDE_CAP := 50
const MULTIPLIER_MIN := 0.5
const MULTIPLIER_MAX := 4.0
const MULTIPLIER_STEP := 0.5
const TIME_DEFAULT := 60
const CONSEQUENCE_KINDS: Array[String] = ["retry", "hp", "ep", "mp", "guild"]
const CONSEQUENCE_MIN := -9
const OPPOSED_YES := "Yes"
const OPPOSED_NO := "No"
const NAME_MAX := 40


static func format_names(names: Array[String]) -> String:
	return LIST_SEP.join(PackedStringArray(names))


static func parse_names(cell: String) -> Array[String]:
	return TsvReader.split_field(cell)


#"<name> <percent>" per entry; every entry carries its number, 0 included.
static func format_percents(entries: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for entry: Dictionary in entries:
		parts.append("%s %d" % [String(entry.get("name", "")), int(entry.get("percent", 0))])
	return LIST_SEP.join(parts)


static func parse_percents(cell: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: String in TsvReader.split_field(cell):
		out.append(_entry(entry, "percent"))
	return out


#Nonzero entries only, each with its sign: "Mage -5, Warrior +15".
static func format_signed(entries: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for entry: Dictionary in entries:
		var value: int = int(entry.get("value", 0))
		if value != 0:
			parts.append("%s %+d" % [String(entry.get("name", "")), value])
	return LIST_SEP.join(parts)


static func parse_signed(cell: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: String in TsvReader.split_field(cell):
		out.append(_entry(entry, "value"))
	return out


#"1" for a whole number, else one decimal: "1.5".
static func format_multiplier(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.1f" % value


#A blank or invalid cell reads as 1; any other value is clamped into the slider range.
static func parse_multiplier(cell: String) -> float:
	var text: String = cell.strip_edges()
	if not text.is_valid_float():
		return 1.0
	return clampf(float(text), MULTIPLIER_MIN, MULTIPLIER_MAX)


static func format_time(minutes: int) -> String:
	return str(minutes) if minutes > 0 else ""


static func parse_time(cell: String) -> int:
	var text: String = cell.strip_edges()
	if text.is_valid_int() and int(text) > 0:
		return int(text)
	return 0


static func format_opposed(yes: bool) -> String:
	return OPPOSED_YES if yes else OPPOSED_NO


static func parse_opposed(cell: String) -> bool:
	return cell.strip_edges().to_lower() == OPPOSED_YES.to_lower()


#Nonzero kinds in CONSEQUENCE_KINDS order: "hp -2, guild -1".
static func format_consequence(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	for kind: String in CONSEQUENCE_KINDS:
		var n: int = int(values.get(kind, 0))
		if n != 0:
			parts.append("%s %d" % [kind, n])
	return LIST_SEP.join(parts)


#Every kind at 0, then "<kind> <n>" tokens with n clamped into CONSEQUENCE_MIN..0; a bare kind reads as -1 as the
#validator reads it; unknown kinds are ignored.
static func parse_consequence(cell: String) -> Dictionary:
	var out: Dictionary = {}
	for kind: String in CONSEQUENCE_KINDS:
		out[kind] = 0
	for token: String in TsvReader.split_field(cell):
		var parts: PackedStringArray = token.split(" ", false)
		if parts.size() > 2 or not out.has(parts[0]):
			continue
		if parts.size() == 1:
			out[parts[0]] = -1
		elif parts[1].is_valid_int():
			out[parts[0]] = clampi(int(parts[1]), CONSEQUENCE_MIN, 0)
	return out


static func blank_row() -> Array[String]:
	var out: Array[String] = []
	for _i: int in range(WIDTH):
		out.append("")
	return out


#One "<Header>: <cell>" line per nonblank column after the name.
static func summary(cells: Array[String]) -> String:
	var lines: PackedStringArray = []
	for c: int in range(1, mini(cells.size(), WIDTH)):
		var cell: String = cells[c].strip_edges()
		if cell != "":
			lines.append("%s: %s" % [HEADER[c], cell])
	return "\n".join(lines)


#True when every character is one TsvRowWriter writes into a cell: ASCII 32 to 126 except the double quote.
static func is_ascii(text: String) -> bool:
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		if code < 32 or code > 126 or code == 34:
			return false
	return true


#Splits "<name> <int>" at the last space; without a trailing int the whole text is the name and the number is 0.
static func _entry(text: String, number_key: String) -> Dictionary:
	var cut: int = text.rfind(" ")
	if cut > 0 and text.substr(cut + 1).is_valid_int():
		return {"name": text.left(cut).strip_edges(), number_key: int(text.substr(cut + 1))}
	return {"name": text, number_key: 0}
