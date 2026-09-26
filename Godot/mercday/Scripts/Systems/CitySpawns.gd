class_name CitySpawns

#City spawns: two opposite map sides, one disc zone per team, plus the upper windows a ranged
#merc may hold. Runs before CityAccess.build, so it reads only the pure helpers of CityAccess.

const MAX_TRIES := 8
const SNAP_RADIUS := 6
const MIN_OUTDOOR := 8
const DIRS4: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


#Picks both centres and zones, writes them on area and fills area.city["spawn"].
static func build(area: BattlefieldArea, ctx: GenerationContext) -> void:
	if area == null:
		return
	var team: int = 4
	if ctx != null:
		team = maxi(ctx.team_size_a, ctx.team_size_b)
	area.spawn_radius = maxf(3.0, float(team))
	area.spawn_radius = maxf(area.spawn_radius, sqrt(float(area.width * area.length)) / 12.0)
	var side_a: int = randi() % 4
	var side_b: int = side_a ^ 1
	var ground: PackedByteArray = CityAccess.flood(area, CityAccess.main_start(area), false)
	var pick_a: Dictionary = _pick_side(area, side_a, ground, team)
	var pick_b: Dictionary = _pick_side(area, side_b, ground, team)
	area.spawn_center_a = pick_a["center"] as Vector2i
	area.spawn_center_b = pick_b["center"] as Vector2i
	area.spawn_zone_a = pick_a["zone"] as Dictionary
	area.spawn_zone_b = pick_b["zone"] as Dictionary
	area.spawn_floor_a = 0
	area.spawn_floor_b = 0
	var built_a: Array[int] = open_buildings(area, 0)
	var built_b: Array[int] = open_buildings(area, 1)
	area.city["spawn"] = {
		"side_a": side_a,
		"side_b": side_b,
		"buildings_a": built_a,
		"buildings_b": built_b,
		"outdoor_a": int(pick_a["outdoor"]),
		"outdoor_b": int(pick_b["outdoor"]),
		"tries": int(pick_a["tries"]) + int(pick_b["tries"]),
	}
	area.generation_log.append("[CITY] spawn: A side=%d (%d,%d) outdoor=%d buildings=%d; B side=%d (%d,%d) outdoor=%d buildings=%d" % [
		side_a, area.spawn_center_a.x, area.spawn_center_a.y, int(pick_a["outdoor"]), built_a.size(),
		side_b, area.spawn_center_b.x, area.spawn_center_b.y, int(pick_b["outdoor"]), built_b.size()])


#The zone cells of a team that lie on open outdoor ground; the on-foot placement stays inside it.
static func outdoor_zone(area: BattlefieldArea, team: int) -> Dictionary:
	var out: Dictionary = {}
	if area == null:
		return out
	for key: Variant in _zone_of(area, team).keys():
		var cell: Vector2i = key as Vector2i
		if CityAccess.is_ground(area, cell):
			out[cell] = true
	return out


#Sorted ids of every building with at least one cell inside the team's zone.
static func open_buildings(area: BattlefieldArea, team: int) -> Array[int]:
	var out: Array[int] = []
	if area == null:
		return out
	var seen: Dictionary = {}
	for key: Variant in _zone_of(area, team).keys():
		var id: int = int(area.building_id_at.get(key as Vector2i, -1))
		if id >= 0:
			seen[id] = true
	for sid: Variant in seen.keys():
		out.append(sid as int)
	out.sort()
	return out


