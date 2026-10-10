class_name FilterPanel extends PanelContainer

#The left column of the Shop: Department, the Type section of the picked department, Price with its
#custom range and Rarity with a lock on every rarity above the entitlement. The panel holds the
#picks and nothing else: every count and every result comes from BazaarManager.

signal filters_changed
signal clear_all_requested
signal take_me_there(target: Dictionary)

const CHECK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FilterCheckRow.tscn")
const ALL_KEY: StringName = &"all"
const ALL_LABEL: String = "All Departments"
const CLEAR_TEXT: String = "Clear all filters"
const GO_TEXT: String = "Go"
const MIN_HINT: String = "Min"
const MAX_HINT: String = "Max"
const PANEL_WIDTH: float = 250.0
const ROW_HEIGHT: float = 26.0
const CHECK_HEIGHT: float = 22.0
const LOCK_HEIGHT: float = 24.0
const FIELD_HEIGHT: float = 26.0
const FIELD_WIDTH: float = 56.0
const LABEL_SIZE: int = 12
const COUNT_SIZE: int = 10
const LINK_SIZE: int = 10
const SECTION_GAP: int = 14
const ROW_GAP: int = 2
const RARITY_TIERS: int = 4
const RARITY_UPGRADE: String = "Better Items"
const RARITY_UPGRADE_ID: String = "betteritems"
const RARITY_ENTITLEMENT: String = "bazaarRarity"

@export var department: StringName = ALL_KEY:
	set(value):
		department = value
		refresh()
@export var subtypes: Dictionary = {}:
	set(value):
		subtypes = value
		refresh()
@export var price_preset: StringName = &"any":
	set(value):
		price_preset = value
		refresh()
@export var price_custom: Vector2i = Vector2i(-1, -1):
	set(value):
		price_custom = value
		refresh()
@export var rarities: Array[int] = []:
	set(value):
		rarities = value
		refresh()

var _scroll: ScrollContainer = null
var _rows: VBoxContainer = null
var _min_field: LineEdit = null
var _max_field: LineEdit = null
var _syncing: bool = false
var _search_active: bool = false


func _ready() -> void:
	custom_minimum_size.x = PANEL_WIDTH
	add_theme_stylebox_override("panel", GuiStyle.flat(GuiColors.ROW_FILL, 2, GuiColors.BLUE_LO, 12.0))
	_scroll = GuiStyle.scroll()
	add_child(_scroll)
	_rows = GuiStyle.vbox(SECTION_GAP)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	refresh()


#The filter half of a manager query; the Shop adds search and sort to it.
func query() -> Dictionary:
	return {
		"department": department_key(),
		"subtypes": checked_subtypes(),
		"rarities": rarities.duplicate(),
		"price_preset": price_preset,
		"price_custom": price_custom,
	}


func department_key() -> String:
	if department == ALL_KEY or department == &"":
		return ""
	return str(department)


func checked_subtypes() -> Array[String]:
	var out: Array[String] = []
	var held: Variant = subtypes.get(department_key(), [])
	if held is Array:
		for entry: Variant in held as Array:
			out.append(str(entry))
	return out


func pick_department(key: StringName) -> void:
	var want: StringName = key if key != &"" else ALL_KEY
	if department == want:
		return
	department = want
	_emit()


func toggle_subtype(key: String) -> void:
	var dept: String = department_key()
	if dept == "":
		return
	var held: Array[String] = checked_subtypes()
	if held.has(key):
		held.erase(key)
	else:
		held.append(key)
	subtypes[dept] = held
	refresh()
	_emit()


func pick_price(key: StringName) -> void:
	price_custom = BazaarManager.NO_CUSTOM_PRICE
	price_preset = key
	_emit()


#Either end may be -1 for an open end; the pair (-1, -1) drops back to the preset.
func set_custom_price(low: int, high: int) -> void:
	price_custom = Vector2i(low, high)
	_emit()


func toggle_rarity(index: int) -> void:
	if index < 0 or index >= BazaarManager.RARITIES.size():
		return
	if index > BazaarManager.rarity_cap():
		return
	var held: Array[int] = rarities.duplicate()
	if held.has(index):
		held.erase(index)
	else:
		held.append(index)
		held.sort()
	rarities = held
	_emit()


func clear_filters() -> void:
	_syncing = true
	department = ALL_KEY
	subtypes = {}
	price_preset = &"any"
	price_custom = BazaarManager.NO_CUSTOM_PRICE
	rarities = []
	_syncing = false
	refresh()
	_emit()


func any_active() -> bool:
	return department_key() != "" or not checked_subtypes().is_empty() \
		or price_preset != &"any" or price_custom != BazaarManager.NO_CUSTOM_PRICE \
		or not rarities.is_empty()


func custom_active() -> bool:
	return price_custom != BazaarManager.NO_CUSTOM_PRICE


func rows() -> VBoxContainer:
	return _rows


#The text the Min or Max box holds right now, for the test suite. which is "min" or "max".
func field_text(which: String) -> String:
	var field: LineEdit = _min_field if which == "min" else _max_field
	return field.text if field != null else ""


