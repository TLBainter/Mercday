extends Node

#Interface sounds. Every BaseButton that enters the tree clicks and hovers through here, and so does any Control
#that declares a no-arg pressed signal (a pressed signal with arguments does not opt in). A no-arg sfx_hovered
#signal stands in for mouse_entered as the hover; override_hover(control, null) silences the hover. A left press
#on a disabled control plays the click_disabled cue. A per-instance override wins, then the control's own click_sfx or
#hover_sfx property, then the config default. Coming back from a child that takes the mouse, without leaving the
#control's rect, is no new hover.
#The sliders, the upgrade dialog and the windows call the play_ helpers directly.

const CONFIG_PATH: String = "res://Resources/Audio/sfx_config.tres"
const PITCH_LOW: float = 0.75
const PITCH_HIGH: float = 1.25
const HOVER_PITCH_LOW: float = 0.95
const HOVER_PITCH_HIGH: float = 1.05
#The pointer counts as moved when a motion event arrived or the viewport mouse position changed within
#HOVER_FRAMES frames. A hover sounds only then, so a button that slides under a still cursor stays silent.
const HOVER_FRAMES: int = 2
const HOOK_META: StringName = &"sfx_hooked"

var config: SfxConfig

#Control instance id to its override library; a null value silences that control until it leaves the tree.
var _click_overrides: Dictionary = {}
var _hover_overrides: Dictionary = {}
var _pointer_frame: int = -HOVER_FRAMES - 1
var _last_pointer: Vector2 = Vector2.ZERO
#reject_press drops its library's click for the rest of the frame, whichever order the press handlers run in.
var _reject_frame: int = -1
var _reject_library: SoundLibrary = null
#Instance id to a hooked control the pointer left for a child that takes the mouse while staying inside its rect.
var _inside: Dictionary = {}
#Instance id to a control that exited during the current input event; _input settles it with the event position.
var _exited: Dictionary = {}
#Instance id to the frame its re-entry consumed _inside; a hover that re-entry raises in that frame stays quiet.
var _reentered: Dictionary = {}


