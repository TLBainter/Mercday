class_name ContractSummary extends PanelContainer

#The posting recap at the top of the Dispatch Window: what it is, how hard, what it pays and how
#many mercs it takes. The meta line under the name carries the type, the distance and the
#deadline.

@onready var name_label: Label = $Pad/Rows/Text/Name
@onready var level_badge: LevelBadge = $Pad/Rows/Level
@onready var type_label: Label = $Pad/Rows/Text/Meta/Type
@onready var km_label: Label = $Pad/Rows/Text/Meta/Km
@onready var deadline_label: Label = $Pad/Rows/Text/Meta/Deadline
@onready var dot_one: ColorRect = $Pad/Rows/Text/Meta/Dot1
@onready var dot_two: ColorRect = $Pad/Rows/Text/Meta/Dot2
@onready var stars: DifficultyStars = $Pad/Rows/Line/Stars
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
	name_label.text = view.name
	type_label.text = view.type
	km_label.text = "%d km" % view.distance_km
	deadline_label.text = "Deadline %s" % TrynnCalendar.date_text(view.expires_minute)
	stars.rating = view.difficulty
	reward_label.text = "%d" % view.reward
	merc_count.required = view.merc_min
	merc_count.allowed = view.merc_max
	level_badge.level = view.contract_level


func badge() -> LevelBadge:
	return level_badge
