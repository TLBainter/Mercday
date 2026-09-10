class_name TestFixtures

#Shared helpers for the deterministic test suites. Printed text must stay byte identical.


#Counts one case into res and prints its PASS or FAIL line.
static func check(res: Dictionary, label: String, ok: bool, detail: String) -> void:
	if ok:
		res["pass"] = int(res["pass"]) + 1
		print("PASS %s | %s" % [label, detail])
	else:
		res["fail"] = int(res["fail"]) + 1
		print("FAIL %s | %s" % [label, detail])


#Prints the suite summary line and reports whether every case passed.
static func summarize(res: Dictionary, suite: String) -> bool:
	var total: int = int(res["pass"]) + int(res["fail"])
	print("%s TESTS SUMMARY: %d/%d passed, %d failed" % [suite, int(res["pass"]), total, int(res["fail"])])
	return int(res["fail"]) == 0


#Flat 24x24x24 exterior field.
static func exterior_field() -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width = 24
	f.length = 24
	f.height = 24
	f.is_interior_map = false
	return f


#Appends one obstacle dict to the field at cell and maps it.
static func put(f: BattlefieldArea, cell: Vector3i, obs: Dictionary) -> Dictionary:
	obs["pos"] = cell
	obs["floor"] = cell.z
	f.obstacles.append(obs)
	f._obs_map[f.obs_key(Vector2i(cell.x, cell.y), cell.z)] = obs
	return obs


#Puts a merc on the ground floor at pos.
static func place(state: BattleState, merc: MercenaryData, pos: Vector2i) -> void:
	state.positions[merc] = pos
	state.heights[merc] = 0
	state.floors[merc] = 0
