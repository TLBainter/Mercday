class_name ContractViewer extends Control

#The Contract Viewer screen: the board on the left, the selected posting on the right.
#It owns the modal popup that carries the Dispatch Window and the merc view, and the one dialog
#that asks before a rejection or a called off dispatch.

const DISPATCH_SCENE: PackedScene = preload("res://Scenes/GUI/Contracts/DispatchWindow.tscn")
const MERC_SCENE: String = "res://Scenes/GUI/Mercs/MercViewer.tscn"
const MISSING_MERC_TEXT: String = "Merc viewer not available"

@onready var list_panel: ContractList = $Margin/Columns/Left
@onready var detail_panel: ContractDetail = $Margin/Columns/Right
@onready var popup: SubWindow = $Popup
@onready var confirm_dialog: ConfirmDialog = $Confirm

var selected_id: int = -1

var _pending: String = ""
var _pending_id: int = -1


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
	_rebuild()


func select_entry(entry_id: int) -> void:
	selected_id = entry_id
	list_panel.select(entry_id)
	detail_panel.set_view(_view_of(entry_id))


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
	select_entry(selected_id)


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
