class_name PlayTests

#The "--auto-play" driver's helpers: default row, solo team builder, flags and the summary math.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_default_row(res)
	_case_team(res)
	_case_flags(res)
	_case_state_restore(res)
	_case_summary_math(res)
	_case_summary_block(res)
	await _case_no_save(res)
	return TestFixtures.summarize(res, "PLAY")


static func _case_default_row(res: Dictionary) -> void:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(HarnessPlays.LIVE_SHEET)
	var first: String = rows[1][0].strip_edges() if rows.size() > 1 and rows[1].size() > 0 else ""
	var row: String = HarnessPlays.default_row()
	TestFixtures.check(res, "play:default_row_first_live", row != "" and row == first,
		"default %s first %s" % [row, first])
	TestFixtures.check(res, "play:default_row_not_stock", not HarnessEntry.STOCK_CONTRACTS.has(row), row)


static func _case_team(res: Dictionary) -> void:
	var previous: int = MercGenerator.forced_level
	var solo: Array[MercenaryData] = HarnessPlays.make_team(1, 1)
	var level: int = ExperienceSystem.current_level(solo[0])
	TestFixtures.check(res, "play:solo_level_1", solo.size() == 1 and level == 1,
		"size %d level %d" % [solo.size(), level])
	TestFixtures.check(res, "play:forced_level_restored", MercGenerator.forced_level == previous,
		"forced %d previous %d" % [MercGenerator.forced_level, previous])
	var trio: Array[MercenaryData] = HarnessPlays.make_team(3, 2)
	var levels: Array[int] = []
	for merc: MercenaryData in trio:
		levels.append(ExperienceSystem.current_level(merc))
	TestFixtures.check(res, "play:team_size_and_level", trio.size() == 3 and levels.count(2) == 3,
		"size %d levels %s" % [trio.size(), str(levels)])
	var floor_team: Array[MercenaryData] = HarnessPlays.make_team(0, 0)
	TestFixtures.check(res, "play:team_floor_one", floor_team.size() == 1
		and ExperienceSystem.current_level(floor_team[0]) == 1, "size %d" % floor_team.size())
	var centre: float = GenLevel.centre(solo, solo, [] as Array[MercenaryData])
	TestFixtures.check(res, "play:solo_level_centre_1", is_equal_approx(centre, 1.0), "centre %.3f" % centre)
	var line: String = HarnessPlays.merc_line(solo[0])
	TestFixtures.check(res, "play:merc_line", line.contains("level 1") and line.contains("EP ")
		and line.contains("Dexterity ") and line.contains("Wile ") and _ascii(line), line)


static func _case_state_restore(res: Dictionary) -> void:
	var pinned: Array[String] = ContractLibrary.pinned_names.duplicate()
	var mercs: Array[MercenaryData] = GameState.mercs.duplicate()
	var kept: Dictionary = HarnessPlays.save_state()
	ContractLibrary.pinned_names = ["Play Test Row"]
	GameState.mercs.assign(HarnessPlays.make_team(2, 1))
	HarnessPlays.restore_state(kept)
	TestFixtures.check(res, "play:pinned_names_restored", ContractLibrary.pinned_names == pinned,
		"pinned %s previous %s" % [str(ContractLibrary.pinned_names), str(pinned)])
	TestFixtures.check(res, "play:mercs_restored", GameState.mercs == mercs,
		"mercs %d previous %d" % [GameState.mercs.size(), mercs.size()])
	ContractLibrary.pinned_names = pinned
	GameState.mercs.assign(mercs)


static func _case_flags(res: Dictionary) -> void:
	var missing: Array[String] = []
	for flag: String in ["--auto-play", "--play-row", "--play-level", "--play-team"]:
		if not HarnessEntry.EXTRA_FLAGS.has(flag):
			missing.append(flag)
	TestFixtures.check(res, "play:flags_registered", missing.is_empty(), "missing %s" % str(missing))


static func _case_summary_math(res: Dictionary) -> void:
	var pcts: String = "%s %s %s %s" % [HarnessPlays.pct(1, 3), HarnessPlays.pct(2, 3), HarnessPlays.pct(0, 0),
		HarnessPlays.pct(3, 3)]
	TestFixtures.check(res, "play:pct_format", pcts == "33% 67% 0% 100%", pcts)
	var hist: String = HarnessPlays.histogram_text({"1.0": 2, "0.5": 1})
	TestFixtures.check(res, "play:histogram_sorted", hist == "0.5:1 1.0:2", hist)
	var spread: String = HarnessPlays.spread(_synthetic(), "value")
	TestFixtures.check(res, "play:spread_min_mean_max", spread == "10.0/20.0/30.0", spread)


