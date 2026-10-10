class_name MercGlyphs

#The Merc Viewer's own atlas cuts. Each PIP is the centred 8 x 8 window of the cell PipDefs names,
#so it comes from the icon sheet instead of a PNG. A locked PIP needs a flat white silhouette for
#the caller's modulate to paint, and that silhouette is the only cache.

const PIP_SCALE: int = 3
const PIP_BOX: Vector2i = Vector2i(8, 8)

static var _cache: Dictionary = {}


#The centred 8 x 8 window of the mode's cell at x3, colour art that no caller tints.
static func pip(mode: StringName) -> Texture2D:
	var id: String = PipDefs.icon_id(mode)
	if id == "":
		return null
	return Icons.baked(id, PIP_SCALE, Icons.MODE_PLAIN, false,
		Icons.centered_box(PIP_BOX.x, PIP_BOX.y))


#The same window flattened to white, which lets the caller's modulate paint the locked colour.
static func pip_locked(mode: StringName) -> Texture2D:
	var id: String = PipDefs.icon_id(mode)
	if id == "":
		return null
	if _cache.has(id):
		return _cache[id] as Texture2D
	var img: Image = Icons.image(id, false, Icons.centered_box(PIP_BOX.x, PIP_BOX.y))
	for y: int in img.get_height():
		for x: int in img.get_width():
			var alpha: float = img.get_pixel(x, y).a
			if alpha > 0.0:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	img.resize(PIP_BOX.x * PIP_SCALE, PIP_BOX.y * PIP_SCALE, Image.INTERPOLATE_NEAREST)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex
