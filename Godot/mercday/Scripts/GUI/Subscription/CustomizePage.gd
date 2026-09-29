class_name CustomizePage extends Control

#The Customize tab: the spend readout above the upgrade tree. The tree scene is loaded only when
#it exists on disk, so this page stands on its own before the tree is built. Without Enterprise the
#page keeps its shape and the locked overlay covers it.

signal plans_requested

const TREE_PATH: String = "res://Scenes/GUI/Subscription/SkillTree.tscn"
const TITLE_TEXT: String = "Customize"
const TITLE_COLOR: Color = Color("#f28c28")
const TITLE_SIZE: int = 13
const TITLE_SPACING: int = 1
const NOTE_OPEN: String = "Click a block to upgrade"
const NOTE_LOCKED: String = "Available on Mercday Enterprise"
const NOTE_OPEN_COLOR: Color = Color("#9cc6ef")
const NOTE_LOCKED_COLOR: Color = Color("#f2b33d")
const MISSING_TEXT: String = "Customize tree is not available yet"
const FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")

@onready var title: Label = $Pad/Rows/Top/Title
@onready var readout: SpendReadout = $Pad/Rows/Top/Readout
@onready var note: Label = $Pad/Rows/Note
@onready var tree_frame: Panel = $Pad/Rows/TreeFrame
@onready var tree_host: Control = $Pad/Rows/TreeFrame/TreeHost
@onready var missing_label: Label = $Pad/Rows/TreeFrame/MissingLabel
@onready var lock: LockedPage = $Lock

var _tree: Node = null


func _ready() -> void:
	title.text = TITLE_TEXT
	title.add_theme_font_override(&"font", FONT)
	title.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	title.add_theme_constant_override(&"font_spacing_glyph", TITLE_SPACING)
	title.add_theme_color_override(&"font_color", TITLE_COLOR)
	missing_label.text = MISSING_TEXT
	lock.take_me_there.connect(_on_take_me_there)
	SubscriptionManager.changed.connect(refresh)
	_load_tree()
	refresh()


func is_locked() -> bool:
	return SubscriptionManager.plan() != SubscriptionManager.Plan.ENTERPRISE


func note_text() -> String:
	return NOTE_LOCKED if is_locked() else NOTE_OPEN


func note_color() -> Color:
	return NOTE_LOCKED_COLOR if is_locked() else NOTE_OPEN_COLOR


func spend_readout() -> SpendReadout:
	return readout


#The SkillTree instance GX2L adds, or null while the scene does not exist.
func tree_node() -> Node:
	return _tree


func has_tree() -> bool:
	return _tree != null


#Asks the tree to bring one upgrade into view; silently does nothing before the tree exists.
func focus_upgrade(id: String, tier: int) -> bool:
	if _tree == null or not _tree.has_method("focus_upgrade"):
		return false
	_tree.call("focus_upgrade", id, tier)
	return true


func refresh() -> void:
	if not is_node_ready():
		return
	note.text = note_text()
	note.add_theme_color_override(&"font_color", note_color())
	lock.visible = is_locked()
	readout.refresh()


func _load_tree() -> void:
	if not ResourceLoader.exists(TREE_PATH):
		missing_label.visible = true
		return
	var scene: PackedScene = load(TREE_PATH) as PackedScene
	if scene == null:
		missing_label.visible = true
		return
	_tree = scene.instantiate()
	tree_host.add_child(_tree)
	var control: Control = _tree as Control
	if control != null:
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	missing_label.visible = false
	if _tree.has_signal("go_to_plans_pressed"):
		_tree.connect("go_to_plans_pressed", _on_tree_plans)


func _on_tree_plans() -> void:
	plans_requested.emit()


func _on_take_me_there(_target: Dictionary) -> void:
	plans_requested.emit()
