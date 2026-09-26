class_name TooltipPanel extends PanelContainer

#Base of every hover tooltip: a top level panel that opens below an anchor and stays inside its
#bounds. A viewer keeps one instance and moves it between anchors; subclasses add rows under Rows.

const GAP: int = 4

@onready var title_label: Label = $Rows/Title
@onready var body_label: Label = $Rows/Body


func _ready() -> void:
	top_level = true
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 100
	hide()


func set_text(title: String, body: String) -> void:
	title_label.text = title
	title_label.visible = title != ""
	body_label.text = body
	body_label.visible = body != ""


#Opens under the anchor's global rect, or above it when the bottom edge would leave the bounds.
func show_at(anchor: Control, bounds: Rect2 = Rect2()) -> void:
	if bounds.size == Vector2.ZERO:
		bounds = get_viewport().get_visible_rect()
	reset_size()
	var wanted: Vector2 = get_combined_minimum_size()
	var rect: Rect2 = anchor.get_global_rect()
	var pos := Vector2(rect.position.x, rect.end.y + GAP)
	pos.x = clampf(pos.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - wanted.x))
	if pos.y + wanted.y > bounds.end.y:
		pos.y = maxf(bounds.position.y, rect.position.y - GAP - wanted.y)
	global_position = pos
	show()


func hide_tip() -> void:
	hide()
