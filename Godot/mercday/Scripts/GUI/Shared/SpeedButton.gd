class_name SpeedButton extends Button

#One clock speed toggle. The face is the atlas icon of its own speed, tinted ink when the button
#is pressed and cream otherwise. The owner (TimeMenu) manages which button in the group is
#pressed; this atom only reports its own click as a speed pick.

signal speed_selected(mode: int)

const LABELS: Dictionary = {
	0: "Slow Down",
	1: "Pause",
	2: "Play",
	3: "Fast Forward",
	4: "Faster Fast Forward",
}

const ICON_IDS: Dictionary = {
	0: "speed_slow",
	1: "pause",
	2: "play",
	3: "speed_fast",
	4: "speed_faster",
}

const INK_COLOR := Color(0.039216, 0.058824, 0.109804, 1)
const CREAM_COLOR := Color(0.952941, 0.917647, 0.843137, 1)

@export var speed_mode: ClockRunner.Speed = ClockRunner.Speed.PLAY:
	set(value):
		speed_mode = value
		_refresh()
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		_refresh()


func _ready() -> void:
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	pressed.connect(_on_pressed)
	_refresh()


func _on_pressed() -> void:
	speed_selected.emit(speed_mode)


func _refresh() -> void:
	if not is_node_ready():
		return
	tooltip_text = label_for(speed_mode)
	queue_redraw()


static func label_for(mode: int) -> String:
	return String(LABELS.get(mode, ""))


static func icon_id(mode: int) -> String:
	return String(ICON_IDS.get(mode, ""))


func _draw() -> void:
	var id: String = icon_id(speed_mode)
	if id == "":
		return
	var art: Vector2 = Vector2(Icons.size(id)) * float(pixel_scale)
	var color: Color = INK_COLOR if button_pressed else CREAM_COLOR
	Icons.draw(self, id, ((size - art) / 2.0).floor(), pixel_scale, color, true)
