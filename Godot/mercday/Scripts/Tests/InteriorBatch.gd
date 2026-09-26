class_name InteriorBatch
extends RefCounted

#Rolls tavern interiors without a battle and dumps the first few for the viewer.
#Run: godot --headless --path . -- --interior-gen=50

const DUMP_FIRST := 12
const YIELD_EVERY := 5
const SUB_DIR := "interior_gen"
const TAVERN := "Tavern"
const ROW_FMT := "INTERIOR %d: wings=%d floors=%d %dx%d rooms=%d mask=%d ms=%d"
const WING_BUCKETS := 4


static func run(host: Node, count: int) -> void:
	print("\n====== INTERIOR GEN BATCH ======\n")
	TestFixtures.ensure_gen_dir(SUB_DIR)
	var area_data: Dictionary = DataManager.get_area_by_name(TAVERN)
	var area_type: String = String(area_data.get("type", "Interior"))
	var bad: int = 0
	var wing_hits: Array[int] = []
	for _b: int in range(WING_BUCKETS):
		wing_hits.append(0)
	for i: int in range(count):
		var ctx := GenerationContext.new()
		var t0 := Time.get_ticks_msec()
		var field := BattlefieldArea.generate_random(null, ctx, area_type, area_data)
		var ms: int = Time.get_ticks_msec() - t0
		var wings: int = InteriorTests.wing_count(field)
		if wings >= 1 and wings <= WING_BUCKETS:
			wing_hits[wings - 1] += 1
		if wings < InteriorTests.WING_MIN or wings > InteriorTests.WING_MAX:
			bad += 1
		print(ROW_FMT % [i, wings, field.interior_floor_elevations.size(),
			field.width, field.length, field.interior_rooms.size(),
			field.footprint_union.size(), ms])
		if i < DUMP_FIRST:
			var stem: String = "%s/%s/interior_gen_%03d" % [EncounterLogger.LOG_DIR, SUB_DIR, i]
			HtmlWireframeGenerator.save(field, stem)
			LevelDumpWriter.save(field, stem)
		if (i + 1) % YIELD_EVERY == 0:
			await host.get_tree().process_frame
	var hist: Array[String] = []
	for b: int in range(WING_BUCKETS):
		hist.append("%dx%d" % [b + 1, wing_hits[b]])
	print("INTERIOR GEN WINGS: %s" % " ".join(hist))
	print("INTERIOR GEN SUMMARY: %d/%d with one to three wings" % [count - bad, count])
	host.get_tree().quit(0 if bad == 0 else 1)
