class_name CrewGlyphs

#The Odd Job atoms (note, plus, star). Each one is an atlas icon tinted to the asked colour and
#scaled by whole art pixels; Icons keeps the cache.

const NOTE_COLS: int = 5
const NOTE_ROWS: int = 9


static func note(color: Color, scale: int = 1) -> ImageTexture:
	return Icons.tinted("note", color, scale, true)


static func plus(color: Color, scale: int = 1) -> ImageTexture:
	return Icons.tinted("plus", color, scale, true)


static func star(color: Color, scale: int = 1) -> ImageTexture:
	return Icons.tinted("star_set", color, scale, false)
