@tool
class_name BakeTerrainGreedy extends MapBakeStep

#Greedy-merges block tops per chunk into quads keyed by (level, nation byte, water); sea bed blocks get none.
#terrain_tops: Vector2i chunk -> PackedInt32Array of x, y, w, h, key in blocks; key = level | nation << 8 | WATER_FLAG.

const STAGE := 1
const STRIDE := 5
#Set in a top key over a river or lake block.
const WATER_FLAG := 1 << 16


func _init() -> void:
	step_name = &"BakeTerrainGreedy"
	stage = STAGE
	inputs = PackedStringArray(["block_level", "block_nation"])
	optional = PackedStringArray(["river_mask", "pond_mask"])
	outputs = PackedStringArray(["terrain_tops"])
	run_last = true


func run(ctx: MapBakeContext) -> bool:
	var level: Image = ctx.get_image("block_level")
	var nation: Image = ctx.get_image("block_nation")
	if level == null or nation == null:
		return ctx.fail("terrain tops need block_level and block_nation")
	if level.get_size() != nation.get_size():
		return ctx.fail("block_level and block_nation sizes differ")
	var river: Image = ctx.get_image("river_mask")
	if river != null and river.get_size() != level.get_size():
		ctx.log("river_mask size differs from block_level; river tops get no water flag")
		river = null
	var pond: Image = ctx.get_image("pond_mask")
	if pond != null and pond.get_size() != level.get_size():
		return ctx.fail("pond_mask and block_level sizes differ")
	var job: Callable = func(c: Vector2i) -> PackedInt32Array:
		return merge_chunk(level, nation, c, river, pond)
	var tops: Dictionary = per_chunk(level, job)
	var quads: int = 0
	var blocks: int = 0
	var levels: Dictionary = {}
	for c: Vector2i in tops:
		var q: PackedInt32Array = tops[c]
		for i: int in range(0, q.size(), STRIDE):
			quads += 1
			blocks += q[i + 2] * q[i + 3]
			levels[q[i + 4] & 0xff] = true
	ctx.put_value("terrain_tops", tops)
	var census: Variant = ctx.get_value(MapBakeManifest.CENSUS_KEY)
	var counts: Dictionary = census if census is Dictionary else {}
	counts["blocks_total"] = level.get_width() * level.get_height()
	counts["blocks_top"] = blocks
	counts["top_quads"] = quads
	counts["levels"] = levels.size()
	ctx.put_value(MapBakeManifest.CENSUS_KEY, counts)
	ctx.log("terrain tops: %d quads over %d blocks in %d chunks" % [quads, blocks, tops.size()])
	return true


#river may be null; then no top carries WATER_FLAG. A pond block keys as its level | POND_BIT.
static func merge_chunk(level: Image, nation: Image, c: Vector2i, river: Image = null, pond: Image = null) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var rect: Rect2i = chunk_rect(level, c)
	if not rect.has_area():
		return out
	var lv: PackedByteArray = chunk_bytes(level, rect)
	var nb: PackedByteArray = chunk_bytes(nation, rect)
	if pond != null:
		var pb: PackedByteArray = chunk_bytes(pond, rect)
		for i: int in lv.size():
			lv[i] |= MapConst.POND_BIT if pb[i] != 0 else 0
	var keys: PackedInt32Array = _keys(lv, nb, chunk_bytes(river, rect) if river != null else PackedByteArray())
	var solid: PackedByteArray = top_levels()
	var w: int = rect.size.x
	var h: int = rect.size.y
	var done: PackedByteArray = PackedByteArray()
	done.resize(w * h)
	done.fill(0)
	for y: int in h:
		var x: int = 0
		while x < w:
			var i: int = y * w + x
			if done[i] != 0 or solid[lv[i] & 127] == 0:
				x += 1
				continue
			var key: int = keys[i]
			var rw: int = 1
			while x + rw < w and done[i + rw] == 0 and keys[i + rw] == key:
				rw += 1
			var rh: int = 1
			while y + rh < h and _row_matches(keys, done, (y + rh) * w + x, rw, key):
				rh += 1
			for yy: int in rh:
				for xx: int in rw:
					done[(y + yy) * w + x + xx] = 1
			out.append_array(PackedInt32Array([rect.position.x + x, rect.position.y + y, rw, rh, key]))
			x += rw
	return out


#Runs job(chunk) for every chunk of the block grid on the worker pool; keeps the non-empty results by chunk.
static func per_chunk(level: Image, job: Callable) -> Dictionary:
	var chunks: Array[Vector2i] = []
	var grid: Vector2i = Vector2i(ceili(level.get_width() / float(MapConst.CHUNK_BLOCKS)),
		ceili(level.get_height() / float(MapConst.CHUNK_BLOCKS)))
	for cy: int in grid.y:
		for cx: int in grid.x:
			chunks.append(Vector2i(cx, cy))
	var results: Array = []
	results.resize(chunks.size())
	var lock: Mutex = Mutex.new()
	var task_fn: Callable = func(i: int) -> void:
		var r: Variant = job.call(chunks[i])
		lock.lock()
		results[i] = r
		lock.unlock()
	if not chunks.is_empty():
		var task: int = WorkerThreadPool.add_group_task(task_fn, chunks.size(), -1, true, "map_terrain")
		WorkerThreadPool.wait_for_group_task_completion(task)
	var out: Dictionary = {}
	for i: int in chunks.size():
		var arr: PackedInt32Array = results[i]
		if not arr.is_empty():
			out[chunks[i]] = arr
	return out


#Block rect of chunk c clipped to the image; empty past the edge.
static func chunk_rect(img: Image, c: Vector2i) -> Rect2i:
	var r: Rect2i = Rect2i(c * MapConst.CHUNK_BLOCKS, Vector2i(MapConst.CHUNK_BLOCKS, MapConst.CHUNK_BLOCKS))
	return r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))


#One byte per block from the red channel of rect.
static func chunk_bytes(img: Image, rect: Rect2i) -> PackedByteArray:
	var region: Image = img.get_region(rect)
	if region.get_format() != Image.FORMAT_R8 and region.get_format() != Image.FORMAT_L8:
		region.convert(Image.FORMAT_R8)
	return region.get_data()


#1 for each level code whose top sits at or above the water line (river and lake channels included), 0 for sea bed.
static func top_levels() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(256)
	for l: int in 256:
		out[l] = 1 if MapSpace.level_height(l) > MapConst.WATER_H - 0.0001 else 0
	return out


static func _keys(lv: PackedByteArray, nb: PackedByteArray, rv: PackedByteArray) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(lv.size())
	for i: int in lv.size():
		out[i] = lv[i] | (nb[i] << 8) | (WATER_FLAG if not rv.is_empty() and rv[i] != 0 else 0)
	return out


static func _row_matches(keys: PackedInt32Array, done: PackedByteArray, start: int, rw: int, key: int) -> bool:
	for k: int in rw:
		var i: int = start + k
		if done[i] != 0 or keys[i] != key:
			return false
	return true
