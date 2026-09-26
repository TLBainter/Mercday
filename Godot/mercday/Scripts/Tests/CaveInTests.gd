class_name CaveInTests

#The cave-in hazard: the chance, the queue, sealing, rubble stacks, crushing, burial, marks and pools.
#Run: godot --headless --path . -- --cavein-tests

const SEAL_FIELDS := 3
const HP_ROLLS := 300
const RUBBLE := "Cave-In Rubble"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	PathCost.water_cost = 2
	PathCost.sunk_depth = 0
	_case_chance(res)
	_case_queue_fires(res)
	_case_seal(res)
	_case_cubes(res)
	_case_cube_hp(res)
	_case_crush_fail(res)
	_case_crush_pass(res)
	_case_pop(res)
	_case_types(res)
	_case_marks(res)
	_case_settle(res)
	_case_forced_start(res)
	_case_sheet(res)
	_case_viewer(res)
	_case_own_cell_los(res)
	_case_dig_weapon(res)
	_case_scatter_replace(res)
	_case_pools(res)
	CaveInSystem.force_every = false
	randomize()
	return TestFixtures.summarize(res, "CAVEIN")


#An open rectangle inset one cell from the border, every cell at the same clear height.
static func _room(w: int, l: int, clear: float) -> BattlefieldArea:
	var ceilings: Dictionary = {}
	for y: int in range(1, l - 1):
		for x: int in range(1, w - 1):
			ceilings[Vector2i(x, y)] = clear
	return TestFixtures.cavern_field(w, l, ceilings)


#One open row across a w x 3 map with its entrance at the left end.
static func _corridor(w: int) -> BattlefieldArea:
	var ceilings: Dictionary = {}
	for x: int in range(1, w - 1):
		ceilings[Vector2i(x, 1)] = 3.0
	var f := TestFixtures.cavern_field(w, 3, ceilings)
	f.entrance_cells.append(Vector2i(1, 1))
	return f


static func _merc(merc_name: String, size: int, swim: float = 0.0, vigor: int = 3) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = merc_name
	m.merc_uid = CampaignKnowledge.next_uid()
	m.stats = {"level": 5.0, "luck": 5.0, "size": size, "maximum_hit_points": 20,
		"maximum_endurance_points": 5, "speed": 3.0, "dexterity": 2, "vigor": vigor,
		"pain_limit": 0, "pace": 3, "swim": swim, "climb": 1, "melee_accuracy": 50.0,
		"ranged_accuracy": 50.0, "thrown_accuracy": 50.0}
	m.current_hp = 20
	return m


#The sheet row when it is loaded, else the row 66 values built in code.
static func _rubble_data() -> ObstacleData:
	var sheet: ObstacleData = DataManager.obstacles_by_name.get(RUBBLE) as ObstacleData
	if sheet != null:
		return sheet
	var d := ObstacleData.new()
	d.obstacle_name = RUBBLE
	d.obstacle_type = "Terrain"
	d.size_x = 1.0
	d.size_y = 1.0
	d.size_z = 1.0
	d.height = 1.0
	d.health = 35
	d.susceptible_to = "Strike, Acid"
	d.immune_to = "Lacerate, Impale, Esoteric, Toxic"
	d.climbable = false
	d.moveable = false
	return d


#One rubble stack attached by hand, bottom cube first.
static func _put_rubble(f: BattlefieldArea, cell: Vector2i, cubes: Array[int]) -> Dictionary:
	var obs: Dictionary = {"pos": cell, "floor": 0, "size": 1, "data": _rubble_data(),
		"cell_type": "terrain", "rubble": true, "cubes": cubes, "current_hp": cubes[0],
		"hp_max": cubes[0], "height": float(cubes.size())}
	f.obstacles.append(obs)
	f._obs_map[f.obs_key(cell, 0)] = obs
	f.los_version += 1
	f.bump_path_version()
	return obs


static func _put_obstacle(f: BattlefieldArea, cell: Vector2i, data: ObstacleData) -> Dictionary:
	var obs: Dictionary = {"pos": cell, "floor": 0, "size": 1, "data": data, "cell_type": "terrain"}
	f.obstacles.append(obs)
	f._obs_map[f.obs_key(cell, 0)] = obs
	f.los_version += 1
	f.bump_path_version()
	return obs


static func _rubble_states_gone(merc: MercenaryData) -> bool:
	return not ConstStates.has_state(merc, ConstStates.GRAPPLED) \
		and not ConstStates.has_state(merc, ConstStates.INHIBITED) \
		and not ConstStates.has_state(merc, ConstStates.SUFFOCATING)


