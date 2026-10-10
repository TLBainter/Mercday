class_name OverviewTab extends MarginContainer

#The first tab: the tradition title row, the four attributes, one middle row holding the level badge
#over the Coaching box, the resource bars and the scrolling lifepath list, then the captioned info
#rows and the knowledge and tool chips. Lineage and salary live on the MercHeader. Three of these
#sections are sold by an upgrade, so each keeps a LockBlock beside it: the block decides for itself
#whether its key is met, and this page only swaps the real list for it.

const EMPTY_TEXT: String = "None"
const LIFEPATH_SLOTS: int = 8
const HP_COLOR: Color = Color("#d6453d")
const EP_COLOR: Color = GuiColors.GREEN
const MP_COLOR: Color = GuiColors.LIGHT_BLUE
const LIFEPATH_KIND: String = "Lifepath Event"
const KNOWLEDGE_KIND: String = "Knowledge"
const TOOL_KIND: String = "Tool"

signal coach_pressed

@onready var title_row: TraditionModule = $Pad/Rows/TitleRow
@onready var sigil_box: PanelContainer = $Pad/Rows/TitleRow/Row/SigilBox
@onready var sigil: TraditionSigil = $Pad/Rows/TitleRow/Row/SigilBox/Center/Sigil
@onready var tradition_label: Label = $Pad/Rows/TitleRow/Row/Name
@onready var attributes: HBoxContainer = $Pad/Rows/Attributes
@onready var middle: HBoxContainer = $Pad/Rows/Middle
@onready var badge: LevelBadge = $Pad/Rows/Middle/Left/Badge
@onready var coaching: CoachingBox = $Pad/Rows/Middle/Left/Coaching
@onready var hp_bar: ResourceBar = $Pad/Rows/Middle/Resources/Bars/Hp
@onready var ep_bar: ResourceBar = $Pad/Rows/Middle/Resources/Bars/Ep
@onready var mp_bar: ResourceBar = $Pad/Rows/Middle/Resources/Bars/Mp
@onready var fields: GridContainer = $Pad/Rows/Fields
@onready var employment_field: InfoField = $Pad/Rows/Fields/Employment
@onready var opinion_field: InfoField = $Pad/Rows/Fields/Opinion
@onready var status_field: InfoField = $Pad/Rows/Fields/Status
@onready var lifepath_scroll: ScrollContainer = $Pad/Rows/Middle/Lifepath/Scroll
@onready var lifepath_lock: LockBlock = $Pad/Rows/Middle/Lifepath/Lock
@onready var lifepath_list: VBoxContainer = $Pad/Rows/Middle/Lifepath/Scroll/Pad/Chips
@onready var lifepath_head: SectionHead = $Pad/Rows/Middle/Lifepath/Head
@onready var lifepath_count: Label = $Pad/Rows/Middle/Lifepath/Head/Count
@onready var knowledge_group: ChipGroup = $Pad/Rows/Groups/Knowledges
@onready var knowledge_grid: GridContainer = $Pad/Rows/Groups/Knowledges/Chips
@onready var knowledge_lock: LockBlock = $Pad/Rows/Groups/Knowledges/Lock
@onready var knowledge_count: Label = $Pad/Rows/Groups/Knowledges/Head/Count
@onready var tool_group: ChipGroup = $Pad/Rows/Groups/Tools
@onready var tool_grid: GridContainer = $Pad/Rows/Groups/Tools/Chips
@onready var tool_lock: LockBlock = $Pad/Rows/Groups/Tools/Lock
@onready var tool_count: Label = $Pad/Rows/Groups/Tools/Head/Count
@onready var tip: SlotTooltip = $Pad/Rows/Tip

var view: MercView = null
#An applicant is not on the payroll, so coaching is on the page but out of reach.
var applicant_mode: bool = false

#Keyless: each LockBlock reads its own key, so the gate only carries the plan change.
var _gate: LockGate = LockGate.new()


