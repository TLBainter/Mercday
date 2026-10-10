class_name CrewPanel extends PanelContainer

#Base of the Odd Job crew columns: the dark crew box and the small orange title over Rows.

const DARK_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/crew_panel_dark.tres")
const TITLE_SIZE: int = 11

@onready var title_label: Label = $Rows/Title


func _ready() -> void:
	add_theme_stylebox_override(&"panel", style())
	GuiStyle.paint(title_label, GuiStyle.SILK, TITLE_SIZE, GuiColors.ORANGE)


#A private copy of a crew style, the dark panel unless the caller names another.
static func style(base: StyleBoxFlat = DARK_STYLE) -> StyleBoxFlat:
	return base.duplicate() as StyleBoxFlat
