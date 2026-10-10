class_name LoanGlyphs

#Runtime pixel art of the Loans page: the change arrows of the offer table come from the icon
#atlas, and the hatch tile stands in for a lender or envoy portrait until real art exists.

const ARROW_IDS: Dictionary = {&"up": "trend_up", &"down": "trend_down",
	&"diag_up": "trend_diag_up", &"diag_down": "trend_diag_down"}
const ARROW_BOX: Rect2i = Rect2i(3, 4, 9, 8)
const ARROW_SCALE: int = 2
const ARROW_BOX_PX: Vector2 = Vector2(18.0, 16.0)
const HATCH_SIDE: int = 8
const HATCH_BAND: int = 4
const PORTRAIT_RING: int = 2
const PORTRAIT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MercPortrait.tscn")


#One change arrow: up and down are the straight pair, diag_up and diag_down the shallow pair.
static func arrow_id(dir: StringName) -> String:
	return ARROW_IDS.get(dir, "") as String


static func arrow(dir: StringName) -> ImageTexture:
	var id: String = arrow_id(dir)
	if id == "":
		return null
	return Icons.baked(id, ARROW_SCALE, Icons.MODE_GRAY, false, ARROW_BOX)


#The fixed box a change arrow sits centred in; its only child is the IconRect set_arrow writes.
static func arrow_box() -> CenterContainer:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = ARROW_BOX_PX
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := IconRect.new()
	rect.window = ARROW_BOX
	rect.mode = Icons.MODE_GRAY
	rect.pixel_scale = ARROW_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rect)
	return holder


#Shows the arrow of dir tinted in color; an empty dir leaves the rect blank.
static func set_arrow(rect: IconRect, dir: StringName, color: Color) -> void:
	rect.tint = color
	rect.icon_id = arrow_id(dir)


#An envoy draws its own portrait, which joins art; a row without a uid keeps the hatch placeholder.
static func envoy_face(row: Dictionary, side: float, art: Array[MercPortrait]) -> Control:
	var uid: int = int(row.get("uid", 0))
	if uid <= 0:
		return portrait(side)
	var face: MercPortrait = PORTRAIT_SCENE.instantiate() as MercPortrait
	face.pixel_size = int(side)
	face.show_uid(uid, String(row.get("name", "")))
	art.append(face)
	return face


#A square placeholder portrait: the shared hatch tile under a ring.
static func portrait(side: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(side, side)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := TextureRect.new()
	tile.texture = GuiGlyphs.hatch(GuiColors.BLUE_LO, GuiColors.ROW_FILL, HATCH_BAND,
		Vector2i(HATCH_SIDE, HATCH_SIDE))
	tile.stretch_mode = TextureRect.STRETCH_TILE
	tile.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tile)
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", GuiStyle.flat(GuiColors.CLEAR, PORTRAIT_RING, GuiColors.BLUE_HI))
	box.add_child(ring)
	return box
