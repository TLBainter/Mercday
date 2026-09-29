class_name SlotTooltip extends TooltipPanel

#Hover tooltip for a lifepath, knowledge or tool slot: an uppercase kind line above the title.
#A foot line under the body carries the one-line note the prototype puts below its rule, and stays
#hidden while it is empty, so every older caller keeps the three-row tooltip it asked for.

const BODY_WIDTH: float = 240.0
const FOOT_COLOR: Color = Color("#f3ead7")

@export var kind_label: String = ""
@export var title: String = ""
@export var description: String = ""
@export var foot: String = ""

@onready var rows: VBoxContainer = $Rows
@onready var kind_field: Label = $Rows/Kind
@onready var foot_field: Label = $Rows/Foot


func _ready() -> void:
	super._ready()
	rows.move_child(kind_field, 0)
	rows.move_child(foot_field, rows.get_child_count() - 1)
	body_label.custom_minimum_size.x = BODY_WIDTH
	foot_field.add_theme_color_override("font_color", FOOT_COLOR)
	_refresh()


func set_slot(kind: String, new_title: String, new_description: String,
		new_foot: String = "") -> void:
	kind_label = kind
	title = new_title
	description = new_description
	foot = new_foot
	_refresh()


func foot_text() -> String:
	return foot_field.text if is_node_ready() else foot


func _refresh() -> void:
	if not is_node_ready():
		return
	kind_field.text = kind_label.to_upper()
	foot_field.text = foot
	foot_field.visible = foot != ""
	set_text(title, description)
