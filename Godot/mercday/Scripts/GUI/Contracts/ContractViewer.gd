class_name ContractViewer extends Control

#The Contract Viewer screen: the board on the left, the selected posting on the right.
#It owns the modal popup that carries the Dispatch Window and the merc view, and the one dialog
#that asks before a rejection or a called off dispatch.

const DISPATCH_SCENE: PackedScene = preload("res://Scenes/GUI/Contracts/DispatchWindow.tscn")
const MERC_SCENE: String = "res://Scenes/GUI/Mercs/MercViewer.tscn"
const MISSING_MERC_TEXT: String = "Merc viewer not available"
#The results panel belongs to the Results screen; the viewer only hosts it over itself.
const RESULTS_SCENE: String = "res://Scenes/GUI/Results/ContractResults.tscn"
#Every range key opened up, so revealing a posting is never undone by a stale slider.
const OPEN_RANGES: Dictionary = {"difficulty_min": 0.0, "difficulty_max": 5.0, "reward_min": 0}

#The Client Viewer opens this screen on one posting and keeps its own list.
@export var hide_list: bool = false:
	set(value):
		hide_list = value
		if is_node_ready():
			list_panel.visible = not hide_list

@onready var list_panel: ContractList = $Margin/Columns/Left
@onready var detail_panel: ContractDetail = $Margin/Columns/Right
@onready var popup: SubWindow = $Popup
@onready var confirm_dialog: ConfirmDialog = $Confirm

var selected_id: int = -1

var _pending: String = ""
var _pending_id: int = -1
#A stand-in for the results panel, so the host can be exercised before that screen exists.
var results_scene: PackedScene = null


func _ready() -> void:
	list_panel.selected.connect(select_entry)
	detail_panel.accept_requested.connect(_on_accept)
	detail_panel.reject_requested.connect(_on_reject)
	detail_panel.cancel_requested.connect(_on_cancel_dispatch)
	detail_panel.merc_picked.connect(_on_merc_picked)
	confirm_dialog.confirmed.connect(_on_confirmed)
	confirm_dialog.cancelled.connect(_on_cancelled)
	GameState.contracts_changed.connect(_rebuild)
	GameState.roster_changed.connect(_rebuild)
	GameState.results_recorded.connect(_on_results_changed)
	GameState.results_seen.connect(_on_results_changed)
	list_panel.visible = not hide_list
	_rebuild()


#Shows one posting whatever the filter hides, and opens its results when nobody has read them.
func select_entry(entry_id: int) -> void:
	_show(entry_id, true)


func _show(entry_id: int, may_open: bool) -> void:
	selected_id = entry_id
	if entry_id >= 0 and not list_panel.has_id(entry_id):
		_reveal(entry_id)
	list_panel.select(entry_id)
	detail_panel.set_view(_view_of(entry_id))
	if may_open:
		open_results(entry_id)


#Turns the posting's own filter option on and opens every range back up (PROTO applyOpen 703).
func _reveal(entry_id: int) -> void:
	var view: ContractView = _view_of(entry_id)
	if view == null:
		return
	var panel: ContractFilterPanel = list_panel.filter_panel
	var rules: Dictionary = panel.filter()
	rules[ContractList.filter_key(view)] = true
	rules.merge(OPEN_RANGES, true)
	rules["reward_max"] = panel.caps["reward_max"]
	rules["max_distance"] = panel.caps["max_distance"]
	panel.set_filter(rules)


#Turns on the claimed posting's own status option only, and opens the ranges too just when that
#option alone still leaves it hidden. Narrower than _reveal: a filter the player switched off on
#purpose stays off for every other posting (PROTO applyOpen 703 sets only its own show+status key).
func _reveal_claim(entry_id: int) -> void:
	var view: ContractView = _view_of(entry_id)
	if view == null:
		return
	var panel: ContractFilterPanel = list_panel.filter_panel
	var rules: Dictionary = panel.filter()
	var key: String = ContractList.filter_key(view)
	rules[key] = true
	var single: Array[ContractView] = []
	single.append(view)
	if ContractList.filtered(single, rules).is_empty():
		rules.merge(OPEN_RANGES, true)
		rules["reward_max"] = panel.caps["reward_max"]
		rules["max_distance"] = panel.caps["max_distance"]
	panel.set_filter(rules)


#Opens the results panel over the viewer for a settled posting nobody has read yet. Without that
#scene on disk the posting is simply marked read, so the board never keeps a row nobody can open.
#The entry is claimed the moment the panel opens (PROTO selectContract 686), so the window X, Esc
#and a backdrop click cannot leave a posting nobody can open again.
func open_results(entry_id: int) -> bool:
	if entry_id < 0 or not GameState.is_unclaimed(entry_id):
		return false
	var result: ContractResultData = GameState.result_of(entry_id)
	var scene: PackedScene = _results_scene()
	if result != null and scene != null:
		var node: Node = popup.open(scene)
		if node != null and node.has_method("show_result"):
			if node.has_signal("finished"):
				node.connect("finished", _on_results_finished)
			node.call("show_result", result)
			GameState.mark_seen(entry_id)
			return true
		popup.close()
	GameState.mark_seen(entry_id)
	_on_results_changed(entry_id)
	return false


