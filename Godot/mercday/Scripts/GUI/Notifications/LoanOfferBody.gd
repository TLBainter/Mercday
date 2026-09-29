class_name LoanOfferBody extends VBoxContainer

#The body of a loan offer row: the offer amount with a coin note glyph and its terms, then the
#time left to accept. The hours come from the live finance layer, never from the snapshot, so a
#stale row hides its countdown instead of lying about it.

const GLYPH_COLOR: Color = Color("#f3ead7")
const TERMS_COLOR: Color = Color("#9cc6ef")
const URGENT_COLOR: Color = Color("#e8583f")
const HOURS_PER_DAY: int = 24
const MANAGER_PATH: String = "/root/FinanceManager"
const HOURS_METHOD: String = "hours_left"
const OFFER_METHOD: String = "offer"

#A suite or a screen may hand the body its own hours source; the autoload is used when it is unset.
static var hours_override: Callable = Callable()

@export var amount_label_path: NodePath = ^"AmountRow/AmountLabel"
@export var note_glyph_path: NodePath = ^"AmountRow/NoteGlyph"
@export var terms_label_path: NodePath = ^"AmountRow/TermsLabel"
@export var remaining_label_path: NodePath = ^"RemainingLabel"

var _amount: Label = null
var _glyph: TextureRect = null
var _terms: Label = null
var _remaining: Label = null
var _row: NotificationData = null


func _ready() -> void:
	_amount = get_node_or_null(amount_label_path) as Label
	_glyph = get_node_or_null(note_glyph_path) as TextureRect
	_terms = get_node_or_null(terms_label_path) as Label
	_remaining = get_node_or_null(remaining_label_path) as Label
	if _glyph != null:
		_glyph.texture = Icons.tinted("note", GLYPH_COLOR, 1, true)
	_refresh()


func apply(data: NotificationData) -> void:
	_row = data
	_refresh()


func amount_text() -> String:
	if _row == null:
		return ""
	return NotificationData.grouped(int(_row.snap.get("offer_amount", 0)))


#"R% - T months" with the rate as a whole percent; the term falls back to the accepted loan term.
func terms_text() -> String:
	if _row == null:
		return ""
	var rate: int = roundi(float(_row.snap.get("offer_rate", 0.0)) * 100.0)
	var term: int = int(_row.snap.get("offer_term", 0))
	if term <= 0:
		term = int(_row.snap.get("term", 0))
	return "%d%% - %d months" % [rate, term]


#Hours left according to the override, or the live finance layer; 0.0 when neither answers.
func hours_left() -> float:
	if _row == null:
		return 0.0
	if hours_override.is_valid():
		return float(hours_override.call(_row.trigger_id))
	var mgr: Node = get_node_or_null(MANAGER_PATH)
	if mgr == null or not mgr.has_method(HOURS_METHOD):
		return 0.0
	return float(mgr.call(HOURS_METHOD, _row.trigger_id))


#True only while the offer is still live: the override answers above 0.0, or the manager still
#holds the offer row (FinanceManager.offer(id) not empty) and its hours are above 0.0.
func remaining_visible() -> bool:
	if _row == null:
		return false
	if hours_override.is_valid():
		return hours_left() > 0.0
	var mgr: Node = get_node_or_null(MANAGER_PATH)
	if mgr == null or not mgr.has_method(OFFER_METHOD):
		return false
	var row: Dictionary = mgr.call(OFFER_METHOD, _row.trigger_id)
	if row.is_empty():
		return false
	return hours_left() > 0.0


func remaining_text() -> String:
	if not remaining_visible():
		return ""
	var whole: int = roundi(hours_left())
	var days: int = int(whole / float(HOURS_PER_DAY))
	var rest: int = whole % HOURS_PER_DAY
	var day_word: String = "Day" if days == 1 else "Days"
	var hour_word: String = "Hour" if rest == 1 else "Hours"
	return "%d %s, %d %s to accept" % [days, day_word, rest, hour_word]


func remaining_color() -> Color:
	if _row != null and _row.urgency == NotificationData.Urgency.URGENT:
		return URGENT_COLOR
	return TERMS_COLOR


func _refresh() -> void:
	if _amount != null:
		_amount.text = amount_text()
	if _terms != null:
		_terms.text = terms_text()
	if _remaining == null:
		return
	_remaining.visible = remaining_visible()
	_remaining.text = remaining_text()
	_remaining.add_theme_color_override("font_color", remaining_color())
