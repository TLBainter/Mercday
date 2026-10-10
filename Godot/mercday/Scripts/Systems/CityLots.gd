class_name CityLots

#Fills the lots of a city map: one generated building per lot, the rest of the lot ground turned to nature.
#Runs after the layout is validated, so every lot already names the building rows that fit it.

const SETBACK := 2
const FRONT_SLACK := 1
const GAP := 2
const NO_SPOT := Vector2i(-1, -1)


#One building per lot in lot id order; a lot that takes none is marked failed and keeps no building cell.
static func build(area: BattlefieldArea) -> void:
	var t0: int = Time.get_ticks_msec()
	var lots: Array = area.city["lots"]
	var tally: Array[int] = [0]
	var placed: int = 0
	var failed: int = 0
	for entry: Variant in lots:
		var lot: Dictionary = entry as Dictionary
		var candidates: Array = (lot.get("rows", []) as Array).duplicate()
		var tried: Array[String] = []
		lot["tried"] = tried
		var won: bool = false
		while not candidates.is_empty():
			var at: int = randi() % candidates.size()
			var row_name: String = String(candidates[at])
			candidates.remove_at(at)
			tried.append(row_name)
			if _try_row(area, lot, row_name, tally):
				won = true
				break
		if won:
			placed += 1
			continue
		lot["failed"] = true
		lot["building"] = -1
		failed += 1
	_paint_ground(area, lots)
	area.generation_log.append("[CITY] lots: %d placed, %d failed, %d scratch builds, %d ms"
		% [placed, failed, tally[0], Time.get_ticks_msec() - t0])


#One row tried on one lot; tally[0] counts the scratch maps built. True when the building reached the map.
static func _try_row(area: BattlefieldArea, lot: Dictionary, row_name: String, tally: Array[int]) -> bool:
	var row: Dictionary = DataManager.get_area_by_name(row_name)
	if row.is_empty():
		return false
	var rect: Rect2i = lot.get("rect", Rect2i())
	var front: String = String(lot.get("front", ""))
	var site: Dictionary = {"max_w": rect.size.x - 2 * SETBACK, "max_d": rect.size.y - 2 * SETBACK}
	var scratch: BattlefieldArea = BuildingStamp.build_scratch(row, front, 0, site)
	tally[0] += 1
	var at: Vector2i = _spot(area, scratch, rect, front)
	if at.x < 0:
		site["no_wings"] = true
		site["no_ext_rooms"] = true
		scratch = BuildingStamp.build_scratch(row, front, 0, site)
		tally[0] += 1
		at = _spot(area, scratch, rect, front)
		if at.x < 0:
			return false
	var id: int = BuildingStamp.place(area, scratch, BuildingStamp.offset_for(scratch, at))
	if id < 0:
		return false
	lot["building"] = id
	return true


#The used rect of a scratch building that fits its lot with the setbacks; an empty rect when it does not.
static func _fit(scratch: BattlefieldArea, lot: Rect2i, front: String) -> Rect2i:
	if scratch == null:
		return Rect2i()
	if not (scratch.building_plan.get("issues", []) as Array).is_empty():
		return Rect2i()
	var ur: Rect2i = BuildingStamp.used_rect(scratch)
	if ur.size.x <= 0 or ur.size.y <= 0:
		return Rect2i()
	var use: Vector2i = CityGrid.front_span(ur.size, front)
	var span: Vector2i = CityGrid.front_span(lot.size, front)
	if use.x > span.x - 2 or use.y > span.y - 1:
		return Rect2i()
	return ur


#Map cell the top left corner of the used rect takes, or NO_SPOT. Frontage offsets that face street ground
#alone are tried first; the first offset and front setback that keep the gap to every placed building win.
static func _spot(area: BattlefieldArea, scratch: BattlefieldArea, lot: Rect2i, front: String) -> Vector2i:
	var ur: Rect2i = _fit(scratch, lot, front)
	if ur.size.x <= 0:
		return NO_SPOT
	var f_use: int = CityGrid.front_span(ur.size, front).x
	var d_use: int = CityGrid.front_span(ur.size, front).y
	var f_lot: int = CityGrid.front_span(lot.size, front).x
	var d_lot: int = CityGrid.front_span(lot.size, front).y
	var clear: Array[int] = []
	var rest: Array[int] = []
	for o: int in range(1, f_lot - f_use):
		if _street_front(area, lot, front, o, f_use):
			clear.append(o)
		else:
			rest.append(o)
	clear.shuffle()
	rest.shuffle()
	var slack: int = mini(FRONT_SLACK, d_lot - 1 - d_use)
	var first: int = randi_range(0, slack)
	for off: int in clear + rest:
		for k: int in range(slack + 1):
			var at: Vector2i = _corner(lot, front, off, (first + k) % (slack + 1), d_use)
			if _gap_free(area, Rect2i(at, ur.size), lot):
				return at
	return NO_SPOT


static func _corner(lot: Rect2i, front: String, off: int, s: int, d_use: int) -> Vector2i:
	match front:
		"N":
			return Vector2i(lot.position.x + off, lot.position.y + s)
		"S":
			return Vector2i(lot.position.x + off, lot.end.y - s - d_use)
		"W":
			return Vector2i(lot.position.x + s, lot.position.y + off)
	return Vector2i(lot.end.x - s - d_use, lot.position.y + off)


#True when no placed building owns a cell within GAP cells of the rect. The lot itself holds no other building.
static func _gap_free(area: BattlefieldArea, r: Rect2i, lot: Rect2i) -> bool:
	var g: Rect2i = r.grow(GAP)
	for y: int in range(maxi(g.position.y, 0), mini(g.end.y, area.length)):
		for x: int in range(maxi(g.position.x, 0), mini(g.end.x, area.width)):
			var c := Vector2i(x, y)
			if lot.has_point(c):
				continue
			if area.building_id_at.has(c):
				return false
	return true


#True when the cells just outside the front edge hold street ground over the span; cells off the map count.
static func _street_front(area: BattlefieldArea, lot: Rect2i, front: String, start: int, count: int) -> bool:
	for i: int in range(start, start + count):
		var c := Vector2i(lot.position.x + i, lot.position.y - 1)
		match front:
			"S":
				c = Vector2i(lot.position.x + i, lot.end.y)
			"W":
				c = Vector2i(lot.position.x - 1, lot.position.y + i)
			"E":
				c = Vector2i(lot.end.x, lot.position.y + i)
		if not area.in_bounds_xy(c.x, c.y):
			continue
		if not CityGrid.is_street(CityGrid.surf(area, c.x, c.y)):
			return false
	return true


#Lot ground after the pass: a cell a building owns keeps SURF_LOT, every other lot cell becomes nature.
static func _paint_ground(area: BattlefieldArea, lots: Array) -> void:
	for entry: Variant in lots:
		var r: Rect2i = (entry as Dictionary).get("rect", Rect2i())
		for y: int in range(maxi(r.position.y, 0), mini(r.end.y, area.length)):
			var row: int = y * area.width
			for x: int in range(maxi(r.position.x, 0), mini(r.end.x, area.width)):
				if area.building_id_at.has(Vector2i(x, y)):
					continue
				area.surface_grid[row + x] = BattlefieldArea.SURF_NATURE
