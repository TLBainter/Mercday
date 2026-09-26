class_name ConfirmDialog extends Control

#Modal yes/no, multi choice or recap popup: a titled message over a dimmed backdrop.
#ask(), ask_buttons() and ask_recap() are the entry points; each rebuilds the rows and shows it.
#The severity drives the box border and title colour. The backdrop click is inert by design.

signal confirmed
signal cancelled
signal chosen(index: int)

enum Severity {ORANGE, RED, GREEN, INFO}
enum Kind {GO, BAD, WARN, NEUTRAL}

const BUTTON_SIZE := Vector2(96.0, 32.0)
const BOX_WIDTH := 460.0
const DARK_INK := Color("#0a0f1c")
const KIND_FILL: Array[Color] = [Color("#6cc36a"), Color("#e8583f"), Color("#2b4f8a"),
	Color("#2b4f8a")]
const BUTTON_EDGE := 3
const BUTTON_PAD_X := 8.0
const BUTTON_PAD_Y := 6.0
const BOX_INSET := 4.0
const BOX_BORDER := 4
const BOX_BG := Color("#1a2b4d")
const EDGE_HI := Color("#28447a")
const EDGE_LO := Color("#111c33")
const EDGE_PX := 4.0
const BLOCK_GAP := 6
const ROW_GAP := 10
const TEAM_ROW_BG := Color("#0e1628")
const STAT_ROW_BG := Color("#0a0f1c")
const NAME_COLOR := Color("#f3ead7")
const ROLE_COLOR := Color("#f28c28")
const STAT_LABEL_COLOR := Color("#9cc6ef")
const SEVERITY_COLORS: Array[Color] = [Color("#f28c28"), Color("#e8583f"), Color("#6cc36a"),
	Color("#9cc6ef")]

const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_SMALL: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")

@export var title: String = ""
@export var message: String = ""
@export var confirm_label: String = "Yes"
@export var cancel_label: String = "No"
@export var buttons: Array[String] = []
@export var kinds: Array[int] = []

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Box
@onready var edges: Control = $Box/Edges
@onready var rows: VBoxContainer = $Box/Pad/Rows
@onready var title_label: Label = $Box/Pad/Rows/Title
@onready var message_label: Label = $Box/Pad/Rows/Message
@onready var button_row: HBoxContainer = $Box/Pad/Rows/Buttons

var _severity: int = Severity.ORANGE
var _confirm_kind: int = Kind.GO
var _button_kinds: Array[int] = []
var _team_rows: Array[Dictionary] = []
var _stat_rows: Array[Dictionary] = []
var _team_box: VBoxContainer = null
var _stat_box: VBoxContainer = null
var _recap_box: VBoxContainer = null
var _stat_values: Array[Label] = []
var _stat_glyphs: Array[NoteIcon] = []
var _viewport_hook: Viewport = null
var _base_box: StyleBoxFlat = null


func _ready() -> void:
	top_level = true
	edges.draw.connect(_draw_edges)
	edges.resized.connect(edges.queue_redraw)
	_hook_viewport()
	_base_box = box.get_theme_stylebox(&"panel", &"PopupBox") as StyleBoxFlat
	box.custom_minimum_size.x = BOX_WIDTH
	_rebuild()
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_unhook_viewport()
		GuiFrameStack.remove(self)
	elif what == NOTIFICATION_ENTER_TREE and is_node_ready():
		_hook_viewport()


#The safe answer sits first, so the cancel label leads and the confirm label carries the kind.
func ask(new_title: String, new_message: String, new_confirm_label: String = "Yes",
		new_cancel_label: String = "No", new_severity: int = Severity.ORANGE,
		confirm_kind: int = Kind.GO) -> void:
	title = new_title
	message = new_message
	confirm_label = new_confirm_label
	cancel_label = new_cancel_label
	buttons = []
	kinds = []
	_confirm_kind = confirm_kind
	_severity = new_severity
	_team_rows = []
	_stat_rows = []
	_rebuild()
	show()
	GuiFrameStack.push(self)


func ask_buttons(new_title: String, new_message: String, labels: Array[String],
		new_severity: int = Severity.ORANGE, new_kinds: Array[int] = []) -> void:
	title = new_title
	message = new_message
	buttons = labels
	kinds = new_kinds
	_severity = new_severity
	_team_rows = []
	_stat_rows = []
	_rebuild()
	show()
	GuiFrameStack.push(self)


