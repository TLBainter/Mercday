class_name GuiCrewTests

#The shared Odd Job atom set: FitStars, CrewCandidates, EnvoySlot, SendMercsPanel, PayMercsPanel,
#CrewMercPicker, OddJobCrew and OddJobWindow. Run with the --gui-crew-tests harness flag.

const FIT_STARS_SCENE: String = "res://Scenes/GUI/Shared/FitStars.tscn"
const ENVOY_SLOT_SCENE: String = "res://Scenes/GUI/Shared/EnvoySlot.tscn"
const SEND_PANEL_SCENE: String = "res://Scenes/GUI/Shared/SendMercsPanel.tscn"
const PAY_PANEL_SCENE: String = "res://Scenes/GUI/Shared/PayMercsPanel.tscn"
const PICKER_SCENE: String = "res://Scenes/GUI/Shared/CrewMercPicker.tscn"
const CREW_SCENE: String = "res://Scenes/GUI/Shared/OddJobCrew.tscn"
const WINDOW_SCENE: String = "res://Scenes/GUI/Shared/OddJobWindow.tscn"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_fit_stars(res, host)
	_case_crew_candidates(res, host)
	await _case_envoy_slot(res, host)
	await _case_send_mercs_panel(res, host)
	await _case_pay_mercs_panel(res, host)
	await _case_crew_merc_picker(res, host)
	await _case_odd_job_crew(res, host)
	await _case_odd_job_window(res, host)
	return TestFixtures.summarize(res, "GUI CREW")


static func _case_fit_stars(res: Dictionary, host: Node) -> void:
	var color_checks: Array[Array] = [
		[0.5, "#e8583f"], [1.0, "#ec6a36"], [1.5, "#ef7c2f"], [2.0, "#f28c28"], [2.5, "#f2a033"],
		[3.0, "#f2b33d"], [3.5, "#5aa6e8"], [4.0, "#5fb0b8"], [4.5, "#64b98c"], [5.0, "#3fae5a"],
	]
	for pair: Array in color_checks:
		var value: float = float(pair[0])
		var expect: Color = Color(String(pair[1]))
		var got: Color = FitStars.color_of(value)
		TestFixtures.check(res, "FitStars.color_of(%s) matches the table" % value,
			got.is_equal_approx(expect), "got %s" % got.to_html(false))
	TestFixtures.check(res, "color_of clamps below 0.5 to 0.5",
		FitStars.color_of(0.1).is_equal_approx(Color("#e8583f")), "")
	TestFixtures.check(res, "color_of clamps above 5.0 to 5.0",
		FitStars.color_of(9.0).is_equal_approx(Color("#3fae5a")), "")
	TestFixtures.check(res, "color_of rounds to the nearest half step",
		FitStars.color_of(1.24).is_equal_approx(Color("#ec6a36")), "")
	var star: FitStars = (load(FIT_STARS_SCENE) as PackedScene).instantiate()
	host.add_child(star)
	await host.get_tree().process_frame
	star.cell = 2
	await host.get_tree().process_frame
	var expected_size: Vector2 = Vector2((5.0 * 9.0 + 4.0) * 2.0, 9.0 * 2.0)
	TestFixtures.check(res, "the minimum size follows the cell size",
		star.get_combined_minimum_size().is_equal_approx(expected_size),
		"got %s" % star.get_combined_minimum_size())
	star.value = 0.2
	TestFixtures.check(res, "the value setter clamps below 0.5", star.value == 0.5, "got %s" % star.value)
	star.value = 5.9
	TestFixtures.check(res, "the value setter clamps above 5.0", star.value == 5.0, "got %s" % star.value)
	star.value = 2.24
	TestFixtures.check(res, "the value setter snaps to the nearest half step",
		star.value == 2.0, "got %s" % star.value)
	star.queue_free()