#The caret column of the Min or Max box right now, for the test suite.
func field_caret(which: String) -> int:
	var field: LineEdit = _min_field if which == "min" else _max_field
	return field.caret_column if field != null else -1


func row_for(key: String) -> Button:
	for child: Node in _all_rows():
		if child is Button and str((child as Button).get_meta("filter_key", "")) == key:
			return child as Button
	return null


func head_for(key: String) -> Label:
	for child: Node in _all_rows():
		if child is Label and str((child as Label).get_meta("filter_key", "")) == key:
			return child as Label
	return null


func lock_for(index: int) -> FeatureLock:
	for child: Node in _all_rows():
		if child is FeatureLock and int((child as FeatureLock).get_meta("rarity", -1)) == index:
			return child as FeatureLock
	return null


func has_type_section() -> bool:
	return head_for("type_head") != null


func clear_link() -> Button:
	for child: Node in _rows.get_children():
		if child is Button and not (child as Button).has_meta("filter_key"):
			return child as Button
	return null


func refresh(q: Dictionary = {}) -> void:
	if not is_node_ready() or _rows == null or _syncing:
		return
	var full: Dictionary = q if not q.is_empty() else query()
	_search_active = str(full.get("search", "")) != ""
	_syncing = true
	GuiNodes.clear(_rows)
	_build_department(full)
	_build_type(full)
	_build_price(full)
	_build_rarity(full)
	if any_active() or _search_active:
		var link: Button = BazaarUi.link(CLEAR_TEXT, GuiColors.SKY, LINK_SIZE)
		link.pressed.connect(_on_clear_pressed)
		_rows.add_child(link)
	_syncing = false


func _all_rows() -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in _rows.get_children():
		out.append(child)
		for inner: Node in child.get_children():
			out.append(inner)
	return out


func _build_department(q: Dictionary) -> void:
	_rows.add_child(_head("Department", "department_head"))
	var counts: Dictionary = BazaarManager.option_counts(q, &"department")
	var group: VBoxContainer = GuiStyle.vbox(ROW_GAP)
	_rows.add_child(group)
	group.add_child(_pick_row(ALL_LABEL, "", int(counts.get("", 0)), department_key() == "", false))
	for dept: Dictionary in BazaarManager.DEPARTMENTS:
		var key: String = str(dept["key"])
		group.add_child(_pick_row(str(dept["name"]), key, int(counts.get(key, 0)),
			department_key() == key, false))


func _build_type(q: Dictionary) -> void:
	var dept: String = department_key()
	if dept == "":
		return
	_rows.add_child(_head("%s Type" % BazaarUi.dept_label(dept), "type_head"))
	var counts: Dictionary = BazaarManager.option_counts(q, &"subtype")
	var held: Array[String] = checked_subtypes()
	var group: VBoxContainer = GuiStyle.vbox(ROW_GAP)
	_rows.add_child(group)
	for key: Variant in counts:
		var subtype: String = str(key)
		var row: FilterCheckRow = _check_row(subtype, held.has(subtype), int(counts[key]),
			GuiColors.CREAM)
		group.add_child(row)
		row.toggled.connect(_on_subtype_toggled.bind(subtype))


func _build_price(q: Dictionary) -> void:
	_rows.add_child(_head("Price", "price_head"))
	var counts: Dictionary = BazaarManager.option_counts(q, &"price")
	var group: VBoxContainer = GuiStyle.vbox(ROW_GAP)
	_rows.add_child(group)
	for row_def: Dictionary in BazaarManager.PRICE_PRESETS:
		var key: StringName = row_def["key"] as StringName
		var picked: bool = not custom_active() and price_preset == key
		group.add_child(_pick_row(str(row_def["label"]), str(key), int(counts.get(key, 0)),
			picked, true))
	var custom: HBoxContainer = GuiStyle.hbox(6)
	_rows.add_child(custom)
	_min_field = _number_field(MIN_HINT, price_custom.x)
	custom.add_child(_min_field)
	custom.add_child(GuiStyle.label("-", GuiStyle.BODY, LABEL_SIZE, GuiColors.MUTED))
	_max_field = _number_field(MAX_HINT, price_custom.y)
	custom.add_child(_max_field)
	var go: Button = BazaarUi.button(GO_TEXT, &"orange", FIELD_HEIGHT, 10)
	go.pressed.connect(_on_go_pressed)
	custom.add_child(go)


func _build_rarity(q: Dictionary) -> void:
	_rows.add_child(_head("Rarity", "rarity_head"))
	var counts: Dictionary = BazaarManager.option_counts(q, &"rarity")
	var cap: int = BazaarManager.rarity_cap()
	var group: VBoxContainer = GuiStyle.vbox(ROW_GAP)
	_rows.add_child(group)
	for index: int in range(BazaarManager.RARITIES.size()):
		var label_text: String = BazaarUi.rarity_name(index)
		if index > cap:
			var lock: FeatureLock = BazaarUi.feature_lock(label_text, RARITY_UPGRADE,
				RARITY_UPGRADE_ID, index, RARITY_TIERS, LOCK_HEIGHT)
			lock.entitlement = RARITY_ENTITLEMENT
			lock.entitlement_tier = index
			lock.set_meta("rarity", index)
			lock.take_me_there.connect(take_me_there.emit)
			group.add_child(lock)
			continue
		var row: FilterCheckRow = _check_row(label_text, rarities.has(index),
			int(counts.get(index, 0)), BazaarUi.rarity_color(index))
		row.set_meta("rarity", index)
		group.add_child(row)
		row.toggled.connect(_on_rarity_toggled.bind(index))


