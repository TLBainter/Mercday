class_name PlanSwitchDialog extends Control

#The modal that confirms a plan switch. Which sections it shows depends on the direction: dropping
#to Free warns about the contracts that leave the board, leaving Enterprise lists the upgrades the
#guild loses, and any upgrade lists what the new plan includes. The fee shown is one month of the
#target plan; the confirm side is dead while the bank cannot cover it.

signal confirmed(plan: int)
signal cancelled

const BOX_WIDTH: float = 600.0
const BOX_BG: Color = Color("#1a2b4d")
const BOX_BORDER: int = 4
const BOX_INSET: float = 4.0
const EDGE_HI: Color = Color("#28447a")
const EDGE_LO: Color = Color("#111c33")
const EDGE_PX: float = 4.0
const RING_UP: Color = Color("#f28c28")
const RING_DOWN: Color = Color("#f2b33d")
const WARN: Color = Color("#f2b33d")
const SKY: Color = Color("#9cc6ef")
const CREAM: Color = Color("#f3ead7")
const RED: Color = Color("#e8583f")
const GREEN: Color = Color("#6cc36a")
const DEAD_ALPHA: float = 0.4
const ROW_GAP: int = 6
const DOT_PX: float = 8.0
const COST_LABEL: String = "Monthly Service Fee"
const BUTTON_SIZE: Vector2 = Vector2(120.0, 34.0)
const HEAD_SLACK: float = 60.0

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Box
@onready var edges: Control = $Box/Edges
@onready var kind_label: Label = $Box/Pad/Rows/Kind
@onready var target_label: Label = $Box/Pad/Rows/Target
@onready var sections_box: VBoxContainer = $Box/Pad/Rows/Sections
@onready var cost_label: Label = $Box/Pad/Rows/Cost/CostLabel
@onready var cost_value: Label = $Box/Pad/Rows/Cost/CostValue
@onready var cost_glyph: NoteIcon = $Box/Pad/Rows/Cost/CostGlyph
@onready var note_label: Label = $Box/Pad/Rows/Note
@onready var button_row: HBoxContainer = $Box/Pad/Rows/Buttons

var _check_row: PackedScene = preload("res://Scenes/GUI/Shared/CheckRow.tscn")
var _target: int = SubscriptionManager.Plan.FREE
var _down: bool = false
var _leave_ent: bool = false
var _can: bool = false
var _fee: int = 0
var _lines: Array[String] = []
var _link: BevelButton = null
var _solid: BevelButton = null
var _viewport_hook: Viewport = null


func _ready() -> void:
	top_level = true
	edges.draw.connect(_draw_edges)
	edges.resized.connect(edges.queue_redraw)
	box.custom_minimum_size.x = BOX_WIDTH
	cost_label.text = COST_LABEL
	cost_label.add_theme_color_override(&"font_color", SKY)
	note_label.add_theme_color_override(&"font_color", SKY)
	_hook_viewport()
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_unhook_viewport()
		GuiFrameStack.remove(self)
	elif what == NOTIFICATION_ENTER_TREE and is_node_ready():
		_hook_viewport()


#Opens the modal for one target plan and works out the direction and the sections from there.
func open_for(plan: int) -> void:
	_target = clampi(plan, SubscriptionManager.Plan.FREE, SubscriptionManager.Plan.ENTERPRISE)
	var current: int = SubscriptionManager.plan()
	_down = _target < current
	_leave_ent = (current == SubscriptionManager.Plan.ENTERPRISE
		and _target != SubscriptionManager.Plan.ENTERPRISE)
	_fee = SubscriptionManager.service_fee(_target)
	_can = GameState.bank_notes >= _fee
	_rebuild()
	show()
	GuiFrameStack.push(self)
	_place_box()


func target_plan() -> int:
	return _target


func is_downgrade() -> bool:
	return _down


func can_afford() -> bool:
	return _can


func fee() -> int:
	return _fee


func kind_text() -> String:
	return "Downgrade Plan" if _down else "Upgrade Plan"


func ring_color() -> Color:
	return RING_DOWN if _down else RING_UP


func ok_text() -> String:
	return "Downgrade" if _down else "Upgrade"


func note_text() -> String:
	if _fee <= 0:
		return "No service fee."
	var per_merc: int = int(UpgradeDefs.plan_data(_target).get("per_merc", 0))
	return "%d notes per merc, billed with Loans & Services on the 15th." % per_merc


func cost_color() -> Color:
	return CREAM if _can else RED


#The section heads in the order they are shown; the tests read this instead of the node tree.
func sections() -> Array[String]:
	return _lines.duplicate()


func press_ok() -> void:
	if not _can:
		return
	if not SubscriptionManager.switch_plan(_target):
		return
	var plan: int = _target
	_dismiss()
	confirmed.emit(plan)


func press_back() -> void:
	_dismiss()
	cancelled.emit()


func _rebuild() -> void:
	if not is_node_ready():
		return
	kind_label.text = kind_text()
	kind_label.add_theme_color_override(&"font_color", ring_color())
	target_label.text = SubscriptionManager.plan_name(_target)
	cost_value.text = "%d" % _fee
	cost_value.add_theme_color_override(&"font_color", cost_color())
	cost_glyph.visible = _fee > 0
	note_label.text = note_text()
	_build_sections()
	_build_buttons()
	_apply_ring()


