class_name SlotTooltip extends TooltipPanel

#Hover tooltip for a lifepath, knowledge or tool slot: an uppercase kind line above the title.

@export var kind_label: String = ""
@export var title: String = ""
@export var description: String = ""

@onready var rows: VBoxContainer = $Rows
@onready var kind_field: Label = $Rows/Kind


func _ready() -> void:
	super._ready()
	rows.move_child(kind_field, 0)
	body_label.custom_minimum_size.x = 240
	_refresh()


func set_slot(kind: String, new_title: String, new_description: String) -> void:
	kind_label = kind
	title = new_title
	description = new_description
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	kind_field.text = kind_label.to_upper()
	set_text(title, description)
