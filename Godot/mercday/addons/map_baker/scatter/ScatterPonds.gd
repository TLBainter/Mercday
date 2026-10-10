@tool
class_name ScatterPonds extends RefCounted

#Pond and mud pit carve over a ScatterGrid (C19; MC:982-993).

const CS: int = 8
const KEY_MUD: int = 1
const KEY_DEFAULT: int = 2
const KEY_WET0: int = 4
const KEY_MAX: int = 126
const LILY_DZ: float = 2.1

var counts: Dictionary = {"wet": 0, "mud": 0, "reeds": 0, "lilies": 0, "overflow": 0}
var water_rgb: Dictionary = {}
var _grid: ScatterGrid
var _cw: int = 0
var _wc: PackedInt32Array = PackedInt32Array()
var _keys: Dictionary = {}


func setup(grid: ScatterGrid, water_code: PackedByteArray, water_rgb_in: Dictionary) -> void:
	_grid = grid
	water_rgb = water_rgb_in
	_keys = {}
	_cw = ceili(float(grid.w) / float(CS))
	var cn: int = _cw * ceili(float(grid.h) / float(CS))
	_wc = PackedInt32Array()
	_wc.resize(cn)
	_wc.fill(-1)
	if water_code.size() < grid.w * grid.h:
		return
	var q: PackedInt32Array = PackedInt32Array()
	for i: int in cn:
		var px: int = mini(grid.w - 1, (i % _cw) * CS + 4)
		var pz: int = mini(grid.h - 1, floori(float(i) / float(_cw)) * CS + 4)
		var c: int = water_code[pz * grid.w + px]
		if c != 255:
			_wc[i] = c
			q.append(i)
	var head: int = 0
	while head < q.size():
		var j: int = q[head]
		head += 1
		var v: int = _wc[j]
		var cx: int = j % _cw
		var nbs: PackedInt32Array = PackedInt32Array()
		if cx > 0:
			nbs.append(j - 1)
		if cx < _cw - 1:
			nbs.append(j + 1)
		if j >= _cw:
			nbs.append(j - _cw)
		if j + _cw < cn:
			nbs.append(j + _cw)
		for n: int in nbs:
			if _wc[n] < 0:
				_wc[n] = v
				q.append(n)


func carve(x: int, z: int, wet: bool, zi: int) -> bool:
	var g: ScatterGrid = _grid
	var rr0: float = 3.0 + MapRng.hh(x + 1, z + 2) * 5.0
	var e: float = 0.8 + MapRng.hh(x + 4, z + 9) * 0.4
	var p1: float = MapRng.hh(x, z + 3) * 6.28
	var p2: float = MapRng.hh(x + 3, z) * 6.28
	var l0: int = g.lvl[g.j_at(x, z)]
	var cx: int = x >> 1
	var cz: int = z >> 1
	var rc: int = ceili(rr0 * 1.4 / 2.0) + 2
	var cells: PackedInt32Array = PackedInt32Array()
	for dz: int in range(-rc, rc + 1):
		for dx: int in range(-rc, rc + 1):
			var xx: int = cx + dx
			var zz: int = cz + dz
			if xx < 1 or zz < 1 or xx >= g.rw - 1 or zz >= g.rh - 1:
				return false
			var j: int = zz * g.rw + xx
			var ox: float = float(dx) * 2.0 / e
			var oz: float = float(dz) * 2.0 * e
			var r: float = sqrt(ox * ox + oz * oz)
			var a: float = atan2(oz, ox)
			var rr: float = rr0 * (1.0 + 0.16 * sin(3.0 * a + p1) + 0.09 * sin(5.0 * a + p2))
			if r <= rr + 3.0 and (g.lvl[j] != l0 or g.dry0[j] == 0):
				return false
			if r <= rr:
				if not g.free_at(j):
					return false
				cells.append(j)
	if cells.size() < 4:
		return false
	var key: int = KEY_MUD
	if wet:
		var wc: int = _wc[(z >> 3) * _cw + (x >> 3)]
		key = KEY_DEFAULT if wc < 0 else KEY_WET0 + wc
		if key > KEY_MAX:
			key = KEY_MUD
			counts["overflow"] = int(counts["overflow"]) + 1
	_commit(cells, key)
	var t: float = MapConst.TERRACE
	var surf: float = maxf(MapConst.WATER_H + t, MapSpace.level_height(l0)) - MapConst.POND * t
	if wet:
		counts["wet"] = int(counts["wet"]) + 1
		var nl: int = 1 + floori(MapRng.hh(x + 8, z + 1) * 3.0)
		for k: int in nl:
			var lj: int = cells[floori(MapRng.hh(x + k * 13, z + 5) * float(cells.size()))]
			var lx: float = float((lj % g.rw) * 2 + 1)
			var lz: float = float(floori(float(lj) / float(g.rw)) * 2 + 1) + LILY_DZ
			g.place(&"w_lily", lx, surf + 0.01 * t, lz, zi)
			counts["lilies"] = int(counts["lilies"]) + 1
	else:
		counts["mud"] = int(counts["mud"]) + 1
	var nh: float = MapRng.hh(x + 2, z + 8)
	var nr: int = 4 + floori(nh * 5.0) if wet else 2 + floori(nh * 2.0)
	for k: int in nr:
		var ra: float = MapRng.hh(x + k * 7, z + k * 3) * 6.283
		var d: float = rr0 * 1.05 + 1.5 + MapRng.hh(x + k, z - k) * 3.0
		var rx: int = int(MapRng.jround(float(x) + cos(ra) * d / e))
		var rz: int = int(MapRng.jround(float(z) + sin(ra) * d * e))
		if g.prop(&"f_reeds", rx, rz, zi):
			counts["reeds"] = int(counts["reeds"]) + 1
	return true


#Takes the layers out of the grid while writing so the packed arrays are not copied per cell.
func _commit(cells: PackedInt32Array, key: int) -> void:
	var pd: PackedByteArray = _grid.pond
	var oc: PackedByteArray = _grid.occ
	_grid.pond = PackedByteArray()
	_grid.occ = PackedByteArray()
	for j: int in cells:
		pd[j] = key
		oc[j] = 3
	_grid.pond = pd
	_grid.occ = oc
	_keys[key] = true


func mask_image() -> Image:
	return Image.create_from_data(_grid.rw, _grid.rh, false, Image.FORMAT_R8, _grid.pond)


func keys() -> Array[int]:
	var out: Array[int] = []
	for k: int in _keys:
		out.append(k)
	out.sort()
	return out
