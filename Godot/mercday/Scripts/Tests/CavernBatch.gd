class_name CavernBatch
extends RefCounted

#Rolls caverns without a battle and reports what CavernGenerator.validate says about each.
#Run: godot --headless --path . -- --cavern-gen=100

const DUMP_FIRST := 5
const YIELD_EVERY := 5
const SUB_DIR := "cavern_gen"
const ROW_FMT := "CAVERN %d: %dx%d chambers=%d tunnels=%d entrances=%d pools=%d scatters=%d ms=%d violations=%d"


static func run(host: Node, count: int) -> void:
	print("\n====== CAVERN GEN BATCH ======\n")
	TestFixtures.ensure_gen_dir(SUB_DIR)
	var clean: int = 0
	for i: int in range(count):
		var ctx := GenerationContext.new()
		var t0 := Time.get_ticks_msec()
		var field := BattlefieldArea.generate_random(null, ctx, "Cavern")
		var ms: int = Time.get_ticks_msec() - t0
		var violations: Array[String] = CavernGenerator.validate(field)
		print(ROW_FMT % [i, field.width, field.length, field.cavern_chambers.size(),
			field.cavern_tunnels.size(), entrances(field), pools(field), scatters(field),
			ms, violations.size()])
		for v: String in violations:
			print("CAVERN %d VIOLATION: %s" % [i, v])
		if violations.is_empty():
			clean += 1
		else:
			for line: String in field.generation_log:
				print("CAVERN %d LOG: %s" % [i, line])
		if i < DUMP_FIRST or not violations.is_empty():
			TestFixtures.dump_gen(field, SUB_DIR, i)
		if (i + 1) % YIELD_EVERY == 0:
			await host.get_tree().process_frame
	print("CAVERN GEN SUMMARY: %d/%d clean" % [clean, count])
	host.get_tree().quit(0 if clean == count else 1)


static func entrances(field: BattlefieldArea) -> int:
	var n: int = 0
	for t: Dictionary in field.cavern_tunnels:
		if str(t.get("kind", "")) == "entrance":
			n += 1
	return n


static func pools(field: BattlefieldArea) -> int:
	var n: int = 0
	for ch: Dictionary in field.cavern_chambers:
		if bool(ch.get("flooded", false)):
			n += 1
	return n


#Everything the scatter pass placed; the rock shell is walls and is counted apart.
static func scatters(field: BattlefieldArea) -> int:
	var n: int = 0
	for obs: Dictionary in field.obstacles:
		if str(obs.get("cell_type", "")) != "wall":
			n += 1
	return n
