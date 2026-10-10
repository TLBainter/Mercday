class_name MercdaveTests

#MercDave data and model: TSVs/Mercdave.tsv, the hint .tres files, validation, faces, triggers and the
#Mercdave autoload state machine. No overlay class is used. Run with the mercdave-tests harness flag.

const HEADER: Array[String] = ["id", "label", "text", "more"]
const HELP_ROWS: int = 121
const DIALOG_IDS: Array[StringName] = [&"scene_OddJobWindow", &"scene_InvestTradeConfirm",
	&"scene_LoanAcceptConfirm", &"scene_ReviewDialog", &"scene_OrderPlacedDialog", &"scene_FeatureLockDialog",
	&"scene_TextEntryDialog"]
const DEVIL_FACES: Array[String] = ["face_devil_frown", "face_devil_smile", "face_devil_rage", "face_devil_laugh"]
const FLAG_KEY: String = "bazaar"
const TIER_KEY: String = "oddJobs"
const MISSING_KEY: String = "noSuchMercdaveKey"
const FAR_DAY: int = 999999
const WINDOW_TYPES: String = "Window|PopupPanel|PopupMenu|Popup|AcceptDialog|ConfirmationDialog|FileDialog|OptionButton|MenuButton"


#Stands in for MercdaveLayer: counts the scans Mercdave.request_scan delivers.
class ScanProbe extends Node:
	var count: int = 0

	func scan() -> void:
		count += 1


#Counts the warning lines that name one key; hears them through OS.add_logger.
class KeyWarnLog extends Logger:
	var watched: String = ""
	var hits: int = 0

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING and (code.contains(watched) or rationale.contains(watched)):
			hits += 1


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	_case_tsv(res)
	_case_files(res)
	_case_shipped_valid(res)
	_case_lock_triggers(res)
	_case_negative(res)
	_case_tell_flag(res)
	_case_faces(res)
	await _case_triggers(res, host)
	_case_memory(res)
	_case_set_scope(res)
	_case_no_auto_open(res)
	_case_spoke(res)
	_case_card(res)
	_case_read_at_open(res)
	_case_wrap(res)
	_case_scope_close(res)
	_case_no_windows(res)
	_fresh()
	return TestFixtures.summarize(res, "MERCDAVE")


static func _fresh() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()
	Mercdave.reset_for_tests()


static func _ids() -> Array[StringName]:
	return HintBook.ids()


static func _case_tsv(res: Dictionary) -> void:
	var rows: Array[PackedStringArray] = TsvReader.load_tsv(HintBook.TSV_PATH)
	var header: Array[String] = []
	for cell: String in rows[0]:
		header.append(cell)
	TestFixtures.check(res, "tsv header is id label text more", header == HEADER, ", ".join(header))
	var sys_row: Dictionary = HintBook.row(HintBook.SYS_NONE)
	TestFixtures.check(res, "tsv has sys_none", not sys_row.is_empty() and HintBook.label(HintBook.SYS_NONE) == "Mercdave",
		"label '%s'" % HintBook.label(HintBook.SYS_NONE))
	var ids: Array[StringName] = _ids()
	var missing: Array[String] = []
	for id: StringName in DIALOG_IDS:
		if not ids.has(id):
			missing.append(String(id))
	TestFixtures.check(res, "tsv has 121 help rows incl. the 7 dialog ids",
		ids.size() == HELP_ROWS and missing.is_empty(), "%d rows, missing %s" % [ids.size(), ", ".join(missing)])
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(HintBook.TSV_PATH)
	var bad: int = 0
	for b: int in bytes:
		if b > 127 or b == 13:
			bad += 1
	TestFixtures.check(res, "tsv is ASCII with LF lines", not bytes.is_empty() and bad == 0, "%d bad bytes" % bad)


