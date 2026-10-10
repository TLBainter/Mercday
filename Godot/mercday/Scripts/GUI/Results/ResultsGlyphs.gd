class_name ResultsGlyphs

#The textures and the portrait filter of the results panel. The fate overlays are atlas cuts baked
#at OVERLAY_SCALE. Only the portrait materials are cached here; Icons caches the art.

const OVERLAY_SCALE: int = 3

const FILTER_CODE: String = """shader_type canvas_item;
uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform float bright : hint_range(0.0, 2.0) = 1.0;
void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(lum), clamp(gray, 0.0, 1.0)) * bright;
}
"""

static var _cache: Dictionary = {}
static var _shader: Shader = null


#11 x 13 art, so 33 x 39 at the x3 the portrait box carries.
static func skull(scale: int = OVERLAY_SCALE) -> Texture2D:
	return Icons.baked("skull", scale, Icons.MODE_PLAIN, true)


#The full cell, so 48 x 48 at x3, which covers the whole portrait.
static func bars(scale: int = OVERLAY_SCALE) -> Texture2D:
	return Icons.baked("bars", scale, Icons.MODE_PLAIN, false)


#14 x 14 art, so 42 x 42 at the x3 the portrait box carries.
static func bandit(scale: int = OVERLAY_SCALE) -> Texture2D:
	return Icons.baked("bandit", scale, Icons.MODE_PLAIN, true)


#12 x 16 art, so 36 x 48 at the x3 the portrait box carries.
static func missing(scale: int = OVERLAY_SCALE) -> Texture2D:
	return Icons.baked("missing", scale, Icons.MODE_PLAIN, true)


static func overlay_for(fate: int, scale: int = OVERLAY_SCALE) -> Texture2D:
	if fate == ResultMemberData.Fate.DEAD:
		return skull(scale)
	if fate == ResultMemberData.Fate.DEFECTED:
		return bandit(scale)
	if fate == ResultMemberData.Fate.DEPARTED:
		return missing(scale)
	if fate == ResultMemberData.Fate.CAPTURED:
		return bars(scale)
	return null


#One material per rounded gray and brightness pair, so a whole roster shares a few of them.
static func portrait_material(gray: float, brightness: float) -> ShaderMaterial:
	var g: float = clampf(gray, 0.0, 1.0)
	var b: float = clampf(brightness, 0.0, 2.0)
	var key: String = "mat:%.2f:%.2f" % [g, b]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = _filter_shader()
		mat.set_shader_parameter("gray", g)
		mat.set_shader_parameter("bright", b)
		_cache[key] = mat
	var out: ShaderMaterial = _cache[key] as ShaderMaterial
	out.set_shader_parameter("gray", g)
	out.set_shader_parameter("bright", b)
	return out


static func _filter_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FILTER_CODE
	return _shader
