class_name BattleHarness
extends RefCounted

#Splits the roster into teams, starts one autobattle and drives its round loop.

static var team_mix: bool = false
#Test flag --betrayal-fresh: clears the campaign betrayal gate before each contract or ambush event.
static var betrayal_fresh: bool = false

static var _battle_state: BattleState = null
static var _battle_line_fn: Callable
static var _battle_team_a: Array[MercenaryData] = []
static var _battle_team_b: Array[MercenaryData] = []
static var _contract_running: bool = false
static var rescue_runs: int = 0
static var rescue_stealth: int = 0
static var rescue_combat: int = 0
static var rescue_failed: int = 0
#Batch state of the "--auto-city" loop: the wanted tier, the spawn-only flag and the last battle's facts.
static var _city_tier: String = ""
static var _city_spawn_only: bool = false
#Battles started by _start_battle so far; the rotate split walks its halvings by this count.
static var _battle_index: int = 0
static var _last_rounds: int = 0
static var _last_winner: int = -1
static var _last_gen_ms: int = 0
static var _last_spawn_ms: int = 0
static var _last_city_tier: String = ""
static var _last_city_size: Vector2i = Vector2i.ZERO


static func _run_battle_loop() -> void:
	while _battle_state != null:
		var ongoing: bool = await AutoBattle.step_round(_battle_state, _battle_line_fn)
		if not ongoing:
			_last_rounds = _battle_state.round_number
			_last_winner = _battle_state.get_winner()
			_print_battle_result()
			_battle_state = null


static func start_battle(mercs: Array[MercenaryData]) -> void:
	_start_battle(mercs, "")


static func start_interior_battle(mercs: Array[MercenaryData]) -> void:
	_start_battle(mercs, "Interior")


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
		cctx.city_tier = _city_tier
		return BattlefieldArea.generate_random(null, cctx, kind, DataManager.get_area_by_name("City Block"))
	return BattlefieldArea.generate_random()


#Splits the roster, builds the field for kind and runs the autobattle loop.
static func _start_battle(mercs: Array[MercenaryData], kind: String) -> void:
	if _contract_running:
		print("Contract already in progress.")
		return
	if mercs.size() < 2:
		print("Need at least 2 mercs to start a battle.")
		return
	if _battle_state != null:
		print("Battle already in progress.")
		return
	BeauSystem.set_roster(mercs)
	GuildRoster.set_roster(mercs)
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
	_battle_team_a.clear()
	_battle_team_b.clear()
	_battle_team_a.assign(halves[0] as Array)
	_battle_team_b.assign(halves[1] as Array)
	var split_a := ", ".join(_battle_team_a.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var split_b := ", ".join(_battle_team_b.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var a_levels: int = 0
	for lm: MercenaryData in _battle_team_a:
		a_levels += ExperienceSystem.current_level(lm)
	var b_levels: int = 0
	for lm: MercenaryData in _battle_team_b:
		b_levels += ExperienceSystem.current_level(lm)
	print("AUTO SPLIT: mode=%s index=%d a=%s b=%s levels=%d/%d" % [
		mode, _battle_index, split_a, split_b, a_levels, b_levels])
	_battle_index += 1
	var g0 := Time.get_ticks_msec()
	var field := _kind_field(kind)
	_last_gen_ms = Time.get_ticks_msec() - g0
	if kind == "City":
		_last_city_tier = String(field.city.get("tier", ""))
		_last_city_size = Vector2i(field.width, field.length)
	var s0 := Time.get_ticks_msec()
	_battle_state = BattleState.create(_battle_team_a, _battle_team_b, field)
	_last_spawn_ms = Time.get_ticks_msec() - s0
	if kind == "City" and _city_spawn_only:
		_battle_state = null
		return
	_battle_line_fn = func(s: String) -> void: print_rich(s)
	var a_names := ", ".join(_battle_team_a.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var b_names := ", ".join(_battle_team_b.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var order_parts: Array[String] = []
	for i: int in range(_battle_state.turn_queue.size()):
		var m: MercenaryData = _battle_state.turn_queue[i]
		var color := "white" if _battle_team_a.has(m) else "yellow"
		order_parts.append("[color=%s]%s[/color]" % [color, m.merc_name.get_slice(" ", 0)])
	print_rich("[color=white]Team A:[/color] %s" % a_names)
	print_rich("[color=yellow]Team B:[/color] %s" % b_names)
	print_rich("Turn order: %s" % ", ".join(order_parts))
	if kind == "City":
		AutoBattle.setup(_battle_state, _battle_line_fn, "city")
	else:
		AutoBattle.setup(_battle_state, _battle_line_fn)
	if enclosed:
		HarnessRoster.log_auto_immune()
		HarnessRoster.inflict_auto_state()
	_run_battle_loop()


static func _print_battle_result() -> void:
	var winner_idx: int = _battle_state.get_winner()
	if winner_idx >= 0:
		var winning_team: Array = _battle_state.teams[winner_idx]
		var winner_names: Array[String] = []
		for m: MercenaryData in winning_team:
			winner_names.append(m.merc_name.get_slice(" ", 0))
		var w_color := "white" if winner_idx == 0 else "yellow"
		print_rich("[color=gray]=== Battle over in %d rounds ===[/color]" % _battle_state.round_number)
		print_rich("[color=%s]Team %s wins!  (%s)[/color]" % [w_color, "A" if winner_idx == 0 else "B", ", ".join(winner_names)])
	else:
		print_rich("[color=gray]=== Draw / timeout after %d rounds ===[/color]" % _battle_state.round_number)
