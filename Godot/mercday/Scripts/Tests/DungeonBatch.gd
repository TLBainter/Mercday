class_name DungeonBatch
extends RefCounted

#Rolls dungeons without a battle and reports what DungeonGenerator.validate says about each.
#Run: godot --headless --path . -- --dungeon-gen=100 --dungeon-difficulty=3.5

const DUMP_FIRST := 12
const SUB_DIR := "dungeon_gen"
const ROW_FMT := "DUNGEON %d: D=%.1f floors=%d %dx%d rooms=%d cells=%d halls=%d loops=%d dead_ends=%d " \
		+ "walls=%d mask=%d fill=%d%% ms=%d violations=%d"
const INDEX_FMT := "dungeon_gen_%03d D=%.1f floors=%d chambers=%d cells=%d blocks=%d fill=%d%%"
const FLOOR_BUCKETS := 4


#difficulty 0 cycles 1.0 to 5.0 in half steps over the batch.
static func run(host: Node, count: int, difficulty: float = 0.0) -> void:
	print("\n====== DUNGEON GEN BATCH ======\n")
	TestFixtures.ensure_gen_dir(SUB_DIR)
	var clean: int = 0
	var index_lines := PackedStringArray()
	var floor_hits: Array[int] = []
	for _b: int in range(FLOOR_BUCKETS):
		floor_hits.append(0)
	for i: int in range(count):
		var ctx := GenerationContext.new()
		ctx.difficulty = difficulty if difficulty > 0.0 else 1.0 + float(i % 9) * 0.5
		var t0 := Time.get_ticks_msec()
		var field := BattlefieldArea.generate_random(null, ctx, "Dungeon")
		var ms: int = Time.get_ticks_msec() - t0
		var violations: Array[String] = DungeonGenerator.validate(field)
		var st: Dictionary = field.dungeon_stats
		var floors: int = int(st.get("floors", 0))
		var fill_min: int = int(st.get("fill_min", 0))
		var chambers: int = int(st.get("chambers", 0))
		var cells: int = int(st.get("cells", 0))
		if floors >= 1 and floors <= FLOOR_BUCKETS:
			floor_hits[floors - 1] += 1
		print(ROW_FMT % [i, field.dungeon_difficulty, floors,
			field.width, field.length, chambers, cells,
			int(st.get("halls", 0)), int(st.get("loops", 0)), int(st.get("dead_ends", 0)),
			int(st.get("walls", 0)), field.footprint_union.size(), fill_min, ms, violations.size()])
		for v: String in violations:
			print("DUNGEON %d VIOLATION: %s" % [i, v])
		if violations.is_empty():
			clean += 1
		else:
			for line: String in field.generation_log:
				print("DUNGEON %d LOG: %s" % [i, line])
		if i < DUMP_FIRST or not violations.is_empty():
			GenFixtures.dump(field, SUB_DIR, "dungeon_gen_%03d" % i)
			index_lines.append(INDEX_FMT % [i, field.dungeon_difficulty, floors, chambers, cells,
				int(st.get("blocks", 0)), fill_min])
		await GenFixtures.pace(host, i + 1)
	TestFixtures.write_gen_index(SUB_DIR, "DungeonBatch", index_lines)
	var hist: Array[String] = []
	for b: int in range(FLOOR_BUCKETS):
		hist.append("%dx%d" % [b + 1, floor_hits[b]])
	print("DUNGEON GEN FLOORS: %s" % " ".join(hist))
	print("DUNGEON GEN SUMMARY: %d/%d clean" % [clean, count])
	host.get_tree().quit(0 if clean == count else 1)

