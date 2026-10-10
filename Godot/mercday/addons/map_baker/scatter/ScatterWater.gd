@tool
class_name ScatterWater extends RefCounted

#Water, river rock and bank passes (C12 steps 4-6, MC:1023-1037) plus the ice mountain claim (MC:947-951).
#rtop takes river cells only; hgt already holds river blocks one terrace down (E35).

var grid: ScatterGrid
var counts: Dictionary = {"ice_mountain": 0, "water": 0, "river": 0}
var _wc: PackedByteArray = PackedByteArray()
var _sh: Dictionary = {}
var _rf: Dictionary = {}
var _ic: Dictionary = {}
var _vi: Dictionary = {}


func setup(scatter_grid: ScatterGrid, water_code: PackedByteArray) -> void:
	grid = scatter_grid
	_wc = water_code
	counts = {"ice_mountain": 0, "water": 0, "river": 0}
	var ws: Dictionary = grid.rules.get("water", {})
	var res: Array = [ScatterGrid.regex_of(ws.get("shallow")), RegEx.create_from_string("(?i)reef"),
		ScatterGrid.regex_of(ws.get("icy")), ScatterGrid.regex_of(ws.get("violet"))]
	var sets: Array[Dictionary] = [{}, {}, {}, {}]
	for row: Variant in grid.rules.get("water_palette", []):
		var cname: String = String((row as Dictionary).get("name", ""))
		for i: int in 4:
			if res[i] != null and (res[i] as RegEx).search(cname) != null:
				sets[i][int((row as Dictionary)["cls"])] = true
	_sh = sets[0]
	_rf = sets[1]
	_ic = sets[2]
	_vi = sets[3]


func is_riv(j: int) -> bool:
	return (grid.river[j] & BakeHeightRivers.MASK_RIVER) != 0


func sea_w(j: int) -> bool:
	return grid.lvl[j] <= MapConst.LEVEL_WATER and not is_riv(j)


func rtop(j: int) -> float:
	return maxf(MapConst.WATER_H, grid.hgt[j])


func lvl0(j: int) -> int:
	return int(MapRng.jround(grid.hgt[j] / MapConst.TERRACE))


#Centred footprint (no spread test); every cell in bounds, ok_c(j), occ clear and, with local, not a rail gap.
func claim(k: Dictionary, x: float, z: float, ok_c: Callable, local: bool) -> PackedInt32Array:
	var r: Vector4i = ScatterGrid.span(k, x, z)
	var cells: PackedInt32Array = PackedInt32Array()
	for zz: int in range(r.y, r.w + 1):
		for xx: int in range(r.x, r.z + 1):
			if xx < 0 or zz < 0 or xx >= grid.rw or zz >= grid.rh:
				return PackedInt32Array()
			var j: int = zz * grid.rw + xx
			if not bool(ok_c.call(j)) or grid.occ[j] != 0 or (local and grid.rail[j] == 2):
				return PackedInt32Array()
			cells.append(j)
	return cells


func wprop(id: StringName, x: int, z: int, gy: float, ok_c: Callable) -> bool:
	var k: Dictionary = grid.kit_of(id)
	if k.is_empty():
		grid.counts["missing_kit"] = int(grid.counts.get("missing_kit", 0)) + 1
		return false
	var cells: PackedInt32Array = claim(k, x, z, ok_c, true)
	if cells.is_empty():
		return false
	grid.mark(cells, 3)
	var fd: float = float(k["D"]) * ScatterGrid.K
	grid.place(id, x, gy, float(z) - fd / 2.0 + fd, -1)
	return true


func ice_mountain() -> int:
	var im: Dictionary = grid.rules.get("ice", {})
	var kits: Array = im.get("kits", [])
	var c: Array = im.get("c", [0, 0])
	var t: float = MapConst.TERRACE
	var n: int = 0
	for i: int in (int(im.get("n", 0)) if not kits.is_empty() else 0):
		var a: float = MapRng.hh(i, 4401) * 6.283
		var rr: float = float(im.get("r", 0)) * sqrt(MapRng.hh(i, 4402)) * (0.35 + 0.65 * MapRng.hh(i, 4403))
		var id: StringName = StringName(String(MapRng.pick(kits, MapRng.hh(i, 4404))))
		var x: float = MapRng.jround(float(c[0]) + cos(a) * rr)
		var z: float = MapRng.jround(float(c[1]) + sin(a) * rr)
		var k: Dictionary = grid.kit_of(id)
		var cells: PackedInt32Array = PackedInt32Array() if k.is_empty() else claim(k, x, z, _ice_ok, false)
		if cells.is_empty():
			continue
		var gmin: float = 1e9
		for j: int in cells:
			gmin = minf(gmin, grid.hgt[j])
		grid.mark(cells, 3)
		var fd: float = float(k["D"]) * ScatterGrid.K
		grid.place(id, x, maxf(MapConst.WATER_H + t, MapRng.jround(gmin / t) * t), z - fd / 2.0 + fd, -1)
		n += 1
	counts["ice_mountain"] = n
	return n


