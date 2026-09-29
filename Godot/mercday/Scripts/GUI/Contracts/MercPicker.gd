class_name MercPicker extends Control

#The Dispatch Window slot picker: every merc who could stand in this slot, best match first. It
#stands over the window on a dimmed backdrop; a merc already standing in another slot says which
#one, and Remove empties a slot that is filled. The backdrop, the X and Esc all close it.

signal picked(uid: int, slot: int)
signal removed(slot: int)

const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const STARS_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/DifficultyStars.tscn")
const NAME_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const SUBTITLE: String = "Sorted by best match for this role"
const ROW_HEIGHT: int = 52
const BOX_WIDTH: int = 380
const BOX_HEIGHT: int = 520
const PORTRAIT_SIZE: int = 40
const ROW_PAD_X: float = 6.0
const ROW_PAD_Y: float = 4.0
const WELL_COLOR: Color = Color("#0e1628")
const WELL_HOVER: Color = Color("#15223d")
const DOT_COLOR: Color = Color("#5e7699")
const DOT_SIZE: Vector2 = Vector2(3, 3)

@onready var backdrop: ColorRect = $Backdrop
@onready var _centre: CenterContainer = $Center
@onready var box: PanelContainer = $Center/Box
@onready var title_label: Label = $Center/Box/Rows/Head/Title
@onready var close_button: Button = $Center/Box/Rows/Head/Close
@onready var subtitle_label: Label = $Center/Box/Rows/Subtitle
@onready var scroll: ScrollContainer = $Center/Box/Rows/Scroll
@onready var items: VBoxContainer = $Center/Box/Rows/Scroll/Pad/Items
@onready var remove_button: BevelButton = $Center/Box/Rows/Remove

var slot: int = 0
var rows: Array[MercView] = []


func _ready() -> void:
	remove_button.pressed.connect(press_remove)
	close_button.pressed.connect(hide)
	backdrop.gui_input.connect(_on_backdrop_input)
	visibility_changed.connect(_on_visibility_changed)
	ModalFrame.fit(self, backdrop, _centre)
	hide()


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


#The picker is a frame of the stack, so it draws above the window under it and Esc closes it
#alone; every path that shows or hides it passes through here.
func _on_visibility_changed() -> void:
	if visible:
		ModalFrame.fit(self, backdrop, _centre)
		GuiFrameStack.push(self)
	else:
		GuiFrameStack.remove(self)


#Opens the picker over the window; scores is uid to fit, placed is uid to the slot holding that
#merc. The overlay is centred, so the clicked slot no longer steers where the box lands.
func open_for(new_slot: int, role: String, candidates: Array[MercView], scores: Dictionary,
		placed: Dictionary, _anchor: Rect2i = Rect2i()) -> void:
	slot = new_slot
	fill(new_slot, role, candidates, scores, placed)
	show()


#The same work without showing the overlay, so the rows can be read without a display.
func fill(new_slot: int, role: String, candidates: Array[MercView], scores: Dictionary,
		placed: Dictionary) -> void:
	slot = new_slot
	rows = sorted(candidates, scores)
	if not is_node_ready():
		return
	title_label.text = "Select Leader" if new_slot == 0 else "Select %s" % role
	subtitle_label.text = SUBTITLE
	for child: Node in items.get_children():
		items.remove_child(child)
		child.queue_free()
	for view: MercView in rows:
		items.add_child(_row_for(view, scores, placed))
	remove_button.visible = holds_slot(placed, new_slot)
	_fit_box()


func row_count() -> int:
	return rows.size()


func row_uid(index: int) -> int:
	if index < 0 or index >= rows.size():
		return 0
	return rows[index].uid


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


func pick(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	picked.emit(rows[index].uid, slot)
	hide()


func press_remove() -> void:
	removed.emit(slot)
	hide()


#The candidates in fit order, the best first; equal fits fall back to the name.
static func sorted(candidates: Array[MercView], scores: Dictionary) -> Array[MercView]:
	var out: Array[MercView] = []
	out.assign(candidates)
	out.sort_custom(func(a: MercView, b: MercView) -> bool:
		var one: float = float(scores.get(a.uid, 0.0))
		var two: float = float(scores.get(b.uid, 0.0))
		if one != two:
			return two < one
		return a.name < b.name)
	return out


#The name, plus where the merc already stands when that is not this slot.
static func row_name(view: MercView, placed: Dictionary, at_slot: int) -> String:
	if view == null:
		return ""
	var where: String = where_text(view, placed, at_slot)
	if where == "":
		return view.name
	return "%s, %s" % [view.name, where]


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


#The scroll area takes the height of its rows, capped so the box never passes BOX_HEIGHT.
func _fit_box() -> void:
	scroll.custom_minimum_size.y = 0.0
	var chrome: float = box.get_combined_minimum_size().y
	var wanted: float = items.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(wanted, maxf(float(BOX_HEIGHT) - chrome, 0.0))


func _row_for(view: MercView, scores: Dictionary, placed: Dictionary) -> Button:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.focus_mode = Control.FOCUS_NONE
	row.add_theme_stylebox_override("normal", _well(WELL_COLOR))
	row.add_theme_stylebox_override("hover", _well(WELL_HOVER))
	row.add_theme_stylebox_override("pressed", _well(WELL_HOVER))
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
	name_label.add_theme_font_override("font", NAME_FONT)
	name_label.add_theme_font_size_override("font_size", 11)
	text.add_child(name_label)
	name_label.text = view.name
	text.add_child(_line_for(view, placed))
	var stars: DifficultyStars = STARS_SCENE.instantiate()
	stars.name = "Stars"
	body.add_child(stars)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.star_size = 1
	stars.ramp = DifficultyStars.Ramp.MATCH
	stars.rating = DispatchLogic.to_stars(float(scores.get(view.uid, 0.0)))
	var uid: int = view.uid
	row.pressed.connect(func() -> void: _on_row_pressed(uid))
	return row


func _line_for(view: MercView, placed: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 5)
	line.add_child(_piece("Lvl", "LVL %02d" % view.level, Color(0, 0, 0, 0)))
	line.add_child(_dot())
	line.add_child(_piece("Tradition", view.tradition, view.tradition_color()))
	var where: String = where_text(view, placed, slot)
	var dot: ColorRect = _dot()
	dot.name = "Dot2"
	dot.visible = where != ""
	line.add_child(dot)
	var tail: Label = _piece("Where", where, Color(0, 0, 0, 0))
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
	dot.color = DOT_COLOR
	return dot


func _well(fill_value: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_value
	return style


func _on_row_pressed(uid: int) -> void:
	picked.emit(uid, slot)
	hide()


func _on_backdrop_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if GuiFrameStack.consume_escape(self, event):
		hide()