func _apply_ring() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BOX_BG
	style.border_width_left = BOX_BORDER
	style.border_width_top = BOX_BORDER
	style.border_width_right = BOX_BORDER
	style.border_width_bottom = BOX_BORDER
	style.border_color = ring_color()
	style.content_margin_left = BOX_INSET
	style.content_margin_top = BOX_INSET
	style.content_margin_right = BOX_INSET
	style.content_margin_bottom = BOX_INSET
	box.add_theme_stylebox_override(&"panel", style)


func _build_sections() -> void:
	_lines.clear()
	for child: Node in sections_box.get_children():
		sections_box.remove_child(child)
		child.queue_free()
	var board: int = SubscriptionManager.board_count()
	var free_board: int = UpgradeDefs.plan_max_contracts(SubscriptionManager.Plan.FREE, 0)
	if _target == SubscriptionManager.Plan.FREE and board > free_board:
		var lost: int = board - free_board
		_add_head("%d contracts will be removed from your board in %d Days if you proceed"
			% [lost, SubscriptionManager.days_to_bill()], WARN)
	if _leave_ent:
		var owned: Array[String] = SubscriptionManager.owned_lines()
		if not owned.is_empty():
			_add_head("You will lose access to the following upgrades and will have to purchase"
				+ " them individually again", WARN)
			for line: String in owned:
				_add_dot_row(line, RED)
	if not _down:
		_add_head("Includes:", SKY)
		for line: Variant in UpgradeDefs.plan_data(_target).get("features", []) as Array:
			_add_check_row(String(line))
	if _down and _lines.is_empty():
		_add_head("You will lose the features of %s." % SubscriptionManager.plan_name(), WARN)


func _add_head(text: String, tint: Color) -> void:
	var head: Label = Label.new()
	head.text = text
	head.theme_type_variation = &"DescriptionLabel"
	head.add_theme_color_override(&"font_color", tint)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = BOX_WIDTH - HEAD_SLACK
	sections_box.add_child(head)
	_lines.append(text)


func _add_check_row(text: String) -> void:
	var row: CheckRow = _check_row.instantiate() as CheckRow
	sections_box.add_child(row)
	row.color = GREEN
	row.text = text


#The lost upgrades read as a red dot and the tier line; nothing about them is clickable.
func _add_dot_row(text: String, tint: Color) -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", ROW_GAP)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot: ColorRect = ColorRect.new()
	dot.color = tint
	dot.custom_minimum_size = Vector2.ONE * DOT_PX
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(dot)
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"DescriptionLabel"
	label.add_theme_color_override(&"font_color", CREAM)
	line.add_child(label)
	sections_box.add_child(line)


#An upgrade confirms on a green button with Back as a link; a downgrade swaps the two, so the
#dangerous answer is the quiet one.
func _build_buttons() -> void:
	for child: Node in button_row.get_children():
		button_row.remove_child(child)
		child.queue_free()
	_link = null
	_solid = null
	if _down:
		_link = _make_bevel(ok_text(), &"danger")
		_link.pressed.connect(press_ok)
		_solid = _make_bevel("Back", &"blue")
		_solid.pressed.connect(press_back)
		_link.modulate.a = 1.0 if _can else DEAD_ALPHA
	else:
		_link = _make_bevel("Back", &"blue")
		_link.pressed.connect(press_back)
		_solid = _make_bevel(ok_text(), &"go")
		_solid.pressed.connect(press_ok)
		_solid.modulate.a = 1.0 if _can else DEAD_ALPHA
	button_row.add_child(_link)
	button_row.add_child(_solid)


func ok_alpha() -> float:
	return 1.0 if _can else DEAD_ALPHA


func _make_bevel(text: String, kind_name: StringName) -> BevelButton:
	var node: BevelButton = BevelButton.make(text, kind_name, BUTTON_SIZE)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


func _draw_edges() -> void:
	var span: Vector2 = edges.size
	edges.draw_rect(Rect2(0.0, 0.0, span.x, EDGE_PX), EDGE_HI)
	edges.draw_rect(Rect2(0.0, 0.0, EDGE_PX, span.y), EDGE_HI)
	edges.draw_rect(Rect2(0.0, span.y - EDGE_PX, span.x, EDGE_PX), EDGE_LO)
	edges.draw_rect(Rect2(span.x - EDGE_PX, 0.0, EDGE_PX, span.y), EDGE_LO)


func _place_box() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view: Vector2 = get_viewport().get_visible_rect().size
	backdrop.offset_bottom = -GuiFrameStack.bottom_reserve
	box.reset_size()
	box.size.x = BOX_WIDTH
	box.position = Vector2((view.x - box.size.x) / 2.0,
		(GuiFrameStack.band_height(view.y) - box.size.y) / 2.0)
	box.position.y = maxf(box.position.y, 0.0)


func _dismiss() -> void:
	hide()
	GuiFrameStack.remove(self)


func _on_viewport_resized() -> void:
	if is_node_ready() and visible:
		_place_box()


func _hook_viewport() -> void:
	if _viewport_hook != null:
		return
	_viewport_hook = get_viewport()
	if _viewport_hook != null:
		_viewport_hook.size_changed.connect(_on_viewport_resized)


func _unhook_viewport() -> void:
	if _viewport_hook == null:
		return
	if not is_instance_valid(_viewport_hook):
		_viewport_hook = null
		return
	if _viewport_hook.size_changed.is_connected(_on_viewport_resized):
		_viewport_hook.size_changed.disconnect(_on_viewport_resized)
	_viewport_hook = null


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.top() != self:
		return
	press_back()
	get_viewport().set_input_as_handled()
