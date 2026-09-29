class_name EnvoySlot extends Button

#One crew slot in an Odd Job. Empty shows a dashed add prompt and a hover tip; filled shows the
#merc's portrait, name and fit stars plus a remove button. Clicking anywhere but the remove
#button (empty or filled) asks the host to open the picker for this slot.

signal slot_pressed(index: int)
signal remove_pressed(index: int)

const SLOT_SIZE: Vector2 = Vector2(84.0, 84.0)
const EMPTY_BG: Color = Color("#0e1628")
const EMPTY_OPACITY: float = 0.6
const DASH_COLOR: Color = Color("#3b6fb6")
const PLUS_COLOR: Color = Color("#3b6fb6")
const ADD_TEXT_COLOR: Color = Color("#9cc6ef")
const PORTRAIT_RING: Color = Color("#3b6fb6")
const NAME_COLOR: Color = Color("#f3ead7")
const REMOVE_COLOR: Color = Color("#ff3b2f")
const REMOVE_HOVER_COLOR: Color = Color("#ff6a55")
const OUTLINE_COLOR: Color = Color("#0a0f1c")
const PORTRAIT_PX: int = 40
const TIP_WIDTH: float = 320.0

const FONT_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_REGULAR: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const MERC_PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")
const FIT_STARS_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FitStars.tscn")
const TOOLTIP_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/TooltipPanel.tscn")

@export var index: int = 0
@export var merc_id: int = -1:
	set(v):
		merc_id = v
		_refresh()
@export var merc_name: String = "":
	set(v):
		merc_name = v
		_refresh()
@export var fit: float = 0.5:
	set(v):
		fit = v
		_refresh()
@export var tip_kind: String = "Odd Job":
	set(v):
		tip_kind = v
		_refresh()
@export var tip_text: String = "Send a merc on this Odd Job.":
	set(v):
		tip_text = v
		_refresh()

@onready var empty_box: Control = $EmptyBox
@onready var plus_label: Label = $EmptyBox/Center/Rows/Plus
@onready var add_label: Label = $EmptyBox/Center/Rows/AddMerc
@onready var filled_box: PanelContainer = $FilledBox
@onready var portrait_wrap: Control = $FilledBox/Pad/Rows/PortraitWrap
@onready var name_label: Label = $FilledBox/Pad/Rows/Name
@onready var stars_slot: Control = $FilledBox/Pad/Rows/StarsSlot
@onready var remove_button: Button = $RemoveButton

var _portrait: MercPortrait = null
var _stars: FitStars = null
var _tip: TooltipPanel = null


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	focus_mode = Control.FOCUS_NONE
	empty_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_box.draw.connect(_draw_empty)
	plus_label.add_theme_font_override(&"font", FONT_BOLD)
	plus_label.add_theme_font_size_override(&"font_size", 22)
	plus_label.add_theme_color_override(&"font_color", PLUS_COLOR)
	plus_label.text = "+"
	add_label.add_theme_font_override(&"font", FONT_REGULAR)
	add_label.add_theme_font_size_override(&"font_size", 12)
	add_label.add_theme_color_override(&"font_color", ADD_TEXT_COLOR)
	add_label.text = "Add Merc"
	filled_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filled_box.add_theme_stylebox_override(&"panel", _slot_filled_style())
	portrait_wrap.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	portrait_wrap.draw.connect(_draw_portrait_ring)
	_portrait = MERC_PORTRAIT_SCENE.instantiate() as MercPortrait
	_portrait.pixel_size = PORTRAIT_PX
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_wrap.add_child(_portrait)
	name_label.add_theme_font_override(&"font", FONT_BOLD)
	name_label.add_theme_font_size_override(&"font_size", 8)
	name_label.add_theme_color_override(&"font_color", NAME_COLOR)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stars = FIT_STARS_SCENE.instantiate() as FitStars
	_stars.cell = 1
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars_slot.add_child(_stars)
	remove_button.text = "X"
	remove_button.flat = true
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.add_theme_font_override(&"font", FONT_BOLD)
	remove_button.add_theme_font_size_override(&"font_size", 18)
	remove_button.add_theme_color_override(&"font_color", REMOVE_COLOR)
	remove_button.add_theme_color_override(&"font_hover_color", REMOVE_HOVER_COLOR)
	remove_button.add_theme_color_override(&"font_pressed_color", REMOVE_HOVER_COLOR)
	remove_button.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	remove_button.add_theme_constant_override(&"outline_size", 2)
	remove_button.anchor_left = 1.0
	remove_button.anchor_right = 1.0
	remove_button.anchor_top = 0.0
	remove_button.anchor_bottom = 0.0
	remove_button.offset_left = -10.0
	remove_button.offset_right = 10.0
	remove_button.offset_top = -10.0
	remove_button.offset_bottom = 10.0
	remove_button.pressed.connect(_on_remove_pressed)
	_tip = TOOLTIP_SCENE.instantiate() as TooltipPanel
	_tip.custom_minimum_size = Vector2(TIP_WIDTH, 0.0)
	add_child(_tip)
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh()


func press() -> void:
	_on_pressed()


func press_remove() -> void:
	_on_remove_pressed()


func is_filled() -> bool:
	return merc_id != -1


#The hover tooltip of this slot: one shared TooltipPanel that draws above every open frame.
func tip_panel() -> TooltipPanel:
	return _tip


func _on_pressed() -> void:
	slot_pressed.emit(index)


func _on_remove_pressed() -> void:
	remove_pressed.emit(index)


func _on_mouse_entered() -> void:
	if is_filled() or _tip == null:
		return
	_tip.set_text(tip_kind, tip_text)
	_tip.show_at(self)


func _on_mouse_exited() -> void:
	if _tip != null:
		_tip.hide_tip()


func _refresh() -> void:
	if not is_node_ready():
		return
	var filled: bool = is_filled()
	empty_box.visible = not filled
	empty_box.modulate = Color(1.0, 1.0, 1.0, 1.0 if filled else EMPTY_OPACITY)
	filled_box.visible = filled
	remove_button.visible = filled
	if filled:
		if _tip != null:
			_tip.hide_tip()
		name_label.text = merc_name
		_stars.value = fit
		_portrait.merc_uid = merc_id
		_portrait.tooltip_text = merc_name


func _slot_filled_style() -> StyleBoxFlat:
	var path: String = "res://Resources/GUI/Theme/Styles/crew_slot_filled.tres"
	return (load(path) as StyleBoxFlat).duplicate() as StyleBoxFlat


func _draw_empty() -> void:
	var span: Vector2 = empty_box.size
	empty_box.draw_rect(Rect2(Vector2.ZERO, span), EMPTY_BG)
	var inset: float = 1.0
	var top_left := Vector2(inset, inset)
	var top_right := Vector2(span.x - inset, inset)
	var low_right := Vector2(span.x - inset, span.y - inset)
	var low_left := Vector2(inset, span.y - inset)
	empty_box.draw_dashed_line(top_left, top_right, DASH_COLOR, 2.0, 4.0)
	empty_box.draw_dashed_line(top_right, low_right, DASH_COLOR, 2.0, 4.0)
	empty_box.draw_dashed_line(low_right, low_left, DASH_COLOR, 2.0, 4.0)
	empty_box.draw_dashed_line(low_left, top_left, DASH_COLOR, 2.0, 4.0)


func _draw_portrait_ring() -> void:
	var span: Vector2 = portrait_wrap.size
	portrait_wrap.draw_rect(Rect2(Vector2(1.0, 1.0), span - Vector2(2.0, 2.0)), PORTRAIT_RING, false, 2.0)