static func _case_chance(res: Dictionary) -> void:
	var f := _room(5, 3, 4.0)
	var crew: Array[MercenaryData] = [_merc("Watcher", 1)]
	var st := TestFixtures.field_state(f, crew)
	TestFixtures.check(res, "cave-in chance starts at 1", st.cave_in_chance == 1,
		"chance %d%%" % st.cave_in_chance)
	CaveInSystem.bump_round(st)
	TestFixtures.check(res, "round bump raises the chance", st.cave_in_chance == 2,
		"chance %d%%" % st.cave_in_chance)
	CaveInSystem.note_damage(st, "Strike", 12)
	TestFixtures.check(res, "strike damage bumps per 5", st.cave_in_chance == 5,
		"chance %d%% after Strike 12" % st.cave_in_chance)
	CaveInSystem.note_damage(st, "Sonic", 4)
	TestFixtures.check(res, "sonic damage bumps once", st.cave_in_chance == 6,
		"chance %d%% after Sonic 4" % st.cave_in_chance)
	CaveInSystem.note_damage(st, "Lacerate", 12)
	TestFixtures.check(res, "other damage never bumps", st.cave_in_chance == 6,
		"chance %d%% after Lacerate 12" % st.cave_in_chance)
	var flat := TestFixtures.exterior_field()
	var open_crew: Array[MercenaryData] = [_merc("Outside", 1)]
	var open_st := TestFixtures.field_state(flat, open_crew)
	CaveInSystem.note_damage(open_st, "Strike", 30)
	TestFixtures.check(res, "open map never bumps", open_st.cave_in_chance == 1,
		"chance %d%%" % open_st.cave_in_chance)
	var lines := CaveInSystem.queue(st, 4)
	TestFixtures.check(res, "queue lists the round and resets",
		st.cave_in_due.has(4) and st.cave_in_chance == 1 and not lines.is_empty(),
		"due %s chance %d%% lines %d" % [str(st.cave_in_due), st.cave_in_chance, lines.size()])


static func _case_queue_fires(res: Dictionary) -> void:
	var f := _room(7, 5, 4.0)
	f.entrance_cells.append(Vector2i(1, 1))
	var watcher := _merc("Watcher", 1)
	var crew: Array[MercenaryData] = [watcher]
	var st := TestFixtures.field_state(f, crew)
	TestFixtures.place(st, watcher, Vector2i(1, 1))
	CaveInSystem.queue(st, 2)
	st.round_number = 1
	var early := CaveInSystem.end_of_round(st)
	TestFixtures.check(res, "queued round waits", early.is_empty() and st.cave_in_count == 0,
		"lines %d count %d" % [early.size(), st.cave_in_count])
	st.round_number = 2
	var fired := CaveInSystem.end_of_round(st)
	TestFixtures.check(res, "queued round fires", TestFixtures.has_line(fired, "CAVE-IN:") and st.cave_in_count == 1,
		"lines %d count %d" % [fired.size(), st.cave_in_count])
	TestFixtures.check(res, "fired round leaves the queue", st.cave_in_due.is_empty(),
		"due %s" % str(st.cave_in_due))


static func _case_seal(res: Dictionary) -> void:
	var fields := CavernTests._seeded_fields(SEAL_FIELDS)
	var chosen: BattlefieldArea = null
	var t_index: int = -1
	var anchor := Vector2i(-1, -1)
	var tunnel: Dictionary = {}
	for f: BattlefieldArea in fields:
		var chambers: Dictionary = CavernGenerator._chamber_index(f)
		for i: int in range(f.cavern_tunnels.size()):
			var cells: Dictionary = {}
			var free: Array[Vector2i] = []
			for cell: Vector2i in (f.cavern_tunnels[i]["cells"] as Array):
				cells[cell] = true
				if not chambers.has(cell) and not f.is_water(cell):
					free.append(cell)
			if free.size() < 5:
				continue
			chosen = f
			t_index = i
			tunnel = cells
			anchor = free[floori(float(free.size()) * 0.5)]
			break
		if chosen != null:
			break
	if chosen == null:
		TestFixtures.check(res, "seal covers the tunnel width", false, "no tunnel to seal")
		return
	var out: Dictionary = {}
	var added := CaveInSystem._seal(chosen, t_index, anchor, out, 2)
	var outside: int = 0
	var xs: Dictionary = {}
	var ys: Dictionary = {}
	for cell: Vector2i in out.keys():
		if not tunnel.has(cell):
			outside += 1
		xs[cell.x] = true
		ys[cell.y] = true
	TestFixtures.check(res, "seal fills a tunnel stretch",
		added > 0 and out.size() == added and out.has(anchor),
		"added %d cells %d anchor %s" % [added, out.size(), str(out.has(anchor))])
	TestFixtures.check(res, "seal stays inside the tunnel", outside == 0,
		"%d of %d cell(s) off the tunnel" % [outside, out.size()])
	TestFixtures.check(res, "seal runs two cells along one axis", mini(xs.size(), ys.size()) <= 2,
		"%d column(s) by %d row(s)" % [xs.size(), ys.size()])
	var dry: Dictionary = {}
	for cell: Vector2i in out.keys():
		if not chosen.is_water(cell):
			dry[cell] = true
	var crew: Array[MercenaryData] = [_merc("Sealer", 1)]
	var st := TestFixtures.field_state(chosen, crew)
	var spawned := CaveInSystem._spawn_rubble(st, dry)
	var not_solid: int = 0
	var vaultable: int = 0
	for cell: Vector2i in dry.keys():
		if not chosen.is_obstacle(cell, 0):
			not_solid += 1
		for size: int in [1, 3]:
			var entry: Array = PathCost.static_entry(chosen, Vector3i(cell.x, cell.y, 0), size)
			if int(entry[6]) != PathCost.KIND_WALL:
				not_solid += 1
			if bool(entry[10]):
				vaultable += 1
	TestFixtures.check(res, "sealed cells are solid", spawned == dry.size() and not_solid == 0,
		"%d spawned of %d, %d soft reading(s)" % [spawned, dry.size(), not_solid])
	TestFixtures.check(res, "rubble is never vaulted", vaultable == 0,
		"%d vaultable reading(s)" % vaultable)


