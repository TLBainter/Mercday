class_name ContractList extends ListPanel

#The left column of the Contract Viewer: the sort controls, the filter popup and the posting rows.
#sorted() and filtered() are static so the order and the visibility rules can be read without a scene.

signal selected(entry_id: int)

enum Sort {DIFFICULTY, VALUE, TYPE, DISTANCE, COMPLETION}

const SORT_OPTIONS: Array[String] = ["Difficulty", "Value", "Type", "Distance",
	"Completion Date"]
const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Contracts/ContractListItem.tscn")
const TIP_SCENE: PackedScene = preload("res://Scenes/GUI/Contracts/ContractTooltip.tscn")
#Open caps of a board with nothing on it; the filter never hides a row on these.
const OPEN_REWARD: int = 1000000
const OPEN_DISTANCE: int = 100000
const GLYPH_COLOR: Color = GuiColors.CREAM
#The filter key a posting falls under, by the status it is drawn as.
const STATUS_KEYS: Dictionary = {
	GuiTypes.ContractStatus.AVAILABLE: "show_available",
	GuiTypes.ContractStatus.ACTIVE: "show_active",
	GuiTypes.ContractStatus.COMPLETED: "show_completed",
	GuiTypes.ContractStatus.FAILED: "show_failed",
	GuiTypes.ContractStatus.REJECTED: "show_rejected",
	GuiTypes.ContractStatus.EXPIRED: "show_expired",
}
#A settled posting nobody has opened sits under its own option, never under the outcome it had.
const UNCLAIMED_KEY: String = "show_unclaimed"
#Which options a fresh filter turns on (PROTO state 493).
const DEFAULT_SHOWN: Dictionary = {
	"show_available": true, "show_active": true, "show_completed": false,
	"show_failed": false, "show_unclaimed": true, "show_rejected": false,
	"show_expired": false,
}

@onready var sort_button: SortButton = $Pad/Rows/Tools/Sort
@onready var dir_toggle: SortDirToggle = $Pad/Rows/Tools/Dir
@onready var filter_button: Button = $Pad/Rows/Tools/Filter
@onready var empty_label: Label = $Pad/Rows/Empty
@onready var filter_panel: ContractFilterPanel = $FilterPanel

var views: Array[ContractView] = []
var rows: Array[ContractView] = []
var filter: Dictionary = default_filter()
var selected_id: int = -1
#One tooltip for the whole list; every row hover moves it and refills it.
var tip_node: ContractTooltip = null


func _ready() -> void:
	super()
	sort_button.options = SORT_OPTIONS
	sort_button.selected = Sort.DIFFICULTY
	sort_button.sort_changed.connect(_on_sort_changed)
	dir_toggle.direction_changed.connect(_on_direction_changed)
	filter_button.icon = GuiGlyphs.funnel(GLYPH_COLOR)
	filter_button.pressed.connect(_on_filter_pressed)
	filter_panel.filters_changed.connect(_on_filters_changed)
	tip_node = TIP_SCENE.instantiate()
	add_child(tip_node)
	_rebuild()


#Takes the board's views, keeps the caps in step with them and redraws the rows.
func set_views(new_views: Array[ContractView]) -> void:
	views = new_views
	if is_node_ready():
		filter_panel.configure(views)
		filter = filter_panel.filter()
	_rebuild()


func select(entry_id: int) -> void:
	selected_id = entry_id
	_mark_selection()


func row_count() -> int:
	return rows.size()


func listed() -> Array[ContractView]:
	return rows


func row_at(index: int) -> ContractListItem:
	if index < 0 or index >= items().get_child_count():
		return null
	return items().get_child(index) as ContractListItem


#The first listed entry id, or -1 when the filter hides everything.
func first_id() -> int:
	return rows[0].entry_id if not rows.is_empty() else -1


#The entry ids of the rows on screen, in the order they are drawn.
func listed_ids() -> Array[int]:
	var out: Array[int] = []
	if not is_node_ready():
		return out
	for child: Node in items().get_children():
		var item: ContractListItem = child as ContractListItem
		if item != null:
			out.append(item.entry_id())
	return out


func has_id(entry_id: int) -> bool:
	for row: ContractView in rows:
		if row.entry_id == entry_id:
			return true
	return false


func _rebuild() -> void:
	if not is_node_ready():
		return
	rows = sorted(filtered(views, filter), sort_button.selected, dir_toggle.descending)
	_on_row_unhovered()
	clear_items()
	for row: ContractView in rows:
		var item: ContractListItem = ROW_SCENE.instantiate()
		items().add_child(item)
		item.set_view(row)
		item.pressed_row.connect(_on_row_selected)
		item.hovered.connect(_on_row_hovered.bind(item))
		item.unhovered.connect(_on_row_unhovered)
	set_count(rows.size(), views.size())
	empty_label.visible = rows.is_empty()
	_mark_selection()


func _mark_selection() -> void:
	if not is_node_ready():
		return
	for child: Node in items().get_children():
		var item: ContractListItem = child as ContractListItem
		if item != null:
			item.selected = item.entry_id() == selected_id


func header_title() -> Label:
	return head.caption_label


func count_text() -> String:
	return head.count_label.text if is_node_ready() else ""


func tooltip() -> ContractTooltip:
	return tip_node


func _on_row_hovered(row_view: ContractView, item: ContractListItem) -> void:
	if tip_node == null or item == null:
		return
	tip_node.set_contract(row_view)
	tip_node.show_at(item)


func _on_row_unhovered() -> void:
	if tip_node != null:
		tip_node.hide_tip()


func _on_row_selected(entry_id: int) -> void:
	selected_id = entry_id
	_mark_selection()
	selected.emit(entry_id)


func _on_sort_changed(_index: int) -> void:
	_rebuild()


func _on_direction_changed(_descending: bool) -> void:
	_rebuild()


func _on_filter_pressed() -> void:
	filter_panel.popup_at(filter_button)


func _on_filters_changed(new_filter: Dictionary) -> void:
	filter = new_filter
	_rebuild()


#The board order for one sort mode; equal keys fall back to the posting name, then the posting id, so it
#never wobbles.
static func sorted(source: Array[ContractView], mode: int, descending: bool) -> Array[ContractView]:
	var out: Array[ContractView] = []
	out.assign(source)
	out.sort_custom(func(a: ContractView, b: ContractView) -> bool:
		return _before(a, b, mode, descending))
	return out


static func _before(a: ContractView, b: ContractView, mode: int, descending: bool) -> bool:
	if mode == Sort.TYPE:
		if a.type == b.type and a.name == b.name:
			return a.entry_id < b.entry_id
		return ListPanel.sorted_before(a.type, b.type, descending, a.name, b.name)
	var one: float = _key(a, mode)
	var two: float = _key(b, mode)
	if one == two and a.name == b.name:
		return a.entry_id < b.entry_id
	return ListPanel.sorted_before(one, two, descending, a.name, b.name)


static func _key(view: ContractView, mode: int) -> float:
	match mode:
		Sort.VALUE:
			return float(view.reward)
		Sort.DISTANCE:
			return float(view.distance_km)
		Sort.COMPLETION:
			return float(view.completion_hours)
	return view.difficulty


#The option one posting answers to: its own row while its results sit unopened, else its status.
static func filter_key(view: ContractView) -> String:
	if view == null or view.is_unclaimed():
		return UNCLAIMED_KEY
	return _status_key(view)


static func _status_key(view: ContractView) -> String:
	return str(STATUS_KEYS.get(view.shown_status(), "show_available"))


#Whether the status options let this posting through. A settled posting nobody has opened answers
#to its own option and to the option of its drawn status, so Completed alone still lists it; rules
#without its key show it unless it is closed.
static func shows_status(view: ContractView, rules: Dictionary) -> bool:
	var key: String = filter_key(view)
	if key == UNCLAIMED_KEY and view != null and bool(rules.get(_status_key(view), false)):
		return true
	if rules.has(key):
		return bool(rules[key])
	return not ContractListItem.is_closed(view)


#Which postings the filter leaves on the board.
static func filtered(source: Array[ContractView], rules: Dictionary) -> Array[ContractView]:
	var out: Array[ContractView] = []
	for view: ContractView in source:
		if view == null:
			continue
		if not shows_status(view, rules):
			continue
		if view.difficulty < float(rules.get("difficulty_min", 0.0)):
			continue
		if view.difficulty > float(rules.get("difficulty_max", 5.0)):
			continue
		if view.reward < int(rules.get("reward_min", 0)):
			continue
		if view.reward > int(rules.get("reward_max", OPEN_REWARD)):
			continue
		if view.distance_km > int(rules.get("max_distance", OPEN_DISTANCE)):
			continue
		out.append(view)
	return out


#The caps a fresh filter carries: the extremes of the postings currently listed.
static func default_filter(source: Array[ContractView] = []) -> Dictionary:
	var out: Dictionary = {"difficulty_min": 0.0, "difficulty_max": 5.0,
		"reward_min": 0, "reward_max": OPEN_REWARD, "max_distance": OPEN_DISTANCE}
	out.merge(DEFAULT_SHOWN)
	if source.is_empty():
		return out
	var low: float = 5.0
	var high: float = 0.0
	var dearest: int = 0
	var farthest: int = 0
	for view: ContractView in source:
		if view == null:
			continue
		low = minf(low, view.difficulty)
		high = maxf(high, view.difficulty)
		dearest = maxi(dearest, view.reward)
		farthest = maxi(farthest, view.distance_km)
	out["difficulty_min"] = clampf(low, 0.0, 5.0)
	out["difficulty_max"] = clampf(high, 0.0, 5.0)
	out["reward_min"] = 0
	out["reward_max"] = dearest
	out["max_distance"] = maxi(1, farthest)
	return out
