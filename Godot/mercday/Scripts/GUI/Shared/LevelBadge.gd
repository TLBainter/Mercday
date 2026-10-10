class_name LevelBadge extends PanelContainer

#The orange level badge. CHIP is the small "LVL n" chip contract rows and slots carry; TILE is the
#48x56 roster tile, LARGE the 112 px Overview plate and PAYROLL the ringed square of the payroll rows
#and the fire dialog. Hovering it opens an XPTooltip child.

enum SizeMode { CHIP, TILE, LARGE, PAYROLL }

const INK_COLOR: Color = GuiColors.INK
const PLATE_COLOR: Color = GuiColors.ORANGE
const BEVEL_HI: Color = GuiColors.ORANGE_HI
const BEVEL_LO: Color = GuiColors.ORANGE_LO
const TILE_SIZE: Vector2 = Vector2(48, 56)
const LARGE_SIZE: Vector2 = Vector2(112, 112)
const TILE_BEVEL_PX: float = 3.0
const LARGE_BORDER_PX: float = 4.0
const LARGE_BEVEL_PX: float = 6.0
const PAYROLL_SIZE: Vector2 = Vector2(40, 40)
const PAYROLL_KICKER_SIZE: int = 7
const PAYROLL_VALUE_SIZE: int = 15
const PAYROLL_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_badge.tres")
const TAG_FONT: FontVariation = GuiStyle.SILK
const NUMBER_FONT: FontVariation = GuiStyle.SILK_BOLD

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
#Overrides the TILE or PAYROLL plate size when non-zero; the roster row carries a narrower tile than the list.
@export var plate_size: Vector2 = Vector2.ZERO:
	set(value):
		plate_size = value
		_refresh()
#Font sizes of the LVL tag and the number on a plate; zero keeps the size the mode sets.
@export var kicker_size: int = 0:
	set(value):
		kicker_size = maxi(0, value)
		_refresh()
@export var value_size: int = 0:
	set(value):
		value_size = maxi(0, value)
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
var _chip_gap: int = 0


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
		GuiNodes.ignore_mouse(child)


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
	_chip_gap = row.get_theme_constant(&"separation")


func _refresh() -> void:
	if not is_node_ready():
		return
	number_label.text = str(level) if size_mode == SizeMode.CHIP else "%02d" % level
	tag_label.text = "Level" if size_mode == SizeMode.LARGE else "LVL"
	tip_node.set_xp(current_xp, next_level_xp)
	_apply_mode()
	queue_redraw()


func _apply_mode() -> void:
	row.add_theme_constant_override(&"separation", 0 if size_mode == SizeMode.PAYROLL else _chip_gap)
	match size_mode:
		SizeMode.TILE:
			_apply_plate(_plate_or(TILE_SIZE), 8, 20, _flat_plate(0))
		SizeMode.LARGE:
			_apply_plate(LARGE_SIZE, 11, 44, _flat_plate(int(LARGE_BORDER_PX)))
		SizeMode.PAYROLL:
			_apply_plate(_plate_or(PAYROLL_SIZE), PAYROLL_KICKER_SIZE, PAYROLL_VALUE_SIZE, PAYROLL_STYLE)
		_:
			_apply_chip()


func _plate_or(fallback: Vector2) -> Vector2:
	return fallback if plate_size == Vector2.ZERO else plate_size


func _apply_chip() -> void:
	row.vertical = false
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	custom_minimum_size = _chip_min
	add_theme_stylebox_override("panel", _chip_box)
	_set_label(tag_label, _chip_tag_font, _chip_tag_size, HORIZONTAL_ALIGNMENT_LEFT)
	_set_label(number_label, _chip_number_font, _chip_number_size, HORIZONTAL_ALIGNMENT_LEFT)


func _apply_plate(box_size: Vector2, tag_size: int, number_size: int, box: StyleBox) -> void:
	row.vertical = true
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	custom_minimum_size = box_size
	add_theme_stylebox_override("panel", box)
	_set_label(tag_label, TAG_FONT, kicker_size if kicker_size > 0 else tag_size, HORIZONTAL_ALIGNMENT_CENTER)
	_set_label(number_label, NUMBER_FONT, value_size if value_size > 0 else number_size, HORIZONTAL_ALIGNMENT_CENTER)


#The flat plate TILE and LARGE paint their bevel over.
func _flat_plate(border: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PLATE_COLOR
	box.set_border_width_all(border)
	box.border_color = INK_COLOR
	box.content_margin_left = 0.0
	box.content_margin_top = 0.0
	box.content_margin_right = 0.0
	box.content_margin_bottom = 0.0
	return box


func _set_label(node: Label, font: Font, font_size: int, align: HorizontalAlignment) -> void:
	node.horizontal_alignment = align
	node.size_flags_horizontal = SIZE_EXPAND_FILL if align == HORIZONTAL_ALIGNMENT_CENTER else SIZE_FILL
	if font != null:
		node.add_theme_font_override("font", font)
	if font_size > 0:
		node.add_theme_font_size_override("font_size", font_size)


#A stylebox has no bevel, so TILE and LARGE paint the prototype's raised edges over it.
func _draw() -> void:
	if size_mode == SizeMode.CHIP or size_mode == SizeMode.PAYROLL:
		return
	var inset: float = 0.0 if size_mode == SizeMode.TILE else LARGE_BORDER_PX
	var px: float = TILE_BEVEL_PX if size_mode == SizeMode.TILE else LARGE_BEVEL_PX
	BevelButton.paint_edges(self, Rect2(Vector2.ZERO, size).grow(-inset), BEVEL_HI, BEVEL_LO, px)


#An owner that turned the badge's mouse input off gets no tip; the Row child still forwards hover
func show_tip() -> void:
	if mouse_filter == MOUSE_FILTER_IGNORE:
		return
	tip_node.show_at(self)


func hide_tip() -> void:
	tip_node.hide_tip()


func tip() -> XPTooltip:
	return tip_node