static func _case_cubes(res: Dictionary) -> void:
	var ceilings: Dictionary = {Vector2i(1, 1): 5.0, Vector2i(2, 1): 1.5, Vector2i(3, 1): 2.75}
	var f := TestFixtures.cavern_field(5, 3, ceilings)
	var tall := CaveInSystem.cube_count(f, Vector2i(1, 1))
	var low := CaveInSystem.cube_count(f, Vector2i(2, 1))
	var mid := CaveInSystem.cube_count(f, Vector2i(3, 1))
	TestFixtures.check(res, "cube count capped at three", tall == 3, "cubes %d under 5 clear" % tall)
	TestFixtures.check(res, "cube count floors at one", low == 1, "cubes %d under 1.5 clear" % low)
	TestFixtures.check(res, "cube count rounds down", mid == 2, "cubes %d under 2.75 clear" % mid)
	var crew: Array[MercenaryData] = [_merc("Sealer", 1)]
	var st := TestFixtures.field_state(f, crew)
	var footprint: Dictionary = {Vector2i(1, 1): true}
	CaveInSystem._spawn_rubble(st, footprint)
	var obs := f.get_obs(Vector2i(1, 1), 0)
	var stack: Array = obs.get("cubes", []) as Array
	TestFixtures.check(res, "stack height matches the cubes",
		stack.size() == 3 and is_equal_approx(float(obs.get("height", 0.0)), 3.0),
		"cubes %d height %.1f" % [stack.size(), float(obs.get("height", 0.0))])


static func _case_cube_hp(res: Dictionary) -> void:
	var lo: int = 9999
	var hi: int = 0
	for _i: int in range(HP_ROLLS):
		var hp := CaveInSystem._cube_hp()
		lo = mini(lo, hp)
		hi = maxi(hi, hp)
	TestFixtures.check(res, "cube hp inside its band", lo >= 10 and hi <= 60,
		"%d rolls span %d..%d" % [HP_ROLLS, lo, hi])


static func _case_crush_fail(res: Dictionary) -> void:
	var f := _room(5, 3, 4.0)
	var victim := _merc("Victim", 1)
	var crew: Array[MercenaryData] = [victim]
	var st := TestFixtures.field_state(f, crew)
	var cell := Vector2i(2, 1)
	TestFixtures.place(st, victim, cell)
	var footprint: Dictionary = {cell: true}
	var lines: Array[String] = []
	var crushed := CaveInSystem._resolve_crush(victim, st, footprint, false, lines)
	TestFixtures.check(res, "crush deals four direct damage",
		crushed and victim.current_hp == 16 and str(st.cave_in_marked.get(victim, "")) == "crushed",
		"hp %d mark %s" % [victim.current_hp, str(st.cave_in_marked.get(victim, ""))])
	CaveInSystem._bury(victim, st, cell, lines)
	var held := ConstStates.has_state(victim, ConstStates.GRAPPLED) \
		and ConstStates.has_state(victim, ConstStates.INHIBITED) \
		and ConstStates.has_state(victim, ConstStates.SUFFOCATING)
	TestFixtures.check(res, "burial holds three states", held and st.cave_in_buried.has(victim),
		"held %s buried %s" % [str(held), str(st.cave_in_buried.has(victim))])
	var bad_source: int = 0
	var relief: float = 0.0
	for state_name: String in [ConstStates.GRAPPLED, ConstStates.INHIBITED, ConstStates.SUFFOCATING]:
		for src: Dictionary in StateSources.state_sources(victim, state_name):
			if str(src.get("kind", "")) != CavernRules.ENGINE_KIND \
					or str(src.get("name", "")) != CavernRules.RUBBLE_SOURCE:
				bad_source += 1
		relief = maxf(relief, StateReliefEvaluator.removal_chance(victim, victim, state_name, st))
	TestFixtures.check(res, "rubble states carry the engine source", bad_source == 0,
		"%d source(s) off the rubble" % bad_source)
	TestFixtures.check(res, "rubble states never relieve", is_zero_approx(relief),
		"best relief %.2f" % relief)
	var vigor := maxi(1, int(victim.stats.get("vigor", 1)))
	for _i: int in range(vigor + 1):
		CavernRules.breath_turn_start(victim, st)
	TestFixtures.check(res, "buried merc suffocates", victim.suffocation_hp_loss == 1,
		"loss %d after %d turn(s)" % [victim.suffocation_hp_loss, vigor + 1])


