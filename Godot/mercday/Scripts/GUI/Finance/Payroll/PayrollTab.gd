class_name PayrollTab extends FinancePage

#The Payroll page of the Finance Viewer: what the guild owes this month, when it is due, the roster
#with sort, direction and status filter, and the Employee Benefits column. Every wage, bonus and
#policy write leaves through BenefitsManager; the page only reads and draws.

const STYLE_PANEL: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_panel.tres")
const STYLE_EMPTY: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_empty.tres")
const ITEM_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/PayrollItem.tscn")
const BENEFIT_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/BenefitDialog.tscn")
const VACATION_SCENE: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/VacationDialog.tscn")

const LEFT_WIDTH: float = 348.0
const COLUMN_GAP: int = 16
const TOOL_HEIGHT: float = 26.0
const TITLE_TEXT: String = "Mercs"
const EMPTY_TEXT: String = "No mercs match this filter."
const PAYROLL_LABEL: String = "Payroll"
const PAYDAY_LABEL: String = "Next Payday In..."

#The four sort rows of the toolbar; every key runs from the highest value down and the ascending
#direction reverses the list.
const SORT_KEYS: Array[String] = ["salary", "guild", "level", "name"]
const SORT_LABELS: Array[String] = ["Salary", "Guild Opinion", "Level", "Name A-Z"]
#The filter row each merc status answers to; an odd job is shown by the loan row, a preparing merc by the
#contract row and a defector by the fired row.
const ROW_OF_STATUS: Dictionary = {
	GuiTypes.MercStatus.AVAILABLE: 0,
	GuiTypes.MercStatus.RESTING: 1,
	GuiTypes.MercStatus.CONTRACT: 2,
	GuiTypes.MercStatus.PREPARING: 2,
	GuiTypes.MercStatus.VACATION: 3,
	GuiTypes.MercStatus.LOAN: 4,
	GuiTypes.MercStatus.ODD_JOB: 4,
	GuiTypes.MercStatus.DEAD: 5,
	GuiTypes.MercStatus.FIRED: 6,
	GuiTypes.MercStatus.DEFECTED: 6,
	GuiTypes.MercStatus.MISSING: 7,
	GuiTypes.MercStatus.CAPTURED: 8,
}

@onready var columns: HBoxContainer = $Columns
@onready var left: VBoxContainer = $Columns/Left
@onready var stats: GridContainer = $Columns/Left/Stats
@onready var payroll_tile: StatTile = $Columns/Left/Stats/PayrollTile
@onready var payday_tile: StatTile = $Columns/Left/Stats/PaydayTile
@onready var mercs_panel: PanelContainer = $Columns/Left/Mercs
@onready var panel_rows: VBoxContainer = $Columns/Left/Mercs/Rows
@onready var head: SectionHead = $Columns/Left/Mercs/Rows/Head
@onready var toolbar: HBoxContainer = $Columns/Left/Mercs/Rows/Toolbar
@onready var sort_button: SortButton = $Columns/Left/Mercs/Rows/Toolbar/Sort
@onready var dir_toggle: SortDirToggle = $Columns/Left/Mercs/Rows/Toolbar/Direction
@onready var filter_button: FilterButton = $Columns/Left/Mercs/Rows/Toolbar/Filter
@onready var scroll: PaddedScroll = $Columns/Left/Mercs/Rows/Scroll
@onready var empty_box: PanelContainer = $Columns/Left/Mercs/Rows/Empty
@onready var empty_label: Label = $Columns/Left/Mercs/Rows/Empty/EmptyLabel
@onready var benefits_panel: BenefitsPanel = $Columns/Benefits
@onready var tip: PayrollTooltip = $Tip
@onready var salary: SalaryDialog = $Salary

var _rows: Array[Dictionary] = []
var _items: Array[PayrollItem] = []
var _sort: int = 0
var _benefit_dialog: BenefitDialog = null
var _vacation_dialog: VacationDialog = null


func _ready() -> void:
	mercs_panel.add_theme_stylebox_override("panel", STYLE_PANEL)
	empty_box.add_theme_stylebox_override("panel", STYLE_EMPTY)
	_style()
	_build_modals()
	sort_button.sort_changed.connect(_on_sort_changed)
	dir_toggle.direction_changed.connect(_on_direction_changed)
	filter_button.changed.connect(_on_filter_changed)
	sort_button.pressed.connect(_on_sort_opened)
	filter_button.pressed.connect(_on_filter_opened)
	benefits_panel.adjust_pressed.connect(_on_adjust_pressed)
	benefits_panel.edit_pressed.connect(_on_edit_pressed)
	salary.confirmed.connect(_on_salary_closed)
	salary.cancelled.connect(_on_salary_cancelled)
	salary.fired.connect(_on_merc_fired)
	BenefitsManager.changed.connect(mark_dirty)
	GameState.money_changed.connect(mark_dirty.unbind(1))
	GameState.roster_changed.connect(mark_dirty)
	GameState.day_changed.connect(mark_dirty.unbind(1))
	SubscriptionManager.changed.connect(mark_dirty)
	refresh()


