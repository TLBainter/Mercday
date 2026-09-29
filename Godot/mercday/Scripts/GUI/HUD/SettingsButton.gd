class_name SettingsButton extends Button

#Cosmetic toggle only (Q40): swaps the gear icon tint between cream and orange. No settings menu yet.

const CREAM := Color(0.952941, 0.917647, 0.843137, 1)
const ORANGE := Color(0.949020, 0.549020, 0.156863, 1)

@onready var icon_rect: IconRect = $Icon


func _ready() -> void:
	tooltip_text = "Settings (not yet available)"
	toggled.connect(_on_toggled)
	_on_toggled(button_pressed)


func _on_toggled(on: bool) -> void:
	icon_rect.tint = ORANGE if on else CREAM