static func _case_summary_block(res: Dictionary) -> void:
	var results: Array[Dictionary] = _synthetic()
	results.append({"posted": false, "reason": "no issuer seat", "anomalies": []})
	var lines: Array[String] = HarnessPlays.summary_lines(results)
	var text: String = "\n".join(PackedStringArray(lines))
	TestFixtures.check(res, "play:summary_counts", lines[0] == "PLAY SUMMARY"
		and text.contains("plays=4 posted=3 no_post=1") and text.contains("succeeded=2 (67%) failed=1"), text)
	TestFixtures.check(res, "play:summary_rolls", text.contains("first_roll_pass=33% retry_used=67%")
		and text.contains("mean_attempts=1.7") and text.contains("mean_clock_minutes=620.0"), text)
	TestFixtures.check(res, "play:summary_ep_and_hist", text.contains("ep_drains=1 mean_loss=2.0")
		and text.contains("difficulty=0.5:2 1.0:1") and text.contains("level=1:3")
		and text.contains("mean_odds=50% actual_success=67%"), text)
	TestFixtures.check(res, "play:summary_tradition_and_anomalies",
		text.contains("success_by_tradition=Hellion 50% of 2; Warrior 100% of 1") and text.contains("ANOMALIES=1")
		and text.contains("play 3: no post (no issuer seat)"), text)


#Three posted plays: a first-roll pass, a retry pass and a retry fail with an EP drain of 2.
static func _synthetic() -> Array[Dictionary]:
	var base: Dictionary = {"posted": true, "anomalies": [], "level": 1, "location": "Aerdis", "issuer_type": "person/people",
		"description": "A cat is stuck.", "mishaps": 0, "distance_km": 5, "deadline_h": 24.0, "completion_h": 2,
		"verdict": "Succeeded", "casualties": 0, "level_ups": 0, "ep_before": 10, "ep_after": 10}
	var out: Array[Dictionary] = []
	var rows: Array = [
		{"success": true, "first_pass": true, "retry": false, "attempts": 1, "minutes": 600, "value": 10,
			"difficulty": 0.5, "odds": 40, "tradition": "Hellion"},
		{"success": true, "first_pass": false, "retry": true, "attempts": 2, "minutes": 620, "value": 20,
			"difficulty": 0.5, "odds": 50, "tradition": "Warrior"},
		{"success": false, "first_pass": false, "retry": true, "attempts": 2, "minutes": 640, "value": 30,
			"difficulty": 1.0, "odds": 60, "tradition": "Hellion", "verdict": "Failed", "ep_after": 8},
	]
	for extra: Dictionary in rows:
		var r: Dictionary = base.duplicate(true)
		r.merge(extra, true)
		out.append(r)
	return out


#The contract_<n>.tres names in the harness save folder; [] when the folder is missing.
static func _saved_names() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(HarnessContracts.SAVE_DIR)
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if file_name.begins_with("contract_") and file_name.ends_with(".tres"):
			out.append(file_name)
	return out


#An auto-play run writes no contract file, while the other _run_saved callers still save one (#704).
static func _case_no_save(res: Dictionary) -> void:
	var config: ContractConfig = ContractLibrary.config()
	var kept_flag: bool = config.save_generated_contracts
	var kept_running: bool = BattleHarness.contract_running
	var kept: Dictionary = HarnessPlays.save_state()
	config.save_generated_contracts = true
	BattleHarness.contract_running = false
	var before: Array[String] = _saved_names()
	var team: Array[MercenaryData] = HarnessPlays.make_team(1, 1)
	var contract: ContractData = ContractGenerator.generate_named("Cat Stuck in Tree!")
	var run: ContractRun = await HarnessContracts.run_on_team(contract, team, "PLAY TEST NO SAVE")
	var after_play: int = _saved_names().size()
	TestFixtures.check(res, "play:auto_play_no_save", run != null and after_play == before.size(),
		"run %s, files %d before %d after" % [run != null, before.size(), after_play])
	TestFixtures.set_roster(team)
	var contract_b: ContractData = ContractGenerator.generate_named("Cat Stuck in Tree!")
	var saved_run: ContractRun = await HarnessContracts._run_saved(contract_b, team, [], "PLAY TEST SAVE")
	var after: Array[String] = _saved_names()
	TestFixtures.check(res, "play:run_saved_default_saves", saved_run != null and after.size() == before.size() + 1,
		"run %s, files %d before %d after" % [saved_run != null, before.size(), after.size()])
	for file_name: String in after:
		if not before.has(file_name):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(HarnessContracts.SAVE_DIR + "/" + file_name))
	config.save_generated_contracts = kept_flag
	BattleHarness.contract_running = kept_running
	HarnessPlays.restore_state(kept)
	CampaignClock.reset()


static func _ascii(text: String) -> bool:
	for i: int in range(text.length()):
		if text.unicode_at(i) > 126:
			return false
	return true