static func _case_crush_pass(res: Dictionary) -> void:
	var f := _room(5, 3, 4.0)
	var dodger := _merc("Dodger", 1)
	var crew: Array[MercenaryData] = [dodger]
	var st := TestFixtures.field_state(f, crew)
	var cell := Vector2i(2, 1)
	TestFixtures.place(st, dodger, cell)
	var footprint: Dictionary = {cell: true}
	var lines: Array[String] = []
	var crushed := CaveInSystem._resolve_crush(dodger, st, footprint, true, lines)
	var dest := st.get_position(dodger)
	var step := maxi(absi(dest.x - cell.x), absi(dest.y - cell.y))
	TestFixtures.check(res, "passed check steps clear",
		not crushed and not footprint.has(dest) and step == 1,
		"dest (%d,%d) step %d" % [dest.x, dest.y, step])
	TestFixtures.check(res, "dodged merc stays whole",
		dodger.current_hp == 20 and not st.cave_in_buried.has(dodger)
		and not ConstStates.has_state(dodger, ConstStates.GRAPPLED),
		"hp %d buried %s" % [dodger.current_hp, str(st.cave_in_buried.has(dodger))])
	var spent := _merc("Spent", 1)
	var nimble := _merc("Nimble", 1)
	var pair: Array[MercenaryData] = [spent, nimble]
	var st2 := TestFixtures.field_state(_room(5, 3, 4.0), pair)
	spent.current_ep = 0
	spent.excess_ep = 0
	nimble.current_ep = 2
	nimble.excess_ep = 0
	TestFixtures.place(st2, spent, cell)
	TestFixtures.place(st2, nimble, Vector2i(3, 1))
	var no_ep := CaveInSystem._crush_attempt(spent, st2, footprint, lines)
	TestFixtures.check(res, "no ep means no check", no_ep and ExcessPool.available_ep(spent) == 0,
		"crushed %s ep %d" % [str(no_ep), ExcessPool.available_ep(spent)])
	var try_fp: Dictionary = {Vector2i(3, 1): true}
	CaveInSystem._crush_attempt(nimble, st2, try_fp, lines)
	TestFixtures.check(res, "check costs one ep", ExcessPool.available_ep(nimble) == 1,
		"ep %d" % ExcessPool.available_ep(nimble))


static func _case_pop(res: Dictionary) -> void:
	var f := _room(5, 3, 4.0)
	var pinned := _merc("Pinned", 1)
	var crew: Array[MercenaryData] = [pinned]
	var st := TestFixtures.field_state(f, crew)
	var cell := Vector2i(2, 1)
	TestFixtures.place(st, pinned, cell)
	var stack: Array[int] = [10, 20, 30]
	var obs := _put_rubble(f, cell, stack)
	var lines: Array[String] = []
	CaveInSystem._bury(pinned, st, cell, lines)
	var first := ObstacleUtils.apply_damage(obs, 5, st, "Tester", "Strike")
	var left: Array = obs.get("cubes", []) as Array
	TestFixtures.check(res, "bottom cube pops and the stack drops",
		not bool(first["destroyed"]) and int(obs["current_hp"]) == 20 and left.size() == 2
		and is_equal_approx(float(obs["height"]), 2.0)
		and ConstStates.has_state(pinned, ConstStates.GRAPPLED),
		"hp %d cubes %d height %.1f" % [int(obs["current_hp"]), left.size(),
		float(obs["height"])])
	ObstacleUtils.apply_damage(obs, 20, st, "Tester", "Acid")
	TestFixtures.check(res, "second cube pops",
		(obs.get("cubes", []) as Array).size() == 1 and int(obs["current_hp"]) == 30,
		"cubes %d hp %d" % [(obs.get("cubes", []) as Array).size(), int(obs["current_hp"])])
	var pv := f.path_version
	var last := ObstacleUtils.apply_damage(obs, 30, st, "Tester", "Strike")
	TestFixtures.check(res, "last cube clears the cell",
		bool(last["destroyed"]) and f.get_obs(cell, 0).is_empty() and f.path_version > pv,
		"destroyed %s obstacle %s" % [str(last["destroyed"]), str(f.get_obs(cell, 0).is_empty())])
	TestFixtures.check(res, "cleared cell frees the merc",
		_rubble_states_gone(pinned) and not st.cave_in_buried.has(pinned),
		"buried %s grappled %s" % [str(st.cave_in_buried.has(pinned)),
		str(ConstStates.has_state(pinned, ConstStates.GRAPPLED))])


static func _case_types(res: Dictionary) -> void:
	var f := _room(6, 3, 4.0)
	var crew: Array[MercenaryData] = [_merc("Tester", 1)]
	var st := TestFixtures.field_state(f, crew)
	var single: Array[int] = [40]
	var obs := _put_rubble(f, Vector2i(1, 1), single)
	var harmless: Array[String] = ["Lacerate", "Impale", "Sonic", "Holy", "Toxic"]
	var took_harm: int = 0
	var said_harmless := false
	for damage_type: String in harmless:
		var out := ObstacleUtils.apply_damage(obs, 50, st, "Tester", damage_type)
		if int(obs["current_hp"]) != 40:
			took_harm += 1
		var out_lines: Array[String] = []
		out_lines.assign(out.get("lines", []) as Array)
		if TestFixtures.has_line(out_lines, "no harm"):
			said_harmless = true
	TestFixtures.check(res, "rubble shrugs off its immunities", took_harm == 0 and said_harmless,
		"%d type(s) hurt it, line %s" % [took_harm, str(said_harmless)])
	ObstacleUtils.apply_damage(obs, 10, st, "Tester", "Frost")
	TestFixtures.check(res, "plain damage lands whole", int(obs["current_hp"]) == 30,
		"hp %d after Frost 10" % int(obs["current_hp"]))
	ObstacleUtils.apply_damage(obs, 5, st, "Tester", "Acid")
	TestFixtures.check(res, "susceptible damage doubles", int(obs["current_hp"]) == 20,
		"hp %d after Acid 5" % int(obs["current_hp"]))
	var spike: ObstacleData = DataManager.obstacles_by_name.get("Stalagmite") as ObstacleData
	if spike == null:
		TestFixtures.check(res, "scatter susceptibility doubles", false, "no Stalagmite row")
		return
	var spike_hp := ObstacleUtils.get_hp(spike)
	var hard := _put_obstacle(f, Vector2i(3, 1), spike)
	ObstacleUtils.apply_damage(hard, 10, st, "Tester", "Strike")
	var soft := _put_obstacle(f, Vector2i(4, 1), spike)
	ObstacleUtils.apply_damage(soft, 10, st, "Tester", "Lacerate")
	TestFixtures.check(res, "scatter susceptibility doubles",
		int(hard["current_hp"]) == spike_hp - 20 and int(soft["current_hp"]) == spike_hp - 10,
		"strike %d lacerate %d of %d" % [int(hard["current_hp"]), int(soft["current_hp"]), spike_hp])