static func _case_crew_candidates(res: Dictionary, _host: Node) -> void:
	var saved_roster: Array[MercView] = GameState.roster
	var saved_mercs: Array[MercenaryData] = GameState.mercs
	var a := MercView.new()
	a.uid = 9101
	a.name = "Anna"
	a.status = GuiTypes.MercStatus.AVAILABLE
	var b := MercView.new()
	b.uid = 9102
	b.name = "Bram"
	b.status = GuiTypes.MercStatus.AVAILABLE
	var c := MercView.new()
	c.uid = 9103
	c.name = "Cora"
	c.status = GuiTypes.MercStatus.RESTING
	var d := MercView.new()
	d.uid = 9104
	d.name = "Dez"
	d.status = GuiTypes.MercStatus.CONTRACT
	var e := MercView.new()
	e.uid = 9105
	e.name = "Elm"
	e.status = GuiTypes.MercStatus.VACATION
	var f := MercView.new()
	f.uid = 9106
	f.name = "Fay"
	f.status = GuiTypes.MercStatus.AVAILABLE
	GameState.roster = [a, b, c, d, e, f]
	var busy_merc: MercenaryData = TestFixtures.flat_merc("BusyOne")
	busy_merc.merc_uid = 9101
	busy_merc.on_contract = true
	GameState.mercs = [busy_merc]
	var fit_map: Dictionary = {9101: 1.0, 9102: 4.0, 9103: 4.0, 9106: 2.3}
	var fit_fn := func(uid: int) -> float: return float(fit_map.get(uid, 0.5))
	var rows: Array[Dictionary] = CrewCandidates.from_roster(fit_fn, [9106])
	var ids: Array[int] = []
	for row: Dictionary in rows:
		ids.append(int(row.get("id", -1)))
	TestFixtures.check(res, "from_roster excludes the exclude list, busy and off-status mercs",
		ids == [9102, 9103], "got %s" % str(ids))
	TestFixtures.check(res, "from_roster sorts by fit descending then name",
		rows[0]["name"] == "Bram" and rows[1]["name"] == "Cora", "got %s" % str(ids))
	var snap_map: Dictionary = {9102: 3.24, 9103: 3.26}
	var snap_fn := func(uid: int) -> float: return float(snap_map.get(uid, 0.5))
	var snap_rows: Array[Dictionary] = CrewCandidates.from_roster(snap_fn, [9106])
	var by_id: Dictionary = {}
	for row: Dictionary in snap_rows:
		by_id[int(row["id"])] = row["fit"]
	TestFixtures.check(res, "fit rounds 3.24 down to 3.0",
		is_equal_approx(float(by_id.get(9102, 0.0)), 3.0), "got %s" % str(by_id))
	TestFixtures.check(res, "fit rounds 3.26 up to 3.5",
		is_equal_approx(float(by_id.get(9103, 0.0)), 3.5), "got %s" % str(by_id))
	var clamp_map: Dictionary = {9102: -4.0, 9103: 40.0}
	var clamp_fn := func(uid: int) -> float: return float(clamp_map.get(uid, 0.5))
	var clamped: Array[Dictionary] = CrewCandidates.from_roster(clamp_fn, [9106])
	var clamped_by_id: Dictionary = {}
	for row: Dictionary in clamped:
		clamped_by_id[int(row["id"])] = row["fit"]
	TestFixtures.check(res, "fit clamps to a 0.5 floor",
		is_equal_approx(float(clamped_by_id.get(9102, 0.0)), 0.5), "got %s" % str(clamped_by_id))
	TestFixtures.check(res, "fit clamps to a 5.0 ceiling",
		is_equal_approx(float(clamped_by_id.get(9103, 0.0)), 5.0), "got %s" % str(clamped_by_id))
	GameState.roster = saved_roster
	GameState.mercs = saved_mercs


