class_name CityFixtures

#The three building fixture that the city suite and the city batch both stamp: one map with a manor,
#a watchtower and a cobbler set out left to right.

const MARGIN := 4
const GAP := 3
const SPECS: Array = [["Manor", "S", 4], ["Watchtower", "W", 0], ["Cobbler", "N", 0]]


#Three buildings generated on scratch maps and stamped left to right into one city map.
static func city(seed_i: int) -> Dictionary:
	seed(seed_i)
	var scratches: Array[BattlefieldArea] = []
	var pre: Array[Dictionary] = []
	for spec: Array in SPECS:
		var scratch: BattlefieldArea = BuildingStamp.build_scratch(
			DataManager.get_area_by_name(String(spec[0])), String(spec[1]), int(spec[2]))
		if scratch == null:
			continue
		var runs: int = 0
		for sk: Variant in scratch.stairwell_connections.keys():
			var key: Vector3i = sk as Vector3i
			var dest: Vector3i = scratch.stairwell_connections[sk] as Vector3i
			if dest.z < key.z:
				runs += 1
		scratches.append(scratch)
		pre.append({"obs": scratch.obstacles.size(), "omap": scratch._obs_map.size(),
			"cells": BuildingStamp.used_cells(scratch).size(), "rect": BuildingStamp.used_rect(scratch),
			"runs": runs})
	var width: int = MARGIN * 2 + GAP * maxi(0, pre.size() - 1)
	var depth: int = 0
	for entry: Dictionary in pre:
		var r: Rect2i = entry["rect"]
		width += r.size.x
		depth = maxi(depth, r.size.y)
	var map := BattlefieldArea.new()
	map.width = width
	map.length = MARGIN * 2 + depth
	map.height = 40
	map.unevenness = 6
	map.is_interior_map = true
	map.area_name = "City Test"
	var ids: Array[int] = []
	var cursor_x: int = MARGIN
	for i: int in range(scratches.size()):
		var rect: Rect2i = pre[i]["rect"]
		ids.append(BuildingStamp.place(map, scratches[i],
			BuildingStamp.offset_for(scratches[i], Vector2i(cursor_x, MARGIN))))
		cursor_x += rect.size.x + GAP
	BuildingStamp.finish(map)
	return {"map": map, "ids": ids, "pre": pre}
