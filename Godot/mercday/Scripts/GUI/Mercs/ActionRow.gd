class_name ActionRow extends PanelContainer

#One action of the Actions tab: the name, the cost as pips and a number, and the battles it has
#been used in. A turn action is orange and priced in AP, a reactive one blue and priced in EP.
#The description stays blank until ActionData carries one (Q19).

const TURN_COLOR: Color = GuiColors.ORANGE
const REACTIVE_COLOR: Color = GuiColors.LIGHT_BLUE
const BG_COLOR: Color = GuiColors.ROW_FILL
const EDGE_PX: int = 4
const PIP_PX: float = 12.0
const PIP_GAP: float = 4.0

@export var action_name: String = "":
	set(value):
		action_name = value
		_refresh()
@export var cost: int = 0:
	set(value):
		cost = value
		_refresh()
@export var times_used: int = 0:
	set(value):
		times_used = value
		_refresh()
@export var description: String = "":
	set(value):
		description = value
		_refresh()
@export var is_reactive: bool = false:
	set(value):
		is_reactive = value
		_refresh()

@onready var name_label: Label = $Rows/Head/ActionName
@onready var pips: Control = $Rows/Head/Pips
@onready var cost_label: Label = $Rows/Head/Cost
@onready var used_label: Label = $Rows/Used
@onready var description_label: Label = $Rows/Description


func _ready() -> void:
	pips.draw.connect(_draw_pips)
	_refresh()


#row carries {"name", "description", "times_used", "cost"}; reactive picks the colour and the unit.
func set_row(row: Dictionary, reactive: bool) -> void:
	is_reactive = reactive
	action_name = String(row.get("name", ""))
	times_used = int(row.get("times_used", 0))
	description = String(row.get("description", ""))
	cost = int(row.get("cost", 0))


func cost_text() -> String:
	return cost_label.text if is_node_ready() else ""


func pip_count() -> int:
	return maxi(0, cost)


func accent() -> Color:
	return REACTIVE_COLOR if is_reactive else TURN_COLOR


func _refresh() -> void:
	if not is_node_ready():
		return
	add_theme_stylebox_override("panel", _panel_box())
	name_label.text = action_name
	cost_label.text = "%d" % cost
	used_label.text = "Used %d" % times_used
	description_label.text = description
	description_label.visible = description != ""
	pips.custom_minimum_size = Vector2(float(pip_count()) * (PIP_PX + PIP_GAP), PIP_PX)
	pips.queue_redraw()


func _panel_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = GuiStyle.flat(BG_COLOR, 0, accent(), 10.0)
	box.border_width_left = EDGE_PX
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	return box


func _draw_pips() -> void:
	var color: Color = accent()
	for i: int in pip_count():
		var x: float = float(i) * (PIP_PX + PIP_GAP)
		pips.draw_rect(Rect2(x, 0.0, PIP_PX, PIP_PX), color)
