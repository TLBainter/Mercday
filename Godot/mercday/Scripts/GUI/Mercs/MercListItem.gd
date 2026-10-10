class_name MercListItem extends BevelButton

#One roster row: the portrait with its status strip and time tag, the first name over the
#tradition and the level badge at the right. A busy merc dims, except the strip and the tag, and
#the selected row takes the list fill. The band takes its colour from GuiTypes so one table rules
#every status, an away merc reads as away, and a merc out chasing a loan carries the ledger's
#note under their tradition.

const ROW_HEIGHT: int = 56
const BUTTON_HEIGHT: int = 68
const BUSY_MODULATE: Color = Color(0.65, 0.65, 0.65, 1.0)

signal selected(uid: int)

@export var uid: int = 0
@export var merc_name: String = "":
	set(value):
		merc_name = value
		_refresh()
@export var tradition: String = "":
	set(value):
		tradition = value
		_refresh()
@export var level: int = 1:
	set(value):
		level = value
		_refresh()
@export var status: int = GuiTypes.MercStatus.AVAILABLE:
	set(value):
		status = value
		_refresh()
@export var time_left_minutes: int = 0:
	set(value):
		time_left_minutes = value
		_refresh()
@export var is_selected: bool = false:
	set(value):
		is_selected = value
		_paint_selection()
		_refresh()

@onready var portrait_holder: Control = $Row/PortraitHolder
@onready var portrait_frame: Panel = $Row/PortraitHolder/Frame
@onready var portrait: MercPortrait = $Row/PortraitHolder/Portrait
@onready var strip: MercStatusStrip = $Row/PortraitHolder/Strip
@onready var time_tag: Label = $Row/PortraitHolder/TimeLeft
@onready var names: VBoxContainer = $Row/Names
@onready var name_label: Label = $Row/Names/MercName
@onready var tradition_label: Label = $Row/Names/Tradition
@onready var note_label: Label = $Row/Names/Note
@onready var badge: LevelBadge = $Row/Badge

var view: MercView = null


func _init() -> void:
	pressed_fill = GuiColors.ROW_HOVER
	click_move = ButtonFx.ClickMove.NONE
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING
	_paint_selection()


func _ready() -> void:
	super()
	custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	pressed.connect(_on_pressed)
	_refresh()


func set_view(new_view: MercView) -> void:
	view = new_view
	if view == null:
		return
	uid = view.uid
	merc_name = MercHeader.split_name(view.name)[0]
	tradition = view.tradition
	level = view.level
	time_left_minutes = int(round(view.status_time_left_hours * 60.0))
	status = shown_status()
	if is_node_ready():
		portrait.set_merc(view)


#The status the band reads: an away merc shows where they are.
func shown_status() -> int:
	return status if view == null else view.shown_status()


func status_text() -> String:
	return GuiTypes.merc_status_text(status)


func status_color() -> Color:
	return strip.get_theme_color("font_color") if is_node_ready() else Color.WHITE


func note_text() -> String:
	return note_label.text if is_node_ready() and note_label.visible else ""


#The loan line under the tradition, when the ledger has one to give.
func loan_note() -> String:
	return "" if view == null else view.loan_note(status)


func _refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = merc_name
	tradition_label.text = tradition
	badge.level = level
	if view != null:
		badge.current_xp = view.xp
		badge.next_level_xp = ExperienceSystem.xp_for_level(view.level + 1)
	strip.status = status
	strip.add_theme_color_override("font_color", GuiTypes.merc_status_color(status))
	MercStatusStrip.dress_time_tag(time_tag, time_left_minutes)
	var note: String = loan_note()
	note_label.text = note
	note_label.visible = note != ""
	_apply_dim()


#A busy row dims its own box, the portrait, the names and the badge; the status strip and the
#time tag keep their full colour so they stay readable.
func _apply_dim() -> void:
	var tint: Color = Color.WHITE if status == GuiTypes.MercStatus.AVAILABLE else BUSY_MODULATE
	self_modulate = tint
	for part: CanvasItem in [portrait_frame, portrait, names, badge]:
		part.modulate = tint


func fx_active() -> bool:
	return super() or is_selected


#A selected row is the pressed fill ringed in orange; an idle row keeps its ink edge on the low band.
func _paint_selection() -> void:
	if is_selected:
		set_colors(GuiColors.ROW_HOVER, GuiColors.ORANGE, GuiColors.ORANGE, text_color)
	else:
		set_colors(GuiColors.ROW_FILL, GuiColors.ROW_FILL.lightened(0.18), GuiColors.ROW_EDGE_LO, text_color)


func _on_pressed() -> void:
	selected.emit(uid)
