class_name DispatchRoster extends ListPanel

#The Dispatch Window left column: every merc who can still be sent, ordered by the picked key.
#A merc already on the team stays listed, dimmed and tagged; clicking that row frees the slot.

signal picked(uid: int)
signal remove_requested(uid: int)

enum Sort {BEST, NAME, LEVEL, TRADITION}

const SORT_OPTIONS: Array[String] = ["Best", "Name A-Z", "Level", "Tradition A-Z"]
const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Contracts/DispatchRosterItem.tscn")
#The count keeps the SmallLabel size; the list head paints it at 11.
const COUNT_FONT_SIZE: int = 8

@onready var sort_button: SortButton = $Pad/Rows/Tools/Sort
@onready var dir_toggle: SortDirToggle = $Pad/Rows/Tools/Dir

var candidates: Array[MercView] = []
var taken: Array[int] = []
#Returns the merc's solo net percent for the posting; the Best sort and the row stars read it.
var scorer: Callable = Callable()


func _ready() -> void:
	super()
	head.count_label.add_theme_font_size_override("font_size", COUNT_FONT_SIZE)
	sort_button.options = SORT_OPTIONS
	sort_button.selected = Sort.BEST
	dir_toggle.descending = true
	sort_button.sort_changed.connect(func(_i: int) -> void: rebuild())
	dir_toggle.direction_changed.connect(func(_d: bool) -> void: rebuild())
	rebuild()


func configure(new_candidates: Array[MercView], new_scorer: Callable) -> void:
	candidates = new_candidates
	scorer = new_scorer
	rebuild()


func set_taken(uids: Array[int]) -> void:
	taken = uids
	rebuild()


func row_count() -> int:
	return items().get_child_count() if is_node_ready() else 0


func row_at(index: int) -> DispatchRosterItem:
	if index < 0 or index >= items().get_child_count():
		return null
	return items().get_child(index) as DispatchRosterItem


#The first row not already on the team; null when every listed merc is placed.
func first_free_row() -> DispatchRosterItem:
	if not is_node_ready():
		return null
	for child: Node in items().get_children():
		var row: DispatchRosterItem = child as DispatchRosterItem
		if row != null and not row.is_assigned():
			return row
	return null


func shown_uids() -> Array[int]:
	var out: Array[int] = []
	for child: Node in items().get_children():
		var row: DispatchRosterItem = child as DispatchRosterItem
		if row != null:
			out.append(row.merc_uid())
	return out


func rebuild() -> void:
	if not is_node_ready():
		return
	clear_items()
	var listed: Array[MercView] = []
	listed.assign(candidates)
	var scores: Dictionary = {}
	for view: MercView in listed:
		scores[view.uid] = float(scorer.call(view)) if scorer.is_valid() else 0.0
	listed = _sorted(listed, scores, sort_button.selected, dir_toggle.descending)
	for view: MercView in listed:
		var row: DispatchRosterItem = ROW_SCENE.instantiate()
		items().add_child(row)
		row.set_merc(view, MatchScore.stars(float(scores.get(view.uid, 0.0))),
			taken.has(view.uid))
		row.picked.connect(func(uid: int) -> void: picked.emit(uid))
		row.remove_requested.connect(func(uid: int) -> void: remove_requested.emit(uid))
	head.count_text = "%d" % listed.size()


static func _sorted(source: Array[MercView], scores: Dictionary, mode: int,
		descending: bool) -> Array[MercView]:
	var out: Array[MercView] = []
	out.assign(source)
	out.sort_custom(func(a: MercView, b: MercView) -> bool:
		return _before(a, b, scores, mode, descending))
	return out


static func _before(a: MercView, b: MercView, scores: Dictionary, mode: int,
		descending: bool) -> bool:
	if mode == Sort.NAME or mode == Sort.TRADITION:
		var left: String = a.name if mode == Sort.NAME else a.tradition
		var right: String = b.name if mode == Sort.NAME else b.tradition
		return ListPanel.sorted_before(left, right, descending, a.name, b.name)
	var one: float = float(a.level) if mode == Sort.LEVEL else float(scores.get(a.uid, 0.0))
	var two: float = float(b.level) if mode == Sort.LEVEL else float(scores.get(b.uid, 0.0))
	return ListPanel.sorted_before(one, two, descending, a.name, b.name)
