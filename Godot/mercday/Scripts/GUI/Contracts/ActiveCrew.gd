class_name ActiveCrew extends VBoxContainer

#The crew of a running posting: one boxed portrait column per team member, the leader's role in
#orange. A column answers the hover with the crew tooltip and the click with merc_picked.

signal merc_picked(uid: int)

const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const PORTRAIT_PX: int = 48
const LEADER_COLOR: Color = Color("#f28c28")
const BOX_BG: Color = Color("#0e1628")
const BOX_RING: Color = Color("#3b6fb6")
const BOX_RING_WIDTH: int = 2
const COLUMN_WIDTH: int = 72

@onready var caption_label: Label = $Caption
@onready var columns: HBoxContainer = $Columns
@onready var tooltip: CrewTooltip = $Tip

var run: ActiveRun = null


func _ready() -> void:
	_refresh()


func set_run(new_run: ActiveRun) -> void:
	run = new_run
	_refresh()


func portrait_count() -> int:
	return columns.get_child_count() if is_node_ready() else 0


func tip() -> CrewTooltip:
	return tooltip


func portrait_box(index: int) -> PanelContainer:
	if not is_node_ready() or index < 0 or index >= columns.get_child_count():
		return null
	return columns.get_child(index).find_child("Box", true, false) as PanelContainer


func _refresh() -> void:
	if not is_node_ready():
		return
	for child: Node in columns.get_children():
		columns.remove_child(child)
		child.queue_free()
	tooltip.hide_tip()
	if run == null:
		return
	for member: TeamMember in run.team:
		if member == null:
			continue
		columns.add_child(_make_column(member))
	_size_columns()


#A Button is no container, so each holder takes the height its stack asks for once it is in the tree.
func _size_columns() -> void:
	for child: Node in columns.get_children():
		var stack: Control = child.get_child(0) as Control
		if stack == null:
			continue
		var holder: Control = child as Control
		holder.custom_minimum_size = Vector2(float(COLUMN_WIDTH),
			stack.get_combined_minimum_size().y)


func _make_column(member: TeamMember) -> Control:
	var view: MercView = _view_of(member.merc_uid)
	var holder: Button = Button.new()
	holder.flat = true
	holder.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 2)
	var role: Label = Label.new()
	role.text = member.role
	role.theme_type_variation = &"SmallLabel"
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if member.role == "Leader":
		role.add_theme_color_override("font_color", LEADER_COLOR)
	stack.add_child(role)
	var box: PanelContainer = PanelContainer.new()
	box.name = "Box"
	box.add_theme_stylebox_override("panel", _make_box())
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait: MercPortrait = PORTRAIT_SCENE.instantiate()
	portrait.pixel_size = PORTRAIT_PX
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait)
	stack.add_child(box)
	holder.add_child(stack)
	if view != null:
		portrait.set_merc(view)
	holder.pressed.connect(func() -> void: merc_picked.emit(member.merc_uid))
	holder.mouse_entered.connect(func() -> void: _on_hover(holder, view, member))
	holder.mouse_exited.connect(tooltip.hide_tip)
	return holder


#The ring the html gives a crew portrait; the default content margins hold it 2 px off the art.
static func _make_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BOX_BG
	box.border_color = BOX_RING
	box.border_width_left = BOX_RING_WIDTH
	box.border_width_top = BOX_RING_WIDTH
	box.border_width_right = BOX_RING_WIDTH
	box.border_width_bottom = BOX_RING_WIDTH
	return box


func _on_hover(anchor: Control, view: MercView, member: TeamMember) -> void:
	tooltip.set_member(view, member.role, member.match)
	tooltip.show_at(anchor)


func _view_of(uid: int) -> MercView:
	for view: MercView in GameState.roster:
		if view.uid == uid:
			return view
	return null