static func _case_files(res: Dictionary) -> void:
	var ids: Array[StringName] = _ids()
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(HintBook.HINT_DIR):
		if file.ends_with(".tres"):
			files.append(file.get_basename())
	var no_file: Array[String] = []
	var bad_id: Array[String] = []
	for id: StringName in ids:
		if not files.has(String(id)):
			no_file.append(String(id))
		elif HintBook.hint(id) == null or HintBook.hint(id).id() != id:
			bad_id.append(String(id))
	var no_row: Array[String] = []
	for base: String in files:
		if HintBook.priority(StringName(base)) < 0:
			no_row.append(base)
	TestFixtures.check(res, "every help row has its .tres", no_file.is_empty(), TestFixtures.detail(no_file, ids.size(), "rows"))
	TestFixtures.check(res, "every .tres has a help row", no_row.is_empty() and files.size() == ids.size(),
		TestFixtures.detail(no_row, files.size(), "files"))
	TestFixtures.check(res, "id() is the file basename", bad_id.is_empty(), TestFixtures.detail(bad_id, ids.size(), "hints"))


static func _case_shipped_valid(res: Dictionary) -> void:
	var bad: Array[String] = []
	for id: StringName in _ids():
		var found: PackedStringArray = HintBook.problems(HintBook.hint(id), HintBook.row(id))
		if not found.is_empty():
			bad.append("%s: %s" % [id, ", ".join(found)])
	TestFixtures.check(res, "every shipped hint validates", bad.is_empty(), TestFixtures.detail(bad, _ids().size(), "hints"))
	TestFixtures.check(res, "zero HintBook warnings on the shipped data", HintBook.warnings.is_empty(),
		"; ".join(HintBook.warnings))


static func _case_lock_triggers(res: Dictionary) -> void:
	var bad: Array[String] = []
	for key: StringName in GameHUD.LOCK_DEFS:
		var row: Dictionary = GameHUD.LOCK_DEFS[key]
		var id: StringName = StringName("menu_" + String(key))
		var trig: UnlockTrigger = HintBook.hint(id).trigger as UnlockTrigger
		if trig == null or trig.entitlement != String(row["entitlement"]) or trig.tier != int(row["tier"]):
			bad.append(String(id))
	TestFixtures.check(res, "locked menu tiles carry an UnlockTrigger keyed as GameHUD.LOCK_DEFS", bad.is_empty(),
		"keys %s, bad [%s]" % [str(GameHUD.LOCK_DEFS.keys()), ", ".join(bad)])


static func _make(trigger: HintTrigger, face: int) -> MercdaveHint:
	var made: MercdaveHint = MercdaveHint.new()
	made.trigger = trigger
	made.face = face
	return made


static func _group(mode: int, list: Array[HintTrigger]) -> TriggerGroup:
	var group: TriggerGroup = TriggerGroup.new()
	group.mode = mode
	group.triggers = list
	return group


#Lays a fixture's trigger, face and row text over a shipped hint, asks Mercdave, then restores it.
static func _available_with(id: StringName, fixture: MercdaveHint, fixture_row: Dictionary) -> bool:
	var shipped: MercdaveHint = HintBook.hint(id)
	var shipped_row: Dictionary = HintBook.row(id)
	var saved: Array = [shipped.trigger, shipped.face, shipped_row["label"], shipped_row["text"]]
	shipped.trigger = fixture.trigger
	shipped.face = fixture.face
	shipped_row["label"] = fixture_row["label"]
	shipped_row["text"] = fixture_row["text"]
	var available: bool = Mercdave.is_available(id)
	shipped.trigger = saved[0]
	shipped.face = int(saved[1])
	shipped_row["label"] = saved[2]
	shipped_row["text"] = saved[3]
	return available


