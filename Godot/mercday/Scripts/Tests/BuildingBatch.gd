class_name BuildingBatch
extends RefCounted

#Rolls planned buildings without a battle and reports what BuildingRules.validate says about each.
#Run: godot --headless --path . -- --building-gen=5 --building-name=Smithy --building-front=W

const DUMP_FIRST := 2
const YIELD_EVERY := 5
const SUB_DIR := "building_gen"
const ROW_FMT := "BUILDING %s %d: front=%s %dx%d floors=%d rooms=%d tries=%d ms=%d violations=%d"
const INDEX_FMT := "%s_%03d front=%s %dx%d floors=%d rooms=%d issues=%d"


static func run(host: Node, count: int, only_name: String, front: String) -> void:
	print("\n====== BUILDING GEN BATCH ======\n")
	TestFixtures.ensure_gen_dir(SUB_DIR)
	var names: Array[String] = _names(only_name)
	if names.is_empty():
		print("BUILDING GEN: no planned building named '%s'" % only_name)
		host.get_tree().quit(1)
		return
	var index_lines := PackedStringArray()
	var clean_of: Dictionary = {}
	var clean: int = 0
	var total: int = 0
	var done: int = 0
	for area_name: String in names:
		clean_of[area_name] = 0
		for i: int in range(count):
			var ctx := GenerationContext.new()
			ctx.building_front = front
			var t0 := Time.get_ticks_msec()
			var field := BattlefieldArea.generate_random(null, ctx, "Interior",
				DataManager.get_area_by_name(area_name))
			var ms: int = Time.get_ticks_msec() - t0
			var plan: Dictionary = field.building_plan
			var issues: Array[String] = BuildingRules.validate(field)
			var floors: int = field.interior_floor_elevations.size()
			var rooms: int = field.interior_rooms.size()
			total += 1
			done += 1
			print(ROW_FMT % [area_name, i, String(plan.get("front", "?")),
				int(plan.get("floor_w", 0)), int(plan.get("floor_d", 0)), floors, rooms,
				int(plan.get("tries", 0)), ms, issues.size()])
			for v: String in issues:
				print("BUILDING %s %d VIOLATION: %s" % [area_name, i, v])
			if issues.is_empty():
				clean += 1
				clean_of[area_name] = int(clean_of[area_name]) + 1
			else:
				for line: String in field.generation_log:
					print("BUILDING %s %d LOG: %s" % [area_name, i, line])
			if i < DUMP_FIRST or not issues.is_empty():
				var stem_name: String = area_name.replace(" ", "_")
				var stem: String = "%s/%s/%s_%03d" % [EncounterLogger.LOG_DIR, SUB_DIR, stem_name, i]
				HtmlWireframeGenerator.save(field, stem)
				LevelDumpWriter.save(field, stem)
				index_lines.append(INDEX_FMT % [stem_name, i, String(plan.get("front", "?")),
					int(plan.get("floor_w", 0)), int(plan.get("floor_d", 0)), floors, rooms,
					issues.size()])
			if done % YIELD_EVERY == 0:
				await host.get_tree().process_frame
	TestFixtures.write_gen_index(SUB_DIR, "BuildingBatch", index_lines)
	print("BUILDING GEN SUMMARY: %d/%d clean" % [clean, total])
	for area_name2: String in names:
		print("BUILDING %s: %d/%d clean" % [area_name2, int(clean_of[area_name2]), count])
	host.get_tree().quit(0 if clean == total else 1)


#Every planned building, or the one named; an unknown name gives an empty list.
static func _names(only_name: String) -> Array[String]:
	var out: Array[String] = []
	for entry: String in DataManager.get_building_names():
		if BuildingRules.is_legacy(DataManager.get_area_by_name(entry)):
			continue
		if only_name != "" and entry != only_name:
			continue
		out.append(entry)
	return out