func _notification(what: int) -> void:
	if what != NOTIFICATION_EXIT_TREE:
		return
	_drop_modal(_benefit_dialog)
	_drop_modal(_vacation_dialog)
	_benefit_dialog = null
	_vacation_dialog = null


#The public redraw the tests and the page handlers call; the base calls _refresh for a dirty page.
func refresh() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_dirty = false
	_fill_stats()
	_fill_count()
	_rows = _visible_rows()
	_build_list()
	_style_filter()
	benefits_panel.refresh()


func sort_key() -> String:
	return SORT_KEYS[_sort] if _sort >= 0 and _sort < SORT_KEYS.size() else SORT_KEYS[0]


func set_sort(key: String) -> void:
	var at: int = SORT_KEYS.find(key)
	if at < 0:
		return
	_sort = at
	if is_node_ready():
		sort_button.selected = at
	refresh()


func descending() -> bool:
	return dir_toggle.descending if is_node_ready() else true


func set_descending(on: bool) -> void:
	if not is_node_ready() or dir_toggle.descending == on:
		return
	dir_toggle.descending = on
	refresh()


func status_shown(status: int) -> bool:
	var at: int = _row_of_status(status)
	return at >= 0 and is_node_ready() and filter_button.is_on(at)


func set_status_shown(status: int, on: bool) -> void:
	var at: int = _row_of_status(status)
	if at < 0 or not is_node_ready() or filter_button.is_on(at) == on:
		return
	filter_button.toggle(at)
	refresh()


func reset_filter() -> void:
	if not is_node_ready():
		return
	filter_button.reset()
	refresh()


#True while the shown set differs from the default set, which is what turns the button orange.
func filter_active() -> bool:
	if not is_node_ready():
		return false
	for i: int in FilterButton.LABELS.size():
		if filter_button.is_on(i) != FilterButton.DEFAULTS[i]:
			return true
	return false


func row_count() -> int:
	return _rows.size()


func row_uid(index: int) -> int:
	if index < 0 or index >= _rows.size():
		return 0
	return int(_rows[index].get("uid", 0))


func row_text(index: int, key: String) -> String:
	if index < 0 or index >= _items.size():
		return ""
	return _items[index].text(key)


func row_color(index: int, key: String) -> Color:
	if index < 0 or index >= _items.size():
		return GuiColors.CREAM
	return _items[index].color(key)


func empty_text() -> String:
	return empty_label.text if is_node_ready() and empty_box.visible else ""


func count_text() -> String:
	return head.count_text if is_node_ready() else ""


func stat_text(key: String) -> String:
	if not is_node_ready():
		return ""
	match key:
		"payroll":
			return str(payroll_tile.amount)
		"payday":
			return payday_tile.value_text
		_:
			return ""


func stat_color(key: String) -> Color:
	if not is_node_ready():
		return GuiColors.CREAM
	match key:
		"payroll":
			return payroll_tile.value_color
		"payday":
			return payday_tile.value_color
		_:
			return GuiColors.CREAM


