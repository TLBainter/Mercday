# TEMP TEST  -  makeshift weapons system verification
# To delete: remove this file, the MakeshiftTest button node from testingArea.tscn,
#            and the _on_makeshift_test() handler + its _ready() line from MercTest.gd

class_name MakeshiftWeaponsTest


static func create_state() -> BattleState:
	var team_a: Array[MercenaryData] = []
	var team_b: Array[MercenaryData] = []
	for i: int in range(2):
		team_a.append(MercGenerator.generate(i))
	for i: int in range(2):
		team_b.append(MercGenerator.generate(i + 2))
	var all_mercs: Array[MercenaryData] = []
	all_mercs.append_array(team_a)
	all_mercs.append_array(team_b)
	for merc: MercenaryData in all_mercs:
		_strip_weapons(merc)
	var field := _make_field()
	return BattleState.create(team_a, team_b, field)


static func _strip_weapons(merc: MercenaryData) -> void:
	merc.equipped_weapon = null
	merc.weapon_drawn = false
	merc.ammo_loaded = 0
	merc.ammo_loaded_type = ""
	merc.ammo_inventory.clear()
	var keep: Array[Dictionary] = []
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			keep.append(entry)
	merc.inventory.clear()
	merc.inventory.append_array(keep)


static func _make_field() -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width = 30
	f.length = 30
	f.height = 20
	f.cover_amount = 3  # "many"  -  up to 2 buildings
	f.unevenness = 1    # gentle terrain
	for _attempt: int in range(12):
		f._generate_cover()
		if not f.building_data.is_empty() and _has_droppable(f):
			print("[MAKESHIFT TEST] Field ready: building + droppable obstacles confirmed")
			return f
	print("[MAKESHIFT TEST] Retry exhausted  -  force-injecting furniture")
	if not f.building_data.is_empty():
		_inject_furniture(f)
	return f


static func _has_droppable(f: BattlefieldArea) -> bool:
	for obs: Dictionary in f.obstacles:
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null and not d.drops.is_empty() and d.health > 0 and not d.passthrough:
			return true
	return false


static func _inject_furniture(f: BattlefieldArea) -> void:
	var names: Array[String] = ["Wooden Chair", "Table", "Stool"]
	var rect: Rect2i = f.building_data[0]["rect"] as Rect2i
	var placed := 0
	for iy: int in range(rect.position.y + 1, rect.end.y - 1):
		for ix: int in range(rect.position.x + 1, rect.end.x - 1):
			if placed >= names.size():
				f._rebuild_cover_obstacles()
				return
			var pos := Vector2i(ix, iy)
			if not f._is_obstacle_at(pos):
				var d: ObstacleData = DataManager.get_obstacle_by_name(names[placed])
				if d != null:
					var entry := {"pos": pos, "size": d.size, "data": d, "cell_type": "furniture"}
					f.obstacles.append(entry)
					f._obs_map[pos] = entry
					placed += 1
	f._rebuild_cover_obstacles()
