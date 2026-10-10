@tool
class_name PixelAtlasRectView extends Control

#Draws the atlas PNG with its rects; drag moves, corner handles resize, Alt-click splits (Shift = vertical).

signal rect_requested(id: StringName, r: Rect2i)
signal split_requested(id: StringName, at: int, vertical: bool)

const HANDLE: float = 5.0

var _atlas: PixelAtlas
var _zoom: int = 1
var _sel: StringName = &""
var _mode: int = 0
var _anchor: Vector2i
var _start: Vector2i
var _base: Rect2i
var _live: Rect2i


func show_atlas(atlas: PixelAtlas, zoom: int) -> void:
	_atlas = atlas
	_zoom = clampi(zoom, 1, 8)
	_mode = 0
	var sz: Vector2 = Vector2(_atlas.texture.get_size()) if _atlas != null and _atlas.texture != null else Vector2.ZERO
	custom_minimum_size = sz * _zoom
	queue_redraw()


func select(id: StringName) -> void:
	_sel = id
	queue_redraw()


func _img() -> Vector2i:
	if _atlas == null or _atlas.texture == null:
		return Vector2i.ZERO
	return Vector2i(_atlas.texture.get_size())


func _draw() -> void:
	if _atlas == null or _atlas.texture == null:
		return
	draw_texture_rect(_atlas.texture, Rect2(Vector2.ZERO, Vector2(_img() * _zoom)), false)
	for id: StringName in _atlas.entries:
		var r: Rect2i = _live if _mode != 0 and id == _sel else _atlas.rect_of(id)
		var on: bool = id == _sel
		draw_rect(Rect2(Vector2(r.position * _zoom), Vector2(r.size * _zoom)), Color.YELLOW if on else Color(0, 1, 1, 0.5), false)
		if on:
			for c: Vector2i in _corners(r):
				draw_rect(Rect2(Vector2(c * _zoom) - Vector2.ONE * HANDLE, Vector2.ONE * HANDLE * 2.0), Color.YELLOW)


func _corners(r: Rect2i) -> Array[Vector2i]:
	return [r.position, r.position + Vector2i(r.size.x, 0), r.position + Vector2i(0, r.size.y), r.end]


func _gui_input(event: InputEvent) -> void:
	if _atlas == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			_press(mb)
		elif _mode != 0:
			_release()
	elif event is InputEventMouseMotion and _mode != 0:
		_drag((event as InputEventMouseMotion).position)


func _texel(p: Vector2) -> Vector2i:
	return Vector2i((p / float(_zoom)).floor())


func _hit(t: Vector2i) -> StringName:
	if _sel != &"" and _atlas.has_entry(_sel) and _atlas.rect_of(_sel).has_point(t):
		return _sel
	var found: StringName = &""
	for id: StringName in _atlas.entries:
		if _atlas.rect_of(id).has_point(t):
			found = id
	return found


func _press(mb: InputEventMouseButton) -> void:
	var t: Vector2i = _texel(mb.position)
	if _sel != &"" and _atlas.has_entry(_sel) and not mb.alt_pressed:
		var r: Rect2i = _atlas.rect_of(_sel)
		var cs: Array[Vector2i] = _corners(r)
		var reach: float = minf(HANDLE * 1.5, mini(r.size.x, r.size.y) * _zoom / 3.0)
		for i: int in 4:
			if (Vector2(cs[i] * _zoom) - mb.position).length() <= reach:
				_mode = 2
				_anchor = cs[3 - i]
				_base = r
				_live = r
				return
	var id: StringName = _hit(t)
	if id == &"":
		return
	_sel = id
	_base = _atlas.rect_of(id)
	_live = _base
	if mb.alt_pressed:
		var vertical: bool = mb.shift_pressed
		split_requested.emit(id, (t.x - _base.position.x) if vertical else (t.y - _base.position.y), vertical)
		queue_redraw()
		return
	_mode = 1
	_start = t
	queue_redraw()


func _drag(pos: Vector2) -> void:
	var img: Vector2i = _img()
	if _mode == 1:
		var p: Vector2i = _base.position + _texel(pos) - _start
		_live = Rect2i(p.clamp(Vector2i.ZERO, img - _base.size), _base.size)
	else:
		var q: Vector2i = Vector2i((pos / float(_zoom)).round()).clamp(Vector2i.ZERO, img)
		var lo: Vector2i = Vector2i(mini(_anchor.x, q.x), mini(_anchor.y, q.y))
		var hi: Vector2i = Vector2i(maxi(_anchor.x, q.x), maxi(_anchor.y, q.y))
		hi = Vector2i(maxi(hi.x, lo.x + 1), maxi(hi.y, lo.y + 1))
		lo = (hi - Vector2i.ONE).min(lo).min(img - Vector2i.ONE)
		hi = hi.min(img)
		_live = Rect2i(lo, hi - lo)
	queue_redraw()


func _release() -> void:
	_mode = 0
	if _live != _base:
		rect_requested.emit(_sel, _live)
	queue_redraw()
