class_name DispatchRosterItem extends BevelButton

#One hireable merc in the Dispatch Window left column. A click fills the next open slot; a drag
#carries the uid to whichever slot it is dropped on. A merc already on the team stays listed,
#dimmed and ringed, and a click on that row takes them back off the team. A band across the top
#of the portrait says whether the merc is AVAILABLE or ASSIGNED.

signal picked(uid: int)
signal remove_requested(uid: int)

#How far a row already on the team fades.
const ASSIGNED_ALPHA: float = 0.6
#How far the source row fades while its ghost rides the cursor.
const HELD_ALPHA: float = 0.45
#The ring an assigned row wears.
const RING_COLOR: Color = GuiColors.GREEN
const RING_WIDTH: float = 3.0
const PORTRAIT_SIZE: int = 48
const AVAILABLE_TEXT: String = "AVAILABLE"
const ASSIGNED_TEXT: String = "ASSIGNED"
const AVAILABLE_COLOR: Color = GuiColors.SKY
const ASSIGNED_COLOR: Color = GuiColors.GREEN
#Ink at 75 percent, so the portrait still reads under the band.
const STATUS_BAND: Color = Color(0.039216, 0.058824, 0.109804, 0.75)
const STATUS_FONT_PX: int = 7
const STATUS_HEIGHT: int = 10

@onready var portrait: MercPortrait = $Row/PortraitBox/Portrait
@onready var name_label: Label = $Row/Text/Name
@onready var tradition_label: Label = $Row/Text/Tradition
@onready var stars: Stars = $Row/Text/Stars
@onready var level_badge: LevelBadge = $Row/Level
@onready var status_panel: PanelContainer = $Row/PortraitBox/Status
@onready var status_label: Label = $Row/PortraitBox/Status/Text

var view: MercView = null
var match_stars: float = 0.0
var assigned: bool = false
#True from the moment this row hands out a drag payload until the drag ends.
var _held: bool = false
#The drag ghost hides the band; the flag outlives the row reaching the tree.
var _status_shown: bool = true


#The row stays see-through over the inset panel; its bevel is shaded from that panel colour.
func _init() -> void:
	fill = GuiColors.CLEAR
	hi = GuiColors.ROW_FILL.lightened(0.18)
	lo = GuiColors.ROW_FILL.darkened(0.25)
	hover_fill = GuiColors.BLUE_HI
	pressed_fill = GuiColors.BLUE_LO
	click_move = ButtonFx.ClickMove.NONE
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.NONE
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	pressed.connect(_on_pressed)
	level_badge.mouse_filter = MOUSE_FILTER_IGNORE
	_refresh()


func set_merc(new_view: MercView, new_stars: float, new_assigned: bool = false) -> void:
	view = new_view
	match_stars = new_stars
	assigned = new_assigned
	_refresh()


func set_assigned(on: bool) -> void:
	assigned = on
	_refresh()


func set_status_visible(on: bool) -> void:
	_status_shown = on
	if is_node_ready():
		status_panel.visible = on


func status_text() -> String:
	if not is_node_ready():
		return ""
	return status_label.text


func is_assigned() -> bool:
	return assigned


func is_held() -> bool:
	return _held


func merc_uid() -> int:
	return view.uid if view != null else 0


func badge() -> LevelBadge:
	return level_badge


func stars_value() -> float:
	return match_stars


func _refresh() -> void:
	if not is_node_ready() or view == null:
		return
	portrait.pixel_size = PORTRAIT_SIZE
	portrait.set_merc(view)
	name_label.text = view.name
	level_badge.level = view.level
	level_badge.current_xp = 0
	level_badge.next_level_xp = 1
	tradition_label.text = view.tradition
	tradition_label.add_theme_color_override("font_color", view.tradition_color())
	stars.value = match_stars
	status_label.text = ASSIGNED_TEXT if assigned else AVAILABLE_TEXT
	status_label.add_theme_color_override("font_color",
		ASSIGNED_COLOR if assigned else AVAILABLE_COLOR)
	status_panel.visible = _status_shown
	modulate.a = _alpha()
	tooltip_text = "%s\nLevel %d\n%s" % [view.name, view.level, view.tradition]
	queue_redraw()


#An assigned row wears a green ring over its bevel.
func _draw_face(rect: Rect2) -> void:
	if not assigned:
		return
	var ring: Rect2 = rect.grow(-RING_WIDTH * 0.5)
	if ring.size.x <= 0.0 or ring.size.y <= 0.0:
		return
	draw_rect(ring, RING_COLOR, false, RING_WIDTH)


#Held beats assigned: a dragged row reads as lifted even when it is already on the team.
func _alpha() -> float:
	if _held:
		return HELD_ALPHA
	return ASSIGNED_ALPHA if assigned else 1.0


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _held:
		return
	_held = false
	_refresh()


func _on_pressed() -> void:
	if assigned:
		remove_requested.emit(merc_uid())
		return
	picked.emit(merc_uid())


func _get_drag_data(at_position: Vector2) -> Variant:
	if view == null:
		return null
	MercDragGhost.attach(self, view, match_stars, size, at_position)
	_held = true
	_refresh()
	return {"uid": view.uid}