static func _case_negative(res: Dictionary) -> void:
	var good_row: Dictionary = {"label": "Label", "text": "Text", "more": ""}
	var day_zero: DayTrigger = DayTrigger.new()
	day_zero.min_day = 0
	var inner: TriggerGroup = _group(TriggerGroup.MODE_OR, [FirstViewTrigger.new(), null])
	var fixtures: Array[Array] = [
		["null trigger", _make(null, 2), good_row],
		["face -99", _make(FirstViewTrigger.new(), MercdaveHint.FACE_UNSET), good_row],
		["empty label", _make(FirstViewTrigger.new(), 2), {"label": "", "text": "Text", "more": ""}],
		["empty text", _make(FirstViewTrigger.new(), 2), {"label": "Label", "text": "", "more": ""}],
		["empty TriggerGroup", _make(_group(TriggerGroup.MODE_AND, []), 2), good_row],
		["TriggerGroup null entry", _make(_group(TriggerGroup.MODE_AND, [FirstViewTrigger.new(), null]), 2), good_row],
		["nested group null entry", _make(_group(TriggerGroup.MODE_AND, [inner]), 2), good_row],
		["DayTrigger min_day 0", _make(day_zero, 2), good_row],
		["UnlockTrigger empty key", _make(UnlockTrigger.new(), 2), good_row],
	]
	var probe_id: StringName = _ids()[0]
	for entry: Array in fixtures:
		var fixture: MercdaveHint = entry[1]
		var found: PackedStringArray = HintBook.problems(fixture, entry[2] as Dictionary)
		var available: bool = _available_with(probe_id, fixture, entry[2] as Dictionary)
		TestFixtures.check(res, "%s: one problem, not available" % entry[0], found.size() == 1 and not available,
			"problems [%s] available %s" % [", ".join(found), str(available)])
	var plain: MercdaveHint = _make(FirstViewTrigger.new(), 2)
	var clean: PackedStringArray = HintBook.problems(plain, good_row)
	TestFixtures.check(res, "empty more and more_face -99 are no problem",
		clean.is_empty() and plain.more_face == MercdaveHint.FACE_UNSET and Mercdave.is_available(probe_id),
		"problems [%s]" % ", ".join(clean))


static func _case_tell_flag(res: Dictionary) -> void:
	var flagged: int = 0
	var mismatched: Array[String] = []
	for id: StringName in _ids():
		var has_text: bool = HintBook.more(id).strip_edges() != ""
		if HintBook.has_more(id):
			flagged += 1
		if HintBook.has_more(id) != has_text:
			mismatched.append(String(id))
	TestFixtures.check(res, "Tell Me More flag follows more (0 at ship)", mismatched.is_empty() and flagged == 0,
		"%d flagged, mismatched %s" % [flagged, ", ".join(mismatched)])


static func _case_faces(res: Dictionary) -> void:
	var bad: Array[String] = []
	for level: int in range(-5, 6):
		var got: String = MercdaveHint.icon_id(level)
		if got != MoodFace.face_id_for(0, true, level, false) or not got.ends_with("_o") or not Icons.has(got):
			bad.append("%d:%s" % [level, got])
	TestFixtures.check(res, "faces -5..5 draw the _o opinion twin", bad.is_empty(), ", ".join(bad))
	bad.clear()
	for i: int in range(DEVIL_FACES.size()):
		var got: String = MercdaveHint.icon_id(20 + i)
		if got != DEVIL_FACES[i] or not Icons.has(got):
			bad.append("%d:%s" % [20 + i, got])
	TestFixtures.check(res, "faces 20-23 draw the devil faces", bad.is_empty(), ", ".join(bad))
	var unselected: String = MercdaveHint.icon_id(MercdaveHint.FACE_UNSELECTED)
	TestFixtures.check(res, "face 30 draws face_unselected_o", unselected == "face_unselected_o" and Icons.has(unselected),
		unselected)
	var made: MercdaveHint = _make(FirstViewTrigger.new(), 3)
	var fallback: int = made.more_level()
	made.more_face = -2
	TestFixtures.check(res, "more_level falls back to face, else more_face", fallback == 3 and made.more_level() == -2,
		"%d then %d" % [fallback, made.more_level()])