func _init() -> void:
	add_child(_gate, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	hp_bar.fill_color = HP_COLOR
	ep_bar.fill_color = EP_COLOR
	mp_bar.fill_color = MP_COLOR
	title_row.empty_text = EMPTY_TEXT
	coaching.coach_pressed.connect(_on_coach_pressed)
	coaching.hover_started.connect(_on_coach_entered)
	coaching.hover_ended.connect(_on_chip_exited)
	_gate.changed.connect(_apply_locks)
	_wire_chips(lifepath_list)
	_wire_chips(knowledge_grid)
	_wire_chips(tool_grid)
	_apply_locks()


func set_view(new_view: MercView) -> void:
	view = new_view
	if not is_node_ready():
		return
	if view == null:
		_clear_view()
		return
	title_row.tradition = view.tradition
	badge.level = view.level
	badge.current_xp = view.xp
	badge.next_level_xp = ExperienceSystem.xp_for_level(view.level + 1)
	coaching.set_merc(view.uid, not applicant_mode)
	for box: AttributeBox in attribute_boxes():
		var entry: Dictionary = view.attributes.get(box.attribute_key, {})
		box.set_attribute(box.attribute_key, entry)
	_set_bar(hp_bar, "HP", view.hp, view.hp_max)
	_set_bar(ep_bar, "EP", view.ep, view.ep_max)
	_set_bar(mp_bar, "MP", view.mp, view.mp_max)
	employment_field.value = employment_text(view.employment_months)
	opinion_field.value = "%+d" % view.guild_opinion
	status_field.value = status_text(view)
	_fill_chips(lifepath_list, view.lifepaths, LIFEPATH_KIND)
	_fill_names(knowledge_grid, view.knowledges, KNOWLEDGE_KIND)
	_fill_names(tool_grid, view.tools, TOOL_KIND)
	_update_counts()
	_apply_locks()


#Greys the Coaching box and takes it out of reach; the rest of the page reads the same.
func set_applicant_mode(on: bool) -> void:
	applicant_mode = on
	if not is_node_ready():
		return
	coaching.greyed = on
	coaching.employed = not on


func coaching_box() -> CoachingBox:
	return coaching


#An empty roster leaves the page readable: the title row and the badge fall back to their blanks.
func _clear_view() -> void:
	title_row.tradition = ""
	badge.level = 1
	badge.current_xp = 0
	badge.next_level_xp = 1
	coaching.set_merc(0, not applicant_mode)


#A sold section keeps its caption and its lock; the list and its count leave the page together.
func _apply_locks() -> void:
	if not is_node_ready():
		return
	var rows: Array = [
		[lifepath_lock, lifepath_scroll, lifepath_count],
		[knowledge_lock, knowledge_grid, knowledge_count],
		[tool_lock, tool_grid, tool_count],
	]
	for row: Array in rows:
		var block: LockBlock = row[0] as LockBlock
		block.refresh()
		var shut: bool = block.gate.is_locked()
		(row[1] as Control).visible = not shut
		(row[2] as Control).visible = not shut


func _update_counts() -> void:
	lifepath_head.count_text = "%d/%d" % [filled_count(lifepath_chips()), LIFEPATH_SLOTS]
	knowledge_group.set_filled(filled_count(knowledge_chips()))
	tool_group.set_filled(filled_count(tool_chips()))


func attribute_boxes() -> Array[AttributeBox]:
	var out: Array[AttributeBox] = []
	if not is_node_ready():
		return out
	out.assign(GuiNodes.children_of(attributes, AttributeBox))
	return out


func lifepath_chips() -> Array[SlotChip]:
	return _chips(lifepath_list)


func knowledge_chips() -> Array[SlotChip]:
	return _chips(knowledge_grid)


func tool_chips() -> Array[SlotChip]:
	return _chips(tool_grid)


func filled_count(list: Array[SlotChip]) -> int:
	var total: int = 0
	for chip: SlotChip in list:
		if chip.is_filled():
			total += 1
	return total


static func employment_text(months: int) -> String:
	return "1 month" if months == 1 else "%d months" % months


static func status_text(source: MercView) -> String:
	if source.status == GuiTypes.MercStatus.AVAILABLE:
		return source.status_text()
	var minutes: int = int(round(source.status_time_left_hours * 60.0))
	return "%s %s" % [source.status_text(), MercStatusStrip.time_text(minutes)]


func _set_bar(bar: ResourceBar, label: String, current: int, maximum: int) -> void:
	bar.label = label
	bar.max_value = maxi(1, maximum)
	bar.current = current


func _chips(grid: Container) -> Array[SlotChip]:
	var out: Array[SlotChip] = []
	if not is_node_ready():
		return out
	out.assign(GuiNodes.children_of(grid, SlotChip))
	return out


func _wire_chips(grid: Container) -> void:
	for chip: SlotChip in _chips(grid):
		chip.mouse_entered.connect(_on_chip_entered.bind(chip))
		chip.mouse_exited.connect(_on_chip_exited)


func _fill_chips(grid: Container, rows: Array[Dictionary], kind: String) -> void:
	var list: Array[SlotChip] = _chips(grid)
	for i: int in list.size():
		if i < rows.size():
			var row: Dictionary = rows[i]
			var row_kind: String = String(row.get("kind", ""))
			list[i].set_slot(row_kind if row_kind != "" else kind, String(row.get("name", "")),
				String(row.get("description", "")))
		else:
			list[i].set_empty(kind)


func _fill_names(grid: Container, names: Array[String], kind: String) -> void:
	var list: Array[SlotChip] = _chips(grid)
	for i: int in list.size():
		if i < names.size():
			list[i].set_slot(kind, names[i], "")
		else:
			list[i].set_empty(kind)


func _on_chip_entered(chip: SlotChip) -> void:
	if not chip.is_filled():
		return
	tip.set_slot(chip.kind, chip.label, chip.description)
	tip.show_at(chip, get_global_rect())


func _on_chip_exited() -> void:
	tip.hide_tip()


func _on_coach_entered(box: CoachingBox) -> void:
	tip.set_slot(box.tip_kind(), box.tip_title(), box.tip_desc())
	tip.show_at(box, get_global_rect())


func _on_coach_pressed() -> void:
	tip.hide_tip()
	coach_pressed.emit()
