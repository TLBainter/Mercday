class_name GridMenuButton extends Button

#A 160x160 dashboard tile: an icon over a label strip. Named GridMenuButton because MenuButton
#is a built-in Godot class (SCENES.md calls this atom MenuButton).

signal opened(scene: PackedScene)

const HOVER_COLOR := Color(0.949020, 0.549020, 0.156863, 1)
const NORMAL_COLOR := Color(0.952941, 0.917647, 0.843137, 1)

#icon is inherited from Button (redeclaring it errors: "Member icon redefined"). set_icon()
#below forwards a texture to the child IconRect, then clears the inherited field so Button
#never draws its own small icon over this tile.
@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var window_scene: PackedScene = null
@export var description: String = "":
	set(value):
		description = value
		_refresh()

@onready var icon_rect: IconRect = $Icon
@onready var text_label: Label = $Strip/Text


func _ready() -> void:
	mouse_entered.connect(func() -> void: hover(true))
	mouse_exited.connect(func() -> void: hover(false))
	pressed.connect(_on_pressed)
	if icon != null:
		set_icon(icon)
	_refresh()


func _on_pressed() -> void:
	opened.emit(window_scene)


func _refresh() -> void:
	if not is_node_ready():
		return
	text_label.text = label
	tooltip_text = description


func set_icon(tex: Texture2D) -> void:
	icon_rect.set_icon(tex)
	icon = null


func hover(on: bool) -> void:
	text_label.add_theme_color_override("font_color", HOVER_COLOR if on else NORMAL_COLOR)


func text_color() -> Color:
	return text_label.get_theme_color("font_color")
