class_name Icons extends RefCounted

#The one icon atlas, cut by cell. Every screen icon is an AtlasTexture over the 16x16 grid of
#merc-manager_ICON-COLLECTION.png, baked to an ImageTexture at an integer scale when it is drawn.
#Tint modes: plain draws the art, gray runs the luminance pass, two_tone paints the active tab.

const ATLAS_PATH: String = "res://Art/GUI/Icons/merc-manager_ICON-COLLECTION.png"
const IDS_PATH: String = "res://Art/GUI/Icons/icon_ids.json"
const ATLAS_TEX: Texture2D = preload("res://Art/GUI/Icons/merc-manager_ICON-COLLECTION.png")

const CELL: int = 16
const COLS: int = 16
const ROWS: int = 40

const MODE_PLAIN: StringName = &"plain"
const MODE_GRAY: StringName = &"gray"
const MODE_TWO_TONE: StringName = &"two_tone"

#Difficulty order, value 0.5 to 5.0 by halves; a positive rating reads the same list backwards.
const STAR_STOPS: Array[Color] = [Color("#29e029"), Color("#50e029"), Color("#77e029"),
	Color("#a6e33b"), Color("#cae33b"), Color("#e3d83b"), Color("#e3b43b"), Color("#e08629"),
	Color("#e05f29"), Color("#e03829")]
const UNUSED_STAR: Color = Color("#1f3560")
const UNUSED_STAR_CLIENT: Color = Color("#2b4f8a")
const STAR_GAP: int = 2
const STAR_COUNT: int = 5

const TAB_ON_LIGHT: Color = Color("#5a3510")
const TAB_ON_MID: Color = Color("#3a2008")
const TAB_ON_INK: Color = Color("#0a0f1c")
const FACE_OUTLINE: Color = Color("#2b4f8a")

#Mood index 0 Angry to 4 Happy, mapped onto the face levels.
const MOOD_LEVELS: Array[int] = [-5, -3, 0, 3, 5]

const LUMA_R: float = 0.299
const LUMA_G: float = 0.587
const LUMA_B: float = 0.114
#tabOn thresholds read off the prototype reader.
const TAB_SPREAD: int = 40
const TAB_DARK: float = 90.0
const TAB_LIGHT: float = 200.0
#The four neighbours the outline pass of solid_outlined walks.
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
	Vector2i(0, -1)]

static var _order: Array[String] = []
static var _cells: Dictionary = {}
static var _offsets: Dictionary = {}
static var _sizes: Dictionary = {}
static var _monos: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _window_cache: Dictionary = {}
static var _bake_cache: Dictionary = {}
static var _solid_cache: Dictionary = {}
static var _tint_cache: Dictionary = {}
static var _outline_cache: Dictionary = {}
static var _star_cache: Dictionary = {}
static var _atlas_image: Image = null
static var _gradient: Gradient = null


static func _static_init() -> void:
	var raw: String = FileAccess.get_file_as_string(IDS_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_error("Icons: cannot read %s" % IDS_PATH)
		return
	var list: Variant = (parsed as Dictionary).get("icons", null)
	if not (list is Array):
		push_error("Icons: %s holds no icon list" % IDS_PATH)
		return
	for entry: Variant in (list as Array):
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry as Dictionary
		var id: String = String(row.get("id", ""))
		if id == "":
			continue
		_order.append(id)
		_cells[id] = _pair(row.get("cell", null))
		_offsets[id] = _pair(row.get("offset", null))
		_sizes[id] = _pair(row.get("size", null))
		_monos[id] = String(row.get("tint", "")) == "mono"


static func _pair(value: Variant) -> Vector2i:
	if not (value is Array) or (value as Array).size() < 2:
		return Vector2i.ZERO
	var arr: Array = value as Array
	return Vector2i(int(arr[0]), int(arr[1]))


static func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_order)
	return out


static func has(id: String) -> bool:
	return _cells.has(id)