#The dispatch recap: the team above the numbers, then the buttons. The last one continues.
func ask_recap(new_title: String, new_message: String, team_rows: Array[Dictionary],
		stat_rows: Array[Dictionary], labels: Array[String],
		new_severity: int = Severity.GREEN, new_kinds: Array[int] = []) -> void:
	title = new_title
	message = new_message
	buttons = labels
	kinds = new_kinds
	_severity = new_severity
	_team_rows = team_rows
	_stat_rows = stat_rows
	_rebuild()
	show()
	GuiFrameStack.push(self)


func button_count() -> int:
	return button_row.get_child_count()


func press(i: int) -> void:
	(button_row.get_child(i) as Button).pressed.emit()


func severity() -> int:
	return _severity


func button_kind(i: int) -> int:
	if i < 0 or i >= _button_kinds.size():
		return -1
	return _button_kinds[i]


func button_labels() -> Array[String]:
	var out: Array[String] = []
	for child: Node in button_row.get_children():
		out.append((child as Button).text)
	return out


func severity_color() -> Color:
	return SEVERITY_COLORS[clampi(_severity, 0, SEVERITY_COLORS.size() - 1)]


func team_row_count() -> int:
	if _team_box == null:
		return 0
	return _team_box.get_child_count()


func stat_row_count() -> int:
	if _stat_box == null:
		return 0
	return _stat_box.get_child_count()


func stat_value_text(i: int) -> String:
	if i < 0 or i >= _stat_values.size():
		return ""
	return _stat_values[i].text


func stat_has_glyph(i: int) -> bool:
	if i < 0 or i >= _stat_glyphs.size():
		return false
	return _stat_glyphs[i] != null


func _rebuild() -> void:
	if not is_node_ready():
		return
	title_label.text = title
	title_label.add_theme_color_override(&"font_color", severity_color())
	message_label.text = message
	_apply_severity()
	_clear_recap()
	_build_recap()
	for child: Node in button_row.get_children():
		button_row.remove_child(child)
		child.queue_free()
	_button_kinds.clear()
	if buttons.is_empty():
		_add_button(cancel_label, Kind.NEUTRAL, _on_cancel)
		_add_button(confirm_label, _confirm_kind, _on_confirm)
	else:
		for i: int in buttons.size():
			_add_button(buttons[i], _kind_at(i), _on_choice.bind(i))
	_place_box()


#One kind per label; with none given every button reads neutral but the last, which continues.
func _kind_at(i: int) -> int:
	if i >= 0 and i < kinds.size():
		return clampi(kinds[i], 0, KIND_FILL.size() - 1)
	return Kind.GO if i == buttons.size() - 1 else Kind.NEUTRAL


func _apply_severity() -> void:
	var style: StyleBoxFlat
	if _base_box != null:
		style = _base_box.duplicate()
	else:
		style = StyleBoxFlat.new()
	style.bg_color = BOX_BG
	style.border_width_left = BOX_BORDER
	style.border_width_top = BOX_BORDER
	style.border_width_right = BOX_BORDER
	style.border_width_bottom = BOX_BORDER
	style.border_color = severity_color()
	style.content_margin_left = BOX_INSET
	style.content_margin_top = BOX_INSET
	style.content_margin_right = BOX_INSET
	style.content_margin_bottom = BOX_INSET
	box.add_theme_stylebox_override(&"panel", style)


#The root covers the viewport through its full rect anchors; writing size here is what makes the
#engine warn about non-equal opposite anchors, so only the box moves.
func _place_box() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view: Vector2 = get_viewport().get_visible_rect().size
	backdrop.offset_bottom = -GuiFrameStack.bottom_reserve
	box.reset_size()
	box.size.x = BOX_WIDTH
	box.position = Vector2((view.x - box.size.x) / 2.0,
		(GuiFrameStack.band_height(view.y) - box.size.y) / 2.0)
	box.position.y = maxf(box.position.y, 0.0)


func _clear_recap() -> void:
	_stat_values.clear()
	_stat_glyphs.clear()
	if _recap_box != null:
		rows.remove_child(_recap_box)
		_recap_box.queue_free()
		_recap_box = null
	_team_box = null
	_stat_box = null


func _build_recap() -> void:
	if _team_rows.is_empty() and _stat_rows.is_empty():
		return
	_team_box = _new_block()
	for row: Dictionary in _team_rows:
		_team_box.add_child(_team_row(row))
	_stat_box = _new_block()
	for row: Dictionary in _stat_rows:
		_stat_box.add_child(_stat_row(row))
	_recap_box = VBoxContainer.new()
	_recap_box.add_theme_constant_override(&"separation", BLOCK_GAP)
	_recap_box.add_child(_team_box)
	_recap_box.add_child(_stat_box)
	rows.add_child(_recap_box)
	rows.move_child(button_row, rows.get_child_count() - 1)


