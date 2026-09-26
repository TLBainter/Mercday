class_name OverviewTab extends ScrollContainer

#The first tab: the tradition title row, the four attributes, one middle row holding the level
#badge over its mode list, the resource bars and the scrolling lifepath list, then the captioned
#info rows and the knowledge and tool chips. Lineage and salary live on the MercHeader.

const EMPTY_TEXT: String = "None"
const LIFEPATH_SLOTS: int = 8
const UTILITY_SLOTS: int = 6
const HP_COLOR: Color = Color("#d6453d")
const EP_COLOR: Color = Color("#6cc36a")
const MP_COLOR: Color = Color("#5aa6e8")
const LIFEPATH_KIND: String = "Lifepath Event"
const KNOWLEDGE_KIND: String = "Knowledge"
const TOOL_KIND: String = "Tool"

const MODE_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/LevelModeList.tscn")

signal level_mode_chosen(mode: String)

@onready var title_row: TraditionModule = $Rows/TitleRow
@onready var sigil_box: PanelContainer = $Rows/TitleRow/Row/SigilBox
@onready var sigil: TraditionSigil = $Rows/TitleRow/Row/SigilBox/Center/Sigil
@onready var tradition_label: Label = $Rows/TitleRow/Row/Name
@onready var attributes: HBoxContainer = $Rows/Attributes
@onready var middle: HBoxContainer = $Rows/Middle
@onready var badge: LevelBadge = $Rows/Middle/Left/Badge
@onready var mode_scroll: ScrollContainer = $Rows/Middle/Left/ModeBox/ModeScroll
@onready var hp_bar: ResourceBar = $Rows/Middle/Resources/Bars/Hp
@onready var ep_bar: ResourceBar = $Rows/Middle/Resources/Bars/Ep
@onready var mp_bar: ResourceBar = $Rows/Middle/Resources/Bars/Mp
@onready var fields: GridContainer = $Rows/Fields
@onready var employment_field: InfoField = $Rows/Fields/Employment
@onready var opinion_field: InfoField = $Rows/Fields/Opinion
@onready var status_field: InfoField = $Rows/Fields/Status
@onready var lifepath_list: VBoxContainer = $Rows/Middle/Lifepath/Scroll/Chips
@onready var lifepath_count: Label = $Rows/Middle/Lifepath/Head/Count
@onready var knowledge_grid: GridContainer = $Rows/Groups/Knowledges/Chips
@onready var knowledge_count: Label = $Rows/Groups/Knowledges/Head/Count
@onready var tool_grid: GridContainer = $Rows/Groups/Tools/Chips
@onready var tool_count: Label = $Rows/Groups/Tools/Head/Count
@onready var tip: SlotTooltip = $Rows/Tip

var mode_list: LevelModeList = null
var view: MercView = null


func _ready() -> void:
	hp_bar.fill_color = HP_COLOR
	ep_bar.fill_color = EP_COLOR
	mp_bar.fill_color = MP_COLOR
	title_row.empty_text = EMPTY_TEXT
	mode_list = MODE_SCENE.instantiate()
	mode_scroll.add_child(mode_list)
	mode_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_list.mode_chosen.connect(_on_mode_chosen)
	_wire_chips(lifepath_list)
	_wire_chips(knowledge_grid)
	_wire_chips(tool_grid)


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
	for box: AttributeBox in attribute_boxes():
		var entry: Dictionary = view.attributes.get(box.attribute_key, {})
		box.set_attribute(box.attribute_key, entry)
	_set_bar(hp_bar, "HP", view.hp, view.hp_max)
	_set_bar(ep_bar, "EP", view.ep, view.ep_max)
	_set_bar(mp_bar, "MP", view.mp, view.mp_max)
	employment_field.value = employment_text(view.employment_months)
	opinion_field.value = "%+d" % view.guild_opinion
	status_field.value = status_text(view)
	mode_list.set_mode(view.level_mode)
	_fill_chips(lifepath_list, view.lifepaths, LIFEPATH_KIND)
	_fill_names(knowledge_grid, view.knowledges, KNOWLEDGE_KIND)
	_fill_names(tool_grid, view.tools, TOOL_KIND)
	_update_counts()


#An empty roster leaves the page readable: the title row and the badge fall back to their blanks.
func _clear_view() -> void:
	title_row.tradition = ""
	badge.level = 1
	badge.current_xp = 0
	badge.next_level_xp = 1


func _update_counts() -> void:
	lifepath_count.text = "%d/%d" % [filled_count(lifepath_chips()), LIFEPATH_SLOTS]
	knowledge_count.text = "%d/%d" % [filled_count(knowledge_chips()), UTILITY_SLOTS]
	tool_count.text = "%d/%d" % [filled_count(tool_chips()), UTILITY_SLOTS]


func attribute_boxes() -> Array[AttributeBox]:
	var out: Array[AttributeBox] = []
	if not is_node_ready():
		return out
	for child: Node in attributes.get_children():
		if child is AttributeBox:
			out.append(child as AttributeBox)
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
	for child: Node in grid.get_children():
		if child is SlotChip:
			out.append(child as SlotChip)
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


func _on_mode_chosen(mode: String) -> void:
	level_mode_chosen.emit(mode)
