class_name BarIconButton extends BevelButton

#A bottom-bar toggle face: neutral at rest, orange while pressed, one atlas icon tinted with the label
#colour of the palette in use. A subclass names its icon in _face_id().

@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		queue_redraw()


func _init() -> void:
	kind = &"neutral"
	active_kind = &"orange"
	click_move = ButtonFx.ClickMove.POP
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.LIFT
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER


#The atlas id drawn on the face; "" draws nothing.
func _face_id() -> String:
	return ""


func _draw_face(rect: Rect2) -> void:
	var id: String = _face_id()
	if id == "":
		return
	var art: Vector2 = Vector2(Icons.size(id)) * float(pixel_scale)
	var tint: Color = _pal()["text"]
	Icons.draw(self, id, (rect.position + (rect.size - art) / 2.0).floor(), pixel_scale, _fx.label(tint), true)
