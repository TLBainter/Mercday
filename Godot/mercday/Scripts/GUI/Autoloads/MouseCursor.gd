extends CanvasLayer

#The software pointer: hides the OS cursor and draws the cursor sheet cut that fits the control under
#the pointer, above every embedded window. A shader blends the blue cut over the orange one wherever
#the backdrop pixel is warm, so the pointer stays readable on orange art. Warm patches thinner than
#3 canvas pixels in x or y (grid lines, outlines) are ignored by a 3x3 opening of the warmth map.

const LAYER := 1025
const ARROW := "arrow"
const HAND := "hand"
const PRESS := "press"
const GRAB := "grab"
const IBEAM := "ibeam"

const SHADER_CODE: String = """shader_type canvas_item;
uniform sampler2D blue_tex : filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float canvas_scale = 1.0;
uniform float hue_center = 30.0;
uniform float hue_full = 22.0;
uniform float hue_zero = 35.0;
uniform float sat_lo = 0.45;
uniform float sat_hi = 0.65;
uniform float val_lo = 0.45;
uniform float val_hi = 0.65;

float warmth(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	if (mx <= 0.0 || d <= 0.0) {
		return 0.0;
	}
	float hue;
	if (mx == c.r) {
		hue = 60.0 * mod((c.g - c.b) / d, 6.0);
	} else if (mx == c.g) {
		hue = 60.0 * ((c.b - c.r) / d + 2.0);
	} else {
		hue = 60.0 * ((c.r - c.g) / d + 4.0);
	}
	hue = mod(hue, 360.0);
	float dist = abs(hue - hue_center);
	dist = min(dist, 360.0 - dist);
	return (1.0 - smoothstep(hue_full, hue_zero, dist)) * smoothstep(sat_lo, sat_hi, d / mx)
		* smoothstep(val_lo, val_hi, mx);
}

float warm_at(vec2 uv) {
	return warmth(texture(screen_tex, uv).rgb);
}

float warm_span(vec2 uv, vec2 px) {
	float w[25];
	for (int y = 0; y < 5; y++) {
		for (int x = 0; x < 5; x++) {
			w[y * 5 + x] = warm_at(uv + vec2(float(x - 2), float(y - 2)) * px);
		}
	}
	float best = 0.0;
	for (int oy = 0; oy < 3; oy++) {
		for (int ox = 0; ox < 3; ox++) {
			float low = 1.0;
			for (int ky = 0; ky < 3; ky++) {
				for (int kx = 0; kx < 3; kx++) {
					low = min(low, w[(oy + ky) * 5 + ox + kx]);
				}
			}
			best = max(best, low);
		}
	}
	return best;
}

void fragment() {
	vec4 o = texture(TEXTURE, UV);
	vec4 b = texture(blue_tex, UV);
	COLOR = mix(o, b, warm_span(SCREEN_UV, SCREEN_PIXEL_SIZE * canvas_scale));
}
"""

var state: String = ARROW
var enabled: bool = false

var _sprite: Sprite2D
var _material: ShaderMaterial
var _windows: Array[Window] = []


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.material = _material
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_fit_scale)
	CaretGlyph.watch(get_tree())
	_fit_scale()
	_apply(ARROW)


func _process(_delta: float) -> void:
	var root: Window = get_tree().root
	var mouse: Vector2 = root.get_mouse_position()
	var hovered: Control = _hovered(root, mouse)
	var local: Vector2 = mouse
	if hovered != null and hovered.get_window() != root:
		local = mouse - Vector2(hovered.get_window().position)
	var next: String = pick(shape_at(hovered, local),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), root.gui_is_dragging())
	if next != state:
		_apply(next)
	_sprite.position = (mouse - Vector2(CursorSheet.hotspot(state))).floor()


func _notification(what: int) -> void:
	if not enabled:
		return
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_sprite.hide()
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_sprite.show()


func _on_node_added(node: Node) -> void:
	if node is Window:
		var win: Window = node as Window
		_windows.append(win)
		win.tree_exiting.connect(_forget.bind(win), CONNECT_ONE_SHOT)


func _forget(win: Window) -> void:
	_windows.erase(win)


#One canvas pixel in screen pixels, so the span test counts canvas pixels at any window size.
func _fit_scale() -> void:
	_material.set_shader_parameter("canvas_scale", get_tree().root.get_final_transform().get_scale().x)


func _hovered(root: Window, mouse: Vector2) -> Control:
	for i: int in range(_windows.size() - 1, -1, -1):
		var win: Window = _windows[i]
		if win.visible and win.is_embedded() and Rect2(win.position, win.size).has_point(mouse):
			return win.gui_get_hovered_control()
	return root.gui_get_hovered_control()


#The shape the engine would show: the hovered control, then its pass-through parents.
static func shape_at(hovered: Control, mouse: Vector2) -> int:
	var c: Control = hovered
	while c != null:
		var local: Vector2 = c.get_global_transform_with_canvas().affine_inverse() * mouse
		var shape: int = c.get_cursor_shape(local)
		if shape != Control.CURSOR_ARROW:
			return shape
		if c is BaseButton:
			return Control.CURSOR_FORBIDDEN if (c as BaseButton).disabled else Control.CURSOR_POINTING_HAND
		if c.mouse_filter == Control.MOUSE_FILTER_STOP or c.top_level:
			break
		c = c.get_parent() as Control
	return Control.CURSOR_ARROW


static func pick(shape: int, pressed: bool, dragging: bool) -> String:
	if dragging or shape == Control.CURSOR_DRAG:
		return GRAB
	if shape == Control.CURSOR_IBEAM:
		return IBEAM
	if shape == Control.CURSOR_POINTING_HAND:
		return PRESS if pressed else HAND
	return ARROW


func _apply(id: String) -> void:
	state = id
	_sprite.texture = CursorSheet.orange(id)
	_material.set_shader_parameter("blue_tex", CursorSheet.blue(id))
