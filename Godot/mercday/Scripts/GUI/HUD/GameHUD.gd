class_name GameHUD extends CanvasLayer

#Root of the Game HUD: menu grid, settings button, bottom bar and the shared popup window.
#autostart = true is the real launch path; tests set it false and call wire_for_test() instead.

const SCENE_PATHS: Dictionary = {
	"Merc Viewer": "res://Scenes/GUI/Mercs/MercViewer.tscn",
	"Contract Viewer": "res://Scenes/GUI/Contracts/ContractViewer.tscn",
	"Metrics Viewer": "res://Scenes/GUI/Metrics/MetricsViewer.tscn",
}

const GRID_ENTRIES: Array[Dictionary] = [
	{"label": "Merc Viewer", "icon": "res://Art/GUI/Icons/icon_group_mercs.png",
		"description": "View and manage your mercenaries"},
	{"label": "Contract Viewer", "icon": "res://Art/GUI/Icons/icon_contracts.png",
		"description": "View and manage your contracts"},
	{"label": "Metrics Viewer", "icon": "res://Art/GUI/Icons/icon_metrics.png",
		"description": "Review your guild's history"},
]

@export var autostart: bool = true

var _wired: bool = false

@onready var root: Control = $Root
@onready var menu_grid: MenuGrid = $Root/MenuGrid
@onready var settings_button: SettingsButton = $Root/SettingsButton
@onready var bottom_bar: BottomBar = $Root/BottomBar
@onready var popup_window: SubWindow = $Root/Popup
@onready var description_label: Label = $Root/Description


func _ready() -> void:
	if autostart:
		if await HarnessEntry.run_if_flagged(self):
			return
		if OS.get_cmdline_user_args().has("--harness"):
			get_tree().change_scene_to_file.call_deferred("res://Scenes/GUI/testingArea.tscn")
			return
		GameState.start_new_game()
		if OS.get_cmdline_user_args().has("--metrics-preview"):
			MetricsHistory.seed_preview(400, _roster_uids())
			print("METRICS PREVIEW days=%d" % MetricsHistory.days())
	_wire()


func _roster_uids() -> Array[int]:
	var uids: Array[int] = []
	for view: MercView in GameState.roster:
		uids.append(view.uid)
	return uids


#Public alias so a test can force wiring right after add_child, without waiting on deferred _ready.
func wire_for_test() -> void:
	_wire()


func _wire() -> void:
	GuiFrameStack.bottom_reserve = bottom_bar.custom_minimum_size.y
	if _wired:
		return
	_wired = true
	for i in 9:
		var btn: GridMenuButton = menu_grid.button(i)
		if btn == null:
			continue
		if i < GRID_ENTRIES.size():
			_wire_active_button(btn, GRID_ENTRIES[i])
		else:
			_wire_blank_button(btn)
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_unhover)
		btn.opened.connect(_on_button_opened.bind(btn))


func _wire_active_button(btn: GridMenuButton, entry: Dictionary) -> void:
	var label: String = str(entry["label"])
	btn.label = label
	btn.description = str(entry["description"])
	btn.disabled = false
	var icon_path: String = str(entry["icon"])
	if ResourceLoader.exists(icon_path):
		btn.set_icon(load(icon_path))
	var scene_path: String = str(SCENE_PATHS.get(label, ""))
	btn.window_scene = load(scene_path) if scene_path != "" and ResourceLoader.exists(scene_path) else null


func _wire_blank_button(btn: GridMenuButton) -> void:
	btn.label = ""
	btn.description = ""
	btn.disabled = true
	btn.window_scene = null


func _on_button_hover(btn: GridMenuButton) -> void:
	description_label.text = btn.description


func _on_button_unhover() -> void:
	description_label.text = ""


func _on_button_opened(scene: PackedScene, btn: GridMenuButton) -> void:
	_open_scene_or_placeholder(scene, btn.label)


#Opens the button's window scene by grid index; disabled buttons and a missing button do nothing.
func open_menu(index: int) -> void:
	var btn: GridMenuButton = menu_grid.button(index)
	if btn == null or btn.disabled:
		return
	_open_scene_or_placeholder(btn.window_scene, btn.label)


func popup() -> SubWindow:
	return popup_window


func button(index: int) -> GridMenuButton:
	return menu_grid.button(index)


func _open_scene_or_placeholder(scene: PackedScene, label: String) -> void:
	if scene != null:
		popup_window.open(scene)
	else:
		popup_window.open(_placeholder_scene("%s is not available yet" % label))


#Builds a one-off placeholder scene in memory; no saved file is needed for a single DescriptionLabel.
static func _placeholder_scene(text: String) -> PackedScene:
	var root_node := Control.new()
	root_node.name = "Placeholder"
	root_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label_node := Label.new()
	label_node.name = "DescriptionLabel"
	label_node.theme_type_variation = &"DescriptionLabel"
	label_node.text = text
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_node.add_child(label_node)
	label_node.owner = root_node
	var packed := PackedScene.new()
	packed.pack(root_node)
	return packed
