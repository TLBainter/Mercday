class_name PayrollItem extends Button

#One merc row in the payroll list: portrait with the status band over it, name, tradition and the
#guild face, the monthly wage and the level plate. Every value comes from one payroll_rows row.
#A fired or dead row opens nothing, so it never emits row_pressed.

const FONT_NAME: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const STYLE_NORMAL: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_item.tres")
const STYLE_HOVER: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_item_hover.tres")
const STYLE_PRESS: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_item_press.tres")

const CREAM: Color = Color("#f3ead7")
const BAND_AVAILABLE: Color = Color("#6cc36a")
const BAND_GONE: Color = Color("#e8583f")
const PLAIN_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const GREY_TINT: Color = Color(0.55, 0.55, 0.55, 1.0)
const SALARY_TIP: String = "Monthly salary"
const ROW_HEIGHT: float = 68.0
const PORTRAIT_PX: int = 56
const BAND_HEIGHT: float = 14.0
const BADGE_PX: int = 40

signal row_pressed(uid: int)
signal row_hovered(uid: int)
signal row_left(uid: int)

@onready var body: MarginContainer = $Body
@onready var portrait_box: Control = $Body/Row/PortraitBox
@onready var portrait: MercPortrait = $Body/Row/PortraitBox/Portrait
@onready var strip: MercStatusStrip = $Body/Row/PortraitBox/Strip
@onready var mid: VBoxContainer = $Body/Row/Mid
@onready var name_label: Label = $Body/Row/Mid/NameLabel
@onready var tradition_label: Label = $Body/Row/Mid/TraditionLabel
@onready var face: MoodFace = $Body/Row/Mid/Face
@onready var salary_row: NotesLabel = $Body/Row/Salary
@onready var badge: PayrollBadge = $Body/Row/Badge

var _row: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "focus"]:
		add_theme_stylebox_override(state, STYLE_NORMAL)
	add_theme_stylebox_override("hover", STYLE_HOVER)
	add_theme_stylebox_override("pressed", STYLE_PRESS)
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_ignore_mouse(body)
	_refresh()


func set_row(row_data: Dictionary) -> void:
	_row = row_data
	_refresh()


func row() -> Dictionary:
	return _row


func uid() -> int:
	return int(_row.get("uid", 0))


func status() -> int:
	return int(_row.get("status", GuiTypes.MercStatus.AVAILABLE))


#A press opens the salary dialog; a fired or dead merc has no wage left to change.
func openable() -> bool:
	var value: int = status()
	return value != GuiTypes.MercStatus.FIRED and value != GuiTypes.MercStatus.DEAD


func press_row() -> void:
	_on_pressed()


func text(key: String) -> String:
	if not is_node_ready():
		return ""
	match key:
		"name":
			return name_label.text
		"tradition":
			return tradition_label.text
		"status":
			return strip.text
		"salary":
			return salary_row.value_text()
		"level":
			return badge.text()
		_:
			return ""


func color(key: String) -> Color:
	if key == "status":
		return band_color(status())
	var raw: Variant = CREAM
	if key == "tradition":
		raw = _row.get("tradition_color", CREAM)
	elif key == "salary":
		raw = _row.get("salary_color", CREAM)
	var out: Color = raw
	return out


#The band the row prints: green while the merc is available, red once fired or dead, cream for
#every other status. The strip itself only knows green and cream, so the row paints it.
static func band_color(status_value: int) -> Color:
	if status_value == GuiTypes.MercStatus.AVAILABLE:
		return BAND_AVAILABLE
	if status_value == GuiTypes.MercStatus.FIRED or status_value == GuiTypes.MercStatus.DEAD:
		return BAND_GONE
	return CREAM


func _on_pressed() -> void:
	if not openable():
		return
	row_pressed.emit(uid())


func _on_mouse_entered() -> void:
	row_hovered.emit(uid())


func _on_mouse_exited() -> void:
	row_left.emit(uid())


func _refresh() -> void:
	if not is_node_ready():
		return
	portrait_box.custom_minimum_size = Vector2(float(PORTRAIT_PX), float(PORTRAIT_PX))
	portrait.pixel_size = PORTRAIT_PX
	var view: MercView = BenefitsManager.view_of(uid()) if uid() > 0 else null
	if view != null:
		portrait.set_merc(view)
	var lit: bool = status() == GuiTypes.MercStatus.AVAILABLE
	portrait.modulate = PLAIN_TINT if lit else GREY_TINT
	strip.band = true
	strip.custom_minimum_size = Vector2(0.0, BAND_HEIGHT)
	strip.status = status()
	strip.add_theme_font_override("font", FONT_BODY)
	strip.add_theme_font_size_override("font_size", 8)
	strip.add_theme_color_override("font_color", color("status"))
	name_label.text = String(_row.get("name", ""))
	name_label.add_theme_font_override("font", FONT_NAME)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", CREAM)
	tradition_label.text = String(_row.get("tradition", ""))
	tradition_label.add_theme_font_override("font", FONT_BODY)
	tradition_label.add_theme_font_size_override("font_size", 12)
	tradition_label.add_theme_color_override("font_color", color("tradition"))
	face.guild = true
	face.pixel_scale = 2
	face.opinion = int(_row.get("opinion", 0))
	salary_row.amount = int(_row.get("salary", 0))
	salary_row.bold = true
	salary_row.font_size = 11
	salary_row.glyph_scale = 2
	salary_row.value_color = color("salary")
	salary_row.tooltip_text = SALARY_TIP
	salary_row.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.plate = BADGE_PX
	badge.kicker_size = 7
	badge.value_size = 15
	badge.level = int(_row.get("level", 0))
	tooltip_text = ""


func _ignore_mouse(node: Node) -> void:
	var control: Control = node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