static func _case_envoy_slot(res: Dictionary, host: Node) -> void:
	var slot: EnvoySlot = (load(ENVOY_SLOT_SCENE) as PackedScene).instantiate()
	host.add_child(slot)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a new slot starts empty", not slot.is_filled(), "")
	TestFixtures.check(res, "an empty slot dims to EMPTY_OPACITY",
		is_equal_approx(slot.empty_box.modulate.a, EnvoySlot.EMPTY_OPACITY),
		"got %s" % slot.empty_box.modulate.a)
	TestFixtures.check(res, "an empty slot reads Add Merc",
		slot.add_label.text == "Add Merc" and slot.plus_label.text == "+", "")
	var pressed_indices: Array[int] = []
	slot.slot_pressed.connect(func(i: int) -> void: pressed_indices.append(i))
	slot.index = 3
	slot.press()
	TestFixtures.check(res, "press emits slot_pressed with the slot index",
		pressed_indices == [3], "got %s" % str(pressed_indices))
	slot.merc_id = 77
	slot.merc_name = "Rook"
	slot.fit = 3.0
	TestFixtures.check(res, "setting merc_id fills the slot", slot.is_filled(), "")
	TestFixtures.check(res, "a filled slot shows the remove button and the name",
		slot.remove_button.visible and slot.name_label.text == "Rook", "")
	TestFixtures.check(res, "a filled slot hides the empty box and shows the filled box",
		not slot.empty_box.visible and slot.filled_box.visible, "")
	TestFixtures.check(res, "a filled slot drops the empty dim",
		is_equal_approx(slot.empty_box.modulate.a, 1.0), "got %s" % slot.empty_box.modulate.a)
	var removed_indices: Array[int] = []
	slot.remove_pressed.connect(func(i: int) -> void: removed_indices.append(i))
	slot.press_remove()
	TestFixtures.check(res, "press_remove emits remove_pressed with the slot index",
		removed_indices == [3], "got %s" % str(removed_indices))
	slot.merc_id = -1
	slot.tip_kind = "Renegotiate"
	slot.tip_text = "Send a merc to renegotiate."
	slot.mouse_entered.emit()
	var tip: TooltipPanel = slot.tip_panel()
	TestFixtures.check(res, "hovering an empty slot shows the tip with its kind and text",
		tip != null and tip.visible and tip.title_label.text == "Renegotiate"
			and tip.body_label.text == "Send a merc to renegotiate.", "")
	TestFixtures.check(res, "the slot tip is top level and draws above every open frame",
		tip.top_level and tip.z_index == TooltipPanel.TOOLTIP_Z
			and tip.z_index > GuiFrameStack.MAX_Z,
		"top_level %s z %d" % [tip.top_level, tip.z_index])
	slot.merc_id = 88
	TestFixtures.check(res, "filling a slot while it is hovered hides the tip",
		not tip.visible, "")
	slot.merc_id = -1
	slot.mouse_entered.emit()
	slot.mouse_exited.emit()
	TestFixtures.check(res, "leaving the slot hides the tip", not tip.visible, "")
	slot.merc_id = 5
	slot.mouse_entered.emit()
	TestFixtures.check(res, "a filled slot never shows the hover tip", not tip.visible, "")
	slot.queue_free()


static func _case_send_mercs_panel(res: Dictionary, host: Node) -> void:
	var panel: SendMercsPanel = (load(SEND_PANEL_SCENE) as PackedScene).instantiate()
	host.add_child(panel)
	await host.get_tree().process_frame
	var rows_in: Array[Dictionary] = [
		{"index": 0, "merc_id": 11, "merc_name": "Ida", "fit": 4.0},
		{"index": 1, "merc_id": -1, "merc_name": "", "fit": 0.5},
	]
	panel.set_slots(rows_in)
	TestFixtures.check(res, "set_slots builds one EnvoySlot per row",
		panel.slot_count() == 2, "got %d" % panel.slot_count())
	TestFixtures.check(res, "a slot from set_slots carries its row fields",
		panel.slot(0).merc_id == 11 and panel.slot(0).merc_name == "Ida", "")
	TestFixtures.check(res, "an empty row builds an empty slot", not panel.slot(1).is_filled(), "")
	var pressed: Array[int] = []
	panel.slot_pressed.connect(func(i: int) -> void: pressed.append(i))
	panel.slot(1).press()
	TestFixtures.check(res, "a slot press bubbles up as slot_pressed",
		pressed == [1], "got %s" % str(pressed))
	var removed: Array[int] = []
	panel.remove_pressed.connect(func(i: int) -> void: removed.append(i))
	panel.slot(0).press_remove()
	TestFixtures.check(res, "a slot remove bubbles up as remove_pressed",
		removed == [0], "got %s" % str(removed))
	TestFixtures.check(res, "unlocked shows the slots row and hides the lock",
		panel.slots_row.visible and not panel.lock_wrap.visible, "")
	panel.locked = true
	TestFixtures.check(res, "locked hides the slots row and shows the FeatureLock",
		not panel.slots_row.visible and panel.lock_wrap.visible, "")
	var targets: Array[Dictionary] = []
	panel.take_me_there.connect(func(t: Dictionary) -> void: targets.append(t))
	panel.lock.take_me_there.emit({"tab": "billing"})
	TestFixtures.check(res, "the lock's take_me_there relays up through the panel",
		targets.size() == 1 and targets[0].get("tab", "") == "billing", "")
	panel.locked = false
	panel.queue_free()


