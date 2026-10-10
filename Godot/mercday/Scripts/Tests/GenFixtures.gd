class_name GenFixtures
extends RefCounted

#Pieces the map batches and the generation suites share: level dumps, frame pacing, orphan counts, building fields.

const YIELD_EVERY := 5


#Writes the wireframe page and the level dump of one field to encounter_logs/<sub_dir>/<stem_name>.
static func dump(field: BattlefieldArea, sub_dir: String, stem_name: String) -> void:
	var stem: String = "%s/%s/%s" % [EncounterLogger.LOG_DIR, sub_dir, stem_name]
	HtmlWireframeGenerator.save(field, stem)
	LevelDumpWriter.save(field, stem)


#Yields one frame after every YIELD_EVERY finished maps so a long batch keeps the window alive.
static func pace(host: Node, done: int) -> void:
	if done % YIELD_EVERY == 0:
		await host.get_tree().process_frame


#How many of the given cells are walkable with open doors yet missing from a flood that starts at start.
static func orphan_count(field: BattlefieldArea, start: Vector3i, cells: Array) -> int:
	var reached: Dictionary = DungeonGenerator._walk_dist(field, start, true)
	var orphans: int = 0
	for key: Variant in cells:
		var c: Vector3i = key as Vector3i
		if DungeonGenerator._passable(field, c, true) and not reached.has(c):
			orphans += 1
	return orphans


#Every Buildings.tsv row that carries a layout in sheet order, or just the one named; unknown names give none.
static func planned_names(only_name: String = "") -> Array[String]:
	var out: Array[String] = []
	for entry: String in DataManager.get_building_names():
		if BuildingRules.is_legacy(DataManager.get_area_by_name(entry)):
			continue
		if only_name != "" and entry != only_name:
			continue
		out.append(entry)
	return out


#One Interior map of a named building facing front; a seed below zero leaves the generator rolls alone.
static func building_field(area_name: String, front: String, seed_i: int = -1) -> BattlefieldArea:
	if seed_i >= 0:
		seed(seed_i)
	var ctx := GenerationContext.new()
	ctx.building_front = front
	return BattlefieldArea.generate_random(null, ctx, "Interior", DataManager.get_area_by_name(area_name))


#An "unreached <name> f<n>" validator line for a Patio or a Balcony; those rooms sit outside the floor mask.
static func is_exterior_issue(text: String) -> bool:
	if not text.begins_with("unreached "):
		return false
	var body: String = text.substr(10)
	var cut: int = body.rfind(" f")
	if cut < 0:
		return false
	var d: ObstacleData = DataManager.get_obstacle_by_name(body.substr(0, cut))
	return d != null and d.room_type.begins_with("Exterior")


#Two rival teams of count mercs from maker, named <tag_a><n> and <tag_b><n> and built in pairs; returns [team_a, team_b].
static func rival_teams(tag_a: String, tag_b: String, count: int, maker: Callable) -> Array:
	var team_a: Array[MercenaryData] = []
	var team_b: Array[MercenaryData] = []
	for i: int in range(count):
		team_a.append(maker.call("%s%d" % [tag_a, i + 1]) as MercenaryData)
		team_b.append(maker.call("%s%d" % [tag_b, i + 1]) as MercenaryData)
	return [team_a, team_b]


#Saves the level dump of field as encounter_logs/<sub_dir>/<stem_name>_level.txt and returns its lines.
static func dump_lines(field: BattlefieldArea, sub_dir: String, stem_name: String) -> PackedStringArray:
	TestFixtures.ensure_gen_dir(sub_dir)
	var stem: String = "%s/%s/%s" % [EncounterLogger.LOG_DIR, sub_dir, stem_name]
	LevelDumpWriter.save(field, stem)
	return FileAccess.get_file_as_string(stem + "_level.txt").split("\n")


#Rows of the character grid under heading, counted while each is as wide as the field; -1 when the heading or
#the Legend line after it is missing.
static func grid_rows(lines: PackedStringArray, heading: String, field: BattlefieldArea) -> int:
	var head: int = lines.find(heading)
	if head < 0 or head + 1 >= lines.size() or not lines[head + 1].begins_with("Legend:"):
		return -1
	var rows: int = 0
	if head + 1 + field.length < lines.size():
		for i: int in range(field.length):
			if lines[head + 2 + i].length() != field.width:
				break
			rows += 1
	return rows

