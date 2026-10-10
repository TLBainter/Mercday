class_name CityObjects

#The outdoor object registry of a city block map: one place call writes the obstacle, its reserved
#cells and the per tag counts, and a rejected footprint rolls the write back.


static func _objects(area: BattlefieldArea) -> Dictionary:
	return area.city["objects"] as Dictionary


#Writes one outdoor object and its reserved cells; {} when a footprint cell fails its test.
static func place(area: BattlefieldArea, data: ObstacleData, cell: Vector2i, tag: String,
		rotated: bool = false) -> Dictionary:
	if data == null:
		return {}
	var pw: int = 1
	var ph: int = 1
	var size: int = 0
	if data.obstacle_type == "Vegetation":
		size = ObstacleGenerator.instance_size(data)
	else:
		pw = maxi(1, ceili(data.size_x))
		ph = maxi(1, ceili(data.size_y))
		if rotated:
			var swap: int = pw
			pw = ph
			ph = swap
		size = pw * ph
	for dy: int in range(ph):
		for dx: int in range(pw):
			if not area.in_bounds_xy(cell.x + dx, cell.y + dy):
				return {}
	for dy2: int in range(ph):
		for dx2: int in range(pw):
			if not CityAccess.can_hold(area, Vector2i(cell.x + dx2, cell.y + dy2)):
				return {}
	var blocking: bool = not (data.passthrough or data.ramp)
	var obs: Dictionary = {"pos": Vector3i(cell.x, cell.y, 0), "size": size, "data": data,
		"rotated": rotated, "floor": 0, "pw": pw, "ph": ph, "city": tag}
	var written: Array[Vector3i] = []
	for dy3: int in range(ph):
		for dx3: int in range(pw):
			var c := Vector2i(cell.x + dx3, cell.y + dy3)
			if blocking and not CityAccess.can_block(area, c):
				_rollback(area, written)
				return {}
			var key := Vector3i(c.x, c.y, 0)
			if dx3 == 0 and dy3 == 0:
				area.add_obstacle(obs, key)
			else:
				area._obs_map[key] = {"cell_type": "reserved", "floor": 0}
			written.append(key)
	var objects: Dictionary = _objects(area)
	objects[tag] = int(objects.get(tag, 0)) + 1
	if blocking and tag == "nature":
		objects["blocking"] = int(objects.get("blocking", 0)) + 1
	return obs


static func _rollback(area: BattlefieldArea, written: Array[Vector3i]) -> void:
	for key: Vector3i in written:
		area._obs_map.erase(key)
	if not written.is_empty():
		area.obstacles.pop_back()
	var objects: Dictionary = _objects(area)
	objects["rolled_back"] = int(objects.get("rolled_back", 0)) + 1
