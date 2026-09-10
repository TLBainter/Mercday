class_name ContractTerrain

#Picks the Areas.tsv row an event fights on: the event's Interior rule, else the location's temperature.

const COLD_AREA := "Arctic Mountain"
const WARM_AREA := "Desert Plain"
const INTERIOR_PREFIX := "Interior:"


static func terrain_for_temperature(raw: String) -> String:
	var cell: String = raw.strip_edges()
	var parts: PackedStringArray = cell.split(" ", false)
	var value: float = 0.0
	if parts.size() >= 2 and parts[parts.size() - 1].is_valid_float():
		value = float(parts[parts.size() - 1])
	elif cell.is_valid_float():
		value = float(cell)
	if cell.begins_with("Below"):
		return COLD_AREA
	if cell.begins_with("Above") and value >= 25.0:
		return WARM_AREA
	if cell.is_valid_float() and value < 0.0:
		return COLD_AREA
	return ""


static func temperature_cell(loc: LocationData) -> String:
	if loc == null:
		return ""
	var cell: String = String(loc.get_meta("temperature_raw", "")).strip_edges()
	if cell == "" and loc.location_type == "Settlement" and loc.parent != null:
		cell = String(loc.parent.get_meta("temperature_raw", "")).strip_edges()
	return cell


static func area_name_for(loc: LocationData) -> String:
	if loc == null:
		return ""
	if loc.location_type != "Country" and loc.location_type != "Settlement":
		return ""
	return terrain_for_temperature(temperature_cell(loc))


static func field_for(event: EventData, location: LocationData, size_a: int, size_b: int) -> BattlefieldArea:
	var ctx := GenerationContext.new()
	ctx.team_size_a = size_a
	ctx.team_size_b = size_b
	var rule: String = event.map_rule if event != null else ""
	var area: Dictionary = {}
	if rule.begins_with(INTERIOR_PREFIX):
		var name: String = rule.substr(INTERIOR_PREFIX.length()).strip_edges()
		area = DataManager.get_area_by_name(name)
		if area.is_empty():
			push_error("ContractTerrain: unknown interior area '%s'" % name)
			area = DataManager.get_random_area("Interior")
	else:
		var name: String = area_name_for(location)
		if name != "":
			area = DataManager.get_area_by_name(name)
		if area.is_empty():
			push_error("ContractTerrain: no terrain for location '%s'" % (location.location_name if location != null else ""))
			area = DataManager.get_random_area("Exterior")
	return BattlefieldArea.generate_random(null, ctx, "Exterior", area)
