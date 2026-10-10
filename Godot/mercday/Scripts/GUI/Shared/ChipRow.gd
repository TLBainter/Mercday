class_name ChipRow extends HFlowContainer

#One wrapping row of pixel chips, the only chip renderer a filter section builds. Multi mode
#toggles a value in and out of selected; single mode holds one at most and a second press on the
#same chip clears it. An option that is not enabled stays dim and carries its note as the tooltip.

signal selection_changed(selected: Array)

const CHIP_HEIGHT: float = 24.0
const CHIP_FONT_SIZE: int = 12
const ON_TEXT: Color = GuiColors.INK
const OFF_TEXT: Color = GuiColors.CREAM
const OFF_TEXT_IDLE: Color = GuiColors.SKY
const DISABLED_ALPHA: float = 0.45
const DOT_PX: int = 8
const DOT_RING: Color = GuiColors.INK
const GAP_PX: int = 6
const STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"focus", &"disabled"]
const STYLE_ON: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_chip_on.tres")
const STYLE_OFF: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_chip_off.tres")
const CHIP_FONT: Font = GuiStyle.BODY

#Every row is {key, label, enabled, note, color}: color adds the tradition dot, note is the
#tooltip of a row that cannot be picked.
@export var options: Array[Dictionary] = []
@export var multi: bool = true
@export var selected: Array = []

static var _dots: Dictionary = {}

var _chips: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override(&"h_separation", GAP_PX)
	add_theme_constant_override(&"v_separation", GAP_PX)
	rebuild()


func set_options(rows: Array[Dictionary]) -> void:
	options = rows
	rebuild()


#Marks the chips without emitting, the read path a section's set_value() takes.
func set_selected(values: Array) -> void:
	selected = values.duplicate()
	_mark()


func chip_count() -> int:
	return _chips.size()


func chip_for(key: Variant) -> Button:
	var idx: int = index_of(key)
	return _chips[idx] if idx >= 0 and idx < _chips.size() else null


func index_of(key: Variant) -> int:
	for i: int in range(options.size()):
		if _key_at(i) == key:
			return i
	return -1


func is_on(key: Variant) -> bool:
	return selected.has(key)


#The press path: a blocked option never changes the selection, single mode replaces it.
func press_chip(key: Variant) -> void:
	var idx: int = index_of(key)
	if idx < 0 or not bool(options[idx].get("enabled", true)):
		return
	var next: Array = selected.duplicate()
	if next.has(key):
		next.erase(key)
	elif multi:
		next.append(key)
	else:
		next = [key]
	selected = next
	_mark()
	selection_changed.emit(selected.duplicate())


func rebuild() -> void:
	if not is_node_ready():
		return
	for chip: Button in _chips:
		remove_child(chip)
		chip.queue_free()
	_chips.clear()
	for i: int in range(options.size()):
		var row: Dictionary = options[i]
		var chip: Button = Button.new()
		chip.name = "Chip%d" % i
		chip.text = String(row.get("label", ""))
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(0.0, CHIP_HEIGHT)
		chip.add_theme_font_override(&"font", CHIP_FONT)
		chip.add_theme_font_size_override(&"font_size", CHIP_FONT_SIZE)
		chip.add_theme_constant_override(&"h_separation", 5)
		if row.has("color"):
			chip.icon = dot_texture(row["color"])
			chip.expand_icon = false
		chip.pressed.connect(_on_chip_pressed.bind(i))
		add_child(chip)
		_chips.append(chip)
	_mark()


#The 8 px tradition dot with its one pixel ink ring, cached per colour.
static func dot_texture(color: Color) -> ImageTexture:
	var key: String = color.to_html(true)
	if _dots.has(key):
		return _dots[key] as ImageTexture
	var side: int = DOT_PX + 2
	var img: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	img.fill(DOT_RING)
	for y: int in range(1, side - 1):
		for x: int in range(1, side - 1):
			img.set_pixel(x, y, color)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_dots[key] = tex
	return tex


func _key_at(index: int) -> Variant:
	return options[index].get("key", index)


func _on_chip_pressed(index: int) -> void:
	press_chip(_key_at(index))


func _mark() -> void:
	for i: int in range(_chips.size()):
		var row: Dictionary = options[i]
		var chip: Button = _chips[i]
		var on: bool = is_on(_key_at(i))
		var enabled: bool = bool(row.get("enabled", true))
		for state: StringName in STATES:
			chip.add_theme_stylebox_override(state, STYLE_ON if on else STYLE_OFF)
		chip.add_theme_color_override(&"font_color", ON_TEXT if on else OFF_TEXT_IDLE)
		chip.add_theme_color_override(&"font_hover_color", ON_TEXT if on else OFF_TEXT)
		chip.add_theme_color_override(&"font_pressed_color", ON_TEXT if on else OFF_TEXT)
		chip.modulate = Color(1.0, 1.0, 1.0, 1.0 if enabled else DISABLED_ALPHA)
		chip.tooltip_text = "" if enabled else String(row.get("note", ""))
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled \
			else Control.CURSOR_FORBIDDEN