static func _case_marks(res: Dictionary) -> void:
	var f := _corridor(11)
	var near := _merc("Near", 1)
	var far_a := _merc("FarA", 1)
	var far_b := _merc("FarB", 1)
	var far_c := _merc("FarC", 1)
	var party: Array[MercenaryData] = [near, far_a, far_b, far_c]
	var st := TestFixtures.field_state(f, party)
	TestFixtures.place(st, near, Vector2i(1, 1))
	TestFixtures.place(st, far_a, Vector2i(6, 1))
	TestFixtures.place(st, far_b, Vector2i(7, 1))
	TestFixtures.place(st, far_c, Vector2i(8, 1))
	var plug: Array[int] = [100]
	_put_rubble(f, Vector2i(3, 1), plug)
	var plug2: Array[int] = [100]
	_put_rubble(f, Vector2i(4, 1), plug2)
	var lines: Array[String] = []
	CaveInSystem._mark_party(st, lines)
	var cut_off := str(st.cave_in_marked.get(far_a, "")) == "cut_off" \
		and str(st.cave_in_marked.get(far_b, "")) == "cut_off" \
		and str(st.cave_in_marked.get(far_c, "")) == "cut_off"
	TestFixtures.check(res, "rubble cuts the party off", cut_off,
		"marks %s %s %s" % [str(st.cave_in_marked.get(far_a, "")),
		str(st.cave_in_marked.get(far_b, "")), str(st.cave_in_marked.get(far_c, ""))])
	TestFixtures.check(res, "most of the party beyond means separated",
		str(st.cave_in_marked.get(near, "")) == "separated",
		"mark %s" % str(st.cave_in_marked.get(near, "")))
	var f2 := _corridor(11)
	var solo := _merc("Solo", 1)
	var mate := _merc("Mate", 1)
	var duo: Array[MercenaryData] = [solo, mate]
	var st2 := TestFixtures.field_state(f2, duo)
	TestFixtures.place(st2, solo, Vector2i(1, 1))
	TestFixtures.place(st2, mate, Vector2i(7, 1))
	var plug3: Array[int] = [100]
	_put_rubble(f2, Vector2i(3, 1), plug3)
	var plug4: Array[int] = [100]
	_put_rubble(f2, Vector2i(4, 1), plug4)
	CaveInSystem._mark_party(st2, lines)
	TestFixtures.check(res, "a pair is never separated",
		str(st2.cave_in_marked.get(mate, "")) == "cut_off" and not st2.cave_in_marked.has(solo),
		"mate %s solo %s" % [str(st2.cave_in_marked.get(mate, "")),
		str(st2.cave_in_marked.get(solo, ""))])


static func _case_settle(res: Dictionary) -> void:
	var contract_run := ContractRun.new()
	contract_run.contract = ContractData.new()
	var marked := _merc("Marked", 1)
	var clean := _merc("Clean", 1)
	var roster: Array[MercenaryData] = [marked, clean]
	contract_run.team.assign(roster)
	var st := TestFixtures.field_state(_room(5, 3, 4.0), roster)
	st.cave_in_marked[marked] = "crushed"
	var lines := CaveInSystem.settle(contract_run, st, roster)
	var marks: Array = contract_run.merc_marks.get(marked, []) as Array
	TestFixtures.check(res, "marked merc earns the contract mark",
		marks.has("Cave-In") and not contract_run.merc_marks.has(clean) and not lines.is_empty(),
		"marks %s clean %s" % [str(marks), str(contract_run.merc_marks.has(clean))])
	CaveInSystem.settle(contract_run, st, roster)
	var again: Array = contract_run.merc_marks.get(marked, []) as Array
	TestFixtures.check(res, "settle never doubles the mark", again.size() == 1,
		"marks %s" % str(again))