static func _case_pay_mercs_panel(res: Dictionary, host: Node) -> void:
	var panel: PayMercsPanel = (load(PAY_PANEL_SCENE) as PackedScene).instantiate()
	host.add_child(panel)
	await host.get_tree().process_frame
	panel.team_size = 0
	TestFixtures.check(res, "Pay Mercs hides with an empty team", not panel.visible, "")
	panel.team_size = 1
	TestFixtures.check(res, "Pay Mercs shows once the team holds a merc", panel.visible, "")
	TestFixtures.check(res, "the pay items sit in one centred row with gap 16",
		panel.items_row.get_class() == "HBoxContainer"
			and panel.items_row.get_theme_constant(&"separation") == 16
			and panel.items_row.alignment == BoxContainer.ALIGNMENT_CENTER, "")
	TestFixtures.check(res, "the items row fills the panel height",
		panel.items_row.size_flags_vertical == Control.SIZE_EXPAND_FILL,
		"got %d" % panel.items_row.size_flags_vertical)
	TestFixtures.check(res, "the items row holds the four pay items",
		panel.items_row.get_child_count() == 4, "got %d" % panel.items_row.get_child_count())
	TestFixtures.check(res, "the note glyph stands after the number in the default row",
		panel.default_row.get_child(0) == panel.default_value_label
			and panel.default_row.get_child(1) == panel.default_glyph
			and panel.default_row.get_theme_constant(&"separation") == 4, "")
	TestFixtures.check(res, "the note glyph stands after the number in the total row",
		panel.total_row.get_child(0) == panel.total_label
			and panel.total_row.get_child(1) == panel.total_glyph
			and panel.total_row.get_theme_constant(&"separation") == 4, "")
	panel.default_pay = 12345
	TestFixtures.check(res, "the default bonus formats with thousands commas",
		panel.default_text() == "12,345", "got %s" % panel.default_text())
	var events: Array[int] = []
	panel.pay_changed.connect(func(v: int) -> void: events.append(v))
	panel.press_stepper_plus()
	TestFixtures.check(res, "a stepper press changes per and emits pay_changed",
		panel.per == panel.stepper_value() and events == [panel.per], "got %s" % str(events))
	panel.team_size = 3
	panel.per = 100
	TestFixtures.check(res, "total is per times the team size",
		panel.total() == 300, "got %d" % panel.total())
	panel.money = 1000
	TestFixtures.check(res, "the total prints cream under the guild's notes",
		panel.total_color().is_equal_approx(Color("#f3ead7")), "")
	panel.money = 50
	TestFixtures.check(res, "the total turns red past the guild's notes",
		panel.total_color().is_equal_approx(Color("#e8583f")), "")
	var saved_notes: int = GameState.bank_notes
	GameState.bank_notes = 5000
	panel.per = 100
	TestFixtures.check(res, "the stepper cap follows the guild's notes",
		panel.stepper.max_value == 5000, "got %d" % panel.stepper.max_value)
	panel.per = 7000
	TestFixtures.check(res, "the stepper cap never clips the current pay",
		panel.stepper.max_value >= 7000 and panel.stepper_value() == 7000,
		"got cap %d value %d" % [panel.stepper.max_value, panel.stepper_value()])
	GameState.bank_notes = saved_notes
	panel.queue_free()


