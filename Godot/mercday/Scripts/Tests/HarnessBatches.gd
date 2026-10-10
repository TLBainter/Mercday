class_name HarnessBatches
extends RefCounted

#Drives the automated encounter and contract batches.


#Runs `count` autobattles of one kind back to back; `pre` takes the battle index and `post` the index
#and the elapsed milliseconds, so the city batch can seed its map and report its file sizes.
static func _run_auto_batch(mercs: Array[MercenaryData], count: int, kind: String, pre: Callable,
		post: Callable) -> void:
	var label: String = "AUTO " + kind.to_upper()
	for i: int in range(count):
		_reset_trial()
		if pre.is_valid():
			pre.call(i)
		var t0 := Time.get_ticks_msec()
		BattleHarness.start_battle(mercs, kind)
		var guard := 0
		while BattleHarness.battle_state != null and guard < 600000:
			guard += 1
			await Engine.get_main_loop().process_frame
		if BattleHarness.battle_state != null:
			print("%s: battle %d did not finish" % [label, i + 1])
			CriticalSuccessSystem.banking = false
			BattleHarness.battle_state = null
		var ms: int = Time.get_ticks_msec() - t0
		if post.is_valid():
			post.call(i, ms)
		print("ENCOUNTER MS: %d" % ms)


#Runs `count` Interior, Cavern or Dungeon autobattles back to back, then quits the engine.
static func run_auto_kind(host: Node, mercs: Array[MercenaryData], count: int, kind: String) -> void:
	await _run_auto_batch(mercs, count, kind, Callable(), Callable())
	if kind != "Interior":
		_print_called_shots()
	if kind == "Cavern":
		print("CAVE-INS TOTAL: %d" % CaveInSystem.triggered_total)
	host.get_tree().quit()


#Fresh generator penalties per trial; "--auto-forget" also empties campaign knowledge.
static func _reset_trial() -> void:
	TestFixtures.reset_generator_rolls()
	if OS.get_cmdline_user_args().has("--auto-forget"):
		CampaignKnowledge.clear()


static func _print_called_shots() -> void:
	print("CALLED SHOTS: made %d, landed %d" % [CalledShotSystem.calls_made, CalledShotSystem.calls_landed])


#Runs `count` city autobattles back to back, then quits the engine.
#tier holds every map to one CityGenerator tier; base_seed >= 0 seeds battle i with base_seed + i.
static func run_auto_city(host: Node, mercs: Array[MercenaryData], count: int, tier: String,
		base_seed: int) -> void:
	BattleHarness.city_tier = tier
	BattleHarness.city_spawn_only = OS.get_cmdline_user_args().has("--auto-city-spawn-only")
	var pre := func(_i: int) -> void:
		if base_seed >= 0:
			seed(base_seed + _i)
		BattleHarness.last_rounds = 0
		BattleHarness.last_winner = -1
	var post := func(_i: int, ms: int) -> void:
		var map_seed: int = (base_seed + _i) if base_seed >= 0 else -1
		var log_kb: int = 0
		var html_kb: int = 0
		var level_kb: int = 0
		var battle_ms: int = 0
		if not BattleHarness.city_spawn_only:
			var log_path: String = EncounterLogger.current_log_path()
			var stem: String = log_path.get_basename()
			log_kb = _file_kb(log_path)
			html_kb = _file_kb(stem + "_3d.html") + _file_kb(stem + "_end.html")
			level_kb = _file_kb(stem + "_level.txt")
			battle_ms = ms - BattleHarness.last_gen_ms - BattleHarness.last_spawn_ms
		print("CITY BATTLE %03d tier=%s seed=%d size=%dx%d gen_ms=%d spawn_ms=%d battle_ms=%d rounds=%d winner=%d log_kb=%d html_kb=%d level_kb=%d" % [
			_i, BattleHarness.last_city_tier, map_seed, BattleHarness.last_city_size.x,
			BattleHarness.last_city_size.y, BattleHarness.last_gen_ms, BattleHarness.last_spawn_ms, battle_ms,
			BattleHarness.last_rounds, BattleHarness.last_winner, log_kb, html_kb, level_kb])
	await _run_auto_batch(mercs, count, "City", pre, post)
	_print_called_shots()
	host.get_tree().quit()


#Size of one file in whole kb rounded up; 0 when the path is empty or the file is missing.
static func _file_kb(path: String) -> int:
	if path == "":
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var bytes: int = f.get_length()
	f.close()
	return ceili(float(bytes) / 1024.0)


#Runs count test contracts back to back, then quits the engine.
static func run_auto_contract(host: Node, mercs: Array[MercenaryData], count: int) -> void:
	MercPool.clear()
	for i: int in range(count):
		_reset_trial()
		await HarnessContracts.run_test_contract(mercs)
	_print_called_shots()
	print("KIDNAP: rolls %d, kidnaps %d" % [KidnapSystem.rolls_made, KidnapSystem.kidnaps_total])
	host.get_tree().quit()


#Runs count rescue contracts back to back, then quits the engine.
static func run_auto_rescue(host: Node, mercs: Array[MercenaryData], count: int) -> void:
	MercPool.clear()
	RescueContractBuilder.pending_records.clear()
	HarnessContracts.rescue_runs = 0
	HarnessContracts.rescue_stealth = 0
	HarnessContracts.rescue_combat = 0
	HarnessContracts.rescue_failed = 0
	for i: int in range(count):
		_reset_trial()
		await HarnessContracts.run_rescue_contract(mercs)
	print("RESCUE: runs %d, stealth %d, combat %d, failed %d" % [HarnessContracts.rescue_runs,
		HarnessContracts.rescue_stealth, HarnessContracts.rescue_combat, HarnessContracts.rescue_failed])
	host.get_tree().quit()