static func cell(id: String) -> Vector2i:
	if not _cells.has(id):
		_unknown(id)
		return Vector2i.ZERO
	return _cells[id] as Vector2i


static func offset(id: String) -> Vector2i:
	if not _offsets.has(id):
		_unknown(id)
		return Vector2i.ZERO
	return _offsets[id] as Vector2i


static func size(id: String) -> Vector2i:
	if not _sizes.has(id):
		_unknown(id)
		return Vector2i.ZERO
	return _sizes[id] as Vector2i


static func is_mono(id: String) -> bool:
	if not _monos.has(id):
		_unknown(id)
		return false
	return bool(_monos[id])


static func atlas() -> Texture2D:
	return ATLAS_TEX


static func atlas_image() -> Image:
	if _atlas_image == null:
		var img: Image = ATLAS_TEX.get_image()
		if img == null:
			push_error("Icons: the atlas holds no image")
			return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		_atlas_image = _rgba(img)
	return _atlas_image


static func tex(id: String, trimmed: bool = false) -> AtlasTexture:
	if not _cells.has(id):
		_unknown(id)
		return null
	var key: String = id + ("|t" if trimmed else "")
	if _tex_cache.has(key):
		return _tex_cache[key] as AtlasTexture
	var origin: Vector2i = cell(id) * CELL
	var region := Rect2(origin.x, origin.y, CELL, CELL)
	if trimmed:
		var off: Vector2i = offset(id)
		var box: Vector2i = size(id)
		region = Rect2(origin.x + off.x, origin.y + off.y, box.x, box.y)
	var out := AtlasTexture.new()
	out.atlas = ATLAS_TEX
	out.region = region
	out.filter_clip = true
	_tex_cache[key] = out
	return out


static func centered_box(w: int, h: int) -> Rect2i:
	return Rect2i((CELL - w) / 2, (CELL - h) / 2, w, h)


static func window(id: String, box: Rect2i) -> AtlasTexture:
	if not _cells.has(id):
		_unknown(id)
		return null
	if not Rect2i(0, 0, CELL, CELL).encloses(box) or box.size.x <= 0 or box.size.y <= 0:
		push_error("Icons: window %s outside the cell of %s" % [box, id])
		return tex(id)
	var key: String = "%s|%d,%d,%d,%d" % [id, box.position.x, box.position.y, box.size.x, box.size.y]
	if _window_cache.has(key):
		return _window_cache[key] as AtlasTexture
	var origin: Vector2i = cell(id) * CELL + box.position
	var out := AtlasTexture.new()
	out.atlas = ATLAS_TEX
	out.region = Rect2(origin.x, origin.y, box.size.x, box.size.y)
	out.filter_clip = true
	_window_cache[key] = out
	return out


#A fresh RGBA8 copy of the pixels behind any texture; get_image() is never called on an atlas cut.
static func source_image(source: Texture2D) -> Image:
	if source == null:
		push_error("Icons: no texture to read")
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	if source is AtlasTexture:
		var cut: AtlasTexture = source as AtlasTexture
		var region := Rect2i(cut.region)
		if cut.atlas == ATLAS_TEX:
			return atlas_image().get_region(region)
		if cut.atlas == null:
			push_error("Icons: the atlas cut has no source texture")
			return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		var sheet: Image = cut.atlas.get_image()
		if sheet == null:
			push_error("Icons: the source sheet holds no image")
			return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		return _rgba(sheet).get_region(region)
	var flat: Image = source.get_image()
	if flat == null:
		push_error("Icons: the texture holds no image")
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	return _rgba(flat)


static func image(id: String, trimmed: bool = false, box: Rect2i = Rect2i()) -> Image:
	if not _cells.has(id):
		_unknown(id)
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	if box.size != Vector2i.ZERO:
		return source_image(window(id, box))
	return source_image(tex(id, trimmed))