static func _case_triggers(res: Dictionary, host: Node) -> void:
	TestFixtures.check(res, "FirstViewTrigger is met", FirstViewTrigger.new().is_met(), "")
	var day: DayTrigger = DayTrigger.new()
	day.min_day = GameState.day() + 1
	var before: bool = day.is_met()
	TestFixtures.pass_days(1)
	TestFixtures.check(res, "DayTrigger unmet before min_day, met on it", not before and day.is_met(),
		"before %s after %s" % [str(before), str(day.is_met())])
	var unlock: UnlockTrigger = UnlockTrigger.new()
	unlock.entitlement = FLAG_KEY
	SubscriptionManager.set_entitlements({FLAG_KEY: false})
	var off: bool = unlock.is_met()
	SubscriptionManager.set_entitlements({FLAG_KEY: true})
	TestFixtures.check(res, "UnlockTrigger follows a flag key off and on", not off and unlock.is_met(),
		"off %s on %s" % [str(off), str(unlock.is_met())])
	unlock.entitlement = TIER_KEY
	unlock.tier = 2
	SubscriptionManager.set_entitlements({TIER_KEY: 1})
	var below: bool = unlock.is_met()
	unlock.tier = 1
	TestFixtures.check(res, "UnlockTrigger tier below fails, at passes", not below and unlock.is_met(),
		"below %s at %s" % [str(below), str(unlock.is_met())])
	unlock.entitlement = MISSING_KEY
	FeatureLock.warned_keys.erase(MISSING_KEY)
	var warn_log: KeyWarnLog = KeyWarnLog.new()
	warn_log.watched = MISSING_KEY
	OS.add_logger(warn_log)
	var first: bool = unlock.is_met()
	var second: bool = unlock.is_met()
	OS.remove_logger(warn_log)
	TestFixtures.check(res, "UnlockTrigger unknown key is false with one warning",
		not first and not second and warn_log.hits == 1, "%d warnings" % warn_log.hits)
	SubscriptionManager.max_out()
	_case_groups(res)
	await _case_watch(res, host)


static func _case_groups(res: Dictionary) -> void:
	var yes: HintTrigger = FirstViewTrigger.new()
	var no: HintTrigger = HintTrigger.new()
	var and_mode: int = TriggerGroup.MODE_AND
	var or_mode: int = TriggerGroup.MODE_OR
	var got: Array[bool] = [
		_group(and_mode, [yes, yes]).is_met(), _group(and_mode, [yes, no]).is_met(),
		_group(and_mode, [no, yes]).is_met(), _group(and_mode, [no, no]).is_met(),
	]
	TestFixtures.check(res, "TriggerGroup AND truth table", got == [true, false, false, false], str(got))
	got = [
		_group(or_mode, [yes, yes]).is_met(), _group(or_mode, [yes, no]).is_met(),
		_group(or_mode, [no, yes]).is_met(), _group(or_mode, [no, no]).is_met(),
	]
	TestFixtures.check(res, "TriggerGroup OR truth table", got == [true, true, true, false], str(got))
	var nested_yes: bool = _group(or_mode, [no, _group(and_mode, [yes, yes])]).is_met()
	var nested_no: bool = _group(or_mode, [no, _group(and_mode, [yes, no])]).is_met()
	TestFixtures.check(res, "OR containing an AND group", nested_yes and not nested_no,
		"%s %s" % [str(nested_yes), str(nested_no)])


static func _case_watch(res: Dictionary, host: Node) -> void:
	var probe: ScanProbe = ScanProbe.new()
	host.add_child(probe)
	probe.add_to_group(Mercdave.LAYER_GROUP)
	var day: DayTrigger = DayTrigger.new()
	day.min_day = FAR_DAY
	var outer: TriggerGroup = _group(TriggerGroup.MODE_OR, [HintTrigger.new(),
		_group(TriggerGroup.MODE_AND, [FirstViewTrigger.new(), day])])
	outer.watch(Mercdave.request_scan)
	outer.watch(Mercdave.request_scan)
	var relay: Callable = Mercdave.request_scan.unbind(1)
	var links: int = 0
	for link: Dictionary in GameState.day_changed.get_connections():
		if link["callable"] == relay:
			links += 1
	await TestFixtures.frames(host)
	probe.count = 0
	TestFixtures.pass_days(1)
	await TestFixtures.frames(host)
	TestFixtures.check(res, "group watch reaches a nested DayTrigger: one scan per day",
		probe.count == 1 and links == 1, "%d scans, %d links" % [probe.count, links])
	if GameState.day_changed.is_connected(relay):
		GameState.day_changed.disconnect(relay)
	probe.queue_free()


static func _user_hint_files() -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at("user://"):
		if file.to_lower().begins_with("mercdave"):
			out.append(file)
	return out


