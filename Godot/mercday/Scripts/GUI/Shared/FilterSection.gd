class_name FilterSection extends VBoxContainer

#One row of a TraitFilterDefs table, rendered by its kind and nothing else: no screen carries a
#per-trait branch. A row the guild is not entitled to keeps its title and shows a FeatureLock in
#place of its body, and hands any Take Me There press up to the panel above it.

signal value_changed(key: StringName, value: Variant)
signal take_me_there(target: Dictionary)

const TITLE_SIZE: int = 9
const TITLE_COLOR: Color = GuiColors.SKY
const TITLE_LOCKED: Color = GuiColors.MUTED
const VALUE_SIZE: int = 11
const VALUE_COLOR: Color = GuiColors.AMBER
const LOCK_HEIGHT: float = 30.0
const LOCK_FONT_SIZE: int = 9
const BAND_HEIGHT: float = 16.0
const MODS_BOX_HEIGHT: float = 260.0
const MODS_COLUMNS: int = 2
const MODS_GAP: int = 8
const MODS_PAD: int = 14
const ROW_GAP: int = 6
const PICK_ONE_NOTE: String = ", pick 1"
const STRIP_PREFIXES: Array[String] = ["Min ", "Avoid "]
const STYLE_MODS_BOX: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_mods_box.tres")
const STYLE_BAND: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_tile_stat.tres")
const FONT_TITLE: Font = GuiStyle.SILK
const FONT_VALUE: Font = GuiStyle.SILK_BOLD
const CHIPS_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/ChipRow.tscn")
const TILE_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/ModuleTile.tscn")
const STARS_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/StarRangePicker.tscn")
const DUAL_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/DualSlider.tscn")
const PIXEL_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/PixelSlider.tscn")

#What a lock says the guild would be able to do: "filter by" on the Hiring list, "target" in a
#campaign builder.
@export var lock_verb: String = "filter by"
#The atlas scale a stars2 section hands its picker: 1 in the 290 px filter column, 2 where the
#host gives the picker its full 452 px.
@export var star_scale: int = StarRangePicker.DEFAULT_STAR_SCALE:
	set(value):
		star_scale = maxi(1, value)
		if _stars != null:
			_stars.star_scale = star_scale

#True when the section is a sub-module of a group: its title sits on a band over the body.
var banded: bool = false:
	set(value):
		banded = value
		_apply_band()

@onready var title_label: Label = $Title
@onready var lock: FeatureLock = $Lock
@onready var body: VBoxContainer = $Body

var _def: Dictionary = {}
var _ents: Dictionary = {}
var _value: Variant = null
var _locked: bool = false
var _chips: ChipRow = null
var _stars: StarRangePicker = null
var _dual: DualSlider = null
var _pixel: PixelSlider = null
var _tiles: Array[ModuleTile] = []
var _low_label: Label = null
var _high_label: Label = null


func _ready() -> void:
	add_theme_constant_override(&"separation", ROW_GAP)
	title_label.add_theme_font_override(&"font", FONT_TITLE)
	title_label.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if banded:
		_apply_band()
	lock.take_me_there.connect(_on_take_me_there)
	if not _def.is_empty():
		_build()


#The one entry point: a def row, the value it holds and the entitlement table to read it by.
func setup(def: Dictionary, held: Variant, ents: Dictionary = {}) -> void:
	_def = def
	_ents = ents if not ents.is_empty() else SubscriptionManager.entitlements()
	_value = _normalize(held)
	if is_node_ready():
		_build()


func def_key() -> StringName:
	return StringName(_def.get("key", &""))


func kind() -> String:
	return String(_def.get("kind", ""))


func is_locked() -> bool:
	return _locked


func value() -> Variant:
	return (_value as Array).duplicate() if _value is Array else _value


#Writes a value in without reporting it, the path a panel takes when it loads stored filters.
func set_value(v: Variant) -> void:
	_value = _normalize(v)
	_push_value()


#Writes a value in and reports it, the path a click takes and the one a headless test uses.
func press_value(v: Variant) -> void:
	set_value(v)
	_emit()


func is_active() -> bool:
	return not _locked and TraitFilterDefs.active(_def, _value)


func chip_row() -> ChipRow:
	return _chips


func tiles() -> Array[ModuleTile]:
	return _tiles


func star_picker() -> StarRangePicker:
	return _stars


func dual_slider() -> DualSlider:
	return _dual


func min_slider() -> PixelSlider:
	return _pixel


func section_lock() -> FeatureLock:
	return lock


func title_text() -> String:
	return title_label.text


#The default a cleared row falls back to: the widest range, or nothing picked.
static func default_value(def: Dictionary) -> Variant:
	var of_kind: String = String(def.get("kind", ""))
	if of_kind == TraitFilterDefs.KIND_SLIDER2 or of_kind == TraitFilterDefs.KIND_RANGE:
		return [float(def.get("min", 0.0)), float(def.get("max", 0.0))]
	if of_kind == TraitFilterDefs.KIND_STARS2:
		return [TraitFilterDefs.MIN_STARS, TraitFilterDefs.MAX_STARS]
	if of_kind == TraitFilterDefs.KIND_MIN:
		return float(def.get("min", 0.0))
	if of_kind == TraitFilterDefs.KIND_ONE:
		return null
	return []


func _build() -> void:
	_clear_body()
	_locked = TraitFilterDefs.locked(_def, _ents)
	title_label.text = _title()
	title_label.add_theme_color_override(&"font_color", TITLE_LOCKED if _locked else TITLE_COLOR)
	body.visible = not _locked
	if _locked:
		_apply_lock()
		return
	_clear_lock()
	match kind():
		TraitFilterDefs.KIND_TRAD:
			_build_chips(true, true)
		TraitFilterDefs.KIND_CHIPS:
			_build_chips(true, false)
		TraitFilterDefs.KIND_ONE:
			_build_chips(false, false)
		TraitFilterDefs.KIND_MODS:
			_build_mods()
		TraitFilterDefs.KIND_STARS2:
			_build_stars()
		TraitFilterDefs.KIND_SLIDER2, TraitFilterDefs.KIND_RANGE:
			_build_dual()
		TraitFilterDefs.KIND_MIN:
			_build_min()
	_push_value()


func _apply_band() -> void:
	if title_label == null:
		return
	if banded:
		title_label.add_theme_stylebox_override(&"normal", STYLE_BAND)
		title_label.custom_minimum_size.y = BAND_HEIGHT
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		title_label.remove_theme_stylebox_override(&"normal")
		title_label.custom_minimum_size.y = 0.0
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _title() -> String:
	var text: String = String(_def.get("label", ""))
	if kind() == TraitFilterDefs.KIND_ONE or (kind() == TraitFilterDefs.KIND_MODS and _single()):
		text += PICK_ONE_NOTE
	return text


func _single() -> bool:
	return bool(_def.get("single", false))


#The feature a lock names: the label without the "Min " or "Avoid " a filter row leads with.
func _feature() -> String:
	var text: String = String(_def.get("label", ""))
	for prefix: String in STRIP_PREFIXES:
		if text.begins_with(prefix):
			return text.substr(prefix.length())
	return text


func _apply_lock() -> void:
	lock.apply_props(_lock_props(_def, _feature()))
	lock.required_plan = SubscriptionManager.Plan.ENTERPRISE
	lock.label = "Locked"
	lock.height = LOCK_HEIGHT
	lock.font_size = LOCK_FONT_SIZE
	lock.always_visible = true
	lock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock.visible = true


#An unlocked row pins its lock shut so no later plan change pops it back into the layout.
func _clear_lock() -> void:
	lock.always_visible = false
	lock.upgrade_id = ""
	lock.entitlement = ""
	lock.required_plan = SubscriptionManager.Plan.FREE
	lock.plan = "Mercday Free"
	lock.visible = false


func _build_chips(multi: bool, dots: bool) -> void:
	_chips = CHIPS_SCENE.instantiate() as ChipRow
	_chips.multi = multi
	_chips.options = _chip_options(dots)
	body.add_child(_chips)
	_chips.selection_changed.connect(_on_chips_changed)


func _chip_options(dots: bool) -> Array[Dictionary]:
	var labels: Array = _def.get("options", [])
	var values: Array = _def.get("values", [])
	var blocked: Array = _def.get("options_disabled", [])
	var notes: Array = _def.get("options_notes", [])
	var out: Array[Dictionary] = []
	for i: int in range(labels.size()):
		var label: String = String(labels[i])
		var row: Dictionary = {
			"key": values[i] if i < values.size() else i,
			"label": label,
			"enabled": not (i < blocked.size() and bool(blocked[i])),
			"note": String(notes[i]) if i < notes.size() else "",
		}
		if dots:
			row["color"] = GuiTypes.tradition_color(label)
		out.append(row)
	return out


func _build_mods() -> void:
	var box: PanelContainer = PanelContainer.new()
	box.name = "ModsBox"
	box.add_theme_stylebox_override(&"panel", STYLE_MODS_BOX)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0.0, MODS_BOX_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var pad: MarginContainer = MarginContainer.new()
	pad.name = "Pad"
	pad.add_theme_constant_override(&"margin_top", MODS_PAD)
	pad.add_theme_constant_override(&"margin_right", MODS_PAD)
	pad.add_theme_constant_override(&"margin_bottom", MODS_PAD)
	pad.add_theme_constant_override(&"margin_left", MODS_PAD)
	scroll.add_child(pad)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Grid"
	grid.columns = MODS_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", MODS_GAP)
	grid.add_theme_constant_override(&"v_separation", MODS_GAP)
	pad.add_child(grid)
	body.add_child(box)
	var mods: Array = _def.get("mods", [])
	var values: Array = _def.get("values", [])
	var open: bool = bool(_ents.get("clientOpinion", false))
	for i: int in range(mods.size()):
		var row: Dictionary = mods[i]
		var tile: ModuleTile = TILE_SCENE.instantiate() as ModuleTile
		tile.key = values[i] if i < values.size() else i
		tile.label = String(row.get("name", ""))
		tile.image_note = String(row.get("image", ""))
		tile.received = int(row.get("received", 0))
		tile.completed = int(row.get("completed", 0))
		tile.failed = int(row.get("failed", 0))
		tile.relationship = int(row.get("relationship", 0)) \
			if bool(row.get("has_relationship", false)) else ModuleTile.NO_RELATION
		tile.relationship_open = open
		tile.disabled_reason = String(row.get("disabled_reason", "")) \
			if bool(row.get("disabled", false)) else ""
		tile.single = _single()
		grid.add_child(tile)
		tile.pressed_tile.connect(_on_tile_pressed)
		_tiles.append(tile)


func _build_stars() -> void:
	_stars = STARS_SCENE.instantiate() as StarRangePicker
	_stars.star_scale = star_scale
	_stars.row_locks = _row_lock_props()
	body.add_child(_stars)
	_stars.range_changed.connect(_on_pair_changed)
	_stars.take_me_there.connect(_on_take_me_there)


#One entry per star row, Min first: empty when the row is readable, the lock copy when it is not.
func _row_lock_props() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: Array = _def.get("row_locks", [])
	for row: int in range(StarRangePicker.ROW_LABELS.size()):
		var row_name: String = StarRangePicker.ROW_LABELS[row]
		var props: Dictionary = {}
		for entry: Variant in rows:
			var lock_row: Dictionary = entry
			if String(lock_row.get("label", "")) != row_name:
				continue
			if not TraitFilterDefs.locked(lock_row, _ents):
				continue
			props = _lock_props(lock_row, "%s %s" % [row_name, _feature()])
		out.append(props)
	return out


#The FeatureLock props of a def or a row lock entry.
func _lock_props(src: Dictionary, feature_text: String) -> Dictionary:
	var upgrade_id: String = String(src.get("upgrade_id", ""))
	return {
		"feature": feature_text,
		"entitlement": String(src.get("lock", "")),
		"entitlement_tier": maxi(1, int(src.get("lock_tier", 1))),
		"upgrade": UpgradeDefs.display_name(upgrade_id),
		"upgrade_id": upgrade_id,
		"tier": maxi(1, int(src.get("upgrade_tier", 1))),
		"tiers": UpgradeDefs.display_tiers(upgrade_id),
		"verb": lock_verb,
	}


func _build_dual() -> void:
	_dual = DUAL_SCENE.instantiate() as DualSlider
	_dual.min_value = float(_def.get("min", 0.0))
	_dual.max_value = float(_def.get("max", 0.0))
	_dual.step = float(_def.get("step", 1.0))
	if String(_def.get("curve", "")) == TraitFilterDefs.CURVE_SALARY:
		_dual.curve = SalaryCurve.new()
	body.add_child(_dual)
	_dual.range_changed.connect(_on_pair_changed)
	_build_value_row(true)


