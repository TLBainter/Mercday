class_name NotificationData extends RefCounted

#One row of the notification list: what fired it, how loud it is and whether it has been read.
#The tables are held here as well as on the center so a panel can colour a row without the autoload.

enum Urgency {INFORMATIONAL, IMPORTANT, URGENT}

const URGENCY_NAMES: Array[String] = ["Informational", "Important", "Urgent"]
const URGENCY_COLORS: Array[Color] = [GuiColors.GREEN, GuiColors.AMBER, GuiColors.RED]
#The filter list is "All" plus these, in this order.
const KINDS: Array[String] = ["Contract", "Mercenary", "Finance", "Metrics"]

const TYPE_CONTRACT_COMPLETED := &"contractCompleted"
const TYPE_CONTRACT_FAILED := &"contractFailed"
const TYPE_LOAN_OFFER := &"loanOffer"
const TYPE_STOCK_MOVE := &"stockMove"
const TYPE_NEW_POSTINGS := &"newPostings"
const TYPE_EXPIRY_WARNING := &"expiryWarning"
const TYPE_EXPIRED := &"postingExpired"

#Which filter kind each known type belongs to; an unknown type keeps the kind its caller passed.
const TYPE_KINDS: Dictionary = {
	"contractCompleted": "Contract",
	"contractFailed": "Contract",
	"loanOffer": "Finance",
	"stockMove": "Finance",
	"newPostings": "Contract",
	"expiryWarning": "Contract",
	"postingExpired": "Contract",
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
#True once the row's arrival cue fired, or for a seeded row that arrived silently.
var alerted: bool = false


func urgency_name() -> String:
	return URGENCY_NAMES[clampi(urgency, 0, URGENCY_NAMES.size() - 1)]


func urgency_color() -> Color:
	return URGENCY_COLORS[clampi(urgency, 0, URGENCY_COLORS.size() - 1)]


static func kind_for(row_type: StringName, fallback: String = "") -> String:
	return String(TYPE_KINDS.get(String(row_type), fallback))


#Title colours: contract orange, an expired posting muted, loan budget yellow, stock green on a rise and red on a fall.
const TITLE_CONTRACT: Color = GuiColors.ORANGE
const TITLE_EXPIRED: Color = GuiColors.MUTED
const TITLE_LOAN: Color = GuiColors.AMBER
const TITLE_STOCK_UP: Color = GuiColors.GREEN
const TITLE_STOCK_DOWN: Color = GuiColors.RED
const TITLE_UNKNOWN: Color = GuiColors.CREAM
#One stock band step is five percent.
const BAND_PERCENT: int = 5
#The name line of a new postings row.
const BOARD_NAME: String = "Guild board"


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
		TYPE_NEW_POSTINGS:
			if count() == 1:
				return "1 new contract on the board"
			return "%d new contracts on the board" % count()
		TYPE_EXPIRY_WARNING:
			return "Posting expires soon"
		TYPE_EXPIRED:
			return "Posting expired"
	return String(type)


func title_color() -> Color:
	match type:
		TYPE_CONTRACT_COMPLETED, TYPE_CONTRACT_FAILED, TYPE_NEW_POSTINGS, TYPE_EXPIRY_WARNING:
			return TITLE_CONTRACT
		TYPE_EXPIRED:
			return TITLE_EXPIRED
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


#The postings a new postings row counts; zero for every other type.
func count() -> int:
	return int(snap.get("count", 0))


#The game date and time the row arrived on, from the campaign calendar.
func when_text() -> String:
	return TrynnCalendar.date_text(minute) + " - " + TrynnCalendar.time_text(minute)


#The name line under the title: the contract, the lender, the company or the guild board.
func name_text() -> String:
	if type == TYPE_NEW_POSTINGS:
		return BOARD_NAME
	for key: String in ["name", "lender", "company"]:
		if snap.has(key):
			return String(snap[key])
	return ""