#Upper-floor cells behind a window that faces the enemy side, best first; no RNG.
static func window_posts(area: BattlefieldArea, team: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if area == null:
		return out
	var enemy: Vector2i = area.spawn_center_a if team == 1 else area.spawn_center_b
	var rows: Array[Array] = []
	for id: int in open_buildings(area, team):
		if id < 0 or id >= area.buildings.size():
			continue
		var rec: Dictionary = area.buildings[id]
		var rect: Rect2i = rec.get("rect", Rect2i())
		for fl: int in (rec.get("floors", []) as Array):
			if fl < 1:
				continue
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					var win := Vector2i(x, y)
					if String(area.get_obs(win, fl).get("cell_type", "")) != "window":
						continue
					var inside := _inside_cell(area, id, win, fl)
					if inside.x < 0:
						continue
					var outward := win - inside
					var facing: int = outward.x * (enemy.x - win.x) + outward.y * (enemy.y - win.y)
					if facing <= 0:
						continue
					rows.append([fl, facing, inside.y, inside.x])
	rows.sort_custom(_post_before)
	var seen: Dictionary = {}
	for row: Array in rows:
		var post := Vector3i(row[3] as int, row[2] as int, row[0] as int)
		if seen.has(post):
			continue
		seen[post] = true
		out.append(post)
	return out


#Open roof footing on a building in the team's zone, highest and nearest the enemy first; no RNG.
static func roof_posts(area: BattlefieldArea, team: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if area == null or area.roof_cells.is_empty():
		return out
	var enemy: Vector2i = area.spawn_center_a if team == 1 else area.spawn_center_b
	var rows: Array[Array] = []
	for id: int in open_buildings(area, team):
		if id < 0 or id >= area.buildings.size():
			continue
		var rect: Rect2i = (area.buildings[id] as Dictionary).get("rect", Rect2i())
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				var rl: int = area.roof_level_at(cell)
				if rl < 1 or not area.is_roof_footing(cell, rl):
					continue
				if int(area.roof_cells.get(Vector3i(x, y, rl), RoofBuilder.SOLID)) == RoofBuilder.SOLID:
					continue
				if not area.get_obs(cell, rl).is_empty():
					continue
				var near: int = -maxi(absi(enemy.x - x), absi(enemy.y - y))
				rows.append([rl, near, y, x])
	rows.sort_custom(_post_before)
	for row: Array in rows:
		out.append(Vector3i(row[3] as int, row[2] as int, row[0] as int))
	return out


#Post row [floor, facing, y, x]: the highest floor first, then the squarest facing, then y then x.
static func _post_before(a: Array, b: Array) -> bool:
	for i: int in range(2):
		if (a[i] as int) != (b[i] as int):
			return (a[i] as int) > (b[i] as int)
	for j: int in range(2, 4):
		if (a[j] as int) != (b[j] as int):
			return (a[j] as int) < (b[j] as int)
	return false


#Up to MAX_TRIES side centres snapped to ground; the first with enough outdoor cells, else the widest.
static func _pick_side(area: BattlefieldArea, side: int, ground: PackedByteArray, team: int) -> Dictionary:
	var need: int = maxi(2 * team, MIN_OUTDOOR)
	var best: Dictionary = {}
	var tries: int = 0
	for attempt: int in range(MAX_TRIES):
		tries = attempt + 1
		var center: Vector2i = _snap(area, area.pick_side_center(side), ground)
		if center.x < 0:
			continue
		var zone: Dictionary = area.build_spawn_zone(center)
		var outdoor: int = 0
		for key: Variant in zone.keys():
			if _on_ground(area, ground, key as Vector2i):
				outdoor += 1
		if best.is_empty() or outdoor > int(best["outdoor"]):
			best = {"center": center, "zone": zone, "outdoor": outdoor}
		if outdoor >= need:
			break
	if best.is_empty():
		var raw: Vector2i = area.pick_side_center(side)
		best = {"center": raw, "zone": area.build_spawn_zone(raw), "outdoor": 0}
	best["tries"] = tries
	return best


#Nearest ground cell by Chebyshev ring, cells in y then x order; (-1,-1) when none is within SNAP_RADIUS.
static func _snap(area: BattlefieldArea, from: Vector2i, ground: PackedByteArray) -> Vector2i:
	for r: int in range(SNAP_RADIUS + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cell := Vector2i(from.x + dx, from.y + dy)
				if _on_ground(area, ground, cell):
					return cell
	return Vector2i(-1, -1)


static func _on_ground(area: BattlefieldArea, ground: PackedByteArray, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= area.width or cell.y < 0 or cell.y >= area.length:
		return false
	var idx: int = cell.y * area.width + cell.x
	if idx >= ground.size():
		return false
	return ground[idx] == 1


static func _zone_of(area: BattlefieldArea, team: int) -> Dictionary:
	return area.spawn_zone_b if team == 1 else area.spawn_zone_a


#The 4-neighbour of a window that the same building owns on that floor and nothing blocks.
static func _inside_cell(area: BattlefieldArea, id: int, win: Vector2i, fl: int) -> Vector2i:
	for d: Vector2i in DIRS4:
		var nb := Vector2i(win.x + d.x, win.y + d.y)
		if nb.x < 0 or nb.x >= area.width or nb.y < 0 or nb.y >= area.length:
			continue
		if int(area.building_id_at.get(nb, -1)) != id:
			continue
		if not area.footprint_cells.has(Vector3i(nb.x, nb.y, fl)):
			continue
		if not area.building_interiors.has(Vector3i(nb.x, nb.y, fl)):
			continue
		if area.is_stair_cell(nb, fl):
			return Vector2i(-1, -1)
		if area.is_obstacle(nb, fl):
			continue
		return nb
	return Vector2i(-1, -1)