static func gray_image(img: Image) -> Image:
	var out: Image = _rgba(img)
	for y: int in out.get_height():
		for x: int in out.get_width():
			var px: Color = out.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			var lum: float = roundf(LUMA_R * px.r8 + LUMA_G * px.g8 + LUMA_B * px.b8)
			var level: int = clampi(int(lum), 0, 255)
			out.set_pixel(x, y, Color8(level, level, level, px.a8))
	return out


static func two_tone_image(img: Image) -> Image:
	var out: Image = _rgba(img)
	for y: int in out.get_height():
		for x: int in out.get_width():
			var px: Color = out.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			var top: int = maxi(px.r8, maxi(px.g8, px.b8))
			var low: int = mini(px.r8, mini(px.g8, px.b8))
			var lum: float = LUMA_R * px.r8 + LUMA_G * px.g8 + LUMA_B * px.b8
			var paint: Color = TAB_ON_INK
			if top - low <= TAB_SPREAD and lum >= TAB_DARK:
				paint = TAB_ON_LIGHT if lum > TAB_LIGHT else TAB_ON_MID
			out.set_pixel(x, y, Color(paint.r, paint.g, paint.b, px.a))
	return out


static func bake(source: Texture2D, scale: int, mode: StringName = MODE_PLAIN) -> ImageTexture:
	if source == null:
		return null
	var steps: int = maxi(1, scale)
	var key: String = "%d|%d|%s" % [source.get_instance_id(), steps, mode]
	if _bake_cache.has(key):
		return _bake_cache[key] as ImageTexture
	var img: Image = source_image(source)
	if mode == MODE_GRAY:
		img = gray_image(img)
	elif mode == MODE_TWO_TONE:
		img = two_tone_image(img)
	if steps > 1:
		img.resize(img.get_width() * steps, img.get_height() * steps, Image.INTERPOLATE_NEAREST)
	var out: ImageTexture = ImageTexture.create_from_image(img)
	_bake_cache[key] = out
	return out


static func baked(id: String, scale: int, mode: StringName = MODE_PLAIN, trimmed: bool = false,
		box: Rect2i = Rect2i()) -> ImageTexture:
	var source: Texture2D = window(id, box) if box.size != Vector2i.ZERO else tex(id, trimmed)
	return bake(source, scale, mode)


#The art of a mono id painted one colour: every rgb is multiplied by the tint and alpha is kept.
static func tinted(id: String, tint: Color, scale: int = 1, trimmed: bool = false,
		box: Rect2i = Rect2i()) -> ImageTexture:
	if not _cells.has(id):
		_unknown(id)
		return null
	var steps: int = maxi(1, scale)
	var key: String = "%s|%s|%d|%s|%s" % [id, tint.to_html(), steps, trimmed, box]
	if _tint_cache.has(key):
		return _tint_cache[key] as ImageTexture
	var out: Image = _rgba(image(id, trimmed, box))
	for y: int in out.get_height():
		for x: int in out.get_width():
			var px: Color = out.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			out.set_pixel(x, y, Color(px.r * tint.r, px.g * tint.g, px.b * tint.b, px.a))
	if steps > 1:
		out.resize(out.get_width() * steps, out.get_height() * steps, Image.INTERPOLATE_NEAREST)
	var made: ImageTexture = ImageTexture.create_from_image(out)
	_tint_cache[key] = made
	return made


#Every opaque pixel becomes fill and the ring around it outline; the art grows one pixel a side
#so the ring never clips.
static func solid_outlined(id: String, fill: Color, outline: Color, scale: int = 1,
		trimmed: bool = false) -> ImageTexture:
	if not _cells.has(id):
		_unknown(id)
		return null
	var steps: int = maxi(1, scale)
	var key: String = "%s|%s|%s|%d|%s" % [id, fill.to_html(true), outline.to_html(true), steps,
		trimmed]
	if _solid_cache.has(key):
		return _solid_cache[key] as ImageTexture
	var out: Image = _ringed(image(id, trimmed), fill, true, outline)
	if steps > 1:
		out.resize(out.get_width() * steps, out.get_height() * steps, Image.INTERPOLATE_NEAREST)
	var made: ImageTexture = ImageTexture.create_from_image(out)
	_solid_cache[key] = made
	return made