func _results_scene() -> PackedScene:
	if results_scene != null:
		return results_scene
	if ResourceLoader.exists(RESULTS_SCENE):
		return load(RESULTS_SCENE) as PackedScene
	return null


func _on_results_finished(entry_id: int) -> void:
	popup.close()
	GameState.mark_seen(entry_id)
	_on_results_changed(entry_id)


#The posting the viewer shows stays the selected posting when its results are claimed
#(GX4D-01; PROTO applyOpen 703 sets the claimed row's own status key unconditionally). A
#_rebuild() from any other source (roster change, a filter the player switched off, a posting
#that left GameState.contracts) keeps falling back to first_id(), since entry_id != selected_id
#or the view no longer exists.
func _on_results_changed(entry_id: int) -> void:
	if entry_id == selected_id and _view_of(entry_id) != null:
		_reveal_claim(entry_id)
	_rebuild()


func selected() -> ContractView:
	return _view_of(selected_id)


func list() -> ContractList:
	return list_panel


func detail() -> ContractDetail:
	return detail_panel


func window() -> SubWindow:
	return popup


func confirm() -> ConfirmDialog:
	return confirm_dialog


func _rebuild() -> void:
	if not is_node_ready():
		return
	list_panel.set_views(GameState.contracts)
	if not list_panel.has_id(selected_id):
		selected_id = list_panel.first_id()
	_show(selected_id, false)


func _view_of(entry_id: int) -> ContractView:
	for view: ContractView in GameState.contracts:
		if view.entry_id == entry_id:
			return view
	return null


func _on_accept(entry_id: int) -> void:
	var view: ContractView = _view_of(entry_id)
	if view == null:
		return
	var window_node: DispatchWindow = popup.open(DISPATCH_SCENE,
		func(node: Node) -> void: (node as DispatchWindow).contract = view) as DispatchWindow
	if window_node == null:
		return
	window_node.dispatched.connect(_on_dispatched)
	window_node.cancelled.connect(popup.close)
	window_node.failed.connect(_on_dispatch_failed)


func _on_dispatched(run: ActiveRun) -> void:
	popup.close()
	select_entry(run.entry_id)


#The posting could not be taken: it is struck off the board and the viewer moves on.
#Nothing is refunded because nothing was charged.
func _on_dispatch_failed(entry_id: int) -> void:
	var next_id: int = next_available(entry_id)
	if next_id < 0:
		next_id = _first_listed_available()
	GameState.discard(entry_id)
	popup.close()
	if next_id < 0 or not list_panel.has_id(next_id):
		next_id = list_panel.first_id()
	select_entry(next_id)


#The first AVAILABLE posting listed after this one, or -1 when there is none.
func next_available(entry_id: int) -> int:
	var ids: Array[int] = list_panel.listed_ids()
	var at: int = ids.find(entry_id)
	for i: int in range(at + 1, ids.size()):
		if _is_available(ids[i]):
			return ids[i]
	return -1


#The first AVAILABLE posting anywhere in the list, for when nothing follows the failed one.
func _first_listed_available() -> int:
	for id_value: int in list_panel.listed_ids():
		if _is_available(id_value):
			return id_value
	return -1


func _is_available(entry_id: int) -> bool:
	var view: ContractView = _view_of(entry_id)
	return view != null and view.status == GuiTypes.ContractStatus.AVAILABLE


func _on_reject(entry_id: int) -> void:
	_pending = "reject"
	_pending_id = entry_id
	confirm_dialog.ask("Are you sure?", "This posting will be removed.", "Yes", "Cancel",
		ConfirmDialog.Severity.RED)


func _on_cancel_dispatch(entry_id: int) -> void:
	_pending = "cancel"
	_pending_id = entry_id
	confirm_dialog.ask("Are you sure?", "The travel money comes back and the posting reopens.",
		"Yes", "Cancel", ConfirmDialog.Severity.RED)


func _on_confirmed() -> void:
	var kind: String = _pending
	var entry_id: int = _pending_id
	_pending = ""
	_pending_id = -1
	if kind == "reject":
		GameState.reject(entry_id)
	elif kind == "cancel":
		GameState.cancel_dispatch(entry_id)


func _on_cancelled() -> void:
	_pending = ""
	_pending_id = -1


#The merc view belongs to another screen; it may be missing, so the popup falls back to a note.
func _on_merc_picked(uid: int) -> void:
	if ResourceLoader.exists(MERC_SCENE):
		var scene: PackedScene = load(MERC_SCENE)
		var node: Node = popup.open(scene, func(n: Node) -> void: n.set("hide_roster", true))
		if node != null and node.has_method("show_merc"):
			node.call("show_merc", uid)
			return
	popup.open(_placeholder_scene())


func _placeholder_scene() -> PackedScene:
	var holder: Control = Control.new()
	holder.name = "MercPlaceholder"
	var label: Label = Label.new()
	label.name = "Missing"
	label.text = MISSING_MERC_TEXT
	label.theme_type_variation = &"DescriptionLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(label)
	label.owner = holder
	var packed: PackedScene = PackedScene.new()
	packed.pack(holder)
	holder.queue_free()
	return packed
