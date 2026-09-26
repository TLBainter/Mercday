class_name InteriorTests

#Tavern interiors: wings, per-floor masks, the outside wall, windows, wing doors and reachability.
#Run: godot --headless --path . -- --interior-tests

const SEEDS := 8
const SEED_BASE := 41
const WING_MIN := 1
const WING_MAX := 3
const TAVERN := "Tavern"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var fields := _seeded_fields()
	_case_wings(res, fields)
	_case_masks(res, fields)
	_case_boundary(res, fields)
	_case_windows(res, fields)
	_case_wing_doors(res, fields)
	_case_reach(res, fields)
	_case_drops(res, fields)
	randomize()
	return TestFixtures.summarize(res, "INTERIOR")


static func _seeded(seed_i: int) -> BattlefieldArea:
	seed(seed_i)
	var ctx := GenerationContext.new()
	var area_data: Dictionary = DataManager.get_area_by_name(TAVERN)
	return BattlefieldArea.generate_random(null, ctx, String(area_data.get("type", "Interior")), area_data)


static func _seeded_fields() -> Array[BattlefieldArea]:
	var out: Array[BattlefieldArea] = []
	for s: int in range(SEEDS):
		out.append(_seeded(SEED_BASE + s))
	return out


#Main block rect of an interior map, walls inclusive; no wing passes its side walls.
static func main_rect(field: BattlefieldArea) -> Rect2i:
	var fpr: Rect2i = field.building_footprint
	return Rect2i(fpr.position.x, field.interior_top_y, fpr.size.x, field.interior_floor_depth + 2)


#Floor 0 mask cells outside the main block, grouped into one entry per wing.
static func wing_parts(field: BattlefieldArea) -> Array[Dictionary]:
	var rect: Rect2i = main_rect(field)
	var outside: Dictionary = {}
	for key: Variant in field.footprint_cells.keys():
		var c: Vector3i = key as Vector3i
		if c.z != 0:
			continue
		var p := Vector2i(c.x, c.y)
		if not rect.has_point(p):
			outside[p] = true
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for key2: Variant in outside.keys():
		var start: Vector2i = key2 as Vector2i
		if seen.has(start):
			continue
		seen[start] = true
		var queue: Array[Vector2i] = []
		queue.append(start)
		var lo: Vector2i = start
		var hi: Vector2i = start
		var n: int = 0
		while not queue.is_empty():
			var p2: Vector2i = queue.pop_back()
			n += 1
			lo.x = mini(lo.x, p2.x)
			lo.y = mini(lo.y, p2.y)
			hi.x = maxi(hi.x, p2.x)
			hi.y = maxi(hi.y, p2.y)
			for d: Vector2i in InteriorGenerator.DIRS4:
				var nb := Vector2i(p2.x + d.x, p2.y + d.y)
				if seen.has(nb) or not outside.has(nb):
					continue
				seen[nb] = true
				queue.append(nb)
		out.append({"side": "n" if hi.y < field.interior_top_y else "s",
			"x0": lo.x, "x1": hi.x, "y0": lo.y, "y1": hi.y, "cells": n})
	return out


static func wing_count(field: BattlefieldArea) -> int:
	return wing_parts(field).size()


