class_name CityBatch
extends RefCounted

#Rolls city block maps without a battle and reports the issues CityValidator left on each kept attempt.
#Run: godot --headless --path . -- --city-gen=8 --city-tier=Large --auto-seed=4000

const SUB_DIR := "city_gen"
const DUMP_PER_TIER := 2
const FIXTURE_SEED := 9100
const ROW_FMT := "CITY %03d tier=%s seed=%d size=%dx%d mains=%d sides=%d alleys=%d deadends=%d plots=%d/%d/%d " \
		+ "lots=%d nature=%d%% ms=%d tries=%d violations=%d bld=%d failed=%d objs=%d lanes=%d"
const INDEX_FMT := "city_%03d_%s tier=%s size=%dx%d mains=%d sides=%d alleys=%d lots=%d nature=%d%% issues=%d bld=%d objs=%d"
const TIME_FMT := "CITY GEN TIME tier=%s n=%d avg=%d ms max=%d ms tries_avg=%.2f"


#tier holds every map to one of CityGenerator.TIERS; anything else cycles the four tiers over the batch.
#base_seed >= 0 seeds map i with base_seed + i; -1 leaves the seed alone.
static func run(host: Node, count: int, tier: String, base_seed: int) -> void:
	print("\n====== CITY GEN BATCH ======\n")
	TestFixtures.ensure_gen_dir(SUB_DIR)
	var index_lines := PackedStringArray()
	var totals: Dictionary = {}
	var clean: int = 0
	for i: int in range(count):
		var map_tier: String = tier
		if not CityGenerator.TIERS.has(tier):
			map_tier = String(CityGenerator.TIERS[i % CityGenerator.TIERS.size()])
		var map_seed: int = -1
		if base_seed >= 0:
			map_seed = base_seed + i
			seed(map_seed)
		var ctx := GenerationContext.new()
		ctx.city_tier = map_tier
		var t0 := Time.get_ticks_msec()
		var field := BattlefieldArea.generate_random(null, ctx, "City",
			DataManager.get_area_by_name("City Block"))
		var city: Dictionary = field.city
		var stats: Dictionary = city.get("stats", {})
		var issues: Array = city.get("issues", [])
		var ms: int = int(city.get("ms", Time.get_ticks_msec() - t0))
		var tries: int = int(city.get("tries", 0))
		var nature: int = int(round(float(stats.get("nature_pct", 0.0))))
		var objs: int = int(stats.get("nature_objects", 0)) + int(stats.get("street_objects", 0))
		var mains: int = int(stats.get("mains", 0))
		var sides: int = int(stats.get("sides", 0))
		var alleys: int = int(stats.get("alleys", 0))
		var lots: int = int(stats.get("lots", 0))
		var built: int = int(stats.get("buildings", 0))
		var rec: Dictionary = totals.get(map_tier, {"n": 0, "ms": 0, "max": 0, "tries": 0})
		var tier_index: int = int(rec["n"])
		rec["n"] = tier_index + 1
		rec["ms"] = int(rec["ms"]) + ms
		rec["max"] = maxi(int(rec["max"]), ms)
		rec["tries"] = int(rec["tries"]) + tries
		totals[map_tier] = rec
		print(ROW_FMT % [i, map_tier, map_seed, field.width, field.length, mains, sides, alleys,
			int(stats.get("dead_ends", 0)), int(stats.get("plots_large", 0)),
			int(stats.get("plots_medium", 0)), int(stats.get("plots_small", 0)), lots, nature, ms,
			tries, issues.size(), built, int(stats.get("failed_lots", 0)), objs,
			int(stats.get("back_lanes", 0))])
		for v: Variant in issues:
			print("  VIOLATION: %s" % str(v))
		if issues.is_empty():
			clean += 1
		if tries > 1 or not issues.is_empty():
			for line: String in field.generation_log:
				if line.begins_with("[CITY]"):
					print("  LOG: %s" % line)
		if tier_index < DUMP_PER_TIER or not issues.is_empty():
			GenFixtures.dump(field, SUB_DIR, "city_%03d_%s" % [i, map_tier.to_lower()])
			index_lines.append(INDEX_FMT % [i, map_tier.to_lower(), map_tier, field.width,
				field.length, mains, sides, alleys, lots, nature, issues.size(), built, objs])
		await GenFixtures.pace(host, i + 1)
	TestFixtures.write_gen_index(SUB_DIR, "CityBatch", index_lines)
	for tier_name: String in CityGenerator.TIERS:
		if not totals.has(tier_name):
			continue
		var done: Dictionary = totals[tier_name]
		var n: int = maxi(1, int(done["n"]))
		print(TIME_FMT % [tier_name, int(done["n"]), int(round(float(done["ms"]) / float(n))),
			int(done["max"]), float(done["tries"]) / float(n)])
	print("CITY GEN SUMMARY: %d/%d clean" % [clean, count])
	_dump_fixture()
	host.get_tree().quit(0 if clean == count else 1)


#The three-building map, so the viewer keeps a per-building floor plane case in the batch output.
static func _dump_fixture() -> void:
	var fx: BattlefieldArea = CityFixtures.city(FIXTURE_SEED)["map"]
	GenFixtures.dump(fx, SUB_DIR, "city_fixture")
	print("CITY FIXTURE DUMPED")

