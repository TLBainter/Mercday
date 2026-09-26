class_name ShowAveragesToggle extends Button

#The header switch that lays the team average under every plotted merc metric. It locks with a
#reason when there is no merc to compare or when a second merc is already the comparison.

const BOX_FILL := Color(0.039216, 0.058824, 0.109804, 1)
const BOX_RING := Color(0.231373, 0.435294, 0.713725, 1)
const CHECK_COLOR := Color(0.949020, 0.549020, 0.156863, 1)
const TEXT_COLOR := Color(0.952941, 0.917647, 0.843137, 1)
const FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_SIZE := 10
const RING_WIDTH := 2.0
const CONTENT_LEFT := 30
const LOCKED_ALPHA := 0.4
const LABEL := "SHOW AVERAGES"
const TIP_NO_MERC := "Select a merc to compare with the team average."
const TIP_COMPARING := "Turn off Merc Comparison to show averages."

signal toggled_on(on: bool)

@onready var swatch: Control = $Swatch


func _ready() -> void:
	text = LABEL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", FONT_SIZE)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_disabled_color"]:
		add_theme_color_override(color_name, TEXT_COLOR)
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxEmpty.new()
		box.content_margin_left = float(CONTENT_LEFT)
		add_theme_stylebox_override(style_name, box)
	swatch.draw.connect(_draw_swatch)
	toggled.connect(_on_toggled)


func is_on() -> bool:
	return button_pressed


#Mirrors a state change made in code; the toggled_on signal never fires for it.
func set_on(on: bool) -> void:
	set_pressed_no_signal(on)
	if is_node_ready():
		swatch.queue_redraw()


#Greys the switch out and says why it cannot be used.
func set_locked(locked: bool, reason: String) -> void:
	disabled = locked
	modulate.a = LOCKED_ALPHA if locked else 1.0
	tooltip_text = reason


func _on_toggled(on: bool) -> void:
	swatch.queue_redraw()
	toggled_on.emit(on)


func _draw_swatch() -> void:
	var rect := Rect2(Vector2.ZERO, swatch.size)
	swatch.draw_rect(rect, BOX_FILL)
	swatch.draw_rect(rect, BOX_RING, false, RING_WIDTH)
	if not button_pressed:
		return
	var mark: Texture2D = GuiGlyphs.check(CHECK_COLOR)
	swatch.draw_texture(mark, (rect.size - mark.get_size()) * 0.5)
