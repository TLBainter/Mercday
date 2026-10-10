class_name ButtonFxRig extends Node

#The animation runtime one BevelButton owns as an internal child. The click, hover and stay layers
#are composed onto the button each frame while any of them moves or holds, and at rest the button
#gets its own position and modulate back. _draw reads the colour blends from here.

var host: BevelButton = null
var _click: ButtonFx.Layer = ButtonFx.Layer.new()
var _hover: ButtonFx.Layer = ButtonFx.Layer.new()
var _stay: ButtonFx.Layer = ButtonFx.Layer.new()
var _layers: Array[ButtonFx.Layer] = [_hover, _stay, _click]
var _base_pos: Vector2 = Vector2.ZERO
var _wrote_pos: Vector2 = Vector2.ZERO
var _base_mod: Color = Color.WHITE
var _wrote_mod: Color = Color.WHITE
var _base_z: int = 0
var _wrote_z: int = 0


func _ready() -> void:
	set_process(false)


func click(move: int, shade: int) -> void:
	_click.kill()
	_click.reset()
	_click.move = _tween(ButtonFx.click_move, _click, move)
	_click.shade = _tween(ButtonFx.click_shade, _click, shade)
	_wake()


func hover_in(move: int, shade: int, stay_move: int, stay_shade: int) -> void:
	for layer: ButtonFx.Layer in [_hover, _stay]:
		layer.kill()
		layer.reset()
	_hover.move = _tween(ButtonFx.hover_move, _hover, move)
	_hover.shade = _tween(ButtonFx.hover_shade, _hover, shade)
	_stay.move = _tween(ButtonFx.stay_move, _stay, stay_move)
	_stay.shade = _tween(ButtonFx.stay_shade, _stay, stay_shade)
	_wake()


#The hover and the stay layer ease back to rest; a click still playing runs out.
func hover_out() -> void:
	for layer: ButtonFx.Layer in [_hover, _stay]:
		layer.kill()
		if not layer.is_identity():
			layer.move = create_tween()
			ButtonFx.release(layer.move, layer)
	_wake()


func stop() -> void:
	for layer: ButtonFx.Layer in _layers:
		layer.kill()
		layer.reset()
	_restore()


func busy() -> bool:
	for layer: ButtonFx.Layer in _layers:
		if layer.running() or not layer.is_identity():
			return true
	return false


#Where the button sits at rest, in the space of its parent.
func rest_rect() -> Rect2:
	return Rect2(_base_pos, host.size)


func body(color: Color) -> Color:
	for layer: ButtonFx.Layer in _layers:
		color = color.lerp(layer.body_to, layer.body_mix)
	return color


#The light and the dark band of the bevel: invert swaps them, edge_mix pulls both toward EDGE_TO.
func edges(hi: Color, lo: Color) -> PackedColorArray:
	for layer: ButtonFx.Layer in _layers:
		var top: Color = hi.lerp(lo, layer.invert).lerp(ButtonFx.EDGE_TO, layer.edge_mix)
		lo = lo.lerp(hi, layer.invert).lerp(ButtonFx.EDGE_TO, layer.edge_mix)
		hi = top
	return PackedColorArray([hi, lo])


func label(color: Color) -> Color:
	for layer: ButtonFx.Layer in _layers:
		color = color.lerp(ButtonFx.LABEL_TO, layer.label_mix)
	return color


func ring() -> Color:
	var alpha: float = 0.0
	for layer: ButtonFx.Layer in _layers:
		alpha = maxf(alpha, layer.ring_alpha)
	return GuiColors.CLEAR if alpha <= 0.0 else Color(ButtonFx.RING_TO, alpha)


#A tween only when there is an animation to put in it.
func _tween(builder: Callable, layer: ButtonFx.Layer, which: int) -> Tween:
	if which <= 0:
		return null
	var tween: Tween = create_tween()
	builder.call(tween, layer, which)
	return tween


func _process(_delta: float) -> void:
	_rebase()
	if host.fx_blocked() or not host.is_visible_in_tree():
		stop()
		return
	var grow: Vector2 = Vector2.ONE
	var turn: float = 0.0
	var shift: Vector2 = Vector2.ZERO
	var whole: float = 1.0
	var alpha: float = 1.0
	for layer: ButtonFx.Layer in _layers:
		grow *= layer.scale
		turn += layer.angle
		shift += layer.offset
		whole *= layer.whole
		alpha *= layer.alpha
	host.pivot_offset = host.size / 2.0
	host.scale = grow
	host.rotation_degrees = turn
	host.position = _base_pos + shift
	#The moving button draws above its siblings, so no flush neighbour painted later covers part of it.
	host.z_index = _base_z + 1 if grow != Vector2.ONE or turn != 0.0 or shift != Vector2.ZERO else _base_z
	_wrote_z = host.z_index
	host.modulate = Color(_base_mod.r * whole, _base_mod.g * whole, _base_mod.b * whole, _base_mod.a * alpha)
	_wrote_pos = host.position
	_wrote_mod = host.modulate
	host.queue_redraw()
	if not busy():
		_restore()


#A container that sorted the button again, or a caller that wrote its modulate or z_index, moves the base.
func _rebase() -> void:
	if host.position != _wrote_pos:
		_base_pos = host.position
	if host.z_index != _wrote_z:
		_base_z = host.z_index
	var now: Color = host.modulate
	if now != _wrote_mod:
		_base_mod = Color(_pick(now.r, _wrote_mod.r, _base_mod.r), _pick(now.g, _wrote_mod.g, _base_mod.g),
			_pick(now.b, _wrote_mod.b, _base_mod.b), _pick(now.a, _wrote_mod.a, _base_mod.a))


#A channel still holding what the rig wrote keeps its base; a channel the caller changed is the new base.
static func _pick(now: float, wrote: float, base: float) -> float:
	return base if now == wrote else now


func _wake() -> void:
	if is_processing():
		return
	_base_pos = host.position
	_wrote_pos = _base_pos
	_base_mod = host.modulate
	_wrote_mod = _base_mod
	_base_z = host.z_index
	_wrote_z = _base_z
	set_process(true)


func _restore() -> void:
	if not is_processing():
		return
	_rebase()
	set_process(false)
	host.z_index = _base_z
	host.scale = Vector2.ONE
	host.rotation_degrees = 0.0
	host.position = _base_pos
	host.modulate = _base_mod
	host.queue_redraw()
