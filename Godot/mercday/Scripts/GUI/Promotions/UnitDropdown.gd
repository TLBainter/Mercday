class_name UnitDropdown extends PopupButton

#The duration unit picker of the builder: Days, Weeks, Months and Infinite, one row per
#CampaignTypeDefs.UNITS entry. A unit the Long Promos cap has not reached yet stays visible and
#wears a FeatureLock that names the tier it needs, and picking it does nothing. OptionDropdown
#cannot hold a lock in a row, so this control builds its own popup.

signal unit_picked(unit_key: StringName)
signal take_me_there(target: Dictionary)

const LOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FeatureLock.tscn")
const FONT_BOLD: FontVariation = GuiStyle.SILK_BOLD
const FIELD_BG: Color = GuiColors.INK
const MENU_BG: Color = GuiColors.ROW_FILL
const RING_IDLE: Color = GuiColors.BLUE_HI
const RING_OPEN: Color = GuiColors.ORANGE
const ON_BG: Color = GuiColors.ORANGE
const ON_FG: Color = GuiColors.INK
const OFF_FG: Color = GuiColors.CREAM
const LOCKED_FG: Color = GuiColors.MUTED
const CARET_COLOR: Color = GuiColors.ORANGE
const FIELD_SIZE: Vector2 = Vector2(128, 38)
const ROW_SIZE: Vector2 = Vector2(128, 32)
const LOCK_PX: float = 14.0
const LOCK_FONT_SIZE: int = 7
const RING_PX: int = 2
const ROW_PAD: float = 10.0
const LABEL_SIZE: int = 11
const CARET_SCALE: int = 2
const CARET_OPEN_ID: String = "caret_up"
const CARET_SHUT_ID: String = "caret_down"
const LOCK_VERB: String = "use"
const FEATURE_INFINITE: String = "Infinite promos"
const FEATURE_LASTING: String = "promos lasting %s"
const SPAN_NAMES: Dictionary = {1: "a day", 7: "a week", 30: "a month"}

@onready var row: HBoxContainer = $Row
@onready var label: Label = $Row/UnitName
@onready var caret: TextureRect = $Row/Caret
@onready var list: VBoxContainer = $Menu/List

var _ent: Dictionary = {}
var _key: StringName = CampaignTypeDefs.UNIT_DAYS
var _rows: Dictionary = {}
var _locks: Dictionary = {}


func _ready() -> void:
	super()
	custom_minimum_size = FIELD_SIZE
	focus_mode = Control.FOCUS_NONE
	text = ""
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	GuiStyle.paint(label, FONT_BOLD, LABEL_SIZE, OFF_FG)
	caret.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	menu.add_theme_stylebox_override(&"panel", GuiStyle.flat(MENU_BG, RING_PX, RING_IDLE))
	list.add_theme_constant_override(&"separation", 0)
	menu.visibility_changed.connect(_apply_field)
	_build()
	_apply()


func set_ent(ent: Dictionary) -> void:
	_ent = ent.duplicate()
	if is_node_ready():
		_apply()


#Keeps the field on a unit the cap still allows, falling back to Days.
func set_unit(wanted: StringName) -> void:
	_key = wanted if _unlocked(wanted) else CampaignTypeDefs.UNIT_DAYS
	if is_node_ready():
		_apply()


func unit_key() -> StringName:
	return _key


func unit_name() -> String:
	return String(CampaignTypeDefs.unit_of(_key).get("name", ""))


func label_text() -> String:
	return label.text if is_node_ready() else ""


func row_for(wanted: StringName) -> Button:
	return _rows.get(wanted, null) as Button


func row_locked(wanted: StringName) -> bool:
	return not _unlocked(wanted)


func lock_for(wanted: StringName) -> FeatureLock:
	return _locks.get(wanted, null) as FeatureLock


func press_row(wanted: StringName) -> void:
	if not _unlocked(wanted):
		return
	_key = wanted
	close_popup()
	_apply()
	unit_picked.emit(_key)


func _build() -> void:
	for unit: Dictionary in CampaignTypeDefs.UNITS:
		var key: StringName = StringName(unit["key"])
		var button := Button.new()
		button.custom_minimum_size = ROW_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.text = ""
		list.add_child(button)
		var inner := HBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = ROW_PAD
		inner.offset_right = -ROW_PAD
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(inner)
		var name_label := Label.new()
		name_label.text = String(unit["name"])
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_override(&"font", FONT_BOLD)
		name_label.add_theme_font_size_override(&"font_size", LABEL_SIZE)
		inner.add_child(name_label)
		#Days needs no upgrade, so that row carries no lock to keep visible.
		if int(unit["upgrade_tier"]) > 0:
			var lock: FeatureLock = LOCK_SCENE.instantiate()
			lock.min_width = LOCK_PX
			lock.height = LOCK_PX
			lock.font_size = LOCK_FONT_SIZE
			lock.verb = LOCK_VERB
			lock.feature = _feature_text(unit)
			lock.upgrade = UpgradeDefs.name_of(String(unit["upgrade_id"]))
			lock.upgrade_id = String(unit["upgrade_id"])
			lock.tier = int(unit["upgrade_tier"])
			lock.tiers = UpgradeDefs.display_tiers(lock.upgrade_id)
			lock.entitlement = CampaignTypeDefs.CAP_KEY
			lock.entitlement_tier = int(unit["min_cap"])
			lock.size_flags_vertical = SIZE_SHRINK_CENTER
			lock.take_me_there.connect(take_me_there.emit)
			inner.add_child(lock)
			_locks[key] = lock
		button.pressed.connect(press_row.bind(key))
		_rows[key] = button


func _apply() -> void:
	label.text = unit_name()
	_apply_field()
	for unit: Dictionary in CampaignTypeDefs.UNITS:
		var key: StringName = StringName(unit["key"])
		var button: Button = _rows[key] as Button
		var lock: FeatureLock = lock_for(key)
		var open_row: bool = _unlocked(key)
		var on: bool = key == _key
		if lock != null:
			lock.visible = not open_row
		button.disabled = not open_row
		var tint: Color = ON_FG if on else (OFF_FG if open_row else LOCKED_FG)
		var inner: HBoxContainer = button.get_child(0) as HBoxContainer
		var name_label: Label = inner.get_child(0) as Label
		name_label.add_theme_color_override(&"font_color", tint)
		var box: StyleBoxFlat = GuiStyle.flat(ON_BG if on else MENU_BG)
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			button.add_theme_stylebox_override(state, box)


func _apply_field() -> void:
	var open_now: bool = menu.visible
	caret.texture = Icons.tinted(CARET_OPEN_ID if open_now else CARET_SHUT_ID, CARET_COLOR,
		CARET_SCALE, true)
	var ring: Color = RING_OPEN if open_now else RING_IDLE
	set_colors(FIELD_BG, ring, ring, OFF_FG)


func _unlocked(wanted: StringName) -> bool:
	return CampaignTypeDefs.unit_unlocked(wanted, _ent)


func _feature_text(unit: Dictionary) -> String:
	if StringName(unit["key"]) == CampaignTypeDefs.UNIT_INFINITE:
		return FEATURE_INFINITE
	var span: int = int(unit["days"])
	return FEATURE_LASTING % String(SPAN_NAMES.get(span, "longer"))