func _ice_ok(j: int) -> bool:
	return grid.dry0[j] != 0 and grid.paint[j] == 0


func water() -> int:
	var ws: Dictionary = grid.rules.get("water", {})
	var gy: float = MapConst.WATER_H - 0.08 * MapConst.TERRACE
	var n: int = 0
	if _wc.size() < grid.w * grid.h:
		return 0
	for z: int in range(5, grid.h - 5, 10):
		for x: int in range(5, grid.w - 5, 10):
			var jx: int = x + floori(MapRng.hh(x + 3, z) * 7) - 3
			var jz: int = z + floori(MapRng.hh(x, z + 5) * 7) - 3
			if not sea_w(grid.j_at(jx, jz)):
				continue
			var code: int = _wc[jz * grid.w + jx]
			var c: int = code >> 2
			if code == 255 or not _sh.has(c):
				continue
			if MapRng.hh(jx * 7 + 3, jz * 3 + 1) > float(ws.get("dReef" if _rf.has(c) else "d", 0.0)):
				continue
			var kits: Array = ws.get("kIcy" if _ic.has(c) else ("kViolet" if _vi.has(c) else "k"), [])
			if kits.is_empty():
				continue
			var id: StringName = StringName(String(MapRng.pick(kits, MapRng.hh(jx + 5, jz + 9))))
			if wprop(id, jx, jz, gy, sea_w):
				n += 1
	counts["water"] = n
	return n


#River rocks (drop, mouth) then bank and wall props; one counter as the JS nr.
func river() -> int:
	var rv: Dictionary = grid.rules.get("river", {})
	var kits: Array = rv.get("kits", [])
	var t: float = MapConst.TERRACE
	var rw: int = grid.rw
	var n: int = 0
	if kits.is_empty():
		return 0
	for cz: int in range(2, grid.rh - 2):
		for cx: int in range(2, rw - 2):
			var j: int = cz * rw + cx
			if not is_riv(j):
				continue
			var r0: float = MapRng.jround(rtop(j) / t)
			var p: float = 0.0
			for nb: int in [j - 1, j + 1, j - rw, j + rw]:
				if is_riv(nb) and MapRng.jround(rtop(nb) / t) < r0:
					p = maxf(p, float(rv.get("drop", 0.0)))
			if p == 0.0 and _near_sea(j):
				p = float(rv.get("mouth", 0.0))
			if p > 0.0 and MapRng.hh(cx * 5 + 1, cz * 7 + 3) < p:
				var id: StringName = StringName(String(MapRng.pick(kits, MapRng.hh(cx, cz + 3))))
				if wprop(id, cx * 2 + 1, cz * 2 + 1, rtop(j) - 0.08 * t, is_riv):
					n += 1
	for cz: int in range(1, grid.rh - 1):
		for cx: int in range(1, rw - 1):
			var j: int = cz * rw + cx
			if grid.dry0[j] == 0 or is_riv(j):
				continue
			var nb: int = -1
			for q: int in [j - 1, j + 1, j - rw, j + rw]:
				if is_riv(q):
					nb = q
					break
			if nb < 0:
				continue
			var wall: bool = float(lvl0(j)) - MapRng.jround(rtop(nb) / t) >= 2.0
			var p: float = float(rv.get("wall" if wall else "bank", 0.0))
			if MapRng.hh(cx * 3 + 7, cz * 5 + 1) < p:
				if grid.prop(StringName(String(MapRng.pick(kits, MapRng.hh(cx + 1, cz)))), cx * 2 + 1, cz * 2 + 1):
					n += 1
	counts["river"] = n
	return n


func _near_sea(j: int) -> bool:
	for dz: int in range(-2, 3):
		for dx: int in range(-2, 3):
			if sea_w(j + dz * grid.rw + dx):
				return true
	return false
