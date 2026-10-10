class_name MercList extends ListPanel

#The roster column: a sort header over one MercListItem per living merc, with the Hire tile riding
#as the last module under them. The viewer owns the selection; the list only reports the row that
#was pressed and re-sorts on demand. Captured mercs, held by a contract or by the law, join the
#rows only while Show captives is ticked.

enum Sort {AVAILABLE, NAME, TRADITION, LEVEL, SALARY, GUILD, EMPLOYMENT}

const SORT_OPTIONS: Array[String] = ["Available", "Name A-Z", "Tradition A-Z", "Level", "Salary",
	"Guild Opinion", "Employment Length"]
const LIST_WIDTH: int = 272
const ITEM_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/MercListItem.tscn")
const SHOW_CAPTIVES: String = "Show captives"

signal merc_selected(uid: int)

@onready var sort_button: SortButton = $Pad/Rows/Tools/Sort
@onready var dir_toggle: SortDirToggle = $Pad/Rows/Tools/Dir
@onready var filter: FilterButton = $Pad/Rows/Tools/Filter
@onready var hire: HireButton = $Pad/Rows/Hire

var views: Array[MercView] = []
var captive_views: Array[MercView] = []
var selected_uid: int = 0

var _captives_row: FilterCheckRow = null


func _ready() -> void:
	super()
	custom_minimum_size = Vector2(LIST_WIDTH, 0)
	sort_button.options = SORT_OPTIONS.duplicate()
	sort_button.selected = Sort.AVAILABLE
	sort_button.sort_changed.connect(_on_sort_changed)
	dir_toggle.descending = true
	dir_toggle.direction_changed.connect(_on_direction_changed)
	_captives_row = filter.add_option(SHOW_CAPTIVES, false)
	filter.changed.connect(_on_filter_changed)
	_rebuild()


func set_views(new_views: Array[MercView], new_captives: Array[MercView] = []) -> void:
	views = new_views.duplicate()
	captive_views = new_captives.duplicate()
	_rebuild()


#Fresh views for the rows already up, so the strip, the time tag and the badge follow the clock.
#A uid with no row waits for the rebuild that a roster change brings.
func update_views(new_views: Array[MercView], new_captives: Array[MercView] = []) -> void:
	views = new_views.duplicate()
	captive_views = new_captives.duplicate()
	for row: MercListItem in rows():
		var view: MercView = view_by_uid(row.uid)
		if view != null:
			row.set_view(view)


func select(uid: int) -> void:
	selected_uid = uid
	for row: MercListItem in rows():
		row.is_selected = row.uid == uid


#The status rows of the filter filter nothing yet; only Show captives changes the rows.
func filter_button() -> FilterButton:
	return filter


func showing_captives() -> bool:
	return _captives_row != null and _captives_row.on


#The views the rows draw from: the roster and the captives, less every Captured merc while they are hidden.
func shown() -> Array[MercView]:
	var out: Array[MercView] = []
	var all: bool = showing_captives()
	for view: MercView in views + captive_views:
		if all or view.shown_status() != GuiTypes.MercStatus.CAPTURED:
			out.append(view)
	return out


func view_by_uid(uid: int) -> MercView:
	return MercView.by_uid(shown(), uid)


#The Hire tile gates itself, so the viewer only takes its press.
func hire_button() -> HireButton:
	return hire


func rows() -> Array[MercListItem]:
	var out: Array[MercListItem] = []
	if not is_node_ready():
		return out
	out.assign(GuiNodes.children_of(items(), MercListItem))
	return out


func row_count() -> int:
	return rows().size()


func sort_mode() -> int:
	return sort_button.selected if is_node_ready() else Sort.AVAILABLE


func descending() -> bool:
	return dir_toggle.descending if is_node_ready() else true


func order() -> Array[MercView]:
	return sorted(shown(), sort_mode(), descending())


#Available puts the ready mercs first, the text modes read A to Z while ascending and the numeric
#modes read high to low while descending. Every tie falls back to the name, A to Z.
static func sorted(source: Array[MercView], mode: int, down: bool) -> Array[MercView]:
	var out: Array[MercView] = source.duplicate()
	out.sort_custom(func(a: MercView, b: MercView) -> bool: return _before(a, b, mode, down))
	return out


static func _before(a: MercView, b: MercView, mode: int, down: bool) -> bool:
	if mode == Sort.NAME:
		return ListPanel.sorted_before(a.name, b.name, down, "", "", true)
	if mode == Sort.TRADITION:
		return ListPanel.sorted_before(a.tradition, b.tradition, down, a.name, b.name, true)
	return ListPanel.sorted_before(_rank(a, mode), _rank(b, mode), down, a.name, b.name, true)


static func _rank(view: MercView, mode: int) -> float:
	match mode:
		Sort.LEVEL:
			return float(view.level)
		Sort.SALARY:
			return float(view.monthly_salary)
		Sort.GUILD:
			return float(view.guild_opinion)
		Sort.EMPLOYMENT:
			return float(view.employment_months)
	return 1.0 if view.status == GuiTypes.MercStatus.AVAILABLE else 0.0


#The Hire tile rides out the wipe: it is pulled from the list first and seated under the last merc
#once the rows are back, so it is always the module at the foot of the column.
func _rebuild() -> void:
	if not is_node_ready():
		return
	if hire.get_parent() != null:
		hire.get_parent().remove_child(hire)
	clear_items()
	for view: MercView in order():
		var row: MercListItem = ITEM_SCENE.instantiate()
		items().add_child(row)
		row.set_view(view)
		row.selected.connect(_on_row_selected)
	items().add_child(hire)
	set_count(row_count(), views.size() + captive_views.size())
	select(selected_uid)


func _on_row_selected(uid: int) -> void:
	select(uid)
	merc_selected.emit(uid)


func _on_sort_changed(_index: int) -> void:
	_rebuild()


func _on_direction_changed(_down: bool) -> void:
	_rebuild()


func _on_filter_changed(_states: Dictionary) -> void:
	_rebuild()
