class_name CustomizePage extends Control

#The Customize tab: the spend readout above the upgrade tree. Without Enterprise the page keeps
#its shape and the locked overlay covers it.

signal plans_requested

const TREE_SCENE: PackedScene = preload("res://Scenes/GUI/Subscription/SkillTree.tscn")
const TITLE_TEXT: String = "Customize"
const TITLE_COLOR: Color = GuiColors.ORANGE
const TITLE_SIZE: int = 13
const TITLE_SPACING: int = 1
const NOTE_OPEN: String = "Click a block to upgrade"
const NOTE_LOCKED: String = "Available on Mercday Enterprise"
const NOTE_OPEN_COLOR: Color = GuiColors.SKY
const NOTE_LOCKED_COLOR: Color = GuiColors.AMBER
const FONT: FontVariation = GuiStyle.SILK_BOLD

@onready var title: Label = $Pad/Rows/Top/Title
@onready var readout: SpendReadout = $Pad/Rows/Top/Readout
@onready var note: Label = $Pad/Rows/Note
@onready var tree_frame: Panel = $Pad/Rows/TreeFrame
@onready var tree_host: Control = $Pad/Rows/TreeFrame/TreeHost
@onready var lock: LockedPage = $Lock

var _tree: SkillTree = null


func _ready() -> void:
	title.text = TITLE_TEXT
	GuiStyle.paint(title, FONT, TITLE_SIZE, TITLE_COLOR)
	title.add_theme_constant_override(&"font_spacing_glyph", TITLE_SPACING)
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


#The hosted SkillTree, or null before the page is ready.
func tree_node() -> SkillTree:
	return _tree


func has_tree() -> bool:
	return _tree != null


#Asks the tree to bring one upgrade into view; does nothing before the page is ready.
func focus_upgrade(id: String, tier: int) -> bool:
	if _tree == null:
		return false
	_tree.focus_upgrade(id, tier)
	return true


func refresh() -> void:
	if not is_node_ready():
		return
	note.text = note_text()
	note.add_theme_color_override(&"font_color", note_color())
	lock.visible = is_locked()
	readout.refresh()


func _load_tree() -> void:
	_tree = TREE_SCENE.instantiate() as SkillTree
	tree_host.add_child(_tree)
	_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tree.go_to_plans_pressed.connect(plans_requested.emit)


func _on_take_me_there(_target: Dictionary) -> void:
	plans_requested.emit()
