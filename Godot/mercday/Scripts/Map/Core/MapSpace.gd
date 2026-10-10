@tool
class_name MapSpace extends RefCounted
#Unit conversions between image px, map px, blocks, chunks, level codes, world space and lat/lon.
#World is Vector3(map x, height, map y) with 1 world unit per map px.

#River and lake tops sit this far over the sea plane (0.0144 world units) so the depth test never ties them.
#Kept above the 16-bit position quantum of a chunk (0.0024) and under the 0.0001 wet_top wall cut in BakeTerrainSides.
const WATER_TOP_LIFT: float = 0.00009

static func img_to_map(p: Vector2) -> Vector2:
	return p - Vector2(MapConst.PAD_L, MapConst.PAD_T)


static func map_to_img(p: Vector2) -> Vector2:
	return p + Vector2(MapConst.PAD_L, MapConst.PAD_T)


static func img_to_block(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / MapConst.BLOCK_PX), floori(p.y / MapConst.BLOCK_PX))


static func block_to_chunk(b: Vector2i) -> Vector2i:
	return Vector2i(floori(float(b.x) / MapConst.CHUNK_BLOCKS), floori(float(b.y) / MapConst.CHUNK_BLOCKS))


#Image px rect of chunk c, clipped to the source image (the last row and column are partial).
static func chunk_rect_img(c: Vector2i) -> Rect2i:
	var r: Rect2i = Rect2i(c * MapConst.CHUNK_PX, Vector2i(MapConst.CHUNK_PX, MapConst.CHUNK_PX))
	return r.intersection(Rect2i(0, 0, MapConst.IMG_W, MapConst.IMG_H))


static func level_height(level: int) -> float:
	if (level & MapConst.POND_BIT) != 0:
		return level_height(level & 127) - MapConst.POND * MapConst.TERRACE
	if level == MapConst.LEVEL_SEA:
		return MapConst.SEA_BED
	if level == MapConst.LEVEL_WATER:
		return MapConst.WATER_H + WATER_TOP_LIFT
	if level == MapConst.LEVEL_RIVER_FLOOR:
		return float(MapConst.RIVER_FLOOR_TERRACES) * MapConst.TERRACE
	if level == MapConst.LEVEL_SHORE:
		return MapConst.WATER_H + MapConst.TERRACE
	return float(level + MapConst.LEVEL_TERRACE_OFFSET) * MapConst.TERRACE


#Inverse of level_height for a resolved block top (0..1); a top below the water line is sea bed.
static func height_to_level(h: float) -> int:
	var eps: float = 0.25 * MapConst.TERRACE
	if h < MapConst.WATER_H - eps:
		return MapConst.LEVEL_SEA
	if h < MapConst.WATER_H + eps:
		return MapConst.LEVEL_WATER
	if h < MapConst.WATER_H + MapConst.TERRACE - eps:
		return MapConst.LEVEL_RIVER_FLOOR
	if h < MapConst.WATER_H + MapConst.TERRACE + eps:
		return MapConst.LEVEL_SHORE
	var level: int = roundi(h / MapConst.TERRACE) - MapConst.LEVEL_TERRACE_OFFSET
	return clampi(level, MapConst.LEVEL_SHORE + 1, 255)


static func level_to_y(level: int) -> float:
	return height_to_y(level_height(level))


static func height_to_y(h: float) -> float:
	return h * MapConst.HEIGHT_SCALE


static func world_to_img(w: Vector3) -> Vector2:
	return map_to_img(Vector2(w.x, w.z) / MapConst.WORLD_PER_PX)


static func img_to_world(p: Vector2, y: float) -> Vector3:
	var m: Vector2 = img_to_map(p) * MapConst.WORLD_PER_PX
	return Vector3(m.x, y, m.y)


#Returns Vector2(lat, lon) in degrees, + is north and east (DATA.md section 3).
static func map_to_latlon(p: Vector2) -> Vector2:
	var lat0: float = deg_to_rad(MapConst.LAT0_DEG)
	var planet_km: float = MapConst.PLAY_W / (MapConst.PLANET_FRACTION * cos(lat0))
	var km_per_deg: float = planet_km / 360.0
	var lat: float = clampf(MapConst.LAT0_DEG - (p.y - MapConst.PLAY_H * 0.5) / km_per_deg, -90.0, 90.0)
	var cos_lat: float = maxf(cos(deg_to_rad(lat)), 0.000001)
	var lon: float = MapConst.LON0_DEG + (p.x - MapConst.PLAY_W * 0.5) / (km_per_deg * cos_lat)
	return Vector2(lat, lon)


#Chunks overlapping the image px rect r, clipped to the chunk grid.
static func chunks_in_rect(r: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo: Vector2i = Vector2i(floori(r.position.x / MapConst.CHUNK_PX), floori(r.position.y / MapConst.CHUNK_PX))
	var hi: Vector2i = Vector2i(floori(r.end.x / MapConst.CHUNK_PX), floori(r.end.y / MapConst.CHUNK_PX))
	lo = lo.clamp(Vector2i.ZERO, Vector2i(MapConst.CHUNKS_X - 1, MapConst.CHUNKS_Y - 1))
	hi = hi.clamp(Vector2i.ZERO, Vector2i(MapConst.CHUNKS_X - 1, MapConst.CHUNKS_Y - 1))
	if r.end.x < 0.0 or r.end.y < 0.0 or r.position.x >= MapConst.IMG_W or r.position.y >= MapConst.IMG_H:
		return out
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			out.append(Vector2i(cx, cy))
	return out