static func _case_forced_start(res: Dictionary) -> void:
	var forced: Array[MercenaryData] = [_merc("Forced", 1)]
	var st := TestFixtures.field_state(_room(5, 3, 4.0), forced)
	CaveInSystem.force_every = true
	var lines := CaveInSystem.on_battle_start(st)
	var due: int = st.cave_in_due[0] if not st.cave_in_due.is_empty() else -1
	TestFixtures.check(res, "forced start queues one cave-in",
		st.cave_in_due.size() == 1 and due >= 1 and due <= 3 and st.cave_in_chance == 1
		and not lines.is_empty(),
		"due %s chance %d%%" % [str(st.cave_in_due), st.cave_in_chance])
	CaveInSystem.force_every = false
	var plain: Array[MercenaryData] = [_merc("Plain", 1)]
	var st2 := TestFixtures.field_state(_room(5, 3, 4.0), plain)
	CaveInSystem.on_battle_start(st2)
	TestFixtures.check(res, "battle start sets the base chance", st2.cave_in_chance == 1,
		"chance %d%%" % st2.cave_in_chance)


static func _case_sheet(res: Dictionary) -> void:
	var d: ObstacleData = DataManager.obstacles_by_name.get(RUBBLE) as ObstacleData
	if d == null:
		TestFixtures.check(res, "cave-in rubble row", false, "no %s row" % RUBBLE)
	else:
		TestFixtures.check(res, "cave-in rubble row",
			d.health == 35 and d.growth_pct == 0 and not d.climbable and not d.moveable,
			"health %d growth %d climbable %s moveable %s" % [d.health, d.growth_pct,
			str(d.climbable), str(d.moveable)])
		TestFixtures.check(res, "cave-in rubble damage columns",
			d.susceptible_to.findn("Strike") >= 0 and d.susceptible_to.findn("Acid") >= 0
			and d.immune_to.findn("Esoteric") >= 0,
			"susceptible %s immune %s" % [d.susceptible_to, d.immune_to])
	var spike: ObstacleData = DataManager.obstacles_by_name.get("Stalagmite") as ObstacleData
	TestFixtures.check(res, "scatter rows keep their columns",
		spike != null and spike.susceptible_to.findn("Strike") >= 0 and spike.immune_to == "",
		"susceptible %s immune %s" % [spike.susceptible_to if spike != null else "none",
		spike.immune_to if spike != null else "none"])


static func _case_viewer(res: Dictionary) -> void:
	var f := _room(5, 3, 4.0)
	var stack: Array[int] = [120, 90]
	_put_rubble(f, Vector2i(2, 1), stack)
	var data := HtmlWireframeGenerator._extract_data(f)
	var entry: Dictionary = {}
	for obs: Dictionary in (data.get("obstacles", []) as Array):
		if bool(obs.get("rubble", false)):
			entry = obs
			break
	TestFixtures.check(res, "viewer reports the rubble stack",
		not entry.is_empty() and int(entry.get("cubes", 0)) == 2
		and is_equal_approx(float(entry.get("height", 0.0)), 2.0),
		"entry %s" % str(entry.is_empty() == false))


static func _case_own_cell_los(res: Dictionary) -> void:
	var f := _room(7, 3, 6.0)
	var buried := _merc("Buried", 1)
	var eyes := _merc("Eyes", 1)
	var digger := _merc("Digger", 1)
	var team_a: Array[MercenaryData] = [buried, digger]
	var team_b: Array[MercenaryData] = [eyes]
	var st := BattleState.create(team_a, team_b, null)
	st.battlefield = f
	var cell := Vector2i(2, 1)
	TestFixtures.place(st, buried, cell)
	TestFixtures.place(st, eyes, Vector2i(4, 1))
	TestFixtures.place(st, digger, Vector2i(1, 1))
	var stack: Array[int] = [80, 80]
	var obs := _put_rubble(f, cell, stack)
	var burial: Array[String] = []
	CaveInSystem._bury(buried, st, cell, burial)
	var inward := LineOfSight.check(st, eyes, buried)
	TestFixtures.check(res, "rubble hides the buried merc",
		not bool(inward["visible"]) and str(inward["cover"]) == "full"
		and str(inward["blocker"]).find("Rubble") >= 0,
		"visible %s cover %s blocker %s" % [str(inward["visible"]), str(inward["cover"]),
		str(inward["blocker"])])
	var outward := LineOfSight.check(st, buried, eyes)
	TestFixtures.check(res, "rubble blocks the buried merc's own sight",
		not bool(outward["visible"]),
		"visible %s blocker %s" % [str(outward["visible"]), str(outward["blocker"])])
	TestFixtures.check(res, "buried merc counts as fully covered",
		st.is_covered_from(buried, eyes, ConstStates.COVERED_FULL), "covered false")
	st.set_position(eyes, Vector2i(3, 1))
	var close := LineOfSight.check(st, eyes, buried)
	TestFixtures.check(res, "adjacency never skips the own-cell rule", not bool(close["visible"]),
		"visible %s via %s" % [str(close["visible"]), str(close["via"])])
	var dig := CaveInSystem.dig_target(digger, st)
	TestFixtures.check(res, "ally digs the rubble holding a teammate", dig == obs,
		"target %s" % str(dig.get("rubble", false)))
	f.obstacles.erase(obs)
	f._obs_map.erase(f.obs_key(cell, 0))
	f.los_version += 1
	f.bump_path_version()
	var turn := CaveInSystem.buried_turn(buried, st, 0)
	TestFixtures.check(res, "a buried turn on a cleared cell frees the merc",
		not st.cave_in_buried.has(buried) and _rubble_states_gone(buried) and not turn.is_empty(),
		"buried %s lines %d" % [str(st.cave_in_buried.has(buried)), turn.size()])
	var cleared := LineOfSight.check(st, eyes, buried)
	TestFixtures.check(res, "cleared cell restores sight", bool(cleared["visible"]),
		"visible %s blocker %s" % [str(cleared["visible"]), str(cleared["blocker"])])
	var giant := _merc("Giant", 3)
	var giants: Array[MercenaryData] = [giant]
	var st2 := BattleState.create(giants, team_b, null)
	st2.battlefield = f
	TestFixtures.place(st2, giant, cell)
	TestFixtures.place(st2, eyes, Vector2i(4, 1))
	var short_stack: Array[int] = [80, 80]
	_put_rubble(f, cell, short_stack)
	var over := LineOfSight.check(st2, eyes, giant)
	TestFixtures.check(res, "a taller merc shows over the rubble",
		bool(over["visible"]) and str(over["cover"]) == "partial",
		"visible %s cover %s" % [str(over["visible"]), str(over["cover"])])
	var f3 := _room(7, 3, 6.0)
	var climber := _merc("Climber", 1)
	var climbers: Array[MercenaryData] = [climber]
	var st3 := BattleState.create(climbers, team_b, null)
	st3.battlefield = f3
	TestFixtures.place(st3, climber, cell)
	TestFixtures.place(st3, eyes, Vector2i(4, 1))
	var boulder := ObstacleData.new()
	boulder.obstacle_name = "Boulder"
	boulder.obstacle_type = "Terrain"
	boulder.health = 20
	boulder.climbable = true
	boulder.size_z = 1.0
	boulder.height = 1.0
	var rock := _put_obstacle(f3, cell, boulder)
	rock["height"] = 1.0
	f3.los_version += 1
	st3.set_height(climber, 1)
	var perch := LineOfSight.check(st3, eyes, climber)
	TestFixtures.check(res, "a merc on top of an obstacle stays visible",
		bool(perch["visible"]) and str(perch["cover"]) == "none",
		"visible %s cover %s" % [str(perch["visible"]), str(perch["cover"])])


