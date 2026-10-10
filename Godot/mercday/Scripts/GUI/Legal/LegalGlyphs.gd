class_name LegalGlyphs

#The hatched placeholder fill of the Legal screens, tiled behind an icon or a portrait box. Every
#other Legal glyph now comes off the icon atlas through Icons.

#The placeholder hatch: 4 px bands at 45 degrees inside an 8 px tile.
const HATCH_TILE: int = 8
const HATCH_BAND: int = 4


#A TextureRect that tiles the hatch over whatever box it is added to.
static func hatch_rect(fill: Color, back: Color) -> TextureRect:
	var out := TextureRect.new()
	out.name = "Hatch"
	out.texture = GuiGlyphs.hatch(fill, back, HATCH_BAND, Vector2i(HATCH_TILE, HATCH_TILE))
	out.stretch_mode = TextureRect.STRETCH_TILE
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.set_anchors_preset(Control.PRESET_FULL_RECT)
	return out
