class_name BuildingBatch
extends RefCounted

#Rolls planned buildings without a battle and reports what BuildingRules.validate says about each.
#Run: godot --headless --path . -- --building-gen=5 --building-name=Smithy --building-front=W

const DUMP_FIRST := 2
const SUB_DIR := "building_gen"
const ROW_FMT := "BUILDING %s %d: front=%s %dx%d floors=%d rooms=%d tries=%d ms=%d violations=%d"
const INDEX_FMT := "%s_%03d front=%s %dx%d floors=%d rooms=%d issues=%d"
const TOTALS_FMT := "BUILDING %s: fields=%d tries=%.2f rooms=%.1f ms=%.1f"
const RETRIES_FMT := "BUILDING RETRIES: %d%% of %d field(s) needed more than one try; %d unreached exterior room(s)"


static func run(host: Node, count: int, only_name: String, front: String) -> void:
	print("\n====== BUILDING GEN BATCH ======\n")
	TestFixtures.ensure_gen_dir(SUB_DIR)
	var names: Array[String] = GenFixtures.planned_names(only_name)
	if names.is_empty():
		print("BUILDING GEN: no planned building named '%s'" % only_name)
		host.get_tree().quit(1)
		return
	var index_lines := PackedStringArray()
	var clean_of: Dictionary = {}
	var totals: Dictionary = {}
	var clean: int = 0
	var total: int = 0
	var done: int = 0
	var retried: int = 0
	var exterior: int = 0
	for area_name: String in names:
		clean_of[area_name] = 0
		totals[area_name] = {"tries": 0, "rooms": 0, "ms": 0}
		for i: int in range(count):
			var t0 := Time.get_ticks_msec()
			var field := GenFixtures.building_field(area_name, front)
			var ms: int = Time.get_ticks_msec() - t0
			var plan: Dictionary = field.building_plan
			var issues: Array[String] = BuildingRules.validate(field)
			var floors: int = field.interior_floor_elevations.size()
			var rooms: int = field.interior_rooms.size()
			var tries: int = int(plan.get("tries", 0))
			var rec: Dictionary = totals[area_name]
			rec["tries"] = int(rec["tries"]) + tries
			rec["rooms"] = int(rec["rooms"]) + rooms
			rec["ms"] = int(rec["ms"]) + ms
			if tries > 1:
				retried += 1
			total += 1
			done += 1
			print(ROW_FMT % [area_name, i, String(plan.get("front", "?")),
				int(plan.get("floor_w", 0)), int(plan.get("floor_d", 0)), floors, rooms, tries, ms,
				issues.size()])
			for v: String in issues:
				print("BUILDING %s %d VIOLATION: %s" % [area_name, i, v])
				if GenFixtures.is_exterior_issue(v):
					exterior += 1
			if issues.is_empty():
				clean += 1
				clean_of[area_name] = int(clean_of[area_name]) + 1
			else:
				for line: String in field.generation_log:
					print("BUILDING %s %d LOG: %s" % [area_name, i, line])
			if i < DUMP_FIRST or not issues.is_empty():
				var stem_name: String = area_name.replace(" ", "_")
				GenFixtures.dump(field, SUB_DIR, "%s_%03d" % [stem_name, i])
				index_lines.append(INDEX_FMT % [stem_name, i, String(plan.get("front", "?")),
					int(plan.get("floor_w", 0)), int(plan.get("floor_d", 0)), floors, rooms,
					issues.size()])
			await GenFixtures.pace(host, done)
	TestFixtures.write_gen_index(SUB_DIR, "BuildingBatch", index_lines)
	print("BUILDING GEN SUMMARY: %d/%d clean" % [clean, total])
	for area_name2: String in names:
		print("BUILDING %s: %d/%d clean" % [area_name2, int(clean_of[area_name2]), count])
		var rec2: Dictionary = totals[area_name2]
		var n: float = float(maxi(1, count))
		print(TOTALS_FMT % [area_name2, count, float(rec2["tries"]) / n, float(rec2["rooms"]) / n,
			float(rec2["ms"]) / n])
	print(RETRIES_FMT % [roundi(100.0 * float(retried) / float(maxi(1, total))), total, exterior])
	host.get_tree().quit(0 if clean == total else 1)

