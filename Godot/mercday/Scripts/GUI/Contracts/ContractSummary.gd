class_name ContractSummary extends PanelContainer

#The posting recap at the top of the Dispatch Window: what it is, how hard, what it pays and how
#many mercs it takes. The meta line under the name carries the type, the distance and the
#deadline.

const DEADLINE_LINE: String = "Deadline %s"

@onready var name_label: Label = $Pad/Rows/Text/Name
@onready var level_badge: LevelBadge = $Pad/Rows/Level
@onready var type_label: Label = $Pad/Rows/Text/Meta/Type
@onready var km_label: Label = $Pad/Rows/Text/Meta/Km
@onready var deadline_label: Label = $Pad/Rows/Text/Meta/Deadline
@onready var dot_one: ColorRect = $Pad/Rows/Text/Meta/Dot1
@onready var dot_two: ColorRect = $Pad/Rows/Text/Meta/Dot2
@onready var stars: Stars = $Pad/Rows/Line/Stars
@onready var reward_label: Label = $Pad/Rows/Line/Reward
@onready var merc_count: MercCount = $Pad/Rows/Line/Count

var view: ContractView = null


func _ready() -> void:
	level_badge.mouse_filter = MOUSE_FILTER_IGNORE
	_refresh()


func set_contract(new_view: ContractView) -> void:
	view = new_view
	_refresh()


func meta_parts() -> Array[String]:
	return [type_label.text, km_label.text, deadline_label.text]


func meta_dots() -> Array[ColorRect]:
	return [dot_one, dot_two]


func _refresh() -> void:
	if not is_node_ready() or view == null:
		return
	fill_header(view, name_label, type_label, stars, reward_label, merc_count, level_badge)
	km_label.text = "%d km" % view.distance_km
	deadline_label.text = deadline_line(view)


#The posting fields this recap and the detail page header both show.
static func fill_header(posting: ContractView, title: Label, kind: Label, rating: Stars, pay: Label,
		count: MercCount, marker: LevelBadge) -> void:
	title.text = posting.name
	kind.text = posting.type
	rating.value = posting.difficulty
	pay.text = "%d" % posting.reward
	count.required = posting.merc_min
	count.allowed = posting.merc_max
	marker.level = posting.contract_level
	marker.current_xp = 0
	marker.next_level_xp = 1


static func deadline_line(posting: ContractView) -> String:
	return DEADLINE_LINE % TrynnCalendar.date_text(posting.expires_minute)


func badge() -> LevelBadge:
	return level_badge