func _ready() -> void:
	config = load(CONFIG_PATH) as SfxConfig
	_last_pointer = get_viewport().get_mouse_position()
	get_tree().node_added.connect(_on_node_added)
	_hook_tree(get_tree().root)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		note_pointer()
	if event is InputEventMouse:
		_settle_inside((event as InputEventMouse).position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_inside.clear()
		_exited.clear()
		_reentered.clear()


func note_pointer() -> void:
	_last_pointer = get_viewport().get_mouse_position()
	_pointer_frame = Engine.get_process_frames()


func override_click(control: Control, library: SoundLibrary) -> void:
	_click_overrides[control.get_instance_id()] = library
	_drop_on_exit(control)


func override_hover(control: Control, library: SoundLibrary) -> void:
	_hover_overrides[control.get_instance_id()] = library
	_drop_on_exit(control)


func clear_overrides(control: Control) -> void:
	var id: int = control.get_instance_id()
	_click_overrides.erase(id)
	_hover_overrides.erase(id)
	_inside.erase(id)
	_exited.erase(id)
	_reentered.erase(id)


func click_library(control: Control) -> SoundLibrary:
	return _library_for(control, _click_overrides, &"click_sfx", config.click)


func hover_library(control: Control) -> SoundLibrary:
	return _library_for(control, _hover_overrides, &"hover_sfx", config.hover)


func play_click(control: Control) -> void:
	var library: SoundLibrary = click_library(control)
	if library == _reject_library and Engine.get_process_frames() == _reject_frame:
		return
	_queue(library)


#A disabled control plays hover_disabled when the config has one, unless a null override silences its hover.
func play_hover(control: Control) -> void:
	var library: SoundLibrary = hover_library(control)
	if _is_disabled(control):
		library = config.hover_disabled if library != null else null
		if library == null or library.is_empty():
			return
	_play_hover_gated(control, library)


#Bad Hover for a control that is not a disabled button, such as a dimmed module, under the same pointer and re-entry gate.
func play_disabled_hover(control: Control) -> void:
	var library: SoundLibrary = config.hover_disabled
	if library == null or library.is_empty():
		return
	_play_hover_gated(control, library)


func _play_hover_gated(control: Control, library: SoundLibrary) -> void:
	var id: int = control.get_instance_id()
	var replay: bool = _inside.erase(id) or _reentered.get(id, -1) == Engine.get_process_frames()
	_reentered.erase(id)
	if replay:
		return
	if _pointer_moved():
		note_pointer()
	if library == null or Engine.get_process_frames() - _pointer_frame > HOVER_FRAMES:
		return
	_queue(library, randf_range(HOVER_PITCH_LOW, HOVER_PITCH_HIGH))


#The default hover at pitch, or at a random hover pitch when pitch <= 0.0, past every override and the pointer gate.
func play_hover_cue(pitch: float = 0.0) -> void:
	_queue(config.hover, pitch if pitch > 0.0 else randf_range(HOVER_PITCH_LOW, HOVER_PITCH_HIGH))


#One stepper step: the control's click_sfx property or the default click, ignoring overrides that silence its buttons.
func play_step(control: Control) -> void:
	_queue(_library_for(control, {}, &"click_sfx", config.click))


#A press the control refuses: the click it queued this frame (or the default click) gives way to the reject cue.
func reject_press(control: Control = null) -> void:
	var library: SoundLibrary = click_library(control) if control != null else config.click
	if library != null:
		AudioManager.unqueue(library)
	_reject_library = library
	_reject_frame = Engine.get_process_frames()
	GameSfx.play_reject()


#A press on a disabled control: click_disabled past every override, or the reject cue while that slot is empty.
func play_disabled_press(_control: Control = null) -> void:
	if config.click_disabled == null or config.click_disabled.is_empty():
		GameSfx.play_reject()
		return
	_queue(config.click_disabled)


func pitch_for(ratio: float) -> float:
	return lerpf(PITCH_LOW, PITCH_HIGH, clampf(ratio, 0.0, 1.0))


func play_slider(ratio: float) -> void:
	_queue(config.slider, pitch_for(ratio))


func play_upgrade(ratio: float) -> void:
	GameSfx.note_action_cue()
	_queue(config.upgrade_click, pitch_for(ratio))


func play_summon(library: SoundLibrary = null) -> void:
	_queue(library if library != null else config.summon_window)


func play_dismiss(library: SoundLibrary = null) -> void:
	_queue(library if library != null else config.dismiss_window)


func play_equip() -> void:
	_queue(config.equip)


func play_unequip() -> void:
	_queue(config.unequip)


func _pointer_moved() -> bool:
	var pos: Vector2 = get_viewport().get_mouse_position()
	var moved: bool = pos != _last_pointer
	_last_pointer = pos
	return moved


func _on_node_added(node: Node) -> void:
	var control: Control = node as Control
	if control == null or control.get_meta(HOOK_META, 0) == control.get_instance_id():
		return
	if not (control is BaseButton or _has_bare_signal(control, &"pressed")):
		return
	control.set_meta(HOOK_META, control.get_instance_id())
	control.connect(&"pressed", play_click.bind(control))
	var hover: StringName = &"sfx_hovered" if _has_bare_signal(control, &"sfx_hovered") else &"mouse_entered"
	control.connect(hover, play_hover.bind(control))
	control.mouse_exited.connect(_on_hooked_exit.bind(control))
	control.mouse_entered.connect(_on_hooked_enter.bind(control))
	control.gui_input.connect(_on_hooked_input.bind(control))


func _has_bare_signal(target: Object, signal_name: StringName) -> bool:
	if not target.has_signal(signal_name):
		return false
	for entry: Dictionary in target.get_signal_list():
		if entry["name"] == String(signal_name):
			return (entry["args"] as Array).is_empty()
	return false


func _is_disabled(control: Control) -> bool:
	var flag: Variant = control.get(&"disabled")
	return flag is bool and flag


#Godot emits gui_input before a disabled BaseButton drops the press, so a press on a disabled control can still sound.
func _on_hooked_input(event: InputEvent, control: Control) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT and _is_disabled(control):
		play_disabled_press(control)


func _on_hooked_exit(control: Control) -> void:
	var id: int = control.get_instance_id()
	if _holds_pointer(control, get_viewport().get_mouse_position()):
		_inside[id] = control
	else:
		_inside.erase(id)
	if control.is_inside_tree() and control.get_viewport() == get_viewport():
		_exited[id] = control


func _on_hooked_enter(control: Control) -> void:
	var id: int = control.get_instance_id()
	_exited.erase(id)
	if _inside.erase(id):
		_reentered[id] = Engine.get_process_frames()


#Godot sends the enter and exit signals before _input, so exits settle against the position of the event behind them.
func _settle_inside(at: Vector2) -> void:
	if _exited.is_empty() and _inside.is_empty() and _reentered.is_empty():
		return
	for id: int in _exited.keys():
		var held: Variant = _exited[id]
		if is_instance_valid(held) and _holds_pointer(held as Control, at):
			_inside[id] = held
		else:
			_inside.erase(id)
	_exited.clear()
	for id: int in _inside.keys():
		var held: Variant = _inside[id]
		if not is_instance_valid(held) or not _holds_pointer(held as Control, at):
			_inside.erase(id)
	for id: int in _reentered.keys():
		if _reentered[id] != Engine.get_process_frames():
			_reentered.erase(id)


#at is a point in this node's viewport; a control in another viewport is tested against that viewport's pointer.
func _holds_pointer(control: Control, at: Vector2) -> bool:
	if not control.is_inside_tree() or not control.is_visible_in_tree():
		return false
	var view: Viewport = control.get_viewport()
	var point: Vector2 = at if view == get_viewport() else view.get_mouse_position()
	var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, control.size).has_point(local)


func _hook_tree(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children(true):
		_hook_tree(child)


func _drop_on_exit(control: Control) -> void:
	var drop: Callable = clear_overrides.bind(control)
	if not control.tree_exiting.is_connected(drop):
		control.tree_exiting.connect(drop)


func _library_for(control: Control, overrides: Dictionary, property: StringName,
		fallback: SoundLibrary) -> SoundLibrary:
	var id: int = control.get_instance_id()
	if overrides.has(id):
		return overrides[id]
	var own: Variant = control.get(property)
	if own is SoundLibrary:
		return own
	return fallback


func _queue(library: SoundLibrary, pitch: float = 1.0) -> void:
	AudioManager.queue(library, String(config.ui_bus), pitch)
