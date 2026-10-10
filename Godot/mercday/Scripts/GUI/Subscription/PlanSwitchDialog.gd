class_name PlanSwitchDialog extends ModalDialog

#The modal that confirms a plan switch. Which sections it shows depends on the direction: dropping
#to Free warns about the contracts that leave the board, leaving Enterprise shows each upgrade the
#guild loses as a card in a scrolling list, and any upgrade lists what the new plan includes. The fee
#shown is one month of the target plan; the confirm side is dead while the bank cannot cover it.

const RING_UP: Color = GuiColors.ORANGE
const RING_DOWN: Color = GuiColors.AMBER
const WARN: Color = GuiColors.AMBER
const SKY: Color = GuiColors.SKY
const CREAM: Color = GuiColors.CREAM
const RED: Color = GuiColors.RED
const GREEN: Color = GuiColors.GREEN
const DEAD_ALPHA: float = 0.4
const COST_LABEL: String = "Monthly Service Fee"
const HEAD_SLACK: float = 60.0
#The box is BOX_H tall while the upgrade list shows, and never taller than the band less BAND_GAP.
const BOX_H: float = 560.0
const BAND_GAP: float = 24.0

@onready var kind_label: Label = $Box/Pad/Rows/Kind
@onready var target_label: Label = $Box/Pad/Rows/Target
@onready var sections_box: VBoxContainer = $Box/Pad/Rows/Sections
@onready var cost_label: Label = $Box/Pad/Rows/Cost/CostLabel
@onready var cost_value: NotesLabel = $Box/Pad/Rows/Cost/CostValue
@onready var note_label: Label = $Box/Pad/Rows/Note
@onready var modules_box: PanelContainer = $Box/Pad/Rows/Modules
@onready var modules_scroll: ScrollContainer = $Box/Pad/Rows/Modules/Scroll
@onready var modules_list: VBoxContainer = $Box/Pad/Rows/Modules/Scroll/List

var _check_row: PackedScene = preload("res://Scenes/GUI/Shared/CheckRow.tscn")
var _target: int = SubscriptionManager.Plan.FREE
var _down: bool = false
var _leave_ent: bool = false
var _can: bool = false
var _fee: int = 0
var _lines: Array[String] = []
var _owned: Array[Dictionary] = []
var _link: BevelButton = null
var _solid: BevelButton = null


func _ready() -> void:
	super()
	cost_label.text = COST_LABEL
	cost_label.add_theme_color_override(&"font_color", SKY)
	note_label.add_theme_color_override(&"font_color", SKY)


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
	present()


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


func ok_text() -> String:
	return "Downgrade" if _down else "Upgrade"


func note_text() -> String:
	if _fee <= 0:
		return "No service fee."
	var per_merc: int = int(UpgradeDefs.plan_data(_target).get("per_merc", 0))
	return "%d notes per merc, billed with Guild Expenses on the 2nd." % per_merc


func cost_color() -> Color:
	return CREAM if _can else RED


#The section heads in the order they are shown; the tests read this instead of the node tree.
func sections() -> Array[String]:
	return _lines.duplicate()


func module_count() -> int:
	return modules_list.get_child_count()


#The loss card at index in the order it is shown, or null.
func module(index: int) -> UpgradeLossCard:
	if index < 0 or index >= module_count():
		return null
	return modules_list.get_child(index) as UpgradeLossCard


func modules_visible() -> bool:
	return modules_box.visible


func list_box() -> VBoxContainer:
	return modules_list


#A dead confirm or a switch the manager refuses keeps the dialog open and plays the reject cue.
func _on_confirm() -> bool:
	if not _can:
		UiSfx.reject_press(confirm_button)
		return false
	if not SubscriptionManager.switch_plan(_target):
		UiSfx.reject_press(confirm_button)
		return false
	return true


func _layout() -> void:
	box.custom_minimum_size.y = _box_height()
	super()


#BOX_H while the loss list shows, held to what the band above the bottom bar leaves; 0 lets the box fit its rows.
func _box_height() -> float:
	if not modules_visible():
		return 0.0
	var band: float = GuiFrameStack.band_height(get_viewport().get_visible_rect().size.y)
	return maxf(0.0, minf(BOX_H, band - BAND_GAP))


func _rebuild() -> void:
	if not is_node_ready():
		return
	ring_color = RING_DOWN if _down else RING_UP
	kind_label.text = kind_text()
	kind_label.add_theme_color_override(&"font_color", ring_color)
	target_label.text = SubscriptionManager.plan_name(_target)
	cost_value.text_override = "%d" % _fee
	cost_value.value_color = cost_color()
	cost_value.show_glyph = _fee > 0
	note_label.text = note_text()
	if _leave_ent:
		_owned = SubscriptionManager.owned_upgrades()
	else:
		_owned = []
	_build_sections()
	_build_modules()
	_build_buttons()


func _build_sections() -> void:
	_lines.clear()
	GuiNodes.clear(sections_box)
	var board: int = GameState.board.own_open() if GameState.board != null else 0
	var free_board: int = UpgradeDefs.plan_max_contracts(SubscriptionManager.Plan.FREE, 0)
	if _target == SubscriptionManager.Plan.FREE and board > free_board:
		var lost: int = board - free_board
		_add_head(("%d postings are over the Free cap of %d; they stay until they close and nothing new is posted"
			+ " until the board is under the cap") % [lost, free_board], WARN)
	if not _owned.is_empty():
		_add_head("You will lose access to the following upgrades and will have to purchase"
			+ " them individually again", WARN)
	if not _down:
		_add_head("Includes:", SKY)
		for line: Variant in UpgradeDefs.plan_data(_target).get("features", []) as Array:
			_add_check_row(String(line))
	if _down and _lines.is_empty():
		_add_head("You will lose the features of %s." % SubscriptionManager.plan_name(), WARN)


#One card per owned upgrade, scrolled back to the top; the shell hides when nothing is lost.
func _build_modules() -> void:
	GuiNodes.clear(modules_list)
	for row: Dictionary in _owned:
		var card: UpgradeLossCard = UpgradeLossCard.new()
		card.setup(String(row["id"]), int(row["tier"]))
		modules_list.add_child(card)
	modules_box.visible = not _owned.is_empty()
	modules_scroll.scroll_vertical = 0


func _add_head(text: String, tint: Color) -> void:
	var heading: Label = Label.new()
	heading.text = text
	heading.theme_type_variation = &"DescriptionLabel"
	heading.add_theme_color_override(&"font_color", tint)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x = box_width - HEAD_SLACK
	sections_box.add_child(heading)
	_lines.append(text)


func _add_check_row(text: String) -> void:
	var row: CheckRow = _check_row.instantiate() as CheckRow
	sections_box.add_child(row)
	row.color = GREEN
	row.text = text


#An upgrade confirms on a green button with Back as a link; a downgrade swaps the two, so the
#dangerous answer is the quiet one.
func _build_buttons() -> void:
	confirm_text = ok_text()
	confirm_kind = &"danger" if _down else &"go"
	_link = confirm_button if _down else cancel_button
	_solid = cancel_button if _down else confirm_button
	button_row.move_child(_link, 0)
	confirm_button.modulate.a = ok_alpha()


func ok_alpha() -> float:
	return 1.0 if _can else DEAD_ALPHA
