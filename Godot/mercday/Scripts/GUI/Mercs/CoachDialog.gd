class_name CoachDialog extends ModalDialog

#The Performance Improvement Plan popup: every level-up mode PipDefs knows, grouped and gridded
#three to a row, in the ModalDialog chrome. A pick only moves the draft; Confirm stays dead
#until the draft differs from the plan in force, and writing it goes through GameState.set_pip_mode
#so a mode whose gate is shut can never be stored. The rows are never spelled out here: they come
#from PipDefs, so a new mode appears with no edit to this screen.

const HEADER_TEXT: String = "Performance Improvement Plan"
const SUBTITLE_TEXT: String = "Choose how this merc focuses when they level up."
const UNCHANGED_HINT: String = "Pick a different plan to confirm"
const MODULE_SCENE_PATH: String = "res://Scenes/GUI/Mercs/PipModule.tscn"
const TIP_SCENE_PATH: String = "res://Scenes/GUI/Shared/SlotTooltip.tscn"
const COLUMNS: int = 3
const GROUP_SEPARATION: int = 10
const GROUP_ROW_SEPARATION: int = 6
const GRID_SEPARATION: int = 8
const HEADING_SIZE: int = 9
const DISABLED_ALPHA: float = 0.4

@onready var subtitle_label: Label = $Box/Pad/Rows/Head/Subtitle
@onready var groups: VBoxContainer = $Box/Pad/Rows/Groups

#MercView is a RefCounted view model, so the merc arrives through open_for, not the editor.
var merc: MercView = null
var current_mode: StringName = PipDefs.DEFAULT_MODE
var draft_mode: StringName = PipDefs.DEFAULT_MODE

var _modules: Dictionary = {}
var _group_boxes: Dictionary = {}
var _tip: SlotTooltip = null


func _ready() -> void:
	super()
	kicker = HEADER_TEXT
	subtitle_label.text = SUBTITLE_TEXT
	SubscriptionManager.changed.connect(_on_entitlements_changed)
	_build_groups()
	_build_tip()
	_refresh()


func open_for(view: MercView) -> void:
	if view == null:
		return
	merc = view
	current_mode = GameState.pip_mode(view.uid)
	draft_mode = current_mode
	_refresh()
	present()


#Moves the draft only. A locked mode is refused here as well as in GameState.
func press_mode(mode: StringName) -> void:
	if not PipDefs.has(mode):
		return
	if not PipDefs.unlocked(mode, SubscriptionManager.entitlements()):
		return
	draft_mode = mode
	_refresh()


#Replaces the base confirm because confirmed carries the stored mode.
func press_confirm() -> void:
	if not confirm_enabled():
		return
	var mode: StringName = draft_mode
	if merc == null or not GameState.set_pip_mode(merc.uid, mode):
		return
	current_mode = mode
	close()
	confirmed.emit(mode)


func press_cancel() -> void:
	draft_mode = current_mode
	_refresh()
	super()


func close() -> void:
	_hide_tip()
	super()


func confirm_enabled() -> bool:
	if draft_mode == current_mode:
		return false
	return PipDefs.unlocked(draft_mode, SubscriptionManager.entitlements())


func modules() -> Array[PipModule]:
	var out: Array[PipModule] = []
	for group: String in PipDefs.groups():
		for mode: StringName in PipDefs.modes_in(group):
			var module: PipModule = module_for(mode)
			if module != null:
				out.append(module)
	return out


func module_for(mode: StringName) -> PipModule:
	return _modules.get(mode, null) as PipModule


func group_box(group: String) -> VBoxContainer:
	return _group_boxes.get(group, null) as VBoxContainer


func group_names() -> Array[String]:
	return PipDefs.groups()


func tooltip() -> SlotTooltip:
	return _tip


#One column of group blocks, each a heading over a three wide grid of modules.
func _build_groups() -> void:
	for group: String in PipDefs.groups():
		var block: VBoxContainer = VBoxContainer.new()
		block.name = node_name_of(group)
		block.add_theme_constant_override("separation", GROUP_ROW_SEPARATION)
		var heading: Label = Label.new()
		heading.name = "Heading"
		heading.text = group
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_theme_color_override("font_color", GuiColors.SKY)
		heading.add_theme_font_size_override("font_size", HEADING_SIZE)
		block.add_child(heading)
		var grid: GridContainer = GridContainer.new()
		grid.name = "Grid"
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
		grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
		block.add_child(grid)
		groups.add_child(block)
		_group_boxes[group] = block
		for mode: StringName in PipDefs.modes_in(group):
			var module: PipModule = _make_module(mode)
			if module != null:
				grid.add_child(module)
				_modules[mode] = module


func _make_module(mode: StringName) -> PipModule:
	var scene: PackedScene = load(MODULE_SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var module: PipModule = scene.instantiate() as PipModule
	module.name = node_name_of(String(mode))
	module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	module.picked.connect(press_mode)
	module.hover_started.connect(_show_tip)
	module.hover_ended.connect(_hide_tip)
	return module


func _build_tip() -> void:
	var scene: PackedScene = load(TIP_SCENE_PATH) as PackedScene
	if scene == null:
		return
	_tip = scene.instantiate() as SlotTooltip
	add_child(_tip)


func _show_tip(module: PipModule) -> void:
	if _tip == null or module == null:
		return
	_tip.set_slot(module.group_title(), module.mode_text(), module.description,
		module.foot_text())
	_tip.show_at(module, get_viewport().get_visible_rect())


func _hide_tip() -> void:
	if _tip != null:
		_tip.hide_tip()


func _on_entitlements_changed() -> void:
	if merc != null:
		current_mode = GameState.pip_mode(merc.uid)
		if not PipDefs.unlocked(draft_mode, SubscriptionManager.entitlements()):
			draft_mode = current_mode
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	title = "" if merc == null else merc.name
	var ent: Dictionary = SubscriptionManager.entitlements()
	for group: String in PipDefs.groups():
		for mode: StringName in PipDefs.modes_in(group):
			var module: PipModule = module_for(mode)
			if module == null:
				continue
			module.set_row(PipDefs.find(mode), ent)
			module.selected = mode == draft_mode
			module.is_current = mode == current_mode
	var live: bool = confirm_enabled()
	confirm_button.disabled = not live
	confirm_button.modulate.a = 1.0 if live else DISABLED_ALPHA
	confirm_button.tooltip_text = "" if live else UNCHANGED_HINT


#A group or mode name becomes a node name, so a test can reach one by path.
static func node_name_of(text: String) -> String:
	return text.replace(" ", "")
