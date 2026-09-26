class_name StatusMark extends Control

#Contract status mark over a portrait; a fixed size footprint whether or not a mark is shown.

const ICON_CHECK: Texture2D = preload("res://Art/GUI/Icons/icon_check.png")
const ICON_EXPIRED: Texture2D = preload("res://Art/GUI/Icons/icon_expired.png")
const ICON_THUMBS_DOWN: Texture2D = preload("res://Art/GUI/Icons/icon_thumbs_down.png")
const MARK_SIZE: Vector2 = Vector2(28, 28)

@onready var icon_rect: IconRect = $Icon

@export var status: int = GuiTypes.ContractStatus.AVAILABLE:
	set(value):
		status = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = MARK_SIZE
	var tex: Texture2D = icon_for(status)
	icon_rect.set_icon(tex)
	icon_rect.visible = tex != null


static func icon_for(status_value: int) -> Texture2D:
	match status_value:
		GuiTypes.ContractStatus.COMPLETED:
			return ICON_CHECK
		GuiTypes.ContractStatus.EXPIRED:
			return ICON_EXPIRED
		GuiTypes.ContractStatus.REJECTED:
			return ICON_THUMBS_DOWN
		_:
			return null
