@tool
class_name MapWorldBind extends RefCounted
#Binds the map global samplers for MapView and MapWorld; holds the editor save guards.

const NATION_FIELD: String = "nation_field.res"
const PROP_ATLAS: String = "res://Art/Map/Atlases/atlas_map_elements.png"
const PROP_LIGHT: String = "res://Art/Map/Atlases/atlas_map_elements_light.png"
#World units the water plane sits under WATER_H so water-line terrain tops win the depth test.
const WATER_SINK: float = 0.05

static var _nation_field: ImageTexture = null


#Global samplers only, so no scene or material file can embed the baked textures.
static func bind_globals() -> void:
	MapGroupState.texture()
	MapNations.bind_all()
	MapUniforms.bind_texture(&"map_cell_index", MapData.cell_index_texture())
	MapUniforms.bind_texture(&"map_palette", MapPalette.texture())
	_bind_png(&"map_prop_atlas", PROP_ATLAS)
	_bind_png(&"map_prop_light", PROP_LIGHT)
	if _nation_field == null:
		var path: String = MapData.BAKED_DIR + NATION_FIELD
		var field: Image = load(path) as Image if ResourceLoader.exists(path) else null
		if field != null:
			_nation_field = ImageTexture.create_from_image(field)
	if _nation_field != null:
		MapUniforms.bind_texture(&"map_nation_field", _nation_field)
	if MapPalette.is_full():
		var water: ShaderMaterial = load(MapData.WATER_MATERIAL) as ShaderMaterial
		if water != null:
			var sea: Color = MapPalette.color_of(MapPalette.SEA_INDEX)
			water.set_shader_parameter("water_color", Vector4(sea.r, sea.g, sea.b, 1.0))


static func _bind_png(uniform_name: StringName, path: String) -> void:
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if tex == null:
		push_warning("MapWorldBind: missing %s" % path)
		return
	MapUniforms.bind_texture(uniform_name, tex)


#Drops the cached nation field, palette and cell colour so the next bind_globals reads the new bake.
static func reset() -> void:
	_nation_field = null
	MapPalette.reset()
	MapData.reset()


static func water_position() -> Vector3:
	var water_y: float = MapSpace.height_to_y(MapConst.WATER_H) - WATER_SINK
	return MapSpace.img_to_world(Vector2(MapConst.IMG_W, MapConst.IMG_H) * 0.5, water_y)


static func capture(node: Object, props: PackedStringArray) -> Dictionary:
	var saved: Dictionary = {}
	for p: String in props:
		saved[p] = node.get(p)
	return saved


static func restore(node: Object, saved: Dictionary) -> void:
	for p: String in saved.keys():
		node.set(p, saved[p])