static func _case_scatter_replace(res: Dictionary) -> void:
	var spike: ObstacleData = DataManager.obstacles_by_name.get("Stalagmite") as ObstacleData
	if spike == null:
		TestFixtures.check(res, "scatter replaced without a drop", false, "no Stalagmite row")
		return
	var f := _room(5, 3, 4.0)
	var crew: Array[MercenaryData] = [_merc("Sealer", 1)]
	var st := TestFixtures.field_state(f, crew)
	var cell := Vector2i(2, 1)
	_put_obstacle(f, cell, spike)
	var footprint: Dictionary = {cell: true}
	CaveInSystem._spawn_rubble(st, footprint)
	var obs := f.get_obs(cell, 0)
	var dropped: Array = st.dropped_weapons.get(cell, []) as Array
	var left: int = 0
	for other: Dictionary in f.obstacles:
		if (other.get("data") as ObstacleData) == spike:
			left += 1
	TestFixtures.check(res, "scatter replaced without a drop",
		bool(obs.get("rubble", false)) and dropped.is_empty() and left == 0,
		"rubble %s drops %d scatter(s) left %d" % [str(obs.get("rubble", false)),
		dropped.size(), left])


static func _case_pools(res: Dictionary) -> void:
	var f := _room(5, 3, 4.0)
	var cell := Vector2i(2, 1)
	f.water_cells[cell] = 5
	f.terrain_heights[cell] = -5.0
	f.ground_heights[cell] = -5.0
	f.cavern_ceiling[cell] = -2.5
	f.bump_path_version()
	TestFixtures.check(res, "deep pool takes a submerged stack",
		CaveInSystem.cube_count(f, cell) == 2 and CaveInSystem.is_submerged(f, cell),
		"cubes %d submerged %s" % [CaveInSystem.cube_count(f, cell),
		str(CaveInSystem.is_submerged(f, cell))])
	var sinker := _merc("Anvil", 1, 1.0)
	sinker.equipped_armor = TestFixtures.swim_armor(false, true)
	var crew: Array[MercenaryData] = [sinker]
	var st := TestFixtures.field_state(f, crew)
	TestFixtures.place(st, sinker, cell)
	var lines: Array[String] = []
	CavernRules.on_enter_cell(sinker, Vector2i(1, 1), cell, st, lines)
	var footprint: Dictionary = {cell: true}
	CaveInSystem._spawn_rubble(st, footprint)
	TestFixtures.check(res, "submerged stack raises the pool floor",
		f.is_water(cell) and f.water_depth(cell) == 3
		and is_equal_approx(f.get_terrain_height(cell), -3.0) and f.get_obs(cell, 0).is_empty(),
		"water %d floor %.1f obstacle %s" % [f.water_depth(cell), f.get_terrain_height(cell),
		str(f.get_obs(cell, 0).is_empty())])
	TestFixtures.check(res, "sunk merc rises with the floor",
		st.sunk_depth(sinker) == 3 and ConstStates.has_state(sinker, ConstStates.DROWNING),
		"depth %d drowning %s" % [st.sunk_depth(sinker),
		str(ConstStates.has_state(sinker, ConstStates.DROWNING))])
	var crushed: Array[MercenaryData] = CaveInSystem._crush_all(st, footprint, lines)
	TestFixtures.check(res, "a submerged cell never buries",
		not crushed.has(sinker) and not st.cave_in_buried.has(sinker),
		"crushed %d buried %s" % [crushed.size(), str(st.cave_in_buried.has(sinker))])
	var f2 := _room(5, 3, 4.0)
	f2.water_cells[cell] = 2
	f2.terrain_heights[cell] = -2.0
	f2.ground_heights[cell] = -2.0
	f2.bump_path_version()
	TestFixtures.check(res, "shallow pool takes a surfaced stack",
		CaveInSystem.cube_count(f2, cell) == 3 and not CaveInSystem.is_submerged(f2, cell),
		"cubes %d submerged %s" % [CaveInSystem.cube_count(f2, cell),
		str(CaveInSystem.is_submerged(f2, cell))])
	var diver := _merc("Diver", 1, 1.0)
	diver.equipped_armor = TestFixtures.swim_armor(false, true)
	var divers: Array[MercenaryData] = [diver]
	var st2 := TestFixtures.field_state(f2, divers)
	TestFixtures.place(st2, diver, cell)
	CavernRules.on_enter_cell(diver, Vector2i(1, 1), cell, st2, lines)
	CavernRules.on_surface(diver, st2, lines)
	CaveInSystem._spawn_rubble(st2, footprint)
	var obs := f2.get_obs(cell, 0)
	CaveInSystem._bury(diver, st2, cell, lines)
	TestFixtures.check(res, "surfaced stack stands on the pool floor",
		bool(obs.get("rubble", false)) and (obs.get("cubes", []) as Array).size() == 3
		and int(obs.get("water_depth", 0)) == 2 and not f2.is_water(cell),
		"cubes %d depth %d water %s" % [(obs.get("cubes", []) as Array).size(),
		int(obs.get("water_depth", 0)), str(f2.is_water(cell))])
	TestFixtures.check(res, "hauled merc is buried dry",
		st2.cave_in_buried.has(diver) and st2.sunk_depth(diver) == 0,
		"buried %s depth %d" % [str(st2.cave_in_buried.has(diver)), st2.sunk_depth(diver)])
	for _i: int in range(3):
		ObstacleUtils.apply_damage(obs, 500, st2, "Tester", "Strike")
	TestFixtures.check(res, "cleared stack gives the pool back",
		f2.is_water(cell) and f2.water_depth(cell) == 2 and not st2.cave_in_buried.has(diver),
		"water %s depth %d buried %s" % [str(f2.is_water(cell)), f2.water_depth(cell),
		str(st2.cave_in_buried.has(diver))])
	TestFixtures.check(res, "freed merc sinks again",
		st2.is_sunk(diver) and ConstStates.has_state(diver, ConstStates.DROWNING),
		"sunk %s drowning %s" % [str(st2.is_sunk(diver)),
		str(ConstStates.has_state(diver, ConstStates.DROWNING))])


