class_name HintScope

#Static scope rules of the MercDave overlay. The scope is the top frame of GuiFrameStack, or an
#open opens_scope panel that frame owns, or the HUD when neither is open. A target belongs to the
#first GuiModal, top frame or scope panel found walking up from it, itself included.

const HUD_KEY: StringName = &"hud"
const MIN_SIDE: float = 4.0
const PROBE: Vector2 = Vector2(24, 18)
const MAX_CONTROLS: int = 300
const MIN_CONTROL: float = 6.0


#The scan of the topmost scope: {root, key, present, visible, controls}. present holds the ids of
#visible targets in scope, visible the on screen subset; controls maps an id to the control that
#carries its marker (the first on screen instance in tree order). HUD targets count only under hud.
static func collect(hud: Node) -> Dictionary:
	var targets: Array[HelpTarget] = []
	var panels: Array[Control] = []
	for node: Node in hud.get_tree().get_nodes_in_group(HelpTarget.GROUP):
		var link: HelpTarget = node as HelpTarget
		if link == null or link.control() == null:
			continue
		targets.append(link)
		if link.opens_scope:
			panels.append(link.control())
	var top: Control = GuiFrameStack.top()
	var root: Control = top
	for panel: Control in panels:
		if panel.is_visible_in_tree() and owner_of(panel.get_parent(), top, panels) == top \
				and (top != null or hud.is_ancestor_of(panel)):
			root = panel
			break
	var present: Array[StringName] = []
	var shown: Array[StringName] = []
	var controls: Dictionary = {}
	for link: HelpTarget in targets:
		if link.hint == null:
			continue
		var id: StringName = link.hint_id()
		if shown.has(id):
			continue
		var box: Control = link.control()
		if not box.is_visible_in_tree() or owner_of(box, top, panels) != root:
			continue
		if root == null and not hud.is_ancestor_of(box):
			continue
		if not present.has(id):
			present.append(id)
		if on_screen(box):
			shown.append(id)
			controls[id] = box
		elif not controls.has(id):
			controls[id] = box
	return {"root": root, "key": key_of(root), "present": present, "visible": shown, "controls": controls}


static func owner_of(node: Node, top: Control, panels: Array[Control]) -> Control:
	var walk: Node = node
	while walk != null:
		if walk is Control and (walk is GuiModal or walk == top or panels.has(walk as Control)):
			return walk as Control
		walk = walk.get_parent()
	return null


#&"hud", else the scene of the frame (a SubWindow's open content) or of the scope panel.
static func key_of(root: Control) -> StringName:
	if root == null:
		return HUD_KEY
	var window: SubWindow = root as SubWindow
	if window != null and window.current() != null and window.current().scene_file_path != "":
		return StringName(window.current().scene_file_path)
	if root.scene_file_path != "":
		return StringName(root.scene_file_path)
	var source: Script = root.get_script() as Script
	return StringName(source.resource_path if source != null else String(root.name))


#True when the probe point near the top left of box lies in the viewport and inside every clipping
#ancestor up to the first top level one.
static func on_screen(box: Control) -> bool:
	var rect: Rect2 = box.get_global_rect()
	if rect.size.x < MIN_SIDE or rect.size.y < MIN_SIDE:
		return false
	var probe: Vector2 = rect.position + Vector2(minf(rect.size.x * 0.5, PROBE.x), minf(rect.size.y * 0.5, PROBE.y))
	if not box.get_viewport_rect().has_point(probe):
		return false
	var walk: Node = null if box.top_level else box.get_parent()
	while walk is Control:
		var clip: Control = walk
		if clip.clip_contents and not clip.get_global_rect().has_point(probe):
			return false
		if clip.top_level:
			break
		walk = clip.get_parent()
	return true


#Rects of the visible buttons and line edits under root, which the card avoids covering.
static func control_rects(root: Node, skip: Node) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var queue: Array[Node] = [root]
	while not queue.is_empty() and out.size() < MAX_CONTROLS:
		var node: Node = queue.pop_back()
		if node == skip or (node is CanvasItem and not (node as CanvasItem).visible):
			continue
		if node is BaseButton or node is LineEdit:
			var rect: Rect2 = (node as Control).get_global_rect()
			if rect.size.x >= MIN_CONTROL and rect.size.y >= MIN_CONTROL:
				out.append(rect)
		for child: Node in node.get_children():
			queue.append(child)
	return out