static func _case_memory(res: Dictionary) -> void:
	var before: Array[String] = _user_hint_files()
	Mercdave.reset_for_tests()
	var id: StringName = _ids()[0]
	Mercdave.set_scope(&"t8", [id], [id])
	Mercdave.toggle()
	Mercdave.ok()
	var read_now: bool = Mercdave.is_read(id) and not Mercdave.card_open
	var after: Array[String] = _user_hint_files()
	TestFixtures.check(res, "ok marks read; no user://mercdave file", read_now and before.is_empty() and after.is_empty(),
		"read %s, files %s / %s" % [str(read_now), ", ".join(before), ", ".join(after)])
	Mercdave.reset_for_tests()
	var cleared: bool = not Mercdave.is_read(id)
	Mercdave.set_scope(&"t8", [id], [id])
	TestFixtures.check(res, "reset_for_tests clears read state",
		cleared and Mercdave.unread.has(id) and not Mercdave.card_open,
		"cleared %s unread %s open %s" % [str(cleared), str(Mercdave.unread), str(Mercdave.card_open)])


static func _case_set_scope(res: Dictionary) -> void:
	Mercdave.reset_for_tests()
	var ids: Array[StringName] = _ids()
	var first: Array[StringName] = [ids[0], ids[1], ids[2], ids[3], ids[4]]
	var shuffled: Array[StringName] = [ids[4], &"no_such_hint", ids[2], HintBook.SYS_NONE, ids[0], ids[3], ids[1]]
	Mercdave.set_scope(&"t9a", shuffled, shuffled)
	TestFixtures.check(res, "set_scope: unread in TSV order, every visible unread id a mark",
		Mercdave.unread == first and Mercdave.marks == first,
		"unread %s marks %s" % [str(Mercdave.unread), str(Mercdave.marks)])
	Mercdave.set_scope(&"t9b", shuffled, [ids[3], ids[0]])
	TestFixtures.check(res, "set_scope: marks only from visible ids", Mercdave.marks == [ids[0], ids[3]],
		str(Mercdave.marks))
	var unmet_hint: MercdaveHint = HintBook.hint(ids[1])
	var invalid_hint: MercdaveHint = HintBook.hint(ids[2])
	var saved_trigger: HintTrigger = unmet_hint.trigger
	var far: DayTrigger = DayTrigger.new()
	far.min_day = FAR_DAY
	unmet_hint.trigger = far
	invalid_hint.face = MercdaveHint.FACE_UNSET
	Mercdave.set_scope(&"t9c", shuffled, shuffled)
	var kept: Array[StringName] = Mercdave.unread.duplicate()
	unmet_hint.trigger = saved_trigger
	invalid_hint.face = 2
	TestFixtures.check(res, "set_scope: unavailable and invalid hints excluded", kept == [ids[0], ids[3], ids[4]],
		str(kept))


static func _case_no_auto_open(res: Dictionary) -> void:
	Mercdave.reset_for_tests()
	var ids: Array[StringName] = _ids()
	var pair: Array[StringName] = [ids[0], ids[1]]
	Mercdave.set_scope(&"t10", pair, pair)
	var shut: bool = not Mercdave.card_open
	Mercdave.toggle()
	var opened: bool = Mercdave.card_open and Mercdave.current == ids[0]
	Mercdave.close()
	Mercdave.set_scope(&"t10", pair, pair)
	TestFixtures.check(res, "no auto-open: the card opens only from the tab or a marker",
		shut and opened and not Mercdave.card_open,
		"shut %s opened %s open %s" % [str(shut), str(opened), str(Mercdave.card_open)])


