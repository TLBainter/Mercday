class_name HintMarker extends Control

#The MercDave notice marker: an invisible hit box (PAD around the box) holding the pale glow halo that rings the
#bevelled amber HintBox, which holds the dark amber question mark. HintMarkers drives the shared pulse through
#set_glow: only the halo alpha pulses. A hovered marker tweens to full glow while the box and glyph pop together,
#then eases back into the pulse; it clicks and hovers with the MercDave sets.

signal pressed

const ICON_ID: String = "question"
const SCALE: int = 1
const GLYPH: Color = Color("#a67114")
const PEAK: Color = Color("#fae1b1")
const HALO_WIDTH: int = 2
const PAD: int = 8
const ICON_SIZE: Vector2 = Vector2(16, 16)
const BOX: Vector2 = HintBox.SIZE + Vector2(PAD, PAD) * 2.0
const HOVER_IN: float = 0.12
const HOVER_OUT: float = 0.3
const POP_SCALE: float = 1.125
const POP_HALF: float = 0.06

var halo: TextureRect = null
var box: HintBox = null
var icon: IconRect = null
var click_sfx: SoundLibrary = null
var hover_sfx: SoundLibrary = null
var hover_level: float = 0.0
var pulse_level: float = 0.0
var _hover_tween: Tween = null
var _pop_tween: Tween = null


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	custom_minimum_size = BOX
	size = BOX
	halo = TextureRect.new()
	halo.name = "Halo"
	halo.texture = HintHalo.bake_rect(Vector2i(HintBox.SIZE), HALO_WIDTH, PEAK)
	halo.mouse_filter = MOUSE_FILTER_IGNORE
	halo.texture_filter = TEXTURE_FILTER_NEAREST
	halo.position = Vector2(PAD - HALO_WIDTH, PAD - HALO_WIDTH)
	halo.size = halo.texture.get_size()
	halo.modulate = Color(1, 1, 1, 0)
	add_child(halo)
	box = HintBox.new()
	box.name = "Box"
	box.position = Vector2(PAD, PAD)
	add_child(box)
	icon = IconRect.new()
	icon.name = "Icon"
	icon.icon_id = ICON_ID
	icon.pixel_scale = SCALE
	icon.tint = GLYPH
	icon.trimmed = false
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	icon.position = (HintBox.SIZE - ICON_SIZE) / 2.0
	icon.size = ICON_SIZE
	box.add_child(icon)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_hover_to.bind(0.0, HOVER_OUT))


func _ready() -> void:
	if UiSfx.config != null:
		click_sfx = UiSfx.config.mercdave_click
		hover_sfx = UiSfx.config.mercdave_hover


func set_glow(level: float) -> void:
	pulse_level = level
	_paint()


func _paint() -> void:
	var level: float = maxf(pulse_level, hover_level)
	halo.modulate = Color(1, 1, 1, clampf(level, 0.0, 1.0))


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_kill(_hover_tween)
		_kill(_pop_tween)
		hover_level = 0.0
		box.scale = Vector2.ONE
		_paint()


func _on_enter() -> void:
	_hover_to(1.0, HOVER_IN)
	_kill(_pop_tween)
	_pop_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_pop_tween.tween_property(box, ^"scale", Vector2.ONE * POP_SCALE, POP_HALF)
	_pop_tween.tween_property(box, ^"scale", Vector2.ONE, POP_HALF)


func _hover_to(level: float, time: float) -> void:
	_kill(_hover_tween)
	_hover_tween = create_tween()
	_hover_tween.tween_method(_set_hover_level, hover_level, level, time)


func _set_hover_level(value: float) -> void:
	hover_level = value
	_paint()


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