static func _case_crew_merc_picker(res: Dictionary, host: Node) -> void:
	var picker: CrewMercPicker = (load(PICKER_SCENE) as PackedScene).instantiate()
	host.add_child(picker)
	await host.get_tree().process_frame
	picker.title = "Send a Merc"
	picker.pick_desc = "Sorted by best fit."
	TestFixtures.check(res, "title and pick_desc push to the labels",
		picker.title_text() == "Send a Merc" and picker.desc_text() == "Sorted by best fit.", "")
	picker.open_for(1, [], false)
	TestFixtures.check(res, "an empty candidate list shows No available mercs.",
		picker.is_empty_shown() and picker.row_count() == 0, "")
	TestFixtures.check(res, "an empty, unfilled slot hides the remove button",
		not picker.remove_visible(), "")
	picker.press_close()
	var rows_in: Array[Dictionary] = [
		{"id": 21, "name": "Vex", "fit": 4.5},
		{"id": 22, "name": "Wynn", "fit": 2.0},
	]
	picker.open_for(2, rows_in, true)
	TestFixtures.check(res, "open_for builds one row per candidate",
		picker.row_count() == 2, "got %d" % picker.row_count())
	TestFixtures.check(res, "rows carry their id, name and fit",
		picker.row_name(0) == "Vex" and picker.row_id(0) == 21
			and is_equal_approx(picker.row_fit(0), 4.5), "")
	TestFixtures.check(res, "a filled slot shows the remove button", picker.remove_visible(), "")
	TestFixtures.check(res, "Remove From Slot is the shared BevelButton scene",
		picker.remove_button is BevelButton and picker.remove_button.text == "Remove From Slot"
			and picker.remove_button.fill.is_equal_approx(Color("#2b4f8a"))
			and picker.remove_button.text_color.is_equal_approx(Color("#e8583f")),
		"fill %s text %s" % [picker.remove_button.fill, picker.remove_button.text_color])
	var row_line: HBoxContainer = picker.row_button(0).get_child(0) as HBoxContainer
	TestFixtures.check(res, "a picker row holds the portrait then one column, gap 10",
		row_line.get_child_count() == 2 and row_line.get_child(0) is MercPortrait
			and row_line.get_child(1) is VBoxContainer
			and row_line.get_theme_constant(&"separation") == CrewMercPicker.ROW_GAP, "")
	var row_col: VBoxContainer = row_line.get_child(1) as VBoxContainer
	TestFixtures.check(res, "the row column stacks the name above the stars with gap 6",
		row_col.get_child_count() == 2 and row_col.get_child(0) is Label
			and row_col.get_child(1) is FitStars
			and row_col.get_theme_constant(&"separation") == CrewMercPicker.ROW_COL_GAP, "")
	var row_portrait: MercPortrait = row_line.get_child(0) as MercPortrait
	TestFixtures.check(res, "the row portrait column is 40 px wide",
		is_equal_approx(row_portrait.custom_minimum_size.x, float(CrewMercPicker.ROW_PORTRAIT_PX)),
		"got %s" % row_portrait.custom_minimum_size)
	var picked: Array = []
	picker.picked.connect(func(slot_index: int, id: int) -> void: picked.append([slot_index, id]))
	picker.press_row(22)
	TestFixtures.check(res, "press_row emits picked with the slot index and the id",
		picked == [[2, 22]], "got %s" % str(picked))
	TestFixtures.check(res, "press_row dismisses the picker", not picker.visible, "")
	picker.open_for(2, rows_in, true)
	var removed_slots: Array[int] = []
	picker.removed.connect(func(slot_index: int) -> void: removed_slots.append(slot_index))
	picker.press_remove()
	TestFixtures.check(res, "press_remove emits removed with the slot index and dismisses",
		removed_slots == [2] and not picker.visible, "")
	picker.open_for(2, rows_in, false)
	var closed_count: Array[int] = [0]
	picker.closed.connect(func() -> void: closed_count[0] += 1)
	picker.press_close()
	TestFixtures.check(res, "press_close emits closed and dismisses",
		closed_count[0] == 1 and not picker.visible, "")
	picker.queue_free()


