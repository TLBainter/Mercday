class_name ModuleTile extends Button

#One picker module of a mods filter section: a square image, the Received / Completed / Failed
#history, an optional Relationship line that the Customer Satisfaction upgrade opens, the module
#name and a checkbox top right. A module with a disabled_reason stays visible but dim and inert.

signal pressed_tile(key: Variant)

const IMAGE_PX: float = 64.0
const CHECK_PX: float = 16.0
const MIN_WIDTH: float = 190.0
const MIN_HEIGHT: float = 104.0
const PAD_PX: float = 8.0
const NAME_SIZE: int = 11
const NOTE_SIZE: int = 11
const STAT_LABEL_SIZE: int = 7
const STAT_VALUE_SIZE: int = 10
const IMAGE_LABEL_SIZE: int = 7
const BLOCKED_ALPHA: float = 0.4
#Stands for a module that carries no relationship at all, so the row never shows.
const NO_RELATION: int = -2147483648
const STAT_LABELS: Array[String] = ["Received", "Completed", "Failed"]
const STAT_COLORS: Array[Color] = [Color("#f3ead7"), Color("#6cc36a"), Color("#e8583f")]
const REL_LABEL: String = "Relation"
const REL_UPGRADE_ID: String = "customer"
const REL_ENTITLEMENT: String = "clientOpinion"
const REL_FEATURE: String = "Relationships"
const REL_POSITIVE: Color = Color("#6cc36a")
const REL_NEGATIVE: Color = Color("#e8583f")
const REL_NEUTRAL: Color = Color("#f2b33d")
const LABEL_COLOR: Color = Color("#9cc6ef")
const NAME_COLOR: Color = Color("#f3ead7")
const NOTE_COLOR: Color = Color("#e8583f")
const IMAGE_LABEL_COLOR: Color = Color("#5e7699")
const LOCK_HEIGHT: float = 14.0
const LOCK_FONT_SIZE: int = 7
const STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"focus", &"disabled"]
const STYLE_ON: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_tile_on.tres")
const STYLE_OFF: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_tile_off.tres")
const STYLE_STAT: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_tile_stat.tres")
const STYLE_CHECK_ON: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_check_on.tres")
const STYLE_CHECK_OFF: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_check_off.tres")
const FONT_LABEL: Font = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_VALUE: Font = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_NOTE: Font = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const LOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FeatureLock.tscn")

@export var label: String = ""
@export var image: Texture2D = null
#The placeholder caption a module without art shows inside its image box.
@export var image_note: String = ""
@export var received: int = 0
@export var completed: int = 0
@export var failed: int = 0
@export var relationship: int = NO_RELATION
#False keeps the relationship line but shows the upgrade lock in place of the number.
@export var relationship_open: bool = true
#Non empty means the module cannot be picked; the text shows as the note and the tooltip.
@export var disabled_reason: String = ""
#A single pick module tells the section to replace the pick instead of adding to it.
@export var single: bool = false
@export var selected: bool = false

#What the section stores when this module is picked.
var key: Variant = null

@onready var rows: VBoxContainer = $Rows
@onready var image_box: PanelContainer = $Rows/Top/ImageBox
@onready var image_label: Label = $Rows/Top/ImageBox/ImageLabel
@onready var image_rect: TextureRect = $Rows/Top/ImageBox/Image
@onready var stats: VBoxContainer = $Rows/Top/Stats
@onready var check_box: Panel = $Rows/Top/Check
@onready var check_mark: TextureRect = $Rows/Top/Check/Mark
@onready var name_label: Label = $Rows/TileName
@onready var note_label: Label = $Rows/Note

var _stat_values: Array[Label] = []
var _rel_panel: PanelContainer = null
var _rel_value: Label = null
var _rel_lock: FeatureLock = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = ""
	image_box.custom_minimum_size = Vector2(IMAGE_PX, IMAGE_PX)
	check_box.custom_minimum_size = Vector2(CHECK_PX, CHECK_PX)
	check_mark.texture = GuiGlyphs.check(Color("#0a0f1c"))
	name_label.add_theme_font_override(&"font", FONT_VALUE)
	name_label.add_theme_font_size_override(&"font_size", NAME_SIZE)
	name_label.add_theme_color_override(&"font_color", NAME_COLOR)
	note_label.add_theme_font_override(&"font", FONT_NOTE)
	note_label.add_theme_font_size_override(&"font_size", NOTE_SIZE)
	note_label.add_theme_color_override(&"font_color", NOTE_COLOR)
	image_label.add_theme_font_override(&"font", FONT_LABEL)
	image_label.add_theme_font_size_override(&"font_size", IMAGE_LABEL_SIZE)
	image_label.add_theme_color_override(&"font_color", IMAGE_LABEL_COLOR)
	_build_stats()
	pressed.connect(press_tile)
	refresh()