func press_row(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_items[index].press_row()


func hover_row(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_on_row_hovered(_items[index].uid())


func clear_hover() -> void:
	tip.hide_tip()


func tooltip() -> PayrollTooltip:
	return tip


func benefits() -> BenefitsPanel:
	return benefits_panel


func salary_dialog() -> SalaryDialog:
	return salary


func benefit_dialog() -> BenefitDialog:
	return _benefit_dialog


func vacation_dialog() -> VacationDialog:
	return _vacation_dialog


func _build_modals() -> void:
	var host: Control = modal_host()
	_benefit_dialog = BENEFIT_SCENE.instantiate() as BenefitDialog
	_vacation_dialog = VACATION_SCENE.instantiate() as VacationDialog
	for box: Control in [_benefit_dialog, _vacation_dialog]:
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.add_child(box)
	_benefit_dialog.confirmed.connect(_on_benefit_confirmed)
	_vacation_dialog.confirmed.connect(_on_vacation_confirmed)


func _drop_modal(box: Control) -> void:
	if box == null or not is_instance_valid(box):
		return
	box.visible = false
	if box.get_parent() != null and box.get_parent() != self:
		box.get_parent().remove_child(box)
	box.queue_free()


func _fill_stats() -> void:
	payroll_tile.label = PAYROLL_LABEL
	payroll_tile.compact = true
	payroll_tile.show_glyph = true
	payroll_tile.value_text = ""
	payroll_tile.value_color = GuiColors.RED
	payroll_tile.amount = BenefitsManager.payroll_total()
	payday_tile.label = PAYDAY_LABEL
	payday_tile.compact = true
	payday_tile.show_glyph = false
	payday_tile.amount = 0
	payday_tile.value_color = BenefitsManager.payday_color()
	payday_tile.value_text = BenefitsManager.payday_text()


func _fill_count() -> void:
	var employed: int = SubscriptionManager.employed()
	head.count_text = "%d/%d" % [employed, _max_mercs()]


func _max_mercs() -> int:
	var seen: Dictionary = SubscriptionManager.entitlements()
	return int(seen.get("maxMercs", 0))


func _visible_rows() -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for row: Dictionary in BenefitsManager.payroll_rows():
		if status_shown(int(row.get("status", 0))):
			kept.append(row)
	kept.sort_custom(_before.bind(sort_key()))
	if not descending():
		kept.reverse()
	return kept


#Highest first on every key, with the name row running A to Z; the toggle reverses the whole list.
static func _before(a: Dictionary, b: Dictionary, key: String) -> bool:
	match key:
		"guild":
			return int(a.get("opinion", 0)) > int(b.get("opinion", 0))
		"level":
			return int(a.get("level", 0)) > int(b.get("level", 0))
		"name":
			return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0
		_:
			return int(a.get("salary", 0)) > int(b.get("salary", 0))


func _build_list() -> void:
	while _items.size() > _rows.size():
		var last: PayrollItem = _items.pop_back()
		scroll.items.remove_child(last)
		last.queue_free()
	while _items.size() < _rows.size():
		var made: PayrollItem = ITEM_SCENE.instantiate() as PayrollItem
		scroll.items.add_child(made)
		made.row_pressed.connect(_on_row_pressed)
		made.row_hovered.connect(_on_row_hovered)
		made.row_left.connect(_on_row_left)
		_items.append(made)
	for i: int in _items.size():
		_items[i].set_row(_rows[i])
	var any: bool = not _rows.is_empty()
	scroll.visible = any
	empty_box.visible = not any
	if not any:
		tip.hide_tip()


func _row_of_status(status: int) -> int:
	return int(ROW_OF_STATUS.get(status, -1))


func _item_of(uid: int) -> PayrollItem:
	for item: PayrollItem in _items:
		if item.uid() == uid:
			return item
	return null


func _on_row_pressed(uid: int) -> void:
	tip.hide_tip()
	salary.open_for_uid(uid)


func _on_row_hovered(uid: int) -> void:
	var item: PayrollItem = _item_of(uid)
	if item == null:
		return
	tip.show_for(uid, Rect2(item.global_position - global_position, item.size))


func _on_row_left(_uid: int) -> void:
	tip.hide_tip()


func _on_sort_changed(index: int) -> void:
	_sort = clampi(index, 0, SORT_KEYS.size() - 1)
	refresh()


func _on_direction_changed(_down: bool) -> void:
	refresh()


func _on_filter_changed(_states: Dictionary) -> void:
	refresh()


func _on_sort_opened() -> void:
	filter_button.menu.hide()


func _on_filter_opened() -> void:
	sort_button.menu.hide()


func _on_adjust_pressed(key: String) -> void:
	if _benefit_dialog != null:
		_benefit_dialog.open_for(key)


func _on_edit_pressed() -> void:
	if _vacation_dialog != null:
		_vacation_dialog.open()


func _on_benefit_confirmed(_key: String, _value: int) -> void:
	refresh()


func _on_vacation_confirmed(_values: Dictionary) -> void:
	refresh()


func _on_salary_closed(_new_salary: int, _opinion_delta: int) -> void:
	refresh()


func _on_salary_cancelled() -> void:
	tip.hide_tip()


func _on_merc_fired(_uid: int) -> void:
	refresh()


func _style_filter() -> void:
	filter_button.apply_palette(&"orange" if filter_active() else filter_button.kind)


func _style() -> void:
	columns.add_theme_constant_override("separation", COLUMN_GAP)
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0.0)
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 8)
	panel_rows.add_theme_constant_override("separation", 12)
	toolbar.add_theme_constant_override("separation", 8)
	head.caption = TITLE_TEXT
	GuiStyle.paint(head.caption_label, GuiStyle.SILK_BOLD, 13, GuiColors.ORANGE)
	head.count_label.size_flags_vertical = Control.SIZE_FILL
	empty_label.text = EMPTY_TEXT
	GuiStyle.paint(empty_label, GuiStyle.BODY, 14, GuiColors.SKY)
	sort_button.options = SORT_LABELS.duplicate()
	sort_button.selected = _sort
	sort_button.custom_minimum_size = Vector2(0.0, TOOL_HEIGHT)
	sort_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_button.custom_minimum_size = Vector2(0.0, TOOL_HEIGHT)
