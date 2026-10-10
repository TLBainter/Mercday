class_name RoomCatalog
extends RefCounted

#Rooms an area may place on a floor, by the floor suffix of each room type.


static func get_rooms_for_floor(area_data: Dictionary, floor_num: int) -> Array[ObstacleData]:
	return _rooms_for(area_data, floor_num, "Interior", true)


static func get_exterior_rooms_for_floor(area_data: Dictionary, floor_num: int) -> Array[ObstacleData]:
	return _rooms_for(area_data, floor_num, "Exterior", false)


#Dungeon rooms of this area: "Dungeon Any" on every floor, "Dungeon F0" on 0, "Dungeon F-" below 0.
static func get_dungeon_rooms_for_floor(area_data: Dictionary, floor_num: int) -> Array[ObstacleData]:
	var rooms_list: Array = area_data.get("rooms_list", [])
	var result: Array[ObstacleData] = []
	for room_name: String in rooms_list:
		var d: ObstacleData = DataManager.get_obstacle_by_name(room_name)
		if d == null or not d.is_room or not d.room_type.begins_with("Dungeon"):
			continue
		var rt: String = d.room_type
		if rt.ends_with("Any") \
				or (rt.ends_with("F0") and floor_num == 0) \
				or (rt.ends_with("F-") and floor_num < 0):
			result.append(d)
	return result


#Rooms of this area whose room_type starts with prefix and whose floor suffix fits floor_num.
#any_floors also accepts the "Any" and "F-" suffixes. "Top" needs a top_floor of 1 or more.
static func _rooms_for(area_data: Dictionary, floor_num: int, prefix: String,
		any_floors: bool) -> Array[ObstacleData]:
	var rooms_list: Array = area_data.get("rooms_list", [])
	var top_floor: int = int(area_data.get("top_floor", -999))
	var result: Array[ObstacleData] = []
	for room_name: String in rooms_list:
		var d: ObstacleData = DataManager.get_obstacle_by_name(room_name)
		if d == null or not d.is_room:
			continue
		var rt: String = d.room_type
		if not rt.begins_with(prefix):
			continue
		var matches: bool = false
		if any_floors and rt.ends_with("Any") and floor_num >= 0:
			matches = true
		elif rt.ends_with("F0") and floor_num == 0:
			matches = true
		elif rt.ends_with("F+") and floor_num > 0:
			matches = true
		elif any_floors and rt.ends_with("F-") and floor_num < 0:
			matches = true
		elif rt.ends_with("Top") and top_floor >= 1 and floor_num == top_floor:
			matches = true
		if matches:
			result.append(d)
	return result
