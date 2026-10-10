class_name HelpTarget extends Node

#The scene side link of one MercDave hint: drag the hint .tres onto hint and, when the control is
#not the parent, the control onto target. Changes that can move a marker ask for a rescan.

const GROUP: StringName = &"help_targets"

@export var hint: MercdaveHint
@export var target: NodePath = ^".."
#Set on a panel that is its own hint scope while it is open (NotificationPanel); target is the panel.
@export var opens_scope: bool = false

var _control: Control = null


func _ready() -> void:
	add_to_group(GROUP)
	if hint == null:
		push_warning("HelpTarget %s has no hint" % get_path())
	_control = get_node_or_null(target) as Control
	if _control == null:
		push_warning("HelpTarget %s: target %s is not a Control" % [get_path(), target])
		return
	_control.visibility_changed.connect(_ping)
	_control.tree_entered.connect(_ping)
	_control.tree_exiting.connect(_ping)
	var walk: Node = _control.get_parent()
	while walk != null:
		if walk is ScrollContainer:
			var scroll: ScrollContainer = walk
			scroll.get_h_scroll_bar().value_changed.connect(_on_scrolled)
			scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)
		walk = walk.get_parent()
	_ping()


func _exit_tree() -> void:
	_ping()


#The linked control, or null when the target never resolved or was freed.
func control() -> Control:
	if not is_instance_valid(_control):
		return null
	return _control


func hint_id() -> StringName:
	return &"" if hint == null else hint.id()


func _ping() -> void:
	if Mercdave.is_inside_tree():
		Mercdave.request_scan()


func _on_scrolled(_value: float) -> void:
	_ping()