#A buried merc holding a Lacerate weapon digs with bare hands, so the swing can still hurt the cube.
static func _case_dig_weapon(res: Dictionary) -> void:
	var f := _room(5, 3, 6.0)
	var buried := _merc("Buried", 1)
	var blade := WeaponData.new()
	blade.item_name = "Test Blade"
	blade.damage_types_1.assign(["Lacerate"] as Array[String])
	buried.equipped_weapon = blade
	buried.weapon_drawn = true
	var club := WeaponData.new()
	club.item_name = "Test Club"
	club.damage_types_1.assign(["Strike"] as Array[String])
	var maul := WeaponData.new()
	maul.item_name = "Test Maul"
	maul.damage_types_1.assign(["Lacerate", "Strike"] as Array[String])
	var rubble := _rubble_data()
	var blade_out: bool = SpecialActionSystem._harmless_against(buried, blade, rubble)
	var club_out: bool = SpecialActionSystem._harmless_against(buried, club, rubble)
	var maul_out: bool = SpecialActionSystem._harmless_against(buried, maul, rubble)
	TestFixtures.check(res, "only a fully immune weapon yields to bare hands",
		blade_out and not club_out and not maul_out,
		"blade %s club %s maul %s" % [str(blade_out), str(club_out), str(maul_out)])
	var swung := SpecialActionSystem._best_type(rubble, SpecialActionSystem._weapon_types(buried, maul),
		"Lacerate")
	TestFixtures.check(res, "a mixed weapon swings the type the rubble takes", swung == "Strike",
		"type %s" % swung)
	var mercs: Array[MercenaryData] = [buried]
	var st := TestFixtures.field_state(f, mercs)
	var cell := Vector2i(2, 1)
	TestFixtures.place(st, buried, cell)
	var stack: Array[int] = [80]
	_put_rubble(f, cell, stack)
	var burial: Array[String] = []
	CaveInSystem._bury(buried, st, cell, burial)
	var joined := "\n".join(CaveInSystem.buried_turn(buried, st, 0))
	TestFixtures.check(res, "buried merc digs bare-handed and keeps its blade",
		joined.find("bare hands") >= 0 and joined.find("does no harm") < 0
		and buried.equipped_weapon == blade and buried.weapon_drawn,
		"lines %s" % joined.replace("\n", " | "))