func _build_min() -> void:
	_pixel = PIXEL_SCENE.instantiate() as PixelSlider
	_pixel.min_value = float(_def.get("min", 0.0))
	_pixel.max_value = float(_def.get("max", 0.0))
	_pixel.step = float(_def.get("step", 1.0))
	body.add_child(_pixel)
	_pixel.value_changed.connect(_on_min_changed)
	_build_value_row(false)


func _build_value_row(pair: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Values"
	_low_label = _value_label(HORIZONTAL_ALIGNMENT_LEFT)
	row.add_child(_low_label)
	if pair:
		_high_label = _value_label(HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(_high_label)
	body.add_child(row)


func _value_label(align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.name = "Low" if align == HORIZONTAL_ALIGNMENT_LEFT else "High"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = align
	GuiStyle.paint(label, FONT_VALUE, VALUE_SIZE, VALUE_COLOR)
	return label


#The number as the prototype prints it: thousands grouped, then the unit of the row.
func _format(v: float) -> String:
	var whole: int = int(roundf(v))
	var text: String = str(absi(whole))
	var out: String = ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	out = text + out
	if whole < 0:
		out = "-" + out
	return out + String(_def.get("unit", ""))


func _push_value() -> void:
	if _locked:
		return
	if _chips != null:
		_chips.set_selected(_selection())
	if not _tiles.is_empty():
		_mark_tiles()
	if _stars != null:
		var pair: Array = _pair()
		_stars.set_range(float(pair[0]), float(pair[1]))
	if _dual != null:
		var span: Array = _pair()
		_dual.set_range_silent(float(span[0]), float(span[1]))
		_low_label.text = _format(_dual.low)
		_high_label.text = _format(_dual.high)
	if _pixel != null:
		_pixel.set_value_silent(float(_value))
		_low_label.text = "%s+" % _format(_pixel.value)


func _selection() -> Array:
	if _value is Array:
		return (_value as Array).duplicate()
	return [] if _value == null else [_value]


func _pair() -> Array:
	if _value is Array and (_value as Array).size() >= 2:
		return _value
	return default_value(_def)


func _mark_tiles() -> void:
	var picked: Array = _selection()
	for tile: ModuleTile in _tiles:
		tile.set_selected(picked.has(tile.key))


func _clear_body() -> void:
	GuiNodes.clear(body)
	_chips = null
	_stars = null
	_dual = null
	_pixel = null
	_low_label = null
	_high_label = null
	_tiles.clear()


func _on_chips_changed(selected: Array) -> void:
	if kind() == TraitFilterDefs.KIND_ONE:
		_value = selected[0] if not selected.is_empty() else null
	else:
		_value = selected.duplicate()
	_emit()


func _on_tile_pressed(key: Variant) -> void:
	var picked: Array = _selection()
	if picked.has(key):
		picked.erase(key)
	elif _single():
		picked = [key]
	else:
		picked.append(key)
	_value = picked
	_mark_tiles()
	_emit()


func _on_pair_changed(low: float, high: float) -> void:
	_value = [low, high]
	if _dual != null:
		_low_label.text = _format(low)
		_high_label.text = _format(high)
	_emit()


func _on_min_changed(v: float) -> void:
	_value = v
	_low_label.text = "%s+" % _format(v)
	_emit()


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)


func _emit() -> void:
	value_changed.emit(def_key(), value())


func _normalize(v: Variant) -> Variant:
	var of_kind: String = kind()
	if of_kind == TraitFilterDefs.KIND_ONE:
		return v
	if of_kind == TraitFilterDefs.KIND_MIN:
		return float(v) if v is float or v is int else default_value(_def)
	if of_kind == TraitFilterDefs.KIND_SLIDER2 or of_kind == TraitFilterDefs.KIND_RANGE \
			or of_kind == TraitFilterDefs.KIND_STARS2:
		if v is Array and (v as Array).size() >= 2:
			var pair: Array = v
			return [float(pair[0]), float(pair[1])]
		return default_value(_def)
	return (v as Array).duplicate() if v is Array else []
