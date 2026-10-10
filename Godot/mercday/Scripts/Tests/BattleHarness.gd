class_name BattleHarness
extends RefCounted

#Splits the roster into teams, starts one autobattle and drives its round loop.

static var team_mix: bool = false
#Test flag --betrayal-fresh: clears the campaign betrayal gate before each contract or ambush event.
static var betrayal_fresh: bool = false

static var battle_state: BattleState = null
static var battle_line_fn: Callable
static var battle_team_a: Array[MercenaryData] = []
static var battle_team_b: Array[MercenaryData] = []
static var contract_running: bool = false
#Batch state of the "--auto-city" loop: the wanted tier, the spawn-only flag and the last battle's facts.
static var city_tier: String = ""
static var city_spawn_only: bool = false
#Battles started by start_battle so far; the rotate split walks its halvings by this count.
static var _battle_index: int = 0
static var last_rounds: int = 0
static var last_winner: int = -1
static var last_gen_ms: int = 0
static var last_spawn_ms: int = 0
static var last_city_tier: String = ""
static var last_city_size: Vector2i = Vector2i.ZERO


static func _run_battle_loop() -> void:
	while battle_state != null:
		var ongoing: bool = await AutoBattle.step_round(battle_state, battle_line_fn)
		if not ongoing:
			last_rounds = battle_state.round_number
			last_winner = battle_state.get_winner()
			_print_battle_result(last_winner)
			battle_state = null


#The probe scripts read the harness command line flags through these two names.
static func probe_levels(fallback: Array[int]) -> Array[int]:
	return HarnessFlags.probe_levels(fallback)


static func arg_int(flag: String, fallback: int) -> int:
	return HarnessFlags.arg_int(flag, fallback)


#Field for one harness battle kind; an unknown kind rolls a plain exterior map.
static func _kind_field(kind: String) -> BattlefieldArea:
	if kind == "Dungeon":
		var ctx := GenerationContext.new()
		ctx.difficulty = HarnessFlags.auto_difficulty()
		return BattlefieldArea.generate_random(null, ctx, kind)
	if kind == "Interior":
		var ictx := GenerationContext.new()
		ictx.building_front = HarnessFlags.auto_spec("--building-front")
		return BattlefieldArea.generate_random(null, ictx, kind, HarnessFlags.auto_building_data())
	if kind == "Cavern":
		return BattlefieldArea.generate_random(null, null, kind)
	#An empty or unknown tier leaves CityGenerator to roll one from its weights.
	if kind == "City":
		var cctx := GenerationContext.new()
		cctx.city_tier = city_tier
		return BattlefieldArea.generate_random(null, cctx, kind, DataManager.get_area_by_name("City Block"))
	return BattlefieldArea.generate_random()


#Splits the roster, builds the field for kind and runs the autobattle loop; "" rolls a plain exterior map.
static func start_battle(mercs: Array[MercenaryData], kind: String = "") -> void:
	if contract_running:
		print("Contract already in progress.")
		return
	if mercs.size() < 2:
		print("Need at least 2 mercs to start a battle.")
		return
	if battle_state != null:
		print("Battle already in progress.")
		return
	TestFixtures.set_roster(mercs)
	var enclosed := kind == "Interior" or kind == "Cavern" or kind == "Dungeon"
	if enclosed or kind == "City":
		print("\n====== AUTOBATTLE (%s) ======\n" % kind.to_upper())
	else:
		print("\n====== AUTOBATTLE ======\n")
	var mixed_ok: bool = false
	if enclosed and team_mix:
		mixed_ok = HarnessRoster.shuffle_mixed_teams(mercs)
		if not mixed_ok:
			print("AUTO MIX: no split with a flyer and a firearm on each side")
	else:
		mercs.shuffle()
	var mode: String = HarnessFlags.auto_spec("--auto-split")
	if mode == "":
		mode = "rotate"
	#A mixed shuffle already chose the halves; keep its result.
	if enclosed and team_mix and mixed_ok:
		mode = "plain"
	var halves: Array = HarnessRoster.split_teams(mercs, mode, _battle_index)
	battle_team_a.clear()
	battle_team_b.clear()
	battle_team_a.assign(halves[0] as Array)
	battle_team_b.assign(halves[1] as Array)
	var a_names := _first_names(battle_team_a)
	var b_names := _first_names(battle_team_b)
	print("AUTO SPLIT: mode=%s index=%d a=%s b=%s levels=%d/%d" % [
		mode, _battle_index, a_names, b_names, _level_sum(battle_team_a), _level_sum(battle_team_b)])
	_battle_index += 1
	var g0 := Time.get_ticks_msec()
	var field := _kind_field(kind)
	last_gen_ms = Time.get_ticks_msec() - g0
	if kind == "City":
		last_city_tier = String(field.city.get("tier", ""))
		last_city_size = Vector2i(field.width, field.length)
	var s0 := Time.get_ticks_msec()
	battle_state = BattleState.create(battle_team_a, battle_team_b, field)
	last_spawn_ms = Time.get_ticks_msec() - s0
	if kind == "City" and city_spawn_only:
		battle_state = null
		return
	battle_line_fn = func(s: String) -> void: print_rich(s)
	var order_parts: Array[String] = []
	for i: int in range(battle_state.turn_queue.size()):
		var m: MercenaryData = battle_state.turn_queue[i]
		var color := "white" if battle_team_a.has(m) else "yellow"
		order_parts.append("[color=%s]%s[/color]" % [color, m.merc_name.get_slice(" ", 0)])
	print_rich("[color=white]Team A:[/color] %s" % a_names)
	print_rich("[color=yellow]Team B:[/color] %s" % b_names)
	print_rich("Turn order: %s" % ", ".join(order_parts))
	if kind == "City":
		AutoBattle.setup(battle_state, battle_line_fn, "city")
	else:
		AutoBattle.setup(battle_state, battle_line_fn)
	if enclosed:
		HarnessRoster.log_auto_immune()
		HarnessRoster.inflict_auto_state()
	_run_battle_loop()


static func _print_battle_result(winner_idx: int) -> void:
	if winner_idx >= 0:
		var w_color := "white" if winner_idx == 0 else "yellow"
		print_rich("[color=gray]=== Battle over in %d rounds ===[/color]" % battle_state.round_number)
		print_rich("[color=%s]Team %s wins!  (%s)[/color]" % [w_color, "A" if winner_idx == 0 else "B",
			_first_names(battle_state.teams[winner_idx])])
	else:
		print_rich("[color=gray]=== Draw / timeout after %d rounds ===[/color]" % battle_state.round_number)


#The first names of the team, comma separated.
static func _first_names(team: Array) -> String:
	var out: Array[String] = []
	for m: MercenaryData in team:
		out.append(m.merc_name.get_slice(" ", 0))
	return ", ".join(out)


static func _level_sum(team: Array[MercenaryData]) -> int:
	var total: int = 0
	for m: MercenaryData in team:
		total += ExperienceSystem.current_level(m)
	return total
