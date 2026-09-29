class_name NotificationData extends RefCounted

#One row of the notification list: what fired it, how loud it is and whether it has been read.
#The tables are held here as well as on the center so a panel can colour a row without the autoload.

enum Urgency {INFORMATIONAL, IMPORTANT, URGENT}

const URGENCY_NAMES: Array[String] = ["Informational", "Important", "Urgent"]
const URGENCY_COLORS: Array[Color] = [Color("#6cc36a"), Color("#f2b33d"), Color("#e8583f")]
#The filter list is "All" plus these, in this order.
const KINDS: Array[String] = ["Contract", "Mercenary", "Finance", "Metrics"]

const TYPE_CONTRACT_COMPLETED := &"contractCompleted"
const TYPE_CONTRACT_FAILED := &"contractFailed"
const TYPE_LOAN_OFFER := &"loanOffer"
const TYPE_STOCK_MOVE := &"stockMove"

#Which filter kind each known type belongs to; an unknown type keeps the kind its caller passed.
const TYPE_KINDS: Dictionary = {
	"contractCompleted": "Contract",
	"contractFailed": "Contract",
	"loanOffer": "Finance",
	"stockMove": "Finance",
}

var id: int = 0
var kind: String = ""
var type: StringName = &""
var trigger_id: int = 0
var snap: Dictionary = {}
var urgency: int = Urgency.INFORMATIONAL
#The game minute the row was received on.
var minute: int = 0
var read: bool = false


func urgency_name() -> String:
	return URGENCY_NAMES[clampi(urgency, 0, URGENCY_NAMES.size() - 1)]


func urgency_color() -> Color:
	return URGENCY_COLORS[clampi(urgency, 0, URGENCY_COLORS.size() - 1)]


static func kind_for(row_type: StringName, fallback: String = "") -> String:
	return String(TYPE_KINDS.get(String(row_type), fallback))


#Title colours: contract orange, loan budget yellow, stock green on a rise and red on a fall.
const TITLE_CONTRACT: Color = Color("#f28c28")
const TITLE_LOAN: Color = Color("#f2b33d")
const TITLE_STOCK_UP: Color = Color("#6cc36a")
const TITLE_STOCK_DOWN: Color = Color("#e8583f")
const TITLE_UNKNOWN: Color = Color("#f3ead7")
#One stock band step is five percent.
const BAND_PERCENT: int = 5


#The panel title of the row. A failed contract reads the same as a completed one (no spoiler).
func title_text() -> String:
	match type:
		TYPE_CONTRACT_COMPLETED, TYPE_CONTRACT_FAILED:
			return "Contract Complete"
		TYPE_LOAN_OFFER:
			return "Loan Offer Received"
		TYPE_STOCK_MOVE:
			var step: int = absi(band()) * BAND_PERCENT
			if rising():
				return "Stock Up %d%%" % step
			return "Stock Down %d%%" % step
	return String(type)


func title_color() -> Color:
	match type:
		TYPE_CONTRACT_COMPLETED, TYPE_CONTRACT_FAILED:
			return TITLE_CONTRACT
		TYPE_LOAN_OFFER:
			return TITLE_LOAN
		TYPE_STOCK_MOVE:
			if rising():
				return TITLE_STOCK_UP
			return TITLE_STOCK_DOWN
	return TITLE_UNKNOWN


#The signed band of a stock move row; zero for every other type.
func band() -> int:
	return int(snap.get("band", 0))


#The signed move of a stock row as a percent.
func pct() -> float:
	return float(snap.get("pct", 0.0))


#True when a stock move row went up; the percent decides, the band is the fallback.
func rising() -> bool:
	if snap.has("pct"):
		return pct() >= 0.0
	return band() >= 0


#The game date and time the row arrived on, from the campaign calendar.
func when_text() -> String:
	return TrynnCalendar.date_text(minute) + " - " + TrynnCalendar.time_text(minute)


#The name line under the title: the contract, the lender or the company.
func name_text() -> String:
	for key: String in ["name", "lender", "company"]:
		if snap.has(key):
			return String(snap[key])
	return ""


#A whole number with thousands separators, for rewards and offer amounts.
static func grouped(value: int) -> String:
	var neg: String = "-" if value < 0 else ""
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3, 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return neg + digits + out
