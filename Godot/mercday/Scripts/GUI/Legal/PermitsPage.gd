class_name PermitsPage extends LegalListPage

#The Permits tab: the head line and one LocationCard per location on a framed strip that scrolls
#sideways. The strip is the only horizontal list in the window; its bar carries the pixel arrows
#at both ends and the wheel pushes it left and right because it has no vertical scroll to take.

signal request_pressed(loc_id: int)

const CARD_SCENE: PackedScene = preload("res://Scenes/GUI/Legal/LocationCard.tscn")
const HEAD_TEXT: String = "Permits"
const SUB_TEXT: String = "Buy Operation permits to expand your guild into different locations"
const CARD_GAP: int = 14
const PAGE_GAP: int = 8
const SCROLLBAR_GAP: int = 8
const ARROW_SCALE: int = 2
const ARROW_KEYS: Array[StringName] = [&"decrement", &"decrement_highlight",
	&"decrement_pressed", &"increment", &"increment_highlight", &"increment_pressed"]

var sub_label: Label = null

#The card row inside the scroll.
var strip: HBoxContainer:
	get:
		return list as HBoxContainer


func _init() -> void:
	row_scene = CARD_SCENE
	title = HEAD_TEXT


func _ready() -> void:
	add_theme_constant_override(&"separation", PAGE_GAP)
	super()
	LegalManager.permits_changed.connect(refresh)
	LegalManager.fines_changed.connect(refresh)
	LegalManager.captures_changed.connect(refresh)
	SubscriptionManager.changed.connect(refresh)


func card_count() -> int:
	return row_count()


func card(i: int) -> LocationCard:
	return row_at(i) as LocationCard


func card_for(loc_id: int) -> LocationCard:
	for child: Node in rows():
		var found: LocationCard = child as LocationCard
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


func _build() -> void:
	if scroll != null:
		return
	sub_label = GuiStyle.label(SUB_TEXT, GuiStyle.BODY, 14, GuiColors.SKY)
	add_child(_head_block(sub_label))
	add_child(_framed(_row_scroll(true, CARD_GAP, _bar_gap())))
	_style_bar()


#The strip sits in an inset panel so it reads as one container.
func _framed(inner: Control) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.theme_type_variation = &"InsetPanel"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(inner)
	return frame


#The pad under the cards keeps them clear of the scroll bar.
func _bar_gap() -> MarginContainer:
	var pad := MarginContainer.new()
	pad.name = "BarGap"
	pad.add_theme_constant_override(&"margin_bottom", SCROLLBAR_GAP)
	return pad


#The theme already paints the track and the orange thumb; only the end arrows are ours.
func _style_bar() -> void:
	var bar: HScrollBar = scroll.get_h_scroll_bar()
	if bar == null:
		return
	for key: StringName in ARROW_KEYS:
		var right: bool = String(key).begins_with("increment")
		var tint: Color = GuiColors.ORANGE_HI if String(key).ends_with("highlight") \
			else GuiColors.ORANGE
		bar.add_theme_icon_override(key, Icons.tinted("caret_right" if right else "caret_left",
			tint, ARROW_SCALE, true))


func _row_data() -> Array:
	return LegalManager.locations()


func _new_row(made: Control) -> void:
	super(made)
	made.name = "Card%d" % made.get_index()
	(made as LocationCard).request_pressed.connect(_on_request)


func _fill_row(line: Node, data: Variant) -> void:
	(line as LocationCard).location = data as LegalLocationData


func _on_request(loc_id: int) -> void:
	request_pressed.emit(loc_id)
