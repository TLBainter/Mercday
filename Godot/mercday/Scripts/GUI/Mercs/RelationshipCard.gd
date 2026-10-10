class_name RelationshipCard extends PanelContainer

#One coworker card: the portrait beside the first name over the mood word, the mood meter under
#them and the mood coloured bottom edge. The two date lines feed the tooltip and stay hidden.

const KNOWN_TEXT: String = "Known since %s"
const CHANGED_TEXT: String = "Last change %s"
const RELATION_TEXT: String = "Relationship %d / 10"
const PANEL_FILL: Color = GuiColors.ROW_FILL
const EDGE_PX: int = 4
const NO_DAY: int = -1

@export var other_uid: int = 0
@export var merc_name: String = "":
	set(value):
		merc_name = value
		_refresh()
@export var relation: int = MercView.NEUTRAL_RELATION:
	set(value):
		relation = value
		_refresh()
@export var known_since: int = NO_DAY:
	set(value):
		known_since = value
		_refresh()
@export var last_changed: int = NO_DAY:
	set(value):
		last_changed = value
		_refresh()

@onready var portrait: MercPortrait = $Rows/Top/PortraitHolder/Portrait
@onready var name_label: Label = $Rows/Top/Names/MercName
@onready var mood_label: Label = $Rows/Top/Names/MoodWord
@onready var meter: MoodMeter = $Rows/Meter
@onready var known_label: Label = $Rows/KnownSince
@onready var changed_label: Label = $Rows/LastChange


func _ready() -> void:
	_refresh()


func set_card(other: MercView, value: int, known_since_day: int = NO_DAY,
		last_changed_day: int = NO_DAY) -> void:
	if other == null:
		return
	other_uid = other.uid
	merc_name = other.name
	relation = value
	known_since = known_since_day
	last_changed = last_changed_day
	if is_node_ready():
		portrait.set_merc(other)


func mood() -> int:
	return meter.mood if is_node_ready() else MercView.relationship_face(relation)


#The calendar date of a campaign day index; an empty string for a day the card has no value for.
static func day_text(day: int) -> String:
	if day < 0:
		return ""
	return TrynnCalendar.date_text(day * CampaignClock.MINUTES_PER_DAY)


func _refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = MercHeader.split_name(merc_name)[0].to_upper()
	var face: int = MercView.relationship_face(relation)
	mood_label.text = MoodFace.MOOD_NAMES[face].to_upper()
	mood_label.add_theme_color_override("font_color", MoodFace.MOOD_COLORS[face])
	meter.set_from_relationship(relation)
	add_theme_stylebox_override(&"panel", _card_box(MoodFace.MOOD_COLORS[face]))
	known_label.text = KNOWN_TEXT % day_text(known_since) if known_since >= 0 else ""
	changed_label.text = CHANGED_TEXT % day_text(last_changed) if last_changed >= 0 else ""
	tooltip_text = _tip()


func _tip() -> String:
	var parts: Array[String] = []
	if known_label.text != "":
		parts.append(known_label.text)
	if changed_label.text != "":
		parts.append(changed_label.text)
	return ", ".join(parts) if not parts.is_empty() else RELATION_TEXT % relation


static func _card_box(edge: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = GuiStyle.flat(PANEL_FILL, 0, edge, 10.0)
	box.border_width_bottom = EDGE_PX
	return box
