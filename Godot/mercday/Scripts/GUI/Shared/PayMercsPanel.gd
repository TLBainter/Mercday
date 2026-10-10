class_name PayMercsPanel extends CrewPanel

#Right side of an Odd Job crew: the default bonus, a per merc stepper and the running total.
#Only shown once the team holds at least one merc. The total turns red past the guild's notes.

signal pay_changed(per: int)

const CAP_FLOOR: int = 999

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
	super()
	title_label.text = "Pay Mercs"
	default_row.tooltip_text = "Odd Job Default Bonus"
	GuiStyle.paint(default_value_label, GuiStyle.SILK_BOLD, 16, GuiColors.SKY)
	stepper.min_value = 0
	stepper.max_value = _stepper_cap()
	stepper.custom_minimum_size = Vector2(170.0, 38.0)
	stepper.value_changed.connect(_on_stepper_changed)
	GameState.money_changed.connect(_on_money_changed)
	per_merc_label.text = "/ Merc"
	GuiStyle.paint(per_merc_label, GuiStyle.SILK, 17, GuiColors.SKY)
	total_label.add_theme_font_override(&"font", GuiStyle.SILK_BOLD)
	total_label.add_theme_font_size_override(&"font_size", 18)
	_refresh()


func total() -> int:
	return per * team_size


#Test probe: one press of the stepper plus button.
func press_stepper_plus() -> void:
	stepper.press_plus()


#Test probe: the value the stepper shows.
func stepper_value() -> int:
	return stepper.value


#Test probe: the default bonus text.
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
	default_value_label.text = TransactionData.grouped(default_pay)
	default_glyph.texture = Icons.tinted("note", GuiColors.SKY, 2, true)
	default_glyph.custom_minimum_size = NoteIcon.GLYPH_SIZE_PX * 2.0
	stepper.max_value = _stepper_cap()
	stepper.set_value_silent(per)
	var over: bool = total() > money
	var tint: Color = GuiColors.RED if over else GuiColors.CREAM
	total_label.text = "Total %s" % TransactionData.grouped(total())
	total_label.add_theme_color_override(&"font_color", tint)
	total_glyph.texture = Icons.tinted("note", tint, 3, true)
	total_glyph.custom_minimum_size = NoteIcon.GLYPH_SIZE_PX * 3.0


#The stepper never caps below the guild's notes, the current per merc pay or CAP_FLOOR.
func _stepper_cap() -> int:
	return maxi(maxi(CAP_FLOOR, GameState.bank_notes), per)


func _on_money_changed(_notes: int) -> void:
	_refresh()
