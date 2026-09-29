class_name UnitDropdown extends Button

#The duration unit picker of the builder: Days, Weeks, Months and Infinite, one row per
#CampaignTypeDefs.UNITS entry. A unit the Long Promos cap has not reached yet stays visible and
#wears a FeatureLock that names the tier it needs, and picking it does nothing. OptionDropdown
#cannot hold a lock in a row, so this control builds its own popup.

signal unit_picked(unit_key: StringName)
signal take_me_there(target: Dictionary)

const LOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FeatureLock.tscn")
const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FIELD_BG: Color = Color("#0a0f1c")
const MENU_BG: Color = Color("#0e1628")
const RING_IDLE: Color = Color("#3b6fb6")
const RING_OPEN: Color = Color("#f28c28")
const ON_BG: Color = Color("#f28c28")
const ON_FG: Color = Color("#0a0f1c")
const OFF_FG: Color = Color("#f3ead7")
const LOCKED_FG: Color = Color("#5e7699")
const CARET_COLOR: Color = Color("#f28c28")
const FIELD_SIZE: Vector2 = Vector2(128, 38)
const ROW_SIZE: Vector2 = Vector2(128, 32)
const LOCK_PX: float = 14.0
const LOCK_FONT_SIZE: int = 7
const RING_PX: int = 2
const PAD_X: float = 10.0
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
@onready var menu: PopupPanel = $Menu
@onready var list: VBoxContainer = $Menu/List

var _ent: Dictionary = {}
var _key: StringName = CampaignTypeDefs.UNIT_DAYS
var _rows: Dictionary = {}
var _locks: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = FIELD_SIZE
	focus_mode = Control.FOCUS_NONE
	text = ""
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.add_theme_font_override(&"font", FONT_BOLD)
	label.add_theme_font_size_override(&"font_size", LABEL_SIZE)
	label.add_theme_color_override(&"font_color", OFF_FG)
	caret.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	menu.add_theme_stylebox_override(&"panel", _menu_box())
	list.add_theme_constant_override(&"separation", 0)
	pressed.connect(open)
	menu.about_to_popup.connect(_apply_field)
	menu.popup_hide.connect(_apply_field)
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


func open() -> void:
	if not is_node_ready():
		return
	var rect: Rect2 = get_global_rect()
	var wanted: Vector2 = menu.get_contents_minimum_size()
	var pos := Vector2i(int(rect.position.x), int(rect.end.y))
	menu.popup(Rect2i(pos, Vector2i(int(FIELD_SIZE.x), int(wanted.y))))
	_apply_field()


func is_open() -> bool:
	return is_node_ready() and menu.visible


func close() -> void:
	if is_node_ready():
		menu.hide()


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
	close()
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
		inner.offset_left = PAD_X
		inner.offset_right = -PAD_X
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
			lock.tiers = int(unit["upgrade_tiers"])
			lock.entitlement = CampaignTypeDefs.CAP_KEY
			lock.entitlement_tier = int(unit["min_cap"])
			lock.size_flags_vertical = SIZE_SHRINK_CENTER
			lock.take_me_there.connect(_on_take_me_there)
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
		var box: StyleBoxFlat = _flat(ON_BG if on else MENU_BG)
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			button.add_theme_stylebox_override(state, box)


func _apply_field() -> void:
	var open_now: bool = menu.visible
	caret.texture = Icons.tinted(CARET_OPEN_ID if open_now else CARET_SHUT_ID, CARET_COLOR,
		CARET_SCALE, true)
	var box := StyleBoxFlat.new()
	box.bg_color = FIELD_BG
	box.set_border_width_all(RING_PX)
	box.border_color = RING_OPEN if open_now else RING_IDLE
	box.content_margin_left = PAD_X
	box.content_margin_right = PAD_X
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		add_theme_stylebox_override(state, box)


func _unlocked(wanted: StringName) -> bool:
	return CampaignTypeDefs.unit_unlocked(wanted, _ent)


func _feature_text(unit: Dictionary) -> String:
	if StringName(unit["key"]) == CampaignTypeDefs.UNIT_INFINITE:
		return FEATURE_INFINITE
	var span: int = int(unit["days"])
	return FEATURE_LASTING % String(SPAN_NAMES.get(span, "longer"))


func _flat(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	return box


func _menu_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = MENU_BG
	box.set_border_width_all(RING_PX)
	box.border_color = RING_IDLE
	return box


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)
