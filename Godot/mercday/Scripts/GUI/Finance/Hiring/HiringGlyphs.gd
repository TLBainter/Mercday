class_name HiringGlyphs

#The diagonal hatch that stands in for an applicant portrait, drawn and cached by GuiGlyphs.hatch
#so no PNG is added. The View button eye comes from the icon sheet, so it is no longer built here.

const HATCH_HALF: int = 4


static func hatch(side_in: int, ink: Color = GuiColors.BLUE_LO,
		back: Color = GuiColors.ROW_FILL) -> ImageTexture:
	var side: int = maxi(1, side_in)
	return GuiGlyphs.hatch(ink, back, HATCH_HALF, Vector2i(side, side))