#Every opaque pixel keeps its own colour and gains the same 1 art px ring.
static func outlined(id: String, outline: Color, scale: int = 1,
		trimmed: bool = false) -> ImageTexture:
	if not _cells.has(id):
		_unknown(id)
		return null
	var steps: int = maxi(1, scale)
	var key: String = "%s|%s|%d|%s" % [id, outline.to_html(true), steps, trimmed]
	if _outline_cache.has(key):
		return _outline_cache[key] as ImageTexture
	var out: Image = _ringed(image(id, trimmed), Color.WHITE, false, outline)
	if steps > 1:
		out.resize(out.get_width() * steps, out.get_height() * steps, Image.INTERPOLATE_NEAREST)
	var made: ImageTexture = ImageTexture.create_from_image(out)
	_outline_cache[key] = made
	return made


#Grows the art by one pixel a side, paints the body and rings it. use_fill drops the source colour.
static func _ringed(src: Image, fill: Color, use_fill: bool, outline: Color) -> Image:
	var w: int = src.get_width() + 2
	var h: int = src.get_height() + 2
	var out: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.0, 0.0, 0.0, 0.0))
	var mask: Array[bool] = []
	mask.resize(w * h)
	for y: int in src.get_height():
		for x: int in src.get_width():
			var was: Color = src.get_pixel(x, y)
			if was.a <= 0.0:
				continue
			mask[(y + 1) * w + x + 1] = true
			out.set_pixel(x + 1, y + 1, fill if use_fill else was)
	for y: int in h:
		for x: int in w:
			if mask[y * w + x]:
				continue
			if _touches_fill(mask, w, h, x, y):
				out.set_pixel(x, y, outline)
	return out


static func _touches_fill(mask: Array[bool], w: int, h: int, x: int, y: int) -> bool:
	for step: Vector2i in NEIGHBOURS:
		var at: Vector2i = Vector2i(x, y) + step
		if at.x < 0 or at.y < 0 or at.x >= w or at.y >= h:
			continue
		if mask[at.y * w + at.x]:
			return true
	return false


#fill 1.0 the set star in color, 0.0 the unused star in empty, 0.5 the left half of each.
static func star_image(fill: float, color: Color, empty: Color = UNUSED_STAR) -> Image:
	var step: float = _star_step(fill)
	var set_img: Image = _tinted(gray_image(image("star_set")), color)
	if is_equal_approx(step, 1.0):
		return set_img
	var unused_img: Image = _tinted(gray_image(image("star_unused")), empty)
	if is_zero_approx(step):
		return unused_img
	for y: int in unused_img.get_height():
		for x: int in range(CELL / 2, unused_img.get_width()):
			set_img.set_pixel(x, y, unused_img.get_pixel(x, y))
	return set_img


static func star(fill: float, color: Color, empty: Color = UNUSED_STAR,
		scale: int = 1) -> ImageTexture:
	var steps: int = maxi(1, scale)
	var step: float = _star_step(fill)
	var key: String = "%.1f|%s|%s|%d" % [step, color.to_html(true), empty.to_html(true), steps]
	if _star_cache.has(key):
		return _star_cache[key] as ImageTexture
	var img: Image = star_image(step, color, empty)
	if steps > 1:
		img.resize(img.get_width() * steps, img.get_height() * steps, Image.INTERPOLATE_NEAREST)
	var out: ImageTexture = ImageTexture.create_from_image(img)
	_star_cache[key] = out
	return out


static func star_color(value: float, positive: bool = false) -> Color:
	var held: float = clampf(value, 0.5, 5.0)
	var t: float = (held - 0.5) / 4.5
	return _star_gradient().sample(1.0 - t if positive else t)