static func _case_spoke(res: Dictionary) -> void:
	_fresh()
	var a: StringName = &""
	var b: StringName = &""
	for id: StringName in _ids():
		if not HintBook.is_valid(id):
			continue
		if a == &"":
			a = id
		elif b == &"" and HintBook.has_more(id):
			b = id
	#No shipped hint has more text today, so the next valid id borrows some the way _case_card does.
	var borrowed: bool = b == &""
	if borrowed:
		for id: StringName in _ids():
			if id != a and HintBook.is_valid(id):
				b = id
				break
		HintBook.row(b)["more"] = "More text"
	var hits: Array[int] = [0]
	var count: Callable = func() -> void: hits[0] += 1
	Mercdave.spoke.connect(count)
	Mercdave.show_hint(a)
	var first: int = hits[0]
	Mercdave.show_hint(a)
	var again: int = hits[0]
	TestFixtures.check(res, "spoke fires once when a hint opens from a closed card and not for the same hint again",
		first == 1 and again == 1, "a %s b %s counts %d then %d" % [a, b, first, again])
	Mercdave.show_hint(b)
	var other: int = hits[0]
	Mercdave.tell_more()
	var more: int = hits[0]
	Mercdave.tell_more()
	var more_again: int = hits[0]
	TestFixtures.check(res, "spoke fires for a different hint and once for Tell Me More",
		other == 2 and more == 3 and more_again == 3,
		"borrowed more %s counts %d, %d, %d" % [str(borrowed), other, more, more_again])
	Mercdave.close()
	var closed: int = hits[0]
	Mercdave.toggle()
	var toggled: int = hits[0]
	Mercdave.ok()
	var oked: int = hits[0]
	TestFixtures.check(res, "close and ok stay silent and toggle from a closed card speaks once",
		closed == 3 and toggled == 4 and oked == 4, "counts %d, %d, %d" % [closed, toggled, oked])
	Mercdave.spoke.disconnect(count)
	if borrowed:
		HintBook.row(b)["more"] = ""
	_fresh()


static func _case_card(res: Dictionary) -> void:
	Mercdave.reset_for_tests()
	var ids: Array[StringName] = _ids()
	var three: Array[StringName] = [ids[0], ids[1], ids[2]]
	Mercdave.set_scope(&"t11", three, three)
	Mercdave.toggle()
	var order: Array[StringName] = [Mercdave.current]
	for _i: int in 2:
		Mercdave.next_hint()
		order.append(Mercdave.current)
	TestFixtures.check(res, "next_hint reads the shown hint and shows the next",
		order == [ids[0], ids[1], ids[2]] and Mercdave.is_read(ids[0]) and Mercdave.is_read(ids[1])
			and Mercdave.is_read(ids[2]) and Mercdave.marks.is_empty() and Mercdave.card_open,
		"order %s marks %s open %s" % [str(order), str(Mercdave.marks), str(Mercdave.card_open)])
	Mercdave.tell_more()
	TestFixtures.check(res, "no Tell Me More when more is empty", not HintBook.has_more(ids[2]) and not Mercdave.showing_more,
		"showing_more %s" % str(Mercdave.showing_more))
	Mercdave.ok()
	TestFixtures.check(res, "ok marks read and closes", Mercdave.is_read(ids[2]) and not Mercdave.card_open,
		"read %s open %s" % [str(Mercdave.is_read(ids[2])), str(Mercdave.card_open)])
	var last: Array[StringName] = [ids[3]]
	Mercdave.set_scope(&"t11b", last, last)
	Mercdave.toggle()
	Mercdave.next_hint()
	TestFixtures.check(res, "next_hint on the last mark reads it and closes the card",
		Mercdave.is_read(ids[3]) and not Mercdave.card_open and Mercdave.marks.is_empty(),
		"read %s open %s marks %s" % [str(Mercdave.is_read(ids[3])), str(Mercdave.card_open), str(Mercdave.marks)])
	var row: Dictionary = HintBook.row(ids[1])
	var shown: MercdaveHint = HintBook.hint(ids[1])
	row["more"] = "More text"
	shown.more_face = -3
	Mercdave.show_hint(ids[1])
	var plain_face: int = Mercdave.face_level()
	Mercdave.tell_more()
	var more_face: int = Mercdave.face_level()
	var showing: bool = Mercdave.showing_more
	row["more"] = ""
	shown.more_face = MercdaveHint.FACE_UNSET
	TestFixtures.check(res, "tell_more sets showing_more and face_level switches to more_level",
		showing and plain_face == 2 and more_face == -3, "showing %s faces %d then %d" % [str(showing), plain_face, more_face])
	Mercdave.close()


