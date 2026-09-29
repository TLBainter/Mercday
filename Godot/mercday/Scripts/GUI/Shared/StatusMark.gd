class_name StatusMark extends Control

#Contract status mark over a portrait; a fixed size footprint whether or not a mark is shown.
#The bang marks a result nobody has opened yet, the skull a contract failed and already claimed.

enum Mark {NONE, CHECK, EXPIRED, THUMBS_DOWN, BANG, SKULL}

const ICON_CHECK: Texture2D = preload("res://Art/GUI/Icons/icon_check.png")
const ICON_EXPIRED: Texture2D = preload("res://Art/GUI/Icons/icon_expired.png")
const ICON_THUMBS_DOWN: Texture2D = preload("res://Art/GUI/Icons/icon_thumbs_down.png")
const ICON_BANG: Texture2D = preload("res://Art/GUI/Icons/contract_mark_results_bang_14x14.png")
const ICON_SKULL: Texture2D = preload("res://Art/GUI/Icons/contract_mark_failed_skull_14x14.png")
const MARK_SIZE: Vector2 = Vector2(28, 28)
#One texture per mark; NONE draws nothing and keeps the footprint.
const MARK_ICONS: Dictionary = {
	Mark.CHECK: ICON_CHECK, Mark.EXPIRED: ICON_EXPIRED, Mark.THUMBS_DOWN: ICON_THUMBS_DOWN,
	Mark.BANG: ICON_BANG, Mark.SKULL: ICON_SKULL,
}
#The mark a plain status carries; an unclaimed result asks for BANG through kind itself.
const STATUS_MARKS: Dictionary = {
	GuiTypes.ContractStatus.COMPLETED: Mark.CHECK,
	GuiTypes.ContractStatus.EXPIRED: Mark.EXPIRED,
	GuiTypes.ContractStatus.REJECTED: Mark.THUMBS_DOWN,
	GuiTypes.ContractStatus.FAILED: Mark.SKULL,
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


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = MARK_SIZE
	var tex: Texture2D = icon_of(kind)
	icon_rect.set_icon(tex)
	icon_rect.visible = tex != null


static func icon_of(kind_value: int) -> Texture2D:
	return MARK_ICONS.get(kind_value, null) as Texture2D


static func mark_for(status_value: int) -> int:
	return int(STATUS_MARKS.get(status_value, Mark.NONE))


static func icon_for(status_value: int) -> Texture2D:
	return icon_of(mark_for(status_value))
