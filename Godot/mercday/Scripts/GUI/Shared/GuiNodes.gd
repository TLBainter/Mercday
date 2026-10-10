class_name GuiNodes

#Node tree helpers the GUI screens share: clearing a container, turning the pointer off for a whole
#subtree and collecting the children of one type.


#Takes every child out of parent at once and frees it at the end of the frame.
static func clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


#Sets MOUSE_FILTER_IGNORE on root and on every Control below it.
static func ignore_mouse(root: Node) -> void:
	var control: Control = root as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in root.get_children():
		ignore_mouse(child)


#The direct children of parent that are instances of kind, a script class or a native class.
static func children_of(parent: Node, kind: Variant) -> Array:
	var out: Array = []
	for child: Node in parent.get_children():
		if is_instance_of(child, kind):
			out.append(child)
	return out