static func _case_read_at_open(res: Dictionary) -> void:
	Mercdave.reset_for_tests()
	var all: Array[StringName] = _ids()
	var three: Array[StringName] = [all[0], all[1], all[2]]
	Mercdave.set_scope(&"t14", three, three)
	var ids: Array[StringName] = Mercdave.marks.duplicate()
	var count: int = ids.size()
	Mercdave.show_hint(ids[0])
	TestFixtures.check(res, "show_hint marks the hint read and drops its mark at once",
		Mercdave.is_read(ids[0]) and not Mercdave.unread.has(ids[0]) and not Mercdave.marks.has(ids[0])
			and Mercdave.card_open and Mercdave.step == 0 and Mercdave.step_total == count,
		"marks %s step %d of %d" % [str(Mercdave.marks), Mercdave.step, Mercdave.step_total])
	Mercdave.close()
	var still: bool = Mercdave.is_read(ids[0])
	Mercdave.set_scope(&"t14", three, three)
	TestFixtures.check(res, "close by clicking out keeps the hint read",
		still and not Mercdave.marks.has(ids[0]) and not Mercdave.unread.has(ids[0]),
		"read %s marks %s" % [str(still), str(Mercdave.marks)])
	Mercdave.reset_for_tests()
	Mercdave.set_scope(&"t14", three, three)
	Mercdave.show_hint(ids[0])
	Mercdave.next_hint()
	var second: Array = [Mercdave.current, Mercdave.step, Mercdave.step_total]
	Mercdave.next_hint()
	TestFixtures.check(res, "next_hint steps the chain",
		second == [ids[1], 1, count] and Mercdave.current == ids[2] and Mercdave.step == 2 and not Mercdave.has_next(),
		"second %s last %s step %d next %s" % [str(second), Mercdave.current, Mercdave.step, str(Mercdave.has_next())])
	Mercdave.close()


static func _case_wrap(res: Dictionary) -> void:
	Mercdave.reset_for_tests()
	var all: Array[StringName] = _ids()
	var five: Array[StringName] = all.slice(0, mini(5, all.size()))
	Mercdave.set_scope(&"t15", five, five)
	var ids: Array[StringName] = Mercdave.marks.duplicate()
	var count: int = ids.size()
	if count < 3:
		TestFixtures.check(res, "a hint opened mid-list counts 1 of N", false, "only %d marks" % count)
		return
	var start: int = count - 2
	Mercdave.show_hint(ids[start])
	TestFixtures.check(res, "a hint opened mid-list counts 1 of N",
		Mercdave.current == ids[start] and Mercdave.step == 0 and Mercdave.step_total == count
			and not Mercdave.marks.has(ids[start]) and Mercdave.card_open,
		"current %s step %d of %d" % [Mercdave.current, Mercdave.step, Mercdave.step_total])
	var seen: Array = []
	var want: Array = []
	var order: Array[StringName] = [ids[start + 1]]
	order.append_array(ids.slice(0, start))
	for i: int in count - 1:
		Mercdave.next_hint()
		seen.append([Mercdave.current, Mercdave.step, Mercdave.step_total, Mercdave.has_next(), Mercdave.card_open])
		want.append([order[i], i + 1, count, i < count - 2, true])
	TestFixtures.check(res, "next_hint continues forward, wraps to the first remaining mark and keeps counting",
		seen == want, "seen %s want %s" % [str(seen), str(want)])
	Mercdave.next_hint()
	var all_read: bool = true
	for id: StringName in ids:
		all_read = all_read and Mercdave.is_read(id)
	TestFixtures.check(res, "next_hint after the last remaining mark closes the card",
		not Mercdave.card_open and Mercdave.marks.is_empty() and all_read,
		"open %s marks %s read %s" % [str(Mercdave.card_open), str(Mercdave.marks), str(all_read)])
	Mercdave.reset_for_tests()
	var three: Array[StringName] = [all[0], all[1], all[2]]
	Mercdave.set_scope(&"t15b", three, three)
	var ids3: Array[StringName] = Mercdave.marks.duplicate()
	Mercdave.show_hint(ids3[0])
	var four: Array[StringName] = three.duplicate()
	four.append(all[3])
	Mercdave.set_scope(&"t15b", four, four)
	Mercdave.next_hint()
	TestFixtures.check(res, "a mark that appears mid-read raises the total",
		Mercdave.current == ids3[1] and Mercdave.step == 1 and Mercdave.step_total == 4 and Mercdave.card_open,
		"current %s step %d of %d open %s" % [Mercdave.current, Mercdave.step, Mercdave.step_total, str(Mercdave.card_open)])
	Mercdave.close()
	Mercdave.reset_for_tests()