static func _case_odd_job_crew(res: Dictionary, host: Node) -> void:
	var crew: OddJobCrew = (load(CREW_SCENE) as PackedScene).instantiate()
	host.add_child(crew)
	await host.get_tree().process_frame
	var candidates: Array[Dictionary] = [
		{"id": 31, "name": "Ash", "fit": 2.0},
		{"id": 32, "name": "Bell", "fit": 4.0},
		{"id": 33, "name": "Cly", "fit": 3.0},
	]
	crew.candidates = candidates
	crew.default_pay = 50
	crew.money = 1000
	crew.max_mercs = 1
	crew.team = []
	TestFixtures.check(res, "max 1, an empty team shows one add slot",
		crew.send_panel.slot_count() == 1, "got %d" % crew.send_panel.slot_count())
	crew.team = [31]
	TestFixtures.check(res, "max 1, a full team shows no trailing add slot",
		crew.send_panel.slot_count() == 1, "got %d" % crew.send_panel.slot_count())
	crew.max_mercs = 2
	crew.team = []
	TestFixtures.check(res, "max 2, an empty team shows one add slot",
		crew.send_panel.slot_count() == 1, "got %d" % crew.send_panel.slot_count())
	crew.team = [31]
	TestFixtures.check(res, "max 2, one merc shows a trailing add slot",
		crew.send_panel.slot_count() == 2, "got %d" % crew.send_panel.slot_count())
	crew.team = [31, 32]
	TestFixtures.check(res, "max 2, a full team shows no trailing add slot",
		crew.send_panel.slot_count() == 2, "got %d" % crew.send_panel.slot_count())
	crew.max_mercs = 3
	crew.team = []
	TestFixtures.check(res, "max 3, an empty team shows one add slot",
		crew.send_panel.slot_count() == 1, "got %d" % crew.send_panel.slot_count())
	crew.team = [31]
	TestFixtures.check(res, "max 3, one merc shows two slots",
		crew.send_panel.slot_count() == 2, "got %d" % crew.send_panel.slot_count())
	crew.team = [31, 32]
	TestFixtures.check(res, "max 3, two mercs shows three slots",
		crew.send_panel.slot_count() == 3, "got %d" % crew.send_panel.slot_count())
	crew.team = [31, 32, 33]
	TestFixtures.check(res, "max 3, a full team shows no trailing add slot",
		crew.send_panel.slot_count() == 3, "got %d" % crew.send_panel.slot_count())

	var team_events: Array = []
	crew.team_changed.connect(func(t: Array[int]) -> void: team_events.append(t.duplicate()))
	crew.team = []
	crew.add_merc(31)
	TestFixtures.check(res, "add_merc appends a new id", crew.team == [31], "got %s" % str(crew.team))
	crew.add_merc(31)
	TestFixtures.check(res, "add_merc ignores an id already on the team",
		crew.team == [31], "got %s" % str(crew.team))
	crew.add_merc(32)
	crew.add_merc(33)
	TestFixtures.check(res, "add_merc fills the team up to max_mercs",
		crew.team == [31, 32, 33], "got %s" % str(crew.team))
	crew.add_merc(34)
	TestFixtures.check(res, "add_merc refuses past a full team",
		crew.team == [31, 32, 33], "got %s" % str(crew.team))
	crew.remove_merc(32)
	TestFixtures.check(res, "remove_merc closes the gap",
		crew.team == [31, 33], "got %s" % str(crew.team))
	TestFixtures.check(res, "every team mutation emitted team_changed exactly once",
		team_events.size() == 5, "got %d" % team_events.size())

	crew.team = [31, 33]
	crew.open_picker(1)
	var picker_ids: Array[int] = []
	for i: int in crew.picker().row_count():
		picker_ids.append(crew.picker().row_id(i))
	TestFixtures.check(res, "the picker leaves out mercs already in another slot",
		not picker_ids.has(31) and picker_ids.has(32), "got %s" % str(picker_ids))
	TestFixtures.check(res, "the picker still offers the occupant of the slot itself",
		picker_ids.has(33), "got %s" % str(picker_ids))
	TestFixtures.check(res, "the picker sorts its rows by fit descending",
		crew.picker().row_id(0) == 32, "got %s" % str(picker_ids))
	crew.picker().press_row(32)
	TestFixtures.check(res, "picking a new id fills the target slot",
		crew.team == [31, 32], "got %s" % str(crew.team))

	crew.team = [31, 32, 33]
	crew.open_picker(0)
	crew.picker().press_row(33)
	TestFixtures.check(res, "picking an id already on the team moves it, overwriting the target",
		crew.team == [33, 32], "got %s" % str(crew.team))

	crew.team = [31, 32]
	crew.open_picker(1)
	crew.picker().press_remove()
	TestFixtures.check(res, "removing from the picker closes the gap",
		crew.team == [31], "got %s" % str(crew.team))

	var pay_events: Array[int] = []
	crew.pay_changed.connect(func(v: int) -> void: pay_events.append(v))
	crew.per = 77
	TestFixtures.check(res, "per pushes to the pay panel and emits pay_changed",
		crew.pay_panel.per == 77 and pay_events == [77], "got %s" % str(pay_events))
	crew.team = [31, 32]
	TestFixtures.check(res, "total is per times the team size",
		crew.total() == 154, "got %d" % crew.total())

	crew.size = Vector2(900.0, 300.0)
	crew.team = []
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "the crew row took the width the block was given",
		crew.cols.size.x > 800.0, "got %s" % crew.cols.size.x)
	TestFixtures.check(res, "the pay column stays in the row while the pay panel hides",
		not crew.pay_panel.visible and crew.pay_col.visible, "")
	TestFixtures.check(res, "Send Mercs keeps its column with the pay panel hidden",
		crew.send_panel.size.x <= crew.cols.size.x * 0.6,
		"send %s of %s" % [crew.send_panel.size.x, crew.cols.size.x])

	TestFixtures.check(res, "unlocked by default", not crew.send_panel.locked, "")
	crew.locked = true
	TestFixtures.check(res, "locked pushes through to the send panel", crew.send_panel.locked, "")
	var relayed: Array[Dictionary] = []
	crew.take_me_there.connect(func(t: Dictionary) -> void: relayed.append(t))
	crew.send_panel.lock.take_me_there.emit({"tab": "billing"})
	TestFixtures.check(res, "take_me_there relays all the way up from the FeatureLock",
		relayed.size() == 1 and relayed[0].get("tab", "") == "billing", "")
	crew.locked = false
	crew.queue_free()


