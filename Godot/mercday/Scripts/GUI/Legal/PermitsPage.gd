class_name PermitsPage extends VBoxContainer

#The Permits tab: the head line and one LocationCard per location on a strip that scrolls
#sideways. The strip is the only horizontal list in the window; its bar carries the pixel arrows
#at both ends and the wheel pushes it left and right because it has no vertical scroll to take.

signal request_pressed(loc_id: int)

const CARD_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/LocationCard.tscn")
const HEAD_TEXT: String = "Permits"
const SUB_TEXT: String = "Buy Operation permits to expand your guild into different locations"
const CARD_GAP: int = 14
const ARROW_SCALE: int = 2
const ARROW_KEYS: Array[StringName] = [&"decrement", &"decrement_highlight",
	&"decrement_pressed", &"increment", &"increment_highlight", &"increment_pressed"]

var head_label: Label = null
var sub_label: Label = null
var scroll: ScrollContainer = null
var strip: HBoxContainer = null


func _ready() -> void:
	add_theme_constant_override(&"separation", 12)
	_build()
	_fill()
	LegalManager.permits_changed.connect(_fill)
	LegalManager.fines_changed.connect(_fill)
	LegalManager.captures_changed.connect(_fill)
	SubscriptionManager.changed.connect(_fill)


func card_count() -> int:
	return strip.get_child_count() if strip != null else 0


func card(i: int) -> LocationCard:
	if strip == null or i < 0 or i >= strip.get_child_count():
		return null
	return strip.get_child(i) as LocationCard


func card_for(loc_id: int) -> LocationCard:
	for i: int in range(card_count()):
		var found: LocationCard = card(i)
		if found != null and found.location != null and found.location.id == loc_id:
			return found
	return null


func press_request(loc_id: int) -> void:
	var found: LocationCard = card_for(loc_id)
	if found != null:
		found.press_request()


func scroll_node() -> ScrollContainer:
	return scroll


func sub_text() -> String:
	return sub_label.text if sub_label != null else ""


func head_text() -> String:
	return head_label.text if head_label != null else ""


func _build() -> void:
	if scroll != null:
		return
	var head: VBoxContainer = LegalStyle.vbox(4)
	head.name = "Head"
	head_label = LegalStyle.pixel(HEAD_TEXT, 16, LegalStyle.ORANGE, true)
	sub_label = LegalStyle.text(SUB_TEXT, 14, LegalStyle.SKY)
	head.add_child(head_label)
	head.add_child(sub_label)
	add_child(head)
	scroll = ScrollContainer.new()
	scroll.name = "Strip"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	strip = LegalStyle.hbox(CARD_GAP)
	strip.name = "Cards"
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(strip)
	add_child(scroll)
	_style_bar()


#The theme already paints the track and the orange thumb; only the end arrows are ours.
func _style_bar() -> void:
	var bar: HScrollBar = scroll.get_h_scroll_bar()
	if bar == null:
		return
	for key: StringName in ARROW_KEYS:
		var right: bool = String(key).begins_with("increment")
		var tint: Color = LegalStyle.ORANGE_HI if String(key).ends_with("highlight") \
			else LegalStyle.ORANGE
		bar.add_theme_icon_override(key, Icons.tinted("caret_right" if right else "caret_left",
			tint, ARROW_SCALE, true))


func _fill() -> void:
	if strip == null:
		return
	var places: Array[LegalLocationData] = LegalManager.locations()
	while strip.get_child_count() > places.size():
		var last: Node = strip.get_child(strip.get_child_count() - 1)
		strip.remove_child(last)
		last.queue_free()
	while strip.get_child_count() < places.size():
		var made: LocationCard = CARD_SCENE.instantiate() as LocationCard
		made.name = "Card%d" % strip.get_child_count()
		made.size_flags_vertical = Control.SIZE_EXPAND_FILL
		made.request_pressed.connect(_on_request)
		strip.add_child(made)
	for i: int in range(places.size()):
		var row: LocationCard = strip.get_child(i) as LocationCard
		if row != null:
			row.location = places[i]


func _on_request(loc_id: int) -> void:
	request_pressed.emit(loc_id)
