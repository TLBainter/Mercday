class_name ActiveCrew extends VBoxContainer

#The crew of a posting: one boxed portrait column per team member, the leader's role in orange. A
#running posting reads its team off the run, a settled one the members of its result. A column
#answers the hover with the crew tooltip and the click with merc_picked.

signal merc_picked(uid: int)

const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const PORTRAIT_PX: int = 48
const LEADER_COLOR: Color = GuiColors.ORANGE
const BOX_BG: Color = GuiColors.ROW_FILL
const BOX_RING: Color = GuiColors.BLUE_HI
const BOX_RING_WIDTH: int = 2
const COLUMN_WIDTH: int = 60
#Over a settled crew; a running one keeps the caption the scene gives it.
const SETTLED_CAPTION: String = "Crew"

@onready var caption_label: Label = $Caption
@onready var columns: HBoxContainer = $Columns
@onready var tooltip: CrewTooltip = $Tip

var run: ActiveRun = null
var members: Array[ResultMemberData] = []

var _run_caption: String = ""


func _ready() -> void:
	_run_caption = caption_label.text
	_refresh()


func set_run(new_run: ActiveRun) -> void:
	run = new_run
	members = []
	_refresh()


#The members of a settled result, in team order; a later set_run takes the strip back.
func set_members(new_members: Array[ResultMemberData]) -> void:
	run = null
	members = new_members.duplicate()
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
	GuiNodes.clear(columns)
	tooltip.hide_tip()
	caption_label.text = SETTLED_CAPTION if run == null and not members.is_empty() else _run_caption
	if run != null:
		for member: TeamMember in run.team:
			if member != null:
				columns.add_child(_run_column(member))
	else:
		for member: ResultMemberData in members:
			if member != null:
				columns.add_child(_settled_column(member))
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


func _run_column(member: TeamMember) -> Button:
	var view: MercView = BenefitsManager.view_of(member.merc_uid)
	var holder: Button = _make_column(view, member.role)
	holder.pressed.connect(func() -> void: merc_picked.emit(member.merc_uid))
	holder.mouse_entered.connect(func() -> void: _on_hover(holder, view, member))
	holder.mouse_exited.connect(tooltip.hide_tip)
	return holder


#A member off the roster still shows the portrait of the record; a click asks for the merc view
#only when that view resolves.
func _settled_column(member: ResultMemberData) -> Button:
	var view: MercView = member.merc_view()
	var holder: Button = _make_column(view, member.role)
	if view != null:
		holder.pressed.connect(func() -> void: merc_picked.emit(member.uid))
	holder.mouse_entered.connect(func() -> void: _on_settled_hover(holder, member))
	holder.mouse_exited.connect(tooltip.hide_tip)
	return holder


func _make_column(view: MercView, role_text: String) -> Button:
	var holder: Button = Button.new()
	holder.flat = true
	holder.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 2)
	var role: Label = Label.new()
	role.text = role_text
	role.theme_type_variation = &"SmallLabel"
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if role_text == ContractResultData.ROLE_LEADER:
		role.add_theme_color_override("font_color", LEADER_COLOR)
	stack.add_child(role)
	var box: PanelContainer = PanelContainer.new()
	box.name = "Box"
	#The ring the html gives a crew portrait; the default content margins hold it 2 px off the art.
	box.add_theme_stylebox_override("panel", GuiStyle.flat(BOX_BG, BOX_RING_WIDTH, BOX_RING))
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
	return holder


func _on_hover(anchor: Control, view: MercView, member: TeamMember) -> void:
	tooltip.set_member(view, member.role, member.match)
	tooltip.show_at(anchor)


func _on_settled_hover(anchor: Control, member: ResultMemberData) -> void:
	tooltip.set_result_member(member)
	tooltip.show_at(anchor)