static func _case_odd_job_window(res: Dictionary, host: Node) -> void:
	var window: OddJobWindow = (load(WINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(window)
	await host.get_tree().process_frame
	var uid_odds: Dictionary = {401: 5, 402: 38, 403: 60, 404: 95, 405: 45}
	var odds_fn := func(team: Array[int]) -> int:
		if team.is_empty():
			return 0
		return int(uid_odds.get(team[0], 0))
	var config: Dictionary = {
		"title": "Renegotiate the Fine",
		"facts": [
			{"label": "Fine", "value": "500", "color": Color("#e8583f")},
			{"label": "Days Left", "value": "3"},
		],
		"max_mercs": 3,
		"candidates": [
			{"id": 401, "name": "Ash", "fit": 4.0},
			{"id": 402, "name": "Bell", "fit": 3.0},
			{"id": 403, "name": "Cly", "fit": 2.0},
			{"id": 404, "name": "Dex", "fit": 1.0},
			{"id": 405, "name": "Eff", "fit": 0.5},
		],
		"default_pay": 40,
		"money": 1000,
		"odds": odds_fn,
		"boost_text": "",
		"send_label": "Send",
	}
	window.open(config)
	TestFixtures.check(res, "open sets the title", window.title_label.text == "Renegotiate the Fine", "")
	TestFixtures.check(res, "the facts grid builds one cell per fact",
		window.facts_grid.get_child_count() == 2, "got %d" % window.facts_grid.get_child_count())
	var cell0: PanelContainer = window.facts_grid.get_child(0) as PanelContainer
	var line0: HBoxContainer = cell0.get_child(0) as HBoxContainer
	var label0: Label = line0.get_child(0) as Label
	var value0: Label = line0.get_child(1) as Label
	TestFixtures.check(res, "a fact cell shows its label and value",
		label0.text == "Fine" and value0.text == "500", "")
	TestFixtures.check(res, "a fact's own colour overrides the default",
		value0.get_theme_color(&"font_color").is_equal_approx(Color("#e8583f")), "")
	var cell1: PanelContainer = window.facts_grid.get_child(1) as PanelContainer
	var line1: HBoxContainer = cell1.get_child(0) as HBoxContainer
	var value1: Label = line1.get_child(1) as Label
	TestFixtures.check(res, "a fact without a colour uses the default cream",
		value1.get_theme_color(&"font_color").is_equal_approx(Color("#f3ead7")), "")
	TestFixtures.check(res, "the facts grid uses gap 8 on both axes",
		window.facts_grid.get_theme_constant(&"h_separation") == 8
			and window.facts_grid.get_theme_constant(&"v_separation") == 8, "")
	TestFixtures.check(res, "every fact cell expands so the four columns are equal",
		cell0.size_flags_horizontal == Control.SIZE_EXPAND_FILL
			and cell1.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"got %d" % cell0.size_flags_horizontal)
	TestFixtures.check(res, "a fact cell puts label and value side by side with gap 8",
		line0.get_theme_constant(&"separation") == 8
			and value0.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
			and value0.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "")
	var box_style: StyleBoxFlat = window.box.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "the window box wears the crew window chrome",
		box_style != null and box_style.bg_color.is_equal_approx(Color("#1a2b4d"))
			and box_style.border_color.is_equal_approx(Color("#f28c28"))
			and box_style.border_width_left == 4 and box_style.border_width_top == 4
			and box_style.border_width_right == 4 and box_style.border_width_bottom == 4,
		"got %s" % ("null" if box_style == null else box_style.bg_color.to_html(false)))
	TestFixtures.check(res, "the box chrome adds no margin over the PROTO paddings",
		box_style != null and is_zero_approx(box_style.content_margin_left)
			and is_zero_approx(box_style.content_margin_top)
			and is_zero_approx(box_style.content_margin_right)
			and is_zero_approx(box_style.content_margin_bottom), "")
	TestFixtures.check(res, "the odds bar reserves 16 px of height",
		is_equal_approx(window.odds_bar.custom_minimum_size.y, 16.0),
		"got %s" % window.odds_bar.custom_minimum_size.y)
	TestFixtures.check(res, "the odds cells are 12 px tall inside the bar",
		is_equal_approx(window.bar_cell_height(), 12.0), "got %s" % window.bar_cell_height())
	TestFixtures.check(res, "boost_text stays hidden when it is empty", not window.boost_label.visible, "")
	TestFixtures.check(res, "an empty team prints a dash for the odds",
		window.odds_value_label.text == "-", "got %s" % window.odds_value_label.text)
	TestFixtures.check(res, "the send button starts disabled with an empty team",
		window.send_button.disabled and window.send_button.tooltip_text == "Add at least one merc.", "")

	window.crew().team = [401]
	TestFixtures.check(res, "odds 5 lights only the first cell",
		window.bar_cell_lit(0) and not window.bar_cell_lit(1), "")
	TestFixtures.check(res, "odds under 40 reads red",
		window.odds_value_label.get_theme_color(&"font_color").is_equal_approx(Color("#e8583f")), "")

	window.crew().team = [402]
	TestFixtures.check(res, "odds 38 lights 8 of 20 cells",
		window.bar_cell_lit(7) and not window.bar_cell_lit(8), "")

	window.crew().team = [405]
	TestFixtures.check(res, "odds 45 reads yellow",
		window.odds_value_label.get_theme_color(&"font_color").is_equal_approx(Color("#f2b33d")), "")

	window.crew().team = [403]
	TestFixtures.check(res, "odds 60 lights 12 of 20 cells",
		window.bar_cell_lit(11) and not window.bar_cell_lit(12), "")
	TestFixtures.check(res, "odds 60 or more reads green",
		window.odds_value_label.get_theme_color(&"font_color").is_equal_approx(Color("#6cc36a")), "")

	window.crew().team = [404]
	TestFixtures.check(res, "odds 95 lights 19 of 20 cells",
		window.bar_cell_lit(18) and not window.bar_cell_lit(19), "")
	TestFixtures.check(res, "odds 95 reads green",
		window.odds_value_label.get_theme_color(&"font_color").is_equal_approx(Color("#6cc36a")), "")

	window.crew().team = []
	TestFixtures.check(res, "clearing the team resets the odds percent to 0",
		window.odds_percent() == 0 and window.odds_value_label.text == "-",
		"got %d" % window.odds_percent())
	var cleared_fills: PackedColorArray = window.bar_cell_colors()
	var cleared_unlit: int = 0
	for fill: Color in cleared_fills:
		if fill.is_equal_approx(Color("#1f3560")):
			cleared_unlit += 1
	TestFixtures.check(res, "an empty team still paints the 20 unlit cells",
		cleared_fills.size() == 20 and cleared_unlit == 20,
		"got %d of %d" % [cleared_unlit, cleared_fills.size()])
	window.crew().team = [404]

	window.crew().per = 1100
	TestFixtures.check(res, "the send button disables when the total exceeds the guild's notes",
		window.send_button.disabled and window.send_button.tooltip_text == "Not enough notes.", "")
	window.crew().per = 40
	TestFixtures.check(res, "the send button re-enables once affordable", not window.send_button.disabled, "")

	var sent_payload: Array = []
	window.sent.connect(func(team: Array[int], per: int) -> void: sent_payload.append([team, per]))
	window.press_send()
	TestFixtures.check(res, "sent carries the team and the per value",
		sent_payload.size() == 1 and sent_payload[0][0] == [404] and sent_payload[0][1] == 40,
		"got %s" % str(sent_payload))
	TestFixtures.check(res, "press_send dismisses the window", not window.visible, "")

	window.open(config)
	var cancel_count: Array[int] = [0]
	window.cancelled.connect(func() -> void: cancel_count[0] += 1)
	window.press_cancel()
	TestFixtures.check(res, "press_cancel emits cancelled and dismisses",
		cancel_count[0] == 1 and not window.visible, "")

	window.open(config)
	window.show_outcome("It worked.", true)
	TestFixtures.check(res, "show_outcome in success shows green text",
		window.outcome_label.text == "It worked."
			and window.outcome_label.get_theme_color(&"font_color").is_equal_approx(Color("#6cc36a")), "")
	window.show_outcome("It failed.", false)
	TestFixtures.check(res, "show_outcome in failure shows red text",
		window.outcome_label.text == "It failed."
			and window.outcome_label.get_theme_color(&"font_color").is_equal_approx(Color("#e8583f")), "")

	var boosted: Dictionary = config.duplicate()
	boosted["boost_text"] = "+5% from morale"
	boosted["odds_label"] = "Approval Odds"
	window.open(boosted)
	TestFixtures.check(res, "boost_text shows when it is not empty",
		window.boost_label.visible and window.boost_label.text == "+5% from morale", "")
	TestFixtures.check(res, "odds_label overrides Success Odds",
		window.odds_label_node.text == "Approval Odds", "")

	var no_max: Dictionary = config.duplicate()
	no_max["max_mercs"] = 0
	window.open(no_max)
	TestFixtures.check(res, "max_mercs 0 locks the embedded crew", window.crew().locked, "")

	window.queue_free()
