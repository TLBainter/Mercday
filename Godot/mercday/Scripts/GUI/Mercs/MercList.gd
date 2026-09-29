class_name MercList extends PanelContainer

#The roster column: a sort header over one MercListItem per living merc. The viewer owns the
#selection; the list only reports the row that was pressed and re-sorts on demand.

enum Sort {AVAILABLE, NAME, TRADITION, LEVEL, SALARY, GUILD, EMPLOYMENT}

const SORT_OPTIONS: Array[String] = ["Available", "Name A-Z", "Tradition A-Z", "Level", "Salary",
	"Guild Opinion", "Employment Length"]
const LIST_WIDTH: int = 272
const ITEM_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/MercListItem.tscn")

signal merc_selected(uid: int)

@onready var title_label: Label = $Rows/Head/Title
@onready var count_label: Label = $Rows/Head/Count
@onready var sort_button: SortButton = $Rows/SortRow/Sort
@onready var dir_toggle: SortDirToggle = $Rows/SortRow/Dir
@onready var filter: FilterButton = $Rows/SortRow/Filter
@onready var items: VBoxContainer = $Rows/Scroll/Pad/Items

var views: Array[MercView] = []
var selected_uid: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(LIST_WIDTH, 0)
	sort_button.options = SORT_OPTIONS.duplicate()
	sort_button.selected = Sort.AVAILABLE
	sort_button.sort_changed.connect(_on_sort_changed)
	dir_toggle.descending = true
	dir_toggle.direction_changed.connect(_on_direction_changed)
	_rebuild()


func set_views(new_views: Array[MercView]) -> void:
	views = new_views.duplicate()
	_rebuild()


func select(uid: int) -> void:
	selected_uid = uid
	for row: MercListItem in rows():
		row.is_selected = row.uid == uid


#The filter popup holds its own state; nothing filters the roster yet.
func filter_button() -> FilterButton:
	return filter


func rows() -> Array[MercListItem]:
	var out: Array[MercListItem] = []
	if not is_node_ready():
		return out
	for child: Node in items.get_children():
		if child is MercListItem:
			out.append(child as MercListItem)
	return out


func row_count() -> int:
	return rows().size()


func sort_mode() -> int:
	return sort_button.selected if is_node_ready() else Sort.AVAILABLE


func descending() -> bool:
	return dir_toggle.descending if is_node_ready() else true


func order() -> Array[MercView]:
	return sorted(views, sort_mode(), descending())


#Available puts the ready mercs first, the text modes read A to Z while ascending and the numeric
#modes read high to low while descending. Every tie falls back to the name, A to Z.
static func sorted(source: Array[MercView], mode: int, down: bool) -> Array[MercView]:
	var out: Array[MercView] = source.duplicate()
	out.sort_custom(func(a: MercView, b: MercView) -> bool: return _before(a, b, mode, down))
	return out


static func _before(a: MercView, b: MercView, mode: int, down: bool) -> bool:
	if mode == Sort.NAME:
		return _text_before(a.name, b.name, down)
	if mode == Sort.TRADITION:
		if a.tradition != b.tradition:
			return _text_before(a.tradition, b.tradition, down)
		return a.name.naturalnocasecmp_to(b.name) < 0
	var ra: float = _rank(a, mode)
	var rb: float = _rank(b, mode)
	if ra != rb:
		return ra > rb if down else ra < rb
	return a.name.naturalnocasecmp_to(b.name) < 0


static func _text_before(x: String, y: String, down: bool) -> bool:
	var c: int = x.naturalnocasecmp_to(y)
	return c > 0 if down else c < 0


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


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child: Node in items.get_children():
		items.remove_child(child)
		child.queue_free()
	for view: MercView in order():
		var row: MercListItem = ITEM_SCENE.instantiate()
		items.add_child(row)
		row.set_view(view)
		row.selected.connect(_on_row_selected)
	count_label.text = "%d/%d" % [row_count(), views.size()]
	select(selected_uid)


func _on_row_selected(uid: int) -> void:
	select(uid)
	merc_selected.emit(uid)


func _on_sort_changed(_index: int) -> void:
	_rebuild()


func _on_direction_changed(_down: bool) -> void:
	_rebuild()
