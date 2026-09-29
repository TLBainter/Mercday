class_name LevelBadge extends PanelContainer

#The orange level badge. CHIP is the small "LVL n" chip contract rows and slots carry; TILE is the
#48x56 roster tile and LARGE the 112 px Overview plate. Hovering it opens an XPTooltip child.

enum SizeMode { CHIP, TILE, LARGE }

const INK_COLOR := Color(0.039216, 0.058824, 0.109804, 1)
const PLATE_COLOR: Color = Color("#f28c28")
const BEVEL_HI: Color = Color("#ffb266")
const BEVEL_LO: Color = Color("#b85a12")
const TILE_SIZE: Vector2 = Vector2(48, 56)
const LARGE_SIZE: Vector2 = Vector2(112, 112)
const TILE_BEVEL_PX: float = 3.0
const LARGE_BORDER_PX: float = 4.0
const LARGE_BEVEL_PX: float = 6.0
const TAG_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const NUMBER_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")

@export var level: int = 1:
	set(value):
		level = value
		_refresh()
@export var current_xp: int = 0:
	set(value):
		current_xp = value
		_refresh()
@export var next_level_xp: int = 1:
	set(value):
		next_level_xp = value
		_refresh()
@export var size_mode: SizeMode = SizeMode.CHIP:
	set(value):
		size_mode = value
		_refresh()
#Overrides the TILE plate size when non-zero; the roster row carries a narrower tile than the list.
@export var plate_size: Vector2 = Vector2.ZERO:
	set(value):
		plate_size = value
		_refresh()

@onready var row: BoxContainer = $Row
@onready var tag_label: Label = $Row/Tag
@onready var number_label: Label = $Row/Number
@onready var tip_node: XPTooltip = $Tip

var _chip_box: StyleBox = null
var _chip_min: Vector2 = Vector2.ZERO
var _chip_tag_font: Font = null
var _chip_number_font: Font = null
var _chip_tag_size: int = 0
var _chip_number_size: int = 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	mouse_entered.connect(show_tip)
	mouse_exited.connect(hide_tip)
	_own_hover()
	_capture_chip()
	_refresh()


#The badge alone owns the hover: a child that took the pointer would count as leaving the plate,
#and the tip is top level so it never sits in the way. The tip then closes the moment the pointer
#leaves the plate, with nothing under it to keep it open.
func _own_hover() -> void:
	for child: Node in get_children():
		if child == tip_node:
			continue
		_ignore_mouse(child)


func _ignore_mouse(node: Node) -> void:
	var control: Control = node as Control
	if control != null:
		control.mouse_filter = MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_MOUSE_EXIT_SELF:
		hide_tip()


#The chip look comes from the scene, so it is read once before any mode writes an override.
func _capture_chip() -> void:
	_chip_box = get_theme_stylebox("panel")
	_chip_min = custom_minimum_size
	_chip_tag_font = tag_label.get_theme_font("font")
	_chip_number_font = number_label.get_theme_font("font")
	_chip_tag_size = tag_label.get_theme_font_size("font_size")
	_chip_number_size = number_label.get_theme_font_size("font_size")


func _refresh() -> void:
	if not is_node_ready():
		return
	number_label.text = str(level) if size_mode == SizeMode.CHIP else "%02d" % level
	tag_label.text = "Level" if size_mode == SizeMode.LARGE else "LVL"
	tip_node.set_xp(current_xp, next_level_xp)
	_apply_mode()
	queue_redraw()


func _apply_mode() -> void:
	match size_mode:
		SizeMode.TILE:
			_apply_plate(TILE_SIZE if plate_size == Vector2.ZERO else plate_size, 8, 20, 0)
		SizeMode.LARGE:
			_apply_plate(LARGE_SIZE, 11, 44, int(LARGE_BORDER_PX))
		_:
			_apply_chip()


func _apply_chip() -> void:
	row.vertical = false
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	custom_minimum_size = _chip_min
	add_theme_stylebox_override("panel", _chip_box)
	_set_label(tag_label, _chip_tag_font, _chip_tag_size, HORIZONTAL_ALIGNMENT_LEFT)
	_set_label(number_label, _chip_number_font, _chip_number_size, HORIZONTAL_ALIGNMENT_LEFT)


func _apply_plate(box_size: Vector2, tag_size: int, number_size: int, border: int) -> void:
	row.vertical = true
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	custom_minimum_size = box_size
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PLATE_COLOR
	box.set_border_width_all(border)
	box.border_color = INK_COLOR
	box.content_margin_left = 0.0
	box.content_margin_top = 0.0
	box.content_margin_right = 0.0
	box.content_margin_bottom = 0.0
	add_theme_stylebox_override("panel", box)
	_set_label(tag_label, TAG_FONT, tag_size, HORIZONTAL_ALIGNMENT_CENTER)
	_set_label(number_label, NUMBER_FONT, number_size, HORIZONTAL_ALIGNMENT_CENTER)


func _set_label(node: Label, font: Font, font_size: int, align: HorizontalAlignment) -> void:
	node.horizontal_alignment = align
	node.size_flags_horizontal = SIZE_EXPAND_FILL if align == HORIZONTAL_ALIGNMENT_CENTER else SIZE_FILL
	if font != null:
		node.add_theme_font_override("font", font)
	if font_size > 0:
		node.add_theme_font_size_override("font_size", font_size)


#A stylebox has no bevel, so the plate modes paint the prototype's raised edges over it.
func _draw() -> void:
	if size_mode == SizeMode.CHIP:
		return
	var inset: float = 0.0 if size_mode == SizeMode.TILE else LARGE_BORDER_PX
	var px: float = TILE_BEVEL_PX if size_mode == SizeMode.TILE else LARGE_BEVEL_PX
	var w: float = size.x - inset * 2.0
	var h: float = size.y - inset * 2.0
	draw_rect(Rect2(inset, inset, w, px), BEVEL_HI)
	draw_rect(Rect2(inset, inset, px, h), BEVEL_HI)
	draw_rect(Rect2(inset, inset + h - px, w, px), BEVEL_LO)
	draw_rect(Rect2(inset + w - px, inset, px, h), BEVEL_LO)


#An owner that turned the badge's mouse input off gets no tip; the Row child still forwards hover
func show_tip() -> void:
	if mouse_filter == MOUSE_FILTER_IGNORE:
		return
	tip_node.show_at(self)


func hide_tip() -> void:
	tip_node.hide_tip()


func tip() -> XPTooltip:
	return tip_node
