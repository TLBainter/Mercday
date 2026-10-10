@tool
class_name MapGroupState extends RefCounted

#Group state image: one row per kind, one column per id, RGBA8 channels highlight, lift, dim, select.
#Changed values mark the image dirty; flush uploads it with one texture update.

enum Kind { NATION, SETTLEMENT, TEMPLE, POI, VEHICLE, ROUTE }

const COLS: int = 256
const ROWS: int = 8
const CH_HIGHLIGHT: int = 0
const CH_LIFT: int = 1
const CH_DIM: int = 2
const CH_SELECT: int = 3

static var _image: Image = null
static var _texture: ImageTexture = null
static var _dirty: bool = false
#Called once each time the image turns dirty; MapView sets it to turn its flush on.
static var _dirty_hook: Callable = Callable()


static func texture() -> ImageTexture:
	if _texture == null:
		_image = Image.create_empty(COLS, ROWS, false, Image.FORMAT_RGBA8)
		_texture = ImageTexture.create_from_image(_image)
		MapUniforms.bind_texture(&"map_group_state", _texture)
	return _texture


static func set_channel(kind: int, id: int, ch: int, v: float) -> void:
	if not _valid(kind, id, ch):
		return
	texture()
	var c: Color = _image.get_pixel(id, kind)
	var q: float = roundf(clampf(v, 0.0, 1.0) * 255.0) / 255.0
	if is_equal_approx(c[ch], q):
		return
	c[ch] = q
	_image.set_pixel(id, kind, c)
	if not _dirty and _dirty_hook.is_valid():
		_dirty_hook.call()
	_dirty = true


static func set_dirty_hook(hook: Callable) -> void:
	_dirty_hook = hook


static func get_channel(kind: int, id: int, ch: int) -> float:
	if not _valid(kind, id, ch) or _image == null:
		return 0.0
	return _image.get_pixel(id, kind)[ch]


static func flush() -> void:
	if not _dirty or _texture == null:
		return
	_texture.update(_image)
	_dirty = false


static func _valid(kind: int, id: int, ch: int) -> bool:
	return kind >= 0 and kind < ROWS and id >= 0 and id < COLS and ch >= 0 and ch < 4
