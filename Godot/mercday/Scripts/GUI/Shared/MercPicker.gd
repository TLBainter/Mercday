class_name MercPicker extends ModalDialog

#The merc picker for one slot: a scrolling list of candidates, best fit first. Each row is a portrait,
#the name over an optional level, tradition and placement line, and the fit in stars. Remove shows
#when the slot is filled. Dispatch and the Odd Job crew each open it through an inherited scene.

signal picked(uid: int, slot: int)
signal removed(slot: int)

const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const NAME_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const ROW_HEIGHT: int = 52
const PORTRAIT_SIZE: int = 40
const ROW_PAD_X: float = 6.0
const ROW_PAD_Y: float = 4.0
const DOT_SIZE: Vector2 = Vector2(3, 3)

@export var subtitle: String = "":
	set(value):
		subtitle = value
		if is_node_ready():
			subtitle_label.text = subtitle
@export var star_ramp: StringName = Stars.MATCH
#Adds the level, tradition and "in slot N" line under each name.
@export var show_detail: bool = false
#0 lets the rows decide the scroll height.
@export var list_height: float = 0.0
@export var max_height: float = 520.0

@onready var subtitle_label: Label = $Box/Pad/Rows/Subtitle
@onready var scroll: ScrollContainer = $Box/Pad/Rows/Scroll
@onready var items: VBoxContainer = $Box/Pad/Rows/Scroll/Pad/Items
@onready var empty_label: Label = $Box/Pad/Rows/Empty
@onready var remove_button: BevelButton = $Box/Pad/Rows/Remove

var slot: int = 0
var _rows: Array[Dictionary] = []


func _ready() -> void:
	super()
	remove_button.pressed.connect(press_remove)
	subtitle_label.text = subtitle


#Each row is {"id", "name", "fit"} with an optional "view" MercView and "where" note, already in
#order; fit is the star value. filled shows Remove.
func open_for(new_slot: int, rows_in: Array[Dictionary], filled: bool) -> void:
	slot = new_slot
	_rows = rows_in
	GuiNodes.clear(items)
	for row: Dictionary in _rows:
		items.add_child(_row_for(_view_of(row), float(row.get("fit", 0.5)), str(row.get("where", ""))))
	empty_label.visible = _rows.is_empty()
	scroll.visible = not _rows.is_empty()
	remove_button.visible = filled
	_fit_box()
	present()


func row_count() -> int:
	return _rows.size()


func row_uid(index: int) -> int:
	if index < 0 or index >= _rows.size():
		return 0
	return int(_rows[index].get("id", 0))


func row_name(index: int) -> String:
	if index < 0 or index >= _rows.size():
		return ""
	return str(_rows[index].get("name", ""))


func row_fit(index: int) -> float:
	if index < 0 or index >= _rows.size():
		return 0.0
	return float(_rows[index].get("fit", 0.0))


#The level, tradition and placement line of a row, joined as "LVL 07, Brave, in slot 1".
func row_text(index: int) -> String:
	var line: HBoxContainer = row_line(index)
	if line == null:
		return ""
	var parts: PackedStringArray = []
	for child: Node in line.get_children():
		var label: Label = child as Label
		if label != null and label.visible:
			parts.append(label.text)
	return ", ".join(parts)


func row_button(index: int) -> Button:
	if not is_node_ready() or index < 0 or index >= items.get_child_count():
		return null
	return items.get_child(index) as Button


func row_line(index: int) -> HBoxContainer:
	var row: Button = row_button(index)
	if row == null:
		return null
	return row.get_node_or_null("Row/Text/Line") as HBoxContainer


func row_portrait(index: int) -> MercPortrait:
	var row: Button = row_button(index)
	if row == null:
		return null
	return row.get_node_or_null("Row/Portrait") as MercPortrait


func subtitle_text() -> String:
	return subtitle_label.text


func press_row(uid: int) -> void:
	close()
	picked.emit(uid, slot)


func press_remove() -> void:
	close()
	removed.emit(slot)


#"in slot 2" when the merc stands in another slot, otherwise nothing.
static func where_text(view: MercView, placed: Dictionary, at_slot: int) -> String:
	if view == null:
		return ""
	var where: int = int(placed.get(view.uid, -1))
	if where < 0 or where == at_slot:
		return ""
	return "in slot %d" % (where + 1)


static func holds_slot(placed: Dictionary, at_slot: int) -> bool:
	for uid: int in placed.keys():
		if int(placed[uid]) == at_slot:
			return true
	return false


static func _fmt_fit(v: float) -> String:
	if v == floor(v):
		return str(int(v))
	return str(v)


#The scroll area takes list_height, or the height of its rows when that is 0, capped so the box
#never passes max_height.
func _fit_box() -> void:
	scroll.custom_minimum_size.y = 0.0
	var chrome: float = box.get_combined_minimum_size().y
	var wanted: float = list_height if list_height > 0.0 else items.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(wanted, maxf(max_height - chrome, 0.0))


func _view_of(row: Dictionary) -> MercView:
	var view: MercView = row.get("view") as MercView
	if view != null:
		return view
	view = MercView.new()
	view.uid = int(row.get("id", -1))
	view.name = str(row.get("name", ""))
	return view


func _row_for(view: MercView, fit: float, where: String) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.focus_mode = Control.FOCUS_NONE
	row.tooltip_text = "Match: %s / 5" % _fmt_fit(fit)
	row.add_theme_stylebox_override("normal", GuiStyle.flat(GuiColors.ROW_FILL))
	row.add_theme_stylebox_override("hover", GuiStyle.flat(GuiColors.ROW_HOVER))
	row.add_theme_stylebox_override("pressed", GuiStyle.flat(GuiColors.ROW_HOVER))
	var body := HBoxContainer.new()
	body.name = "Row"
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = ROW_PAD_X
	body.offset_top = ROW_PAD_Y
	body.offset_right = -ROW_PAD_X
	body.offset_bottom = -ROW_PAD_Y
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 8)
	row.add_child(body)
	var portrait: MercPortrait = PORTRAIT_SCENE.instantiate()
	portrait.name = "Portrait"
	body.add_child(portrait)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.pixel_size = PORTRAIT_SIZE
	portrait.set_merc(view)
	var text := VBoxContainer.new()
	text.name = "Text"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 2)
	body.add_child(text)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_override("font", NAME_FONT)
	name_label.add_theme_font_size_override("font_size", 11)
	text.add_child(name_label)
	name_label.text = view.name
	if show_detail:
		text.add_child(_line_for(view, where))
	var stars := Stars.new()
	stars.name = "Stars"
	stars.ramp = star_ramp
	stars.star_px = 1
	stars.snap_half = true
	stars.value_tip = false
	stars.value = fit
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(stars)
	row.pressed.connect(press_row.bind(view.uid))
	return row


func _line_for(view: MercView, where: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 5)
	line.add_child(_piece("Lvl", "LVL %02d" % view.level, GuiColors.CLEAR))
	line.add_child(_dot())
	line.add_child(_piece("Tradition", view.tradition, view.tradition_color()))
	var dot: ColorRect = _dot()
	dot.name = "Dot2"
	dot.visible = where != ""
	line.add_child(dot)
	var tail: Label = _piece("Where", where, GuiColors.CLEAR)
	tail.visible = where != ""
	line.add_child(tail)
	return line


func _piece(node_name: String, text: String, tint: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"ListSecondaryLabel"
	label.text = text
	if tint.a > 0.0:
		label.add_theme_color_override("font_color", tint)
	return label


func _dot() -> ColorRect:
	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.custom_minimum_size = DOT_SIZE
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.color = GuiColors.MUTED
	return dot
