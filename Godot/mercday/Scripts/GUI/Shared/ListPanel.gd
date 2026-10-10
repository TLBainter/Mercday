class_name ListPanel extends PanelContainer

#A titled list box: the section head, a tool row for the sort and filter buttons, and a padded
#scroll of items. An inherited scene sets the caption on Head and the pads on Scroll; the tool row
#shows only when it holds a child.

@onready var head: SectionHead = $Pad/Rows/Head
@onready var tools: HBoxContainer = $Pad/Rows/Tools
@onready var scroll: PaddedScroll = $Pad/Rows/Scroll


func _ready() -> void:
	tools.visible = tools.get_child_count() > 0


func items() -> VBoxContainer:
	return scroll.items


func set_count(shown: int, total: int) -> void:
	head.count_text = "%d/%d" % [shown, total]


func clear_items() -> void:
	GuiNodes.clear(scroll.items)


#The one row order of the sorted lists: the keys first, flipped when descending, then the tie
#names ascending. natural compares text case-free in natural number order.
static func sorted_before(one: Variant, two: Variant, descending: bool, tie_one: String,
		tie_two: String, natural: bool = false) -> bool:
	var order: int = _compare(one, two, natural)
	if order != 0:
		return order > 0 if descending else order < 0
	return _compare(tie_one, tie_two, natural) < 0


static func _compare(one: Variant, two: Variant, natural: bool) -> int:
	if natural and one is String:
		return String(one).naturalnocasecmp_to(String(two))
	if one == two:
		return 0
	return -1 if one < two else 1
