class_name StatusMark extends Control

#Contract status mark over a portrait; a fixed size footprint whether or not a mark is shown.
#The bang marks a result nobody has opened yet, the cross a contract failed and already claimed.

enum Mark {NONE, CHECK, EXPIRED, THUMBS_DOWN, BANG, FAILED}

#One atlas id per mark; NONE draws nothing and keeps the footprint.
const MARK_IDS: Dictionary = {
	Mark.CHECK: "check_lg", Mark.EXPIRED: "prohibited", Mark.THUMBS_DOWN: "thumbs_down",
	Mark.BANG: "alert", Mark.FAILED: "x_lg",
}
#The mark a plain status carries; an unclaimed result asks for BANG through kind itself.
const STATUS_MARKS: Dictionary = {
	GuiTypes.ContractStatus.COMPLETED: Mark.CHECK,
	GuiTypes.ContractStatus.EXPIRED: Mark.EXPIRED,
	GuiTypes.ContractStatus.REJECTED: Mark.THUMBS_DOWN,
	GuiTypes.ContractStatus.FAILED: Mark.FAILED,
}

@onready var icon_rect: IconRect = $Icon

@export var kind: int = Mark.NONE:
	set(value):
		kind = value
		_refresh()

@export var status: int = GuiTypes.ContractStatus.AVAILABLE:
	set(value):
		status = value
		kind = mark_for(value)

@export var mark_scale: int = 2:
	set(value):
		mark_scale = maxi(1, value)
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = mark_size(mark_scale)
	var id: String = id_of(kind)
	if id != "":
		icon_rect.set_id(id, mark_scale, Icons.MODE_PLAIN)
	icon_rect.visible = id != ""


static func mark_size(scale_value: int) -> Vector2:
	return Vector2(Icons.CELL, Icons.CELL) * maxi(1, scale_value)


static func id_of(kind_value: int) -> String:
	return String(MARK_IDS.get(kind_value, ""))


static func icon_of(kind_value: int) -> Texture2D:
	var id: String = id_of(kind_value)
	return Icons.tex(id) if id != "" else null


static func mark_for(status_value: int) -> int:
	return int(STATUS_MARKS.get(status_value, Mark.NONE))


static func id_for(status_value: int) -> String:
	return id_of(mark_for(status_value))


static func icon_for(status_value: int) -> Texture2D:
	return icon_of(mark_for(status_value))