static func star_fills(value: float, count: int = STAR_COUNT) -> Array[float]:
	var held: float = clampf(value, 0.0, float(count))
	var out: Array[float] = []
	for i: int in count:
		if held >= float(i) + 1.0:
			out.append(1.0)
		elif held >= float(i) + 0.5:
			out.append(0.5)
		else:
			out.append(0.0)
	return out


static func stars_width(scale: int = 1, count: int = STAR_COUNT, gap: int = STAR_GAP) -> int:
	if count <= 0:
		return 0
	return count * CELL * scale + (count - 1) * gap * scale


static func draw_stars(canvas: CanvasItem, pos: Vector2, scale: int, value: float,
		positive: bool = false, empty: Color = UNUSED_STAR, gap: int = STAR_GAP) -> int:
	var steps: int = maxi(1, scale)
	var tint: Color = star_color(value, positive)
	var fills: Array[float] = star_fills(value)
	var at: Vector2 = pos.floor()
	var stride: int = CELL * steps + gap * steps
	for i: int in fills.size():
		var art: ImageTexture = star(fills[i], tint, empty, steps)
		canvas.draw_texture_rect(art, Rect2(at + Vector2(i * stride, 0), art.get_size()),
			false, Color.WHITE)
	return stars_width(steps, fills.size(), gap)


static func draw(canvas: CanvasItem, id: String, pos: Vector2, scale: int = 1,
		tint: Color = Color.WHITE, trimmed: bool = false) -> void:
	var art: AtlasTexture = tex(id, trimmed)
	if art == null:
		return
	canvas.draw_texture_rect(art, Rect2(pos.floor(), art.get_size() * float(maxi(1, scale))),
		false, tint)


static func draw_texture(canvas: CanvasItem, art: Texture2D, pos: Vector2, scale: int,
		tint: Color = Color.WHITE) -> void:
	if art == null:
		return
	canvas.draw_texture_rect(art, Rect2(pos.floor(), art.get_size() * float(maxi(1, scale))),
		false, tint)


static func face_id(level: int, outline: bool = false) -> String:
	var tail: String = "_o" if outline else ""
	if level < -5 or level > 5:
		return "face_unselected" + tail
	if level == 0:
		return "face_0" + tail
	if level < 0:
		return "face_m%d%s" % [-level, tail]
	return "face_p%d%s" % [level, tail]


static func mood_level(mood: int) -> int:
	return MOOD_LEVELS[clampi(mood, 0, MOOD_LEVELS.size() - 1)]


static func sigil_id(tradition: String) -> String:
	var id: String = "sigil_" + tradition.to_lower()
	return id if has(id) else ""


static func clear_cache() -> void:
	_tex_cache.clear()
	_window_cache.clear()
	_bake_cache.clear()
	_solid_cache.clear()
	_tint_cache.clear()
	_outline_cache.clear()
	_star_cache.clear()
	_atlas_image = null


static func _star_step(fill: float) -> float:
	if fill >= 0.75:
		return 1.0
	return 0.5 if fill >= 0.25 else 0.0


static func _tinted(img: Image, tint: Color) -> Image:
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			img.set_pixel(x, y, Color(px.r * tint.r, px.g * tint.g, px.b * tint.b, px.a))
	return img


static func _star_gradient() -> Gradient:
	if _gradient == null:
		var made := Gradient.new()
		var offsets := PackedFloat32Array()
		var colors := PackedColorArray()
		for i: int in STAR_STOPS.size():
			offsets.append(float(i) / float(STAR_STOPS.size() - 1))
			colors.append(STAR_STOPS[i])
		made.offsets = offsets
		made.colors = colors
		_gradient = made
	return _gradient


static func _rgba(img: Image) -> Image:
	var out: Image = Image.create_empty(img.get_width(), img.get_height(), false,
		Image.FORMAT_RGBA8)
	out.copy_from(img)
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	return out


static func _unknown(id: String) -> void:
	push_error("Icons: unknown id %s" % id)
