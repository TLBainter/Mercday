class_name NotifyGlyphs

#The notification icon box stripe sizes and the drop shadow plate. GuiGlyphs.hatch builds the 8 px
#stripe tile behind an icon; the 2 px ink shadow sits behind the art. Glyphs come from the icon atlas.

#The icon box stripes: 4 px bands at 45 degrees inside an 8 px tile.
const STRIPE_TILE: int = 8
const STRIPE_BAND: int = 4
const SHADOW_STEP: int = 2
const SHADOW_COLOR: Color = GuiColors.INK


#A glyph with a 2 px ink drop shadow behind it. The art is already baked at its final size, so the
#plate is that size plus the step; face_tint colours the face alone.
static func shadowed(tex: Texture2D, step: int = SHADOW_STEP,
		face_tint: Color = Color.WHITE) -> Control:
	var box := Control.new()
	box.name = "Glyph"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph_size: Vector2 = Vector2(tex.get_size())
	box.custom_minimum_size = glyph_size + Vector2(step, step)
	box.add_child(_plate("Shadow", tex, glyph_size, Vector2(step, step), SHADOW_COLOR))
	box.add_child(_plate("Face", tex, glyph_size, Vector2.ZERO, face_tint))
	return box


static func _plate(node_name: String, tex: Texture2D, glyph_size: Vector2, at: Vector2,
		tint: Color) -> TextureRect:
	var plate := TextureRect.new()
	plate.name = node_name
	plate.texture = tex
	plate.modulate = tint
	plate.position = at
	plate.size = glyph_size
	plate.custom_minimum_size = glyph_size
	plate.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate
