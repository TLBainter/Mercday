class_name ContractTerrain

#Picks the Areas.tsv row an event fights on: the Cavern or Interior map rule, else the contract
#Terrain Odds, else a weighted draw over the Area rows naming the location's Environment.

const INTERIOR_PREFIX := "Interior:"
const CAVERN := "Cavern"
const DUNGEON := "Dungeon"
const URBAN := "Urban"
const MAX_PARENT_HOPS := 8

#The text of the last field_for pick, for the contract log.
static var last_draw: String = ""


#Walks the parent chain for the first Environment that is neither blank nor Urban.
static func terrain_environment(loc: LocationData) -> String:
	var node: LocationData = loc
	for _hop: int in range(MAX_PARENT_HOPS):
		if node == null:
			break
		var env: String = node.environment.strip_edges()
		if env != "" and env != URBAN:
			return env
		node = node.parent
	return ""


#Exterior and Cavern Area rows naming that Environment with a weight above 0, in sheet order.
static func candidates(loc: LocationData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var env: String = terrain_environment(loc).to_lower()
	if env == "":
		return out
	for area: Dictionary in DataManager.areas_pool:
		if not drawable(area):
			continue
		var weight: int = int((area.get("environments", {}) as Dictionary).get(env, 0))
		if weight > 0:
			out.append({"area": area, "weight": weight})
	return out


static func has_terrain(loc: LocationData) -> bool:
	return not candidates(loc).is_empty()


#Only Exterior, Cavern and Dungeon rows take part in draws and odds.
static func drawable(area: Dictionary) -> bool:
	var area_type: String = String(area.get("type", ""))
	return area_type == "Exterior" or area_type == CAVERN or area_type == DUNGEON


static func describe(loc: LocationData) -> String:
	var list: Array[Dictionary] = candidates(loc)
	if list.is_empty():
		return "none"
	return "%s: %s" % [terrain_environment(loc), weights_text(list)]


static func weights_text(list: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in list:
		parts.append("%s %d" % [String((entry["area"] as Dictionary).get("name", "")), int(entry["weight"])])
	return ", ".join(parts)


#Terrain Odds cell -> [{"area": String, "percent": int}]; a bad or missing number gives percent -1.
static func parse_odds(cell: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: String in TsvReader.split_field(cell):
		var parts: PackedStringArray = entry.split(" ", false)
		if parts.is_empty():
			continue
		var name: String = entry.strip_edges()
		var percent: int = -1
		if parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
			percent = int(parts[parts.size() - 1])
			parts.remove_at(parts.size() - 1)
			name = " ".join(parts)
		out.append({"area": name, "percent": percent})
	return out


#The contract odds roll first, in cell order; the location's candidates carry the rest.
static func draw(loc: LocationData, contract: ContractData) -> Dictionary:
	if contract != null:
		for entry: Dictionary in contract.terrain_odds:
			var percent: int = int(entry.get("percent", -1))
			if percent < 1:
				continue
			var forced: Dictionary = DataManager.get_area_by_name(String(entry.get("area", "")))
			if forced.is_empty() or not drawable(forced):
				continue
			if randi_range(1, 100) <= percent:
				return {"area": forced, "how": "%s odds (%s %d)" % [contract.contract_type,
					String(forced.get("name", "")), percent]}
	var list: Array[Dictionary] = candidates(loc)
	if list.is_empty():
		return {}
	var total: int = 0
	for entry: Dictionary in list:
		total += int(entry["weight"])
	var roll: int = randi_range(1, total)
	var picked: Dictionary = list[list.size() - 1]["area"] as Dictionary
	for entry: Dictionary in list:
		roll -= int(entry["weight"])
		if roll <= 0:
			picked = entry["area"] as Dictionary
			break
	return {"area": picked, "how": "%s (%s)" % [terrain_environment(loc), weights_text(list)]}


static func field_for(event: EventData, location: LocationData, size_a: int, size_b: int,
		contract: ContractData = null, min_cell_blocks: int = 0) -> BattlefieldArea:
	var ctx := GenerationContext.new()
	ctx.team_size_a = size_a
	ctx.team_size_b = size_b
	ctx.min_cell_blocks = min_cell_blocks
	if contract != null:
		ctx.difficulty = contract.difficulty
	var rule: String = event.map_rule if event != null else ""
	var area: Dictionary = {}
	if rule == DUNGEON:
		area = DataManager.get_random_area(DUNGEON)
		last_draw = "%s via map rule" % DUNGEON
		return BattlefieldArea.generate_random(null, ctx, DUNGEON, area)
	if rule == CAVERN:
		area = DataManager.get_random_area(CAVERN)
		last_draw = "%s via map rule" % CAVERN
		return BattlefieldArea.generate_random(null, ctx, CAVERN, area)
	if rule.begins_with(INTERIOR_PREFIX):
		var name: String = rule.substr(INTERIOR_PREFIX.length()).strip_edges()
		area = DataManager.get_area_by_name(name)
		if area.is_empty():
			push_error("ContractTerrain: unknown interior area '%s'" % name)
			area = DataManager.get_random_area("Interior")
		last_draw = "%s via map rule" % String(area.get("name", name))
	else:
		var picked: Dictionary = draw(location, contract)
		if picked.is_empty():
			push_error("ContractTerrain: no terrain for location '%s'"
				% (location.location_name if location != null else ""))
			area = DataManager.get_random_area("Exterior")
			last_draw = "%s via fallback" % String(area.get("name", ""))
		else:
			area = picked["area"] as Dictionary
			last_draw = "%s via %s" % [String(area.get("name", "")), String(picked["how"])]
	return BattlefieldArea.generate_random(null, ctx, str(area.get("type", "Exterior")), area)
