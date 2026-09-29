class_name PayMercsPanel extends PanelContainer

#Right side of an Odd Job crew: the default bonus, a per merc stepper and the running total.
#Only shown once the team holds at least one merc. The total turns red past the guild's notes.

signal pay_changed(per: int)

const CAP_FLOOR: int = 999
const RED: Color = Color("#e8583f")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const TITLE_COLOR: Color = Color("#f28c28")
const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_REGULAR: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")

@export var default_pay: int = 0:
	set(v):
		default_pay = v
		_refresh()
@export var per: int = 0:
	set(v):
		per = v
		_refresh()
@export var team_size: int = 0:
	set(v):
		team_size = v
		_refresh()
@export var money: int = 0:
	set(v):
		money = v
		_refresh()

@onready var title_label: Label = $Rows/Title
@onready var items_row: HBoxContainer = $Rows/ItemsRow
@onready var default_row: HBoxContainer = $Rows/ItemsRow/DefaultRow
@onready var default_glyph: TextureRect = $Rows/ItemsRow/DefaultRow/Glyph
@onready var default_value_label: Label = $Rows/ItemsRow/DefaultRow/Value
@onready var stepper: QuantityStepper = $Rows/ItemsRow/Stepper
@onready var per_merc_label: Label = $Rows/ItemsRow/PerMerc
@onready var total_row: HBoxContainer = $Rows/ItemsRow/TotalRow
@onready var total_glyph: TextureRect = $Rows/ItemsRow/TotalRow/Glyph
@onready var total_label: Label = $Rows/ItemsRow/TotalRow/Value


func _ready() -> void:
	add_theme_stylebox_override(&"panel", _panel_style())
	title_label.text = "Pay Mercs"
	title_label.add_theme_font_override(&"font", FONT_REGULAR)
	title_label.add_theme_font_size_override(&"font_size", 11)
	title_label.add_theme_color_override(&"font_color", TITLE_COLOR)
	default_row.tooltip_text = "Odd Job Default Bonus"
	default_value_label.add_theme_font_override(&"font", FONT_BOLD)
	default_value_label.add_theme_font_size_override(&"font_size", 16)
	default_value_label.add_theme_color_override(&"font_color", SKY)
	stepper.min_value = 0
	stepper.max_value = _stepper_cap()
	stepper.custom_minimum_size = Vector2(170.0, 38.0)
	stepper.value_changed.connect(_on_stepper_changed)
	GameState.money_changed.connect(_on_money_changed)
	per_merc_label.text = "/ Merc"
	per_merc_label.add_theme_font_override(&"font", FONT_REGULAR)
	per_merc_label.add_theme_font_size_override(&"font_size", 17)
	per_merc_label.add_theme_color_override(&"font_color", SKY)
	total_label.add_theme_font_override(&"font", FONT_BOLD)
	total_label.add_theme_font_size_override(&"font_size", 18)
	_refresh()


func total() -> int:
	return per * team_size


func press_stepper_plus() -> void:
	stepper.press_plus()


func press_stepper_minus() -> void:
	stepper.press_minus()


func stepper_value() -> int:
	return stepper.value


func default_text() -> String:
	return default_value_label.text


func total_text() -> String:
	return total_label.text


func total_color() -> Color:
	return total_label.get_theme_color(&"font_color")


func _on_stepper_changed(v: int) -> void:
	per = v
	pay_changed.emit(per)


func _refresh() -> void:
	if not is_node_ready():
		return
	visible = team_size >= 1
	default_value_label.text = _format(default_pay)
	default_glyph.texture = CrewGlyphs.note(SKY, 2)
	default_glyph.custom_minimum_size = Vector2(CrewGlyphs.NOTE_COLS, CrewGlyphs.NOTE_ROWS) * 2.0
	stepper.max_value = _stepper_cap()
	stepper.set_value_silent(per)
	var over: bool = total() > money
	var tint: Color = RED if over else CREAM
	total_label.text = "Total %s" % _format(total())
	total_label.add_theme_color_override(&"font_color", tint)
	total_glyph.texture = CrewGlyphs.note(tint, 3)
	total_glyph.custom_minimum_size = Vector2(CrewGlyphs.NOTE_COLS, CrewGlyphs.NOTE_ROWS) * 3.0


#The stepper never caps below the guild's notes, the current per merc pay or CAP_FLOOR.
func _stepper_cap() -> int:
	return maxi(maxi(CAP_FLOOR, GameState.bank_notes), per)


func _on_money_changed(_notes: int) -> void:
	_refresh()


func _panel_style() -> StyleBoxFlat:
	var path: String = "res://Resources/GUI/Theme/Styles/crew_panel_dark.tres"
	return (load(path) as StyleBoxFlat).duplicate() as StyleBoxFlat


static func _format(n: int) -> String:
	var neg: bool = n < 0
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i != 0:
			out = "," + out
	return ("-" if neg else "") + out
