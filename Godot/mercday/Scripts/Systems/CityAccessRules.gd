class_name CityAccessRules

#Validator rules 4 and 6 of a city block map: every door reachable from both spawns, and no
#blocking object cutting ground off or sitting on a cell it may not hold.

#Every cell a blocking city object covers, anchors and reserved cells alike.
static func _blocking_cells(area: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	for obs: Dictionary in area.obstacles:
		if not obs.has("city"):
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.passthrough or d.ramp:
			continue
		var pos: Vector3i = obs.get("pos", Vector3i.ZERO)
		for dy: int in range(int(obs.get("ph", 1))):
			for dx: int in range(int(obs.get("pw", 1))):
				out[Vector2i(pos.x + dx, pos.y + dy)] = true
	return out


#Validator rules 4 (both spawns reach every door) and 6 (objects cut nothing off and sit legally).
static func check(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	if area == null or not area.city.has("access"):
		out.append("no access model")
		return out
	var access: Dictionary = area.city["access"]
	var open_mask: PackedByteArray = CityAccess.pass_mask(area, true)
	var reach_a: PackedByteArray = CityAccess.spread(area, area.spawn_center_a, open_mask)
	var reach_b: PackedByteArray = CityAccess.spread(area, area.spawn_center_b, open_mask)
	var hits: int = 0
	for entry: Dictionary in (access.get("doors", []) as Array):
		var o: Vector2i = entry.get("outside", Vector2i(-1, -1))
		var i: int = -1
		if area.in_bounds_xy(o.x, o.y):
			i = o.y * area.width + o.x
		var id: int = int(entry.get("building", -1))
		var kind: String = String(entry.get("kind", ""))
		if i < 0 or reach_a[i] == 0:
			hits = CityValidator._hit(out, hits, "door of building %d (%s) not reachable from spawn a" % [id, kind])
		if i < 0 or reach_b[i] == 0:
			hits = CityValidator._hit(out, hits, "door of building %d (%s) not reachable from spawn b" % [id, kind])
	var blocked: Dictionary = _blocking_cells(area)
	_check_cut(area, access, open_mask, blocked, out)
	_check_legal(area, access, blocked, out)
	return out


static func _check_cut(area: BattlefieldArea, access: Dictionary, open_mask: PackedByteArray,
		blocked: Dictionary, out: Array[String]) -> void:
	var reach0: PackedByteArray = access.get("reach0", PackedByteArray())
	var after: PackedByteArray = CityAccess.spread(area, CityAccess.main_start(area), open_mask)
	if reach0.size() != after.size():
		out.append("no reach0 mask")
		return
	var hits: int = 0
	for y: int in range(area.length):
		var row: int = y * area.width
		for x: int in range(area.width):
			var i: int = row + x
			if reach0[i] == 0 or after[i] == 1:
				continue
			if blocked.has(Vector2i(x, y)):
				continue
			hits = CityValidator._hit(out, hits, "ground %d,%d cut off by objects" % [x, y])


static func _check_legal(area: BattlefieldArea, access: Dictionary, blocked: Dictionary,
		out: Array[String]) -> void:
	var protected: Dictionary = access.get("protected", {})
	var hits: int = 0
	for ck: Variant in blocked.keys():
		var c: Vector2i = ck as Vector2i
		var why: String = ""
		if protected.has(c):
			why = "a protected cell"
		elif area.spawn_zone_a.has(c) or area.spawn_zone_b.has(c):
			why = "a spawn zone"
		elif CityGrid.is_carriage(CityGrid.surf(area, c.x, c.y)):
			why = "a carriageway"
		elif CityAccess.narrow_gap(area, c):
			why = "a narrow gap"
		if why != "":
			hits = CityValidator._hit(out, hits, "blocking object at %d,%d on %s" % [c.x, c.y, why])
