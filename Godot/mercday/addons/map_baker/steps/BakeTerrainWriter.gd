@tool
class_name BakeTerrainWriter extends MapBakeStep

#Builds one compressed ArrayMesh per non-empty chunk from tops and sides and writes the terrain chunk index.
#CUSTOM0 RGBA8: nation byte, group kind 0, group index 0, face code (top 0; sides dir 1-4 plus bit 3 for water).

const STAGE := 1
const LAYER := &"terrain"
const INDEX_FILE := "index.tres"


func _init() -> void:
	step_name = &"BakeTerrainWriter"
	stage = STAGE
	inputs = PackedStringArray(["terrain_tops", "terrain_sides"])
	outputs = PackedStringArray(["terrain/*", "terrain/index"])
	run_last = true


func run(ctx: MapBakeContext) -> bool:
	var tops_v: Variant = ctx.get_value("terrain_tops")
	var sides_v: Variant = ctx.get_value("terrain_sides")
	if not (tops_v is Dictionary) or not (sides_v is Dictionary):
		return ctx.fail("terrain writer needs terrain_tops and terrain_sides from this run")
	var tops: Dictionary = tops_v
	var sides: Dictionary = sides_v
	var keys: Array[Vector2i] = []
	for c: Vector2i in tops.keys() + sides.keys():
		if not keys.has(c):
			keys.append(c)
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var dir: String = ctx.path_of("terrain/*") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var idx: MapChunkIndex = MapChunkIndex.new()
	idx.layer = LAYER
	var verts: Dictionary = {}
	var max_verts: int = 0
	for c: Vector2i in keys:
		var mesh: ArrayMesh = build_chunk(tops.get(c, PackedInt32Array()), sides.get(c, PackedInt32Array()))
		var n: int = mesh.surface_get_array_len(0) if mesh.get_surface_count() > 0 else 0
		if n == 0:
			continue
		var name: String = "chunk_%02d_%02d" % [c.x, c.y]
		if n > MapConst.TERRAIN_CHUNK_VERTS:
			return ctx.fail("terrain %s has %d verts, cap %d" % [name, n, MapConst.TERRAIN_CHUNK_VERTS])
		var path: String = dir + name + ".res"
		var err: Error = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			return ctx.fail("cannot save %s (error %d)" % [path, err])
		var box: AABB = mesh.get_aabb()
		box.size.y += MapConst.LIFT
		idx.coords.append(Vector2(c))
		idx.paths.append(path)
		idx.aabbs.append(box)
		idx.vert_counts.append(n)
		verts[name] = n
		max_verts = maxi(max_verts, n)
	_remove_stale(dir, verts)
	var err_idx: Error = ResourceSaver.save(idx, dir + INDEX_FILE)
	if err_idx != OK:
		return ctx.fail("cannot save %s (error %d)" % [dir + INDEX_FILE, err_idx])
	var layers_v: Variant = ctx.get_value(MapBakeManifest.VERTS_KEY)
	var layers: Dictionary = layers_v if layers_v is Dictionary else {}
	layers[String(LAYER)] = verts
	ctx.put_value(MapBakeManifest.VERTS_KEY, layers)
	var census_v: Variant = ctx.get_value(MapBakeManifest.CENSUS_KEY)
	var counts: Dictionary = census_v if census_v is Dictionary else {}
	counts["chunks_non_empty"] = idx.coords.size()
	counts["terrain_verts_total"] = idx.total_verts()
	counts["terrain_verts_max"] = max_verts
	ctx.put_value(MapBakeManifest.CENSUS_KEY, counts)
	ctx.log("terrain: %d chunks, %d verts, max %d" % [idx.coords.size(), idx.total_verts(), max_verts])
	return true


#Tops are BakeTerrainGreedy records, sides BakeTerrainSides records; vertices in map px, y from the level code.
static func build_chunk(tops: PackedInt32Array, sides: PackedInt32Array) -> ArrayMesh:
	var pos: PackedVector3Array = PackedVector3Array()
	var tags: PackedByteArray = PackedByteArray()
	for i: int in range(0, tops.size(), BakeTerrainGreedy.STRIDE):
		var x0: float = _map_x(tops[i])
		var z0: float = _map_z(tops[i + 1])
		var x1: float = _map_x(tops[i] + tops[i + 2])
		var z1: float = _map_z(tops[i + 1] + tops[i + 3])
		var y: float = MapSpace.level_to_y(tops[i + 4] & 0xff)
		var n: int = (tops[i + 4] >> 8) & 0xff
		var wb: int = BakeTerrainSides.WATER_BIT if tops[i + 4] & BakeTerrainGreedy.WATER_FLAG else 0
		pos.append_array(PackedVector3Array([Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x0, y, z1),
			Vector3(x1, y, z1)]))
		tags.append_array(PackedByteArray([n, 0, 0, wb, n, 0, 0, wb, n, 0, 0, wb, n, 0, 0, wb]))
	for i: int in range(0, sides.size(), BakeTerrainSides.STRIDE):
		var bx: int = sides[i]
		var by: int = sides[i + 1]
		var span: int = sides[i + 2]
		var yt: float = MapSpace.level_to_y(sides[i + 4])
		var yb: float = MapSpace.level_to_y(sides[i + 5])
		var a: Vector2 = Vector2.ZERO
		var b: Vector2 = Vector2.ZERO
		#a to b runs so that (b - a) x up is the outward normal; Godot front faces wind clockwise.
		match sides[i + 3]:
			1:
				a = Vector2(_map_x(bx), _map_z(by + 1))
				b = Vector2(_map_x(bx + span), a.y)
			4:
				a = Vector2(_map_x(bx + span), _map_z(by))
				b = Vector2(_map_x(bx), a.y)
			3:
				a = Vector2(_map_x(bx + 1), _map_z(by + span))
				b = Vector2(a.x, _map_z(by))
			_:
				a = Vector2(_map_x(bx), _map_z(by))
				b = Vector2(a.x, _map_z(by + span))
		var face: int = sides[i + 6]
		var nt: int = sides[i + 7] & 0xff
		var nl: int = (sides[i + 7] >> 8) & 0xff
		pos.append_array(PackedVector3Array([Vector3(a.x, yt, a.y), Vector3(b.x, yt, b.y), Vector3(a.x, yb, a.y),
			Vector3(b.x, yb, b.y)]))
		tags.append_array(PackedByteArray([nt, 0, 0, face, nt, 0, 0, face, nl, 0, 0, face, nl, 0, 0, face]))
	var mesh: ArrayMesh = ArrayMesh.new()
	if pos.is_empty():
		return mesh
	var index: PackedInt32Array = PackedInt32Array()
	for base: int in range(0, pos.size(), 4):
		index.append_array(PackedInt32Array([base, base + 1, base + 2, base + 2, base + 1, base + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_CUSTOM0] = tags
	arrays[Mesh.ARRAY_INDEX] = index
	var flags: int = (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return mesh


static func _map_x(block_x: int) -> float:
	return float(block_x * MapConst.BLOCK_PX - MapConst.PAD_L)


static func _map_z(block_y: int) -> float:
	return float(block_y * MapConst.BLOCK_PX - MapConst.PAD_T)


#Deletes chunk files left from an earlier bake whose chunk is now empty.
static func _remove_stale(dir: String, kept: Dictionary) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if file.begins_with("chunk_") and file.get_extension() == "res" and not kept.has(file.get_basename()):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + file))