func _head(body_text: String, key: String) -> Label:
	var made: Label = BazaarUi.heading(body_text)
	made.set_meta("filter_key", key)
	return made


func _pick_row(body_text: String, key: String, count: int, picked: bool,
		price: bool) -> Button:
	var row: Button = Button.new()
	row.text = body_text
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_font_override("font", GuiStyle.BODY)
	row.add_theme_font_size_override("font_size", LABEL_SIZE)
	row.set_meta("filter_key", key)
	row.set_meta("price_row", price)
	var fill: Color = GuiColors.ORANGE if picked else GuiColors.ROW_HOVER
	var ink: Color = GuiColors.INK if picked else GuiColors.CREAM
	var box: StyleBoxFlat = GuiStyle.flat(fill, 0, fill, 4.0)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	GuiStyle.set_all_boxes(row, box)
	GuiStyle.set_all_font_colors(row, ink)
	var count_label: Label = GuiStyle.label(str(count), GuiStyle.BODY, COUNT_SIZE, ink)
	count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_label.offset_right = -8.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count_label)
	row.pressed.connect(_on_row_pressed.bind(key, price))
	return row


func _check_row(body_text: String, on: bool, count: int, tint: Color) -> FilterCheckRow:
	var row: FilterCheckRow = CHECK_SCENE.instantiate() as FilterCheckRow
	row.label = body_text
	row.on = on
	row.custom_minimum_size.y = CHECK_HEIGHT
	row.set_meta("filter_key", body_text)
	var count_label: Label = GuiStyle.label(str(count), GuiStyle.BODY, COUNT_SIZE, GuiColors.MUTED)
	count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_label.offset_right = -4.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count_label)
	row.add_theme_color_override("font_color", tint)
	row.add_theme_color_override("font_hover_color", tint)
	row.add_theme_color_override("font_pressed_color", tint)
	return row


func _number_field(hint: String, value: int) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.placeholder_text = hint
	field.text = "" if value < 0 else str(value)
	field.custom_minimum_size = Vector2(FIELD_WIDTH, FIELD_HEIGHT)
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_override("font", GuiStyle.BODY)
	field.add_theme_font_size_override("font_size", LABEL_SIZE)
	field.add_theme_color_override("font_color", GuiColors.CREAM)
	var ring: Color = GuiColors.ORANGE if custom_active() else GuiColors.BLUE_HI
	field.add_theme_stylebox_override("normal", GuiStyle.flat(GuiColors.INK, 2, ring, 4.0))
	field.add_theme_stylebox_override("focus", GuiStyle.flat(GuiColors.INK, 2, GuiColors.ORANGE, 4.0))
	field.text_submitted.connect(_on_field_submitted)
	field.text_changed.connect(_on_number_text_changed.bind(field))
	return field


func _digits(field: LineEdit) -> int:
	if field == null:
		return -1
	var cleaned: String = ""
	for i: int in range(field.text.length()):
		var glyph: String = field.text.substr(i, 1)
		if glyph.is_valid_int():
			cleaned += glyph
	if cleaned == "":
		return -1
	return int(cleaned)


func _emit() -> void:
	filters_changed.emit()


func _on_row_pressed(key: String, price: bool) -> void:
	if _syncing:
		return
	if price:
		pick_price(StringName(key))
		return
	pick_department(StringName(key))


func _on_subtype_toggled(_on_now: bool, key: String) -> void:
	if _syncing:
		return
	toggle_subtype(key)


func _on_rarity_toggled(_on_now: bool, index: int) -> void:
	if _syncing:
		return
	toggle_rarity(index)


func _on_go_pressed() -> void:
	set_custom_price(_digits(_min_field), _digits(_max_field))


func _on_field_submitted(_submitted: String) -> void:
	_on_go_pressed()


func _on_number_text_changed(new_text: String, field: LineEdit) -> void:
	var caret: int = field.caret_column
	var cleaned: String = ""
	var new_caret: int = caret
	for i: int in range(new_text.length()):
		var glyph: String = new_text.substr(i, 1)
		if glyph.is_valid_int():
			cleaned += glyph
		elif i < caret:
			new_caret -= 1
	if cleaned == new_text:
		return
	field.text = cleaned
	field.caret_column = new_caret


#Drives the Min or Max field the way typing would, for the test suite. which is "min" or "max".
func type_field(which: String, text: String) -> void:
	var field: LineEdit = _min_field if which == "min" else _max_field
	if field == null:
		return
	field.text = text
	field.caret_column = text.length()
	_on_number_text_changed(text, field)


func _on_clear_pressed() -> void:
	clear_all_requested.emit()
