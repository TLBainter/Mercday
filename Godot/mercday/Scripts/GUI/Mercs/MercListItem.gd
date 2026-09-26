class_name MercListItem extends Button

#One roster row: the portrait with its status strip, the first name over the tradition and the
#level badge at the right. A busy merc dims and the selected row takes the list fill.

const ROW_HEIGHT: int = 56
const BUTTON_HEIGHT: int = 68
const SELECTED_FILL: Color = Color("#15223d")
const NORMAL_FILL: Color = Color("#0e1628")
const SELECTED_EDGE: Color = Color("#f28c28")
const NORMAL_EDGE: Color = Color("#0a0f1c")
const EDGE_PX: int = 3
const BOX_MARGIN: float = 6.0
const BUSY_MODULATE: Color = Color(0.65, 0.65, 0.65, 1.0)

signal selected(uid: int)

@export var uid: int = 0
@export var merc_name: String = "":
	set(value):
		merc_name = value
		_refresh()
@export var tradition: String = "":
	set(value):
		tradition = value
		_refresh()
@export var level: int = 1:
	set(value):
		level = value
		_refresh()
@export var status: int = GuiTypes.MercStatus.AVAILABLE:
	set(value):
		status = value
		_refresh()
@export var time_left_minutes: int = 0:
	set(value):
		time_left_minutes = value
		_refresh()
@export var is_selected: bool = false:
	set(value):
		is_selected = value
		_refresh()

@onready var portrait_holder: Control = $Row/PortraitHolder
@onready var portrait_frame: Panel = $Row/PortraitHolder/Frame
@onready var portrait: MercPortrait = $Row/PortraitHolder/Portrait
@onready var strip: MercStatusStrip = $Row/PortraitHolder/Strip
@onready var name_label: Label = $Row/Names/MercName
@onready var tradition_label: Label = $Row/Names/Tradition
@onready var badge: LevelBadge = $Row/Badge

var view: MercView = null


func _ready() -> void:
	custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	pressed.connect(_on_pressed)
	_refresh()


func set_view(new_view: MercView) -> void:
	view = new_view
	if view == null:
		return
	uid = view.uid
	merc_name = MercHeader.split_name(view.name)[0]
	tradition = view.tradition
	level = view.level
	status = view.status
	time_left_minutes = int(round(view.status_time_left_hours * 60.0))
	if is_node_ready():
		portrait.set_merc(view)


func _refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = merc_name
	tradition_label.text = tradition
	badge.level = level
	strip.status = status
	strip.time_left_minutes = time_left_minutes
	modulate = Color.WHITE if status == GuiTypes.MercStatus.AVAILABLE else BUSY_MODULATE
	_apply_boxes()


#The row never shows the theme's blue button look: every state carries the row box and the focus
#ring is emptied, so only the selection ring reads.
func _apply_boxes() -> void:
	var box: StyleBoxFlat = selected_box() if is_selected else normal_box()
	add_theme_stylebox_override("normal", box)
	add_theme_stylebox_override("hover", box)
	add_theme_stylebox_override("pressed", box)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func normal_box() -> StyleBoxFlat:
	return _row_box(NORMAL_FILL, NORMAL_EDGE)


static func selected_box() -> StyleBoxFlat:
	return _row_box(SELECTED_FILL, SELECTED_EDGE)


static func _row_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_width_left = EDGE_PX
	box.border_width_top = EDGE_PX
	box.border_width_right = EDGE_PX
	box.border_width_bottom = EDGE_PX
	box.border_color = edge
	box.content_margin_left = BOX_MARGIN
	box.content_margin_right = BOX_MARGIN
	box.content_margin_top = BOX_MARGIN
	box.content_margin_bottom = BOX_MARGIN
	return box


func _on_pressed() -> void:
	selected.emit(uid)
