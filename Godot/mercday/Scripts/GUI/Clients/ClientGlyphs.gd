class_name ClientGlyphs

#The hatched placeholder fill of the client window, one tile the size of the box it covers, so
#nothing has to stretch. Every other client glyph now comes off the icon atlas through Icons.

const HATCH_BACK: Color = GuiColors.ROW_FILL
const HATCH_LINE: Color = GuiColors.BLUE_LO


#A 45 degree hatch, one tile the size of the node it fills, so nothing has to stretch.
static func hatch(size: int, band: int) -> Texture2D:
	return GuiGlyphs.hatch(HATCH_LINE, HATCH_BACK, band, Vector2i(size, size))