static func _case_scope_close(res: Dictionary) -> void:
	Mercdave.reset_for_tests()
	var ids: Array[StringName] = _ids()
	var pair: Array[StringName] = [ids[0], ids[1]]
	var none: Array[StringName] = []
	Mercdave.set_scope(&"t12a", pair, pair)
	Mercdave.toggle()
	var opened: bool = Mercdave.card_open
	Mercdave.set_scope(&"t12b", none, none)
	TestFixtures.check(res, "scope key change closes the card", opened and not Mercdave.card_open,
		"opened %s open %s" % [str(opened), str(Mercdave.card_open)])
	var later: Array[StringName] = [ids[1], ids[2]]
	Mercdave.set_scope(&"t12c", later, later)
	Mercdave.toggle()
	var reopened: bool = Mercdave.card_open and Mercdave.current == ids[1]
	var rest: Array[StringName] = [ids[2]]
	Mercdave.set_scope(&"t12c", rest, rest)
	TestFixtures.check(res, "current hint leaving present_ids closes the card", reopened and not Mercdave.card_open,
		"reopened %s open %s" % [str(reopened), str(Mercdave.card_open)])
	Mercdave.set_scope(&"t12d", none, none)
	Mercdave.toggle()
	TestFixtures.check(res, "empty scope toggle opens sys_none",
		Mercdave.card_open and Mercdave.current == HintBook.SYS_NONE and Mercdave.face_level() == Mercdave.SYS_FACE,
		"open %s current %s face %d" % [str(Mercdave.card_open), Mercdave.current, Mercdave.face_level()])
	Mercdave.toggle()
	TestFixtures.check(res, "toggle closes an open card", not Mercdave.card_open, "")


#Check 13: no scene node and no script base is a Window, a popup or an engine popup button.
static func _case_no_windows(res: Dictionary) -> void:
	var node_rx: RegEx = RegEx.create_from_string("(?m)^\\[node [^\\n]*type=\"(%s)\"" % WINDOW_TYPES)
	var base_rx: RegEx = RegEx.create_from_string("(?m)^(class_name\\s+\\w+\\s+)?extends\\s+(%s)\\b" % WINDOW_TYPES)
	var fixture: String = "[node name=\"Menu\" type=\"PopupPanel\" parent=\".\"]\n[node name=\"Role\" type=\"OptionButton\"]\n" \
		+ "[node name=\"Drop\" type=\"PanelContainer\"]\nclass_name Pick extends MenuButton\nextends PopupButton\n"
	var sees_fixture: bool = node_rx.search_all(fixture).size() == 2 and base_rx.search_all(fixture).size() == 1
	var offenders: Array[String] = []
	var scenes: Array[String] = _files_under("res://Scenes", ".tscn")
	for path: String in scenes:
		for hit: RegExMatch in node_rx.search_all(FileAccess.get_file_as_string(path)):
			offenders.append("%s %s" % [path, hit.get_string(1)])
	var scripts: Array[String] = _files_under("res://Scripts", ".gd")
	for path: String in scripts:
		for hit: RegExMatch in base_rx.search_all(FileAccess.get_file_as_string(path)):
			offenders.append("%s extends %s" % [path, hit.get_string(2)])
	for line: String in offenders:
		print("  window-family offender: %s" % line)
	TestFixtures.check(res, "no Window-family node or OptionButton/MenuButton in Scenes and no Scripts base",
		sees_fixture and offenders.is_empty() and scenes.size() > 100 and scripts.size() > 100,
		"fixture %s, %d offenders in %d scenes, %d scripts" % [sees_fixture, offenders.size(), scenes.size(), scripts.size()])


static func _files_under(root: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var dirs: Array[String] = [root]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(suffix):
				out.append(dir.path_join(file))
	return out
