class_name DurationControl extends VBoxContainer

#How long a campaign runs: the quantity stepper beside the unit picker, with the cap the Long
#Promos upgrade sets written under the caption. Picking Infinite takes the quantity away, since an
#infinite promo is billed by the month until the guild ends it.

signal quantity_changed(qty: int)
signal unit_changed(unit_key: StringName)
signal take_me_there(target: Dictionary)

const FONT_SILK: FontVariation = GuiStyle.SILK
const CAPTION_COLOR: Color = GuiColors.SKY
const NOTE_COLOR: Color = GuiColors.MUTED
const CAPTION_SIZE: int = 9
const NOTE_SIZE: int = 8
const STEPPER_WIDTH: float = 170.0
const UNIT_WIDTH: float = 128.0
const ROW_GAP: int = 10
const COLUMN_GAP: int = 6
const CAPTION_TEXT: String = "Duration"
const CAP_TIP: String = "Long Promos raises this cap"
const NO_LIMIT: String = "No limit"
const UP_TO: String = "Up to %d days"
const INFINITE_TIP: String = "Infinite promos run until you end them"
#The prototype greys the whole stepper while Infinite stands, not only its glyphs.
const INFINITE_ALPHA: float = 0.35

@onready var head: HBoxContainer = $Head
@onready var caption: Label = $Head/Caption
@onready var cap_note: Label = $Head/CapNote
@onready var row: HBoxContainer = $Row
@onready var stepper: QuantityStepper = $Row/Stepper
@onready var unit_field: UnitDropdown = $Row/Unit

var _ent: Dictionary = {}
var _qty: int = 5


func _ready() -> void:
	add_theme_constant_override(&"separation", COLUMN_GAP)
	head.add_theme_constant_override(&"separation", ROW_GAP)
	row.add_theme_constant_override(&"separation", ROW_GAP)
	GuiStyle.paint(caption, FONT_SILK, CAPTION_SIZE, CAPTION_COLOR)
	GuiStyle.paint(cap_note, FONT_SILK, NOTE_SIZE, NOTE_COLOR)
	caption.text = CAPTION_TEXT
	caption.size_flags_horizontal = SIZE_EXPAND_FILL
	cap_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cap_note.tooltip_text = CAP_TIP
	stepper.custom_minimum_size = Vector2(STEPPER_WIDTH, 0.0)
	stepper.min_value = CampaignTypeDefs.MIN_DAYS
	stepper.value_changed.connect(_on_qty_changed)
	unit_field.custom_minimum_size = Vector2(UNIT_WIDTH, 0.0)
	unit_field.unit_picked.connect(_on_unit_picked)
	unit_field.take_me_there.connect(take_me_there.emit)
	_apply()


func set_ent(ent: Dictionary) -> void:
	_ent = ent.duplicate()
	if is_node_ready():
		unit_field.set_ent(_ent)
		_fit_if_known()
		_apply()


func set_quantity(qty: int) -> void:
	_qty = maxi(CampaignTypeDefs.MIN_DAYS, qty)
	if is_node_ready():
		_fit_if_known()
		_apply()


#Keeps the quantity inside the cap the new unit allows, the way the prototype does on a pick.
func set_unit(wanted: StringName) -> void:
	if not is_node_ready():
		return
	unit_field.set_unit(wanted)
	_fit_quantity()
	_apply()


func quantity() -> int:
	return _qty


func unit_key() -> StringName:
	return unit_field.unit_key() if is_node_ready() else CampaignTypeDefs.UNIT_DAYS


func is_infinite() -> bool:
	return unit_key() == CampaignTypeDefs.UNIT_INFINITE


func days() -> int:
	if is_infinite():
		return 0
	return CampaignTypeDefs.days_of(unit_key(), _qty)


func max_quantity() -> int:
	return maxi(CampaignTypeDefs.MIN_DAYS, CampaignTypeDefs.unit_qty_max(unit_key(), _ent))


func hint_text() -> String:
	var cap: int = CampaignTypeDefs.cap_of(_ent)
	if cap >= CampaignTypeDefs.INFINITE_CAP:
		return NO_LIMIT
	return UP_TO % cap


func stepper_disabled() -> bool:
	return is_node_ready() and stepper.disabled


func unit_picker() -> UnitDropdown:
	return unit_field


func quantity_stepper() -> QuantityStepper:
	return stepper


func press_unit(wanted: StringName) -> void:
	if is_node_ready():
		unit_field.press_row(wanted)


#The cap only binds once the entitlements have arrived: an empty table reads a cap of one day and
#would pull every quantity down to one before the window is set up. No signal is sent from here.
func _fit_if_known() -> void:
	if _ent.is_empty():
		return
	_fit_quantity()


func _fit_quantity() -> void:
	if is_infinite():
		_qty = 1
		return
	_qty = clampi(_qty, CampaignTypeDefs.MIN_DAYS, max_quantity())


func _apply() -> void:
	var inf: bool = is_infinite()
	cap_note.text = hint_text()
	stepper.max_value = 1 if inf else max_quantity()
	stepper.set_value_silent(_qty)
	stepper.disabled = inf
	stepper.modulate.a = INFINITE_ALPHA if inf else 1.0
	stepper.tooltip_text = INFINITE_TIP if inf else ""


func _on_qty_changed(new_value: int) -> void:
	_qty = new_value
	quantity_changed.emit(_qty)


func _on_unit_picked(picked: StringName) -> void:
	_fit_quantity()
	_apply()
	unit_changed.emit(picked)
	quantity_changed.emit(_qty)
