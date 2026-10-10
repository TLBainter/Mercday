class_name LegalCrewModule extends VBoxContainer

#The crew strip of the Review dialog: one boxed portrait per merc named on the case, its role over
#it, and the shared crew tooltip on hover.

const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const TOOLTIP_SCENE: PackedScene = preload("res://Scenes/GUI/Contracts/CrewTooltip.tscn")
const PORTRAIT_PX: int = 48
const COLUMN_WIDTH: int = 72
const BOX_RING_WIDTH: int = 2
const DEFAULT_FIT: float = 2.5
const EMPTY_TEXT: String = "No mercs on record."

var caption: String = "Crew":
	set(value):
		caption = value
		if caption_label != null:
			caption_label.text = value

var caption_label: Label = null
var columns: HBoxContainer = null
var empty_label: Label = null
var tooltip: CrewTooltip = null

var members: Array[Dictionary] = []


func _ready() -> void:
	_build()
	_refresh()


#Each row carries a uid and the role wording the dialog wants over the portrait.
func set_members(rows: Array[Dictionary]) -> void:
	members = rows
	_refresh()


func member_count() -> int:
	return columns.get_child_count() if columns != null else 0


func member_uid(i: int) -> int:
	if i < 0 or i >= members.size():
		return 0
	return int(members[i].get("uid", 0))


func member_role(i: int) -> String:
	if i < 0 or i >= members.size():
		return ""
	return str(members[i].get("role", ""))


func caption_text() -> String:
	return caption_label.text if caption_label != null else ""


func empty_visible() -> bool:
	return empty_label != null and empty_label.visible


func tip() -> CrewTooltip:
	return tooltip


func portrait_box(i: int) -> PanelContainer:
	var holder: Control = _holder(i)
	if holder == null:
		return null
	return holder.find_child("Box", true, false) as PanelContainer


#Headless stand-in for the mouse: the same call the hover makes.
func hover(i: int) -> void:
	var holder: Control = _holder(i)
	if holder == null or tooltip == null:
		return
	tooltip.set_member(BenefitsManager.view_of(member_uid(i)), member_role(i),
		_fit_of(member_uid(i)))
	tooltip.show_at(holder)


func unhover() -> void:
	if tooltip != null:
		tooltip.hide_tip()


func press_member(i: int) -> void:
	var holder: Button = _holder(i) as Button
	if holder != null:
		holder.pressed.emit()


func _holder(i: int) -> Control:
	if columns == null or i < 0 or i >= columns.get_child_count():
		return null
	return columns.get_child(i) as Control


func _build() -> void:
	if columns != null:
		return
	add_theme_constant_override(&"separation", 6)
	caption_label = LegalStyle.head(caption)
	caption_label.name = "Caption"
	add_child(caption_label)
	columns = GuiStyle.hbox(8)
	columns.name = "Columns"
	add_child(columns)
	empty_label = GuiStyle.label(EMPTY_TEXT, GuiStyle.BODY, 12, GuiColors.MUTED)
	empty_label.name = "Empty"
	add_child(empty_label)
	tooltip = TOOLTIP_SCENE.instantiate() as CrewTooltip
	tooltip.name = "Tip"
	add_child(tooltip)


func _refresh() -> void:
	if columns == null:
		return
	GuiNodes.clear(columns)
	unhover()
	for i: int in range(members.size()):
		columns.add_child(_make_column(i))
	empty_label.visible = members.is_empty()
	_size_columns()


func _size_columns() -> void:
	for child: Node in columns.get_children():
		var holder: Control = child as Control
		if holder == null or holder.get_child_count() == 0:
			continue
		var stack: Control = holder.get_child(0) as Control
		if stack == null:
			continue
		holder.custom_minimum_size = Vector2(float(COLUMN_WIDTH),
			stack.get_combined_minimum_size().y)


func _make_column(i: int) -> Control:
	var uid: int = member_uid(i)
	var view: MercView = BenefitsManager.view_of(uid)
	var holder := Button.new()
	holder.name = "Member%d" % i
	holder.flat = true
	holder.focus_mode = Control.FOCUS_NONE
	holder.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	var stack: VBoxContainer = GuiStyle.vbox(2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	var role: Label = GuiStyle.label(member_role(i), GuiStyle.SILK, 9, GuiColors.SKY)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(role)
	var box := PanelContainer.new()
	box.name = "Box"
	box.add_theme_stylebox_override(&"panel", GuiStyle.flat(GuiColors.ROW_FILL,
		BOX_RING_WIDTH, GuiColors.BLUE_HI, 2.0))
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait: MercPortrait = PORTRAIT_SCENE.instantiate() as MercPortrait
	portrait.pixel_size = PORTRAIT_PX
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait)
	stack.add_child(box)
	holder.add_child(stack)
	if view != null:
		portrait.set_merc(view)
	holder.mouse_entered.connect(hover.bind(i))
	holder.mouse_exited.connect(unhover)
	return holder


#The design names no match source for a legal case, so the finance fit stands in for the stars.
func _fit_of(uid: int) -> float:
	if GameState.merc_by_uid(uid) == null:
		return DEFAULT_FIT
	return FinanceManager.merc_fit(uid)