func is_blocked() -> bool:
	return disabled_reason != ""


#The press path a headless test takes; a blocked module never reports a press.
func press_tile() -> void:
	if is_blocked():
		return
	pressed_tile.emit(key)


func set_selected(on: bool) -> void:
	selected = on
	refresh()


func relationship_lock() -> FeatureLock:
	return _rel_lock


func refresh() -> void:
	if not is_node_ready():
		return
	for state: StringName in STATES:
		add_theme_stylebox_override(state, STYLE_ON if selected else STYLE_OFF)
	modulate = Color(1.0, 1.0, 1.0, BLOCKED_ALPHA if is_blocked() else 1.0)
	mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if is_blocked() \
		else Control.CURSOR_POINTING_HAND
	tooltip_text = disabled_reason
	check_box.add_theme_stylebox_override(&"panel", STYLE_CHECK_ON if selected else STYLE_CHECK_OFF)
	check_mark.visible = selected
	image_rect.texture = image
	image_rect.visible = image != null
	image_label.visible = image == null
	image_label.text = image_note
	name_label.text = label
	note_label.text = disabled_reason
	note_label.visible = is_blocked()
	var counts: Array[int] = [received, completed, failed]
	for i: int in range(_stat_values.size()):
		_stat_values[i].text = str(counts[i])
	_rel_panel.visible = relationship != NO_RELATION
	_rel_value.visible = _rel_panel.visible and relationship_open
	_rel_lock.visible = _rel_panel.visible and not relationship_open
	if _rel_panel.visible:
		_rel_value.text = ("+%d" % relationship) if relationship > 0 else str(relationship)
		_rel_value.add_theme_color_override(&"font_color", _rel_color())
	custom_minimum_size = Vector2(MIN_WIDTH,
		maxf(MIN_HEIGHT, rows.get_combined_minimum_size().y + PAD_PX * 2.0))


func _rel_color() -> Color:
	if relationship > 0:
		return REL_POSITIVE
	return REL_NEGATIVE if relationship < 0 else REL_NEUTRAL


func _build_stats() -> void:
	_rel_panel = _stat_panel(REL_LABEL)
	var rel_row: HBoxContainer = _rel_panel.get_child(0)
	_rel_value = _value_label()
	rel_row.add_child(_rel_value)
	_rel_lock = LOCK_SCENE.instantiate() as FeatureLock
	_rel_lock.size_flags_horizontal = Control.SIZE_SHRINK_END
	rel_row.add_child(_rel_lock)
	_rel_lock.feature = REL_FEATURE
	_rel_lock.upgrade = UpgradeDefs.name_of(REL_UPGRADE_ID)
	_rel_lock.upgrade_id = REL_UPGRADE_ID
	_rel_lock.entitlement = REL_ENTITLEMENT
	_rel_lock.tier = 1
	_rel_lock.tiers = 1
	_rel_lock.verb = "view"
	_rel_lock.label = "Locked"
	_rel_lock.height = LOCK_HEIGHT
	_rel_lock.font_size = LOCK_FONT_SIZE
	_rel_lock.always_visible = true
	for i: int in range(STAT_LABELS.size()):
		var panel: PanelContainer = _stat_panel(STAT_LABELS[i])
		var value: Label = _value_label()
		value.add_theme_color_override(&"font_color", STAT_COLORS[i])
		(panel.get_child(0) as HBoxContainer).add_child(value)
		_stat_values.append(value)


func _stat_panel(row_name: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = row_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", STYLE_STAT)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	panel.add_child(row)
	var key_label: Label = Label.new()
	key_label.name = "Key"
	key_label.text = row_name
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.add_theme_font_override(&"font", FONT_LABEL)
	key_label.add_theme_font_size_override(&"font_size", STAT_LABEL_SIZE)
	key_label.add_theme_color_override(&"font_color", LABEL_COLOR)
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_label)
	stats.add_child(panel)
	return panel


func _value_label() -> Label:
	var value: Label = Label.new()
	value.name = "Value"
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_override(&"font", FONT_VALUE)
	value.add_theme_font_size_override(&"font_size", STAT_VALUE_SIZE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return value