static func _case_wings(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var bad_count: int = 0
	var no_growth: int = 0
	var past_side: int = 0
	for f: BattlefieldArea in fields:
		var wings: Array[Dictionary] = wing_parts(f)
		if wings.size() < WING_MIN or wings.size() > WING_MAX:
			bad_count += 1
		var rect: Rect2i = main_rect(f)
		if _mask_size(f, 0) <= rect.size.x * rect.size.y:
			no_growth += 1
		for w: Dictionary in wings:
			if int(w["x0"]) < rect.position.x or int(w["x1"]) > rect.end.x - 1:
				past_side += 1
	TestFixtures.check(res, "every tavern carries one to three wings", bad_count == 0,
		"%d field(s) outside %d to %d" % [bad_count, WING_MIN, WING_MAX])
	TestFixtures.check(res, "the floor 0 mask grows past the main block", no_growth == 0,
		"%d field(s) without" % no_growth)
	TestFixtures.check(res, "no wing passes the main block side walls", past_side == 0,
		"%d wing(s) outside" % past_side)


static func _case_masks(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var above_differs: int = 0
	var below_differs: int = 0
	for f: BattlefieldArea in fields:
		var top: Dictionary = _mask_of(f, 0)
		var rect: Rect2i = main_rect(f)
		for fl: int in _floor_nums(f):
			var mask: Dictionary = _mask_of(f, fl)
			if fl >= 0:
				if not _masks_equal(mask, top):
					above_differs += 1
				continue
			if mask.size() != rect.size.x * rect.size.y:
				below_differs += 1
				continue
			for key: Variant in mask.keys():
				if not rect.has_point(key as Vector2i):
					below_differs += 1
					break
	TestFixtures.check(res, "every floor above ground shares one mask", above_differs == 0,
		"%d floor(s) apart" % above_differs)
	TestFixtures.check(res, "every basement floor is the main block", below_differs == 0,
		"%d floor(s) apart" % below_differs)


#Union boundary cells carry the outside of the building: wall, window, door or fence.
static func _case_boundary(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var open_edge: int = 0
	var stray_door: int = 0
	for f: BattlefieldArea in fields:
		for fl: int in _floor_nums(f):
			for key: Variant in f.footprint_cells.keys():
				var c: Vector3i = key as Vector3i
				if c.z != fl or not _on_union_edge(f, Vector2i(c.x, c.y)):
					continue
				var ct: String = String((f._obs_map.get(c, {}) as Dictionary).get("cell_type", ""))
				if ct != "wall" and ct != "window" and ct != "door" and ct != "fence":
					open_edge += 1
				elif ct == "door" and not _door_leads_out(f, c):
					stray_door += 1
	TestFixtures.check(res, "the outside wall is closed", open_edge == 0,
		"%d open edge cell(s)" % open_edge)
	TestFixtures.check(res, "outside doors open on the street or an exterior room", stray_door == 0,
		"%d stray door(s)" % stray_door)


static func _case_windows(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var inside: int = 0
	var total: int = 0
	for f: BattlefieldArea in fields:
		for obs: Dictionary in f.obstacles:
			if String(obs.get("cell_type", "")) != "window":
				continue
			total += 1
			var p: Vector3i = obs["pos"] as Vector3i
			if not f.footprint_cells.has(p) or not _on_union_edge(f, Vector2i(p.x, p.y)):
				inside += 1
	TestFixtures.check(res, "windows sit on the outside wall", inside == 0,
		"%d of %d window(s) inside" % [inside, total])
	TestFixtures.check(res, "taverns carry windows", total > 0, "%d window(s)" % total)


static func _case_wing_doors(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var shut: int = 0
	var checked: int = 0
	for f: BattlefieldArea in fields:
		var bot_y: int = f.interior_top_y + f.interior_floor_depth + 1
		for w: Dictionary in wing_parts(f):
			var row: int = f.interior_top_y if String(w["side"]) == "n" else bot_y
			for fl: int in _floor_nums(f):
				if fl < 0:
					continue
				checked += 1
				if not _row_has_door(f, row, int(w["x0"]), int(w["x1"]), fl):
					shut += 1
	TestFixtures.check(res, "every wing opens on the main block", shut == 0,
		"%d of %d shared wall(s) shut" % [shut, checked])


static func _case_reach(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var no_entrance: int = 0
	var cut_off: int = 0
	for f: BattlefieldArea in fields:
		var start: Vector3i = _west_entrance(f)
		if start.x < 0:
			no_entrance += 1
			continue
		var dist: Dictionary = DungeonGenerator._walk_dist(f, start, true)
		for key: Variant in f.footprint_cells.keys():
			var c: Vector3i = key as Vector3i
			if DungeonGenerator._passable(f, c, true) and not dist.has(c):
				cut_off += 1
	TestFixtures.check(res, "every tavern has a west entrance", no_entrance == 0,
		"%d field(s) without" % no_entrance)
	TestFixtures.check(res, "every open cell reaches the entrance", cut_off == 0,
		"%d orphan cell(s)" % cut_off)


static func _case_drops(res: Dictionary, fields: Array[BattlefieldArea]) -> void:
	var missing: int = 0
	var with_balcony: int = 0
	for f: BattlefieldArea in fields:
		var has_balcony: bool = false
		for entry: Dictionary in f.interior_rooms:
			if int(entry.get("floor", 0)) < 1:
				continue
			if String(entry.get("name", "")).to_lower().contains("balcony"):
				has_balcony = true
		if not has_balcony:
			continue
		with_balcony += 1
		if f.drop_links.is_empty():
			missing += 1
	TestFixtures.check(res, "a balcony carries a drop link", missing == 0,
		"%d of %d field(s) without" % [missing, with_balcony])


static func _floor_nums(field: BattlefieldArea) -> Array[int]:
	var out: Array[int] = []
	for k: Variant in field.interior_floor_elevations.keys():
		out.append(k as int)
	out.sort()
	out.reverse()
	return out


static func _mask_of(field: BattlefieldArea, f: int) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in field.footprint_cells.keys():
		var c: Vector3i = key as Vector3i
		if c.z == f:
			out[Vector2i(c.x, c.y)] = true
	return out


static func _mask_size(field: BattlefieldArea, f: int) -> int:
	var n: int = 0
	for key: Variant in field.footprint_cells.keys():
		if (key as Vector3i).z == f:
			n += 1
	return n


static func _masks_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a.keys():
		if not b.has(key):
			return false
	return true


static func _on_union_edge(field: BattlefieldArea, p: Vector2i) -> bool:
	if not field.footprint_union.has(p):
		return false
	for d: Vector2i in InteriorGenerator.DIRS4:
		if not field.footprint_union.has(Vector2i(p.x + d.x, p.y + d.y)):
			return true
	return false


#An outside door faces the street or a patio cell, never a sealed pocket of the map.
static func _door_leads_out(field: BattlefieldArea, c: Vector3i) -> bool:
	for d: Vector2i in InteriorGenerator.DIRS4:
		var p := Vector2i(c.x + d.x, c.y + d.y)
		if field.footprint_union.has(p):
			continue
		if p.x < 0 or p.y < 0 or p.x >= field.width or p.y >= field.length:
			continue
		if field.building_interiors.has(Vector3i(p.x, p.y, c.z)):
			return true
		if not field._obs_map.has(Vector3i(p.x, p.y, c.z)):
			return true
	return false


static func _row_has_door(field: BattlefieldArea, row: int, x0: int, x1: int, f: int) -> bool:
	for x: int in range(x0, x1 + 1):
		var obs: Dictionary = field._obs_map.get(Vector3i(x, row, f), {}) as Dictionary
		if String(obs.get("cell_type", "")) == "door":
			return true
	return false


#Cell just inside the west street door of floor 0; x below zero when the wall holds none.
static func _west_entrance(field: BattlefieldArea) -> Vector3i:
	var x: int = main_rect(field).position.x
	for key: Variant in field._obs_map.keys():
		var c: Vector3i = key as Vector3i
		if c.z != 0 or c.x != x:
			continue
		if String((field._obs_map[c] as Dictionary).get("cell_type", "")) == "door":
			return Vector3i(x + 1, c.y, 0)
	return Vector3i(-1, -1, 0)
