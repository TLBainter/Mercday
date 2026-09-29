class_name FilterGroup extends VBoxContainer

#One collapsible band of filter sections: a header carrying a caret, the group name and the count of
#the filters inside it that are active, over a body that holds the sections. A headless group has no
#header at all and stays open, which is what a def table with no group names renders as.

signal toggled_open(open: bool)

const HEAD_HEIGHT: float = 26.0
const TITLE_SIZE: int = 10
const TITLE_COLOR: Color = Color("#f3ead7")
const TITLE_CLOSED: Color = Color("#9cc6ef")
const BADGE_SIZE: int = 9
const BADGE_TEXT: Color = Color("#0a0f1c")
const CARET_PX: int = 10
const CARET_COLOR: Color = Color("#9cc6ef")
const ROW_GAP: int = 10
const BODY_GAP: int = 12
const STYLE_HEAD_OPEN: StyleBoxFlat = preload(
	"res://Resources/GUI/Theme/Styles/filter_group_head_open.tres")
const STYLE_HEAD_CLOSED: StyleBoxFlat = preload(
	"res://Resources/GUI/Theme/Styles/filter_group_head_closed.tres")
const STYLE_BODY: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_group_body.tres")
const STYLE_BADGE: StyleBoxFlat = preload(
	"res://Resources/GUI/Theme/Styles/filter_group_badge.tres")
const STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"focus", &"disabled"]
const FONT_TITLE: Font = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BADGE: Font = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")

@export var expanded: bool = false
@export var title: String = ""
#A group with no header: it never closes and shows no caret, name or badge.
@export var headless: bool = false

@onready var head: Button = $Head
@onready var head_row: HBoxContainer = $Head/Row
@onready var caret: TextureRect = $Head/Row/Caret
@onready var title_label: Label = $Head/Row/Title
@onready var badge: PanelContainer = $Head/Row/Badge
@onready var badge_label: Label = $Head/Row/Badge/Count
@onready var body_box: PanelContainer = $Body
@onready var body_rows: VBoxContainer = $Body/Rows

var _count: int = 0


func _ready() -> void:
	add_theme_constant_override(&"separation", 0)
	head.custom_minimum_size = Vector2(0.0, HEAD_HEIGHT)
	head.focus_mode = Control.FOCUS_NONE
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	head_row.add_theme_constant_override(&"separation", ROW_GAP)
	title_label.add_theme_font_override(&"font", FONT_TITLE)
	title_label.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	badge.add_theme_stylebox_override(&"panel", STYLE_BADGE)
	badge_label.add_theme_font_override(&"font", FONT_BADGE)
	badge_label.add_theme_font_size_override(&"font_size", BADGE_SIZE)
	badge_label.add_theme_color_override(&"font_color", BADGE_TEXT)
	body_box.add_theme_stylebox_override(&"panel", STYLE_BODY)
	body_rows.add_theme_constant_override(&"separation", BODY_GAP)
	head.pressed.connect(toggle)
	refresh()


func count() -> int:
	return _count


func set_count(n: int) -> void:
	_count = maxi(0, n)
	refresh()


#The press path a click and a headless test share.
func toggle() -> void:
	if headless:
		return
	expanded = not expanded
	refresh()
	toggled_open.emit(expanded)


#Opens or closes without reporting it, the path a panel takes while it builds.
func set_open(open: bool) -> void:
	expanded = open or headless
	refresh()


func is_open() -> bool:
	return expanded or headless


func add_section(section: FilterSection) -> void:
	body_rows.add_child(section)


func clear_sections() -> void:
	for child: Node in body_rows.get_children():
		body_rows.remove_child(child)
		child.queue_free()


func sections() -> Array[FilterSection]:
	var out: Array[FilterSection] = []
	for child: Node in body_rows.get_children():
		if child is FilterSection:
			out.append(child)
	return out


func body() -> VBoxContainer:
	return body_rows


func header() -> Button:
	return head


func refresh() -> void:
	if not is_node_ready():
		return
	var open: bool = is_open()
	head.visible = not headless
	body_box.visible = open
	title_label.text = title
	title_label.add_theme_color_override(&"font_color", TITLE_COLOR if open else TITLE_CLOSED)
	badge.visible = _count > 0
	badge_label.text = str(_count)
	caret.texture = caret_texture(open, CARET_COLOR)
	for state: StringName in STATES:
		head.add_theme_stylebox_override(state, STYLE_HEAD_OPEN if open else STYLE_HEAD_CLOSED)


#The caret of the header: the atlas caret, down when the group is open and right when it is shut.
static func caret_texture(open: bool, color: Color) -> ImageTexture:
	return Icons.tinted("caret_down" if open else "caret_right", color, 2, true)