func _new_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override(&"separation", BLOCK_GAP)
	return block


func _team_row(row: Dictionary) -> PanelContainer:
	var panel: PanelContainer = _row_panel(TEAM_ROW_BG)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", ROW_GAP)
	var merc_name: Label = _row_label(str(row.get("name", "")), FONT_BOLD, 11, NAME_COLOR)
	merc_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(merc_name)
	var role: Label = _row_label(str(row.get("role", "")), FONT_BODY, 10, ROLE_COLOR)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(role)
	panel.add_child(line)
	return panel


func _stat_row(row: Dictionary) -> PanelContainer:
	var panel: PanelContainer = _row_panel(STAT_ROW_BG)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", ROW_GAP)
	var caption: Label = _row_label(str(row.get("label", "")), FONT_SMALL, 9, STAT_LABEL_COLOR)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(caption)
	var tint: Color = NAME_COLOR
	if row.get("color") is Color:
		tint = row["color"]
	var value: Label = _row_label(str(row.get("value", "")), FONT_BODY, 14, tint)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(value)
	_stat_values.append(value)
	var glyph: NoteIcon = null
	if bool(row.get("glyph", false)):
		glyph = NoteIcon.new()
		glyph.pixel_scale = 1
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(glyph)
	_stat_glyphs.append(glyph)
	panel.add_child(line)
	return panel


func _row_panel(fill: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override(&"panel", style)
	return panel


func _row_label(text: String, font: FontVariation, font_size: int, tint: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override(&"font", font)
	node.add_theme_font_size_override(&"font_size", font_size)
	node.add_theme_color_override(&"font_color", tint)
	return node


func _draw_edges() -> void:
	var span: Vector2 = edges.size
	edges.draw_rect(Rect2(0.0, 0.0, span.x, EDGE_PX), EDGE_HI)
	edges.draw_rect(Rect2(0.0, 0.0, EDGE_PX, span.y), EDGE_HI)
	edges.draw_rect(Rect2(0.0, span.y - EDGE_PX, span.x, EDGE_PX), EDGE_LO)
	edges.draw_rect(Rect2(span.x - EDGE_PX, 0.0, EDGE_PX, span.y), EDGE_LO)


func _add_button(label: String, kind: int, target: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = BUTTON_SIZE
	if kind == Kind.GO:
		b.theme_type_variation = &"ButtonGo"
	elif kind != Kind.NEUTRAL:
		var fill: Color = KIND_FILL[kind]
		b.add_theme_stylebox_override(&"normal", _button_box(fill))
		b.add_theme_stylebox_override(&"hover", _button_box(fill.lightened(0.12)))
		b.add_theme_stylebox_override(&"pressed", _button_box(fill.darkened(0.15)))
	var ink: Color = NAME_COLOR if kind == Kind.NEUTRAL else DARK_INK
	b.add_theme_color_override(&"font_color", ink)
	b.add_theme_color_override(&"font_hover_color", ink)
	b.add_theme_color_override(&"font_pressed_color", ink)
	b.pressed.connect(target)
	button_row.add_child(b)
	_button_kinds.append(kind)


func _button_box(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = DARK_INK
	style.border_width_left = BUTTON_EDGE
	style.border_width_top = BUTTON_EDGE
	style.border_width_right = BUTTON_EDGE
	style.border_width_bottom = BUTTON_EDGE
	style.content_margin_left = BUTTON_PAD_X
	style.content_margin_right = BUTTON_PAD_X
	style.content_margin_top = BUTTON_PAD_Y
	style.content_margin_bottom = BUTTON_PAD_Y
	return style


func _on_confirm() -> void:
	_dismiss()
	confirmed.emit()


func _on_cancel() -> void:
	_dismiss()
	cancelled.emit()


func _on_choice(i: int) -> void:
	_dismiss()
	chosen.emit(i)


func _dismiss() -> void:
	hide()
	GuiFrameStack.remove(self)


func _on_viewport_resized() -> void:
	if is_node_ready():
		_place_box()


func _hook_viewport() -> void:
	if _viewport_hook != null:
		return
	_viewport_hook = get_viewport()
	if _viewport_hook != null:
		_viewport_hook.size_changed.connect(_on_viewport_resized)


func _unhook_viewport() -> void:
	if _viewport_hook == null:
		return
	if not is_instance_valid(_viewport_hook):
		_viewport_hook = null
		return
	if _viewport_hook.size_changed.is_connected(_on_viewport_resized):
		_viewport_hook.size_changed.disconnect(_on_viewport_resized)
	_viewport_hook = null


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.top() != self:
		return
	_dismiss()
	cancelled.emit()
	get_viewport().set_input_as_handled()
