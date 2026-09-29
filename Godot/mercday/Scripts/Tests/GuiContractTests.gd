class_name GuiContractTests

#Stage 2 contract screens: ContractList, ContractFilterPanel, ContractDetail, ContractViewer and
#DispatchWindow, all driven through the live GameState autoload.
#Run: the headless harness flag gui-contract-tests, after the bare argument separator.

const VIEWER: PackedScene = preload("res://Scenes/GUI/Contracts/ContractViewer.tscn")
const WINDOW: PackedScene = preload("res://Scenes/GUI/Contracts/DispatchWindow.tscn")
const OLD_DIR_TOGGLE_SCENE: String = "res://Scenes/GUI/Shared/DirToggle.tscn"
const SORT_DIR_TOGGLE_SCENE: String = "res://Scenes/GUI/Shared/SortDirToggle.tscn"

const CLEAR_TEXT: String = "This will clear all changes to this dispatch."
const OPTIMIZE_TEXT: String = "Optimizing will clear your current configuration. Are you sure?"
const CANCEL_TEXT: String = "Canceling will discard any changes you have made to this dispatch."
const CAUTION_TEXT: String = "Chances of success are low! This team may fail the contract. Continue?"
const WARN_TEXT: String = "Chances of success are extremely low! This team is unlikely to succeed. Continue?"

const NIGHT_MINUTE: int = TrynnCalendar.START_MINUTE - 8 * 60 + 23 * 60


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	await host.get_tree().process_frame
	await _case_list(res, host)
	await _case_filter(res, host)
	await _case_detail(res, host)
	await _case_reject(res, host)
	await _case_show_closed(res, host)
	await _case_pulse(res, host)
	await _case_row_extras(res, host)
	await _case_tooltip(res, host)
	await _case_payout(res, host)
	await _case_dispatch_window(res, host)
	await _case_preview_rows(res, host)
	await _case_summary_meta(res, host)
	await _case_team_controls(res, host)
	await _case_slots(res, host)
	await _case_picker(res, host)
	await _case_dialogs(res, host)
	await _case_travel_rows(res, host)
	await _case_action_bar(res, host)
	await _case_dialog_kinds(res, host)
	await _case_commit(res, host)
	await _case_failed(res, host)
	await _case_receipt_escape(res, host)
	await _case_next_available(res, host)
	await _case_night_queue(res, host)
	await _case_description_tokens(res, host)
	await _case_row_layout(res, host)
	await _case_detail_layout(res, host)
	await _case_decision_colors(res, host)
	await _case_drag_ghost(res, host)
	await _case_slot_roles(res, host)
	await _case_trait_scroll(res, host)
	await _case_roster_rows(res, host)
	await _case_picker_overlay(res, host)
	await _case_window_fit(res, host)
	await _case_decision_palettes(res, host)
	await _case_shown_status(res, host)
	await _case_result_rows(res, host)
	await _case_pay_rows(res, host)
	await _case_filter_options(res, host)
	await _case_reveal(res, host)
	await _case_results_host(res, host)
	await _case_results_dismiss(res, host)
	await _case_sort_toggle(res, host)
	await _case_claim_keeps_selection(res, host)
	await _case_claim_no_scene_fallback(res, host)
	await _case_claim_selection_narrow(res, host)
	_case_bonus_pct_placeholder(res)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI CONTRACT")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


static func _viewer(host: Node) -> ContractViewer:
	var node: ContractViewer = VIEWER.instantiate()
	host.add_child(node)
	return node


static func _open_count() -> int:
	var total: int = 0
	for view: ContractView in GameState.contracts:
		if view.status != GuiTypes.ContractStatus.COMPLETED:
			total += 1
	return total


static func _ids(views: Array[ContractView]) -> Array[int]:
	var out: Array[int] = []
	for view: ContractView in views:
		out.append(view.entry_id)
	return out


#A sorted copy of GameState.busy_uids(), so two reads compare by value.
static func _busy_now() -> Array[int]:
	var out: Array[int] = GameState.busy_uids().duplicate()
	out.sort()
	return out


#True when the busy list has not moved since the case took its own snapshot.
static func _same_busy(before: Array[int]) -> bool:
	return _busy_now() == before


#True when the listed difficulties never rise (descending) or never fall (ascending).
static func _monotonic(views: Array[ContractView], descending: bool) -> bool:
	for i: int in range(1, views.size()):
		var back: float = views[i - 1].difficulty
		var front: float = views[i].difficulty
		if descending and front > back:
			return false
		if not descending and front < back:
			return false
	return true


static func _first_open(viewer: ContractViewer) -> ContractView:
	for view: ContractView in viewer.list().listed():
		if view.status == GuiTypes.ContractStatus.AVAILABLE:
			return view
	return null


#The listed row carrying one posting, or null when the filter hides it.
static func _row_of(panel: ContractList, entry_id: int) -> ContractListItem:
	for i: int in panel.row_count():
		var row: ContractListItem = panel.row_at(i)
		if row != null and row.entry_id() == entry_id:
			return row
	return null


#The roster row for one merc, or null when the merc is not listed.
static func _roster_row(panel: DispatchRoster, uid: int) -> DispatchRosterItem:
	for i: int in panel.row_count():
		var row: DispatchRosterItem = panel.row_at(i)
		if row != null and row.merc_uid() == uid:
			return row
	return null


#A dispatch window over a posting widened to five slots, two of them required, so the slot
#cases never depend on the band the board happened to roll.
static func _wide_window(view: ContractView, host: Node) -> DispatchWindow:
	view.merc_min = 2
	view.merc_max = 5
	var node: DispatchWindow = WINDOW.instantiate()
	node.contract = view
	host.add_child(node)
	await host.get_tree().process_frame
	return node


static func _case_list(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var open_rows: int = _open_count()
	TestFixtures.check(res, "the list shows every open posting",
		viewer.list().row_count() == open_rows,
		"rows %d of %d" % [viewer.list().row_count(), open_rows])
	var listed: Array[ContractView] = viewer.list().listed()
	TestFixtures.check(res, "the first row starts selected",
		listed.size() > 0 and viewer.detail().name_text() == listed[0].name,
		"detail %s" % viewer.detail().name_text())
	var third: ContractView = listed[mini(2, listed.size() - 1)]
	viewer.select_entry(third.entry_id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "select_entry moves the detail",
		viewer.detail().entry_id() == third.entry_id and viewer.detail().name_text() == third.name,
		"detail id %d wanted %d" % [viewer.detail().entry_id(), third.entry_id])
	var dearest: int = 0
	for view: ContractView in GameState.contracts:
		dearest = maxi(dearest, view.reward)
	var by_value: Array[ContractView] = ContractList.sorted(GameState.contracts,
		ContractList.Sort.VALUE, true)
	TestFixtures.check(res, "Value descending puts the richest posting first",
		by_value.size() > 0 and by_value[0].reward == dearest,
		"top %d of %d" % [by_value[0].reward, dearest])
	var by_type: Array[ContractView] = ContractList.sorted(GameState.contracts,
		ContractList.Sort.TYPE, false)
	var alphabetical: bool = true
	for i: int in range(1, by_type.size()):
		if by_type[i].type < by_type[i - 1].type:
			alphabetical = false
	TestFixtures.check(res, "Type ascending is alphabetical", alphabetical,
		"%d rows" % by_type.size())
	TestFixtures.check(res, "the board starts on descending difficulty",
		_monotonic(viewer.list().listed(), true), "%d rows" % viewer.list().row_count())
	viewer.list().dir_toggle.toggle()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the direction toggle flips the order",
		not viewer.list().dir_toggle.descending and _monotonic(viewer.list().listed(), false),
		"%d rows" % viewer.list().row_count())
	viewer.queue_free()


static func _case_filter(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var open_rows: int = viewer.list().row_count()
	var closed_id: int = viewer.list().listed()[0].entry_id
	var entry: BoardEntry = GameState.board.entry(closed_id)
	entry.status = BoardEntry.STATUS_SUCCEEDED
	entry.closed_minute = CampaignClock.now()
	if entry.contract != null:
		entry.contract.status = "Succeeded"
	GameState.refresh_views()
	GameState.contracts_changed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a settled posting drops off the board",
		not viewer.list().has_id(closed_id) and viewer.list().row_count() == open_rows - 1,
		"rows %d of %d" % [viewer.list().row_count(), open_rows - 1])
	var rules: Dictionary = viewer.list().filter_panel.filter()
	rules["show_completed"] = true
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Completed option brings the settled posting back",
		viewer.list().has_id(closed_id) and viewer.list().row_count() == open_rows,
		"rows %d of %d" % [viewer.list().row_count(), open_rows])
	var nearest: int = ContractList.OPEN_DISTANCE
	for view: ContractView in viewer.list().listed():
		nearest = mini(nearest, view.distance_km)
	rules = viewer.list().filter_panel.filter()
	rules["max_distance"] = maxi(0, nearest - 1)
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a distance cap under the nearest posting empties the list",
		viewer.list().row_count() == 0 and viewer.list().empty_label.visible,
		"rows %d" % viewer.list().row_count())
	viewer.list().filter_panel.reset()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Reset puts the open count back",
		viewer.list().row_count() == open_rows - 1,
		"rows %d of %d" % [viewer.list().row_count(), open_rows - 1])
	viewer.queue_free()


static func _case_detail(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	var buttons: DecisionButtons = viewer.detail().decisions()
	TestFixtures.check(res, "an open posting offers Accept and Reject only",
		buttons.accept_button.visible and buttons.reject_button.visible
		and not buttons.cancel_button.visible,
		"accept %s reject %s cancel %s" % [buttons.accept_button.visible,
		buttons.reject_button.visible, buttons.cancel_button.visible])
	var counter: MercCount = viewer.detail().counter()
	TestFixtures.check(res, "the merc count reads the posting band",
		counter.required == view.merc_min and counter.allowed == view.merc_max,
		"%d of %d wanted %d of %d" % [counter.required, counter.allowed, view.merc_min,
		view.merc_max])
	var wanted: Array[int] = [view.recommended_knowledges.size(), view.recommended_tools.size(),
		view.recommended_traditions.size()]
	var got: Array[int] = [viewer.detail().list(0).row_count(),
		viewer.detail().list(1).row_count(), viewer.detail().list(2).row_count()]
	TestFixtures.check(res, "the three recommended blocks list every entry", got == wanted,
		"got %s wanted %s" % [str(got), str(wanted)])
	var card: StatCard = viewer.detail().card(ContractDetail.CARD_URGENCY)
	TestFixtures.check(res, "the urgency card carries the urgency colour",
		card.accent_color() == GuiTypes.urgency_color(view.urgency),
		"urgency %d colour %s" % [view.urgency, str(card.accent_color())])
	TestFixtures.check(res, "the issuer block names the issuer type",
		viewer.detail().issuer_type_value.text == "Issuer %d" % view.issuer_type,
		"type %s" % viewer.detail().issuer_type_value.text)
	TestFixtures.check(res, "the detail panel level badge ignores mouse input",
		viewer.detail().badge().mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"filter %d" % viewer.detail().badge().mouse_filter)
	TestFixtures.check(res, "an open posting shows its expiry",
		viewer.detail().date_line().begins_with("Expires in"),
		"dates %s" % viewer.detail().date_line())
	viewer.queue_free()


static func _case_reject(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	var before: int = viewer.list().row_count()
	viewer.detail().decisions().reject_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Reject asks in red before it removes the posting",
		viewer.confirm().visible and viewer.confirm().title == "Are you sure?"
		and viewer.confirm().severity() == ConfirmDialog.Severity.RED,
		"title %s severity %d" % [viewer.confirm().title, viewer.confirm().severity()])
	viewer.confirm().press(1)
	await host.get_tree().process_frame
	var kept: ContractView = null
	for row: ContractView in GameState.contracts:
		if row.entry_id == view.entry_id:
			kept = row
	TestFixtures.check(res, "a rejected posting stays on record as Rejected",
		kept != null and kept.status == GuiTypes.ContractStatus.REJECTED
		and not viewer.list().has_id(view.entry_id),
		"status %d" % (kept.status if kept != null else -1))
	TestFixtures.check(res, "the board loses one row",
		viewer.list().row_count() == before - 1,
		"rows %d of %d" % [viewer.list().row_count(), before - 1])
	TestFixtures.check(res, "the selection moves to another row",
		viewer.selected() != null and viewer.selected().entry_id != view.entry_id,
		"selected %d" % viewer.selected_id)
	viewer.queue_free()


static func _open_window(viewer: ContractViewer, view: ContractView, host: Node) -> DispatchWindow:
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	viewer.detail().decisions().accept_button.pressed.emit()
	await host.get_tree().process_frame
	return viewer.window().current() as DispatchWindow


#Fills slot 0 and every required slot from the top of the roster; returns the uids placed.
static func _fill_team(window: DispatchWindow) -> Array[int]:
	var placed: Array[int] = []
	var wanted: int = mini(window.contract.merc_min, window.slot_count())
	wanted = maxi(1, wanted)
	for slot: int in wanted:
		var row: DispatchRosterItem = window.roster_panel().first_free_row()
		if row == null:
			break
		window.place(row.merc_uid(), slot)
		placed.append(row.merc_uid())
	return placed


static func _left_button(down: bool) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	return click


#An Esc the way the keyboard sends it, so the topmost frame answers it.
static func _push_escape(host: Node) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	host.get_viewport().push_input(event)


static func _leg_cost(window: DispatchWindow, key: String) -> int:
	return DispatchLogic.travel_cost(GuiTypes.travel_mode(key), window.team_size(),
		window.contract.merc_min, window.contract.distance_km)


static func _case_dispatch_window(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _open_window(viewer, view, host)
	TestFixtures.check(res, "Accept opens the dispatch window on the posting",
		viewer.window().is_open() and window != null and window.contract == view,
		"open %s" % viewer.window().is_open())
	TestFixtures.check(res, "the roster lists every free merc",
		window.roster_panel().row_count() == GameState.roster.size(),
		"rows %d of %d" % [window.roster_panel().row_count(), GameState.roster.size()])
	var leader: int = window.roster_panel().row_at(0).merc_uid()
	var placed: bool = window.place(leader, 0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "place fills slot 0 as the leader",
		placed and window.slot_at(0).is_filled() and window.slot_at(0).role() == "Leader"
		and window.slot_at(0).merc_uid() == leader,
		"slot 0 uid %d role %s" % [window.slot_at(0).merc_uid(), window.slot_at(0).role()])
	TestFixtures.check(res, "the filled slot badge ignores mouse input",
		window.slot_at(0).badge().mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"filter %d" % window.slot_at(0).badge().mouse_filter)
	var assigned_row: DispatchRosterItem = _roster_row(window.roster_panel(), leader)
	TestFixtures.check(res, "a placed merc keeps its roster row",
		window.roster_panel().row_count() == GameState.roster.size()
		and assigned_row != null and assigned_row.is_assigned(),
		"rows %d of %d" % [window.roster_panel().row_count(), GameState.roster.size()])
	TestFixtures.check(res, "an assigned row dims and tags itself",
		assigned_row != null and assigned_row.status_text() == DispatchRosterItem.ASSIGNED_TEXT
		and is_equal_approx(assigned_row.modulate.a, DispatchRosterItem.ASSIGNED_ALPHA),
		"alpha %.2f" % (assigned_row.modulate.a if assigned_row != null else 1.0))
	TestFixtures.check(res, "the roster row badge ignores mouse input",
		assigned_row != null and assigned_row.badge().mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"filter %d" % (assigned_row.badge().mouse_filter if assigned_row != null else -1))
	assigned_row.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "clicking an assigned row frees its slot",
		not window.slot_at(0).is_filled()
		and window.roster_panel().row_count() == GameState.roster.size(),
		"filled %s rows %d" % [window.slot_at(0).is_filled(),
		window.roster_panel().row_count()])
	window.place(leader, 0)
	await host.get_tree().process_frame
	var odds: int = window.current_odds()
	TestFixtures.check(res, "the odds sit inside the estimator band",
		odds >= 1 and odds <= 99, "odds %d" % odds)
	TestFixtures.check(res, "the meter reads the same odds",
		window.odds_meter().odds == odds,
		"meter %d of %d" % [window.odds_meter().odds, odds])
	_fill_team(window)
	window.pick_travel(0, "foot")
	window.pick_travel(1, "foot")
	await host.get_tree().process_frame
	var on_foot: int = _leg_cost(window, "foot") * 2
	TestFixtures.check(res, "two foot legs cost what DispatchLogic charges",
		window.travel_total() == on_foot,
		"total %d of %d" % [window.travel_total(), on_foot])
	TestFixtures.check(res, "a legal team on foot is ready to go",
		window.ready_to_dispatch() and on_foot <= GameState.bank_notes,
		"ready %s cost %d bank %d" % [window.ready_to_dispatch(), on_foot,
		GameState.bank_notes])
	window.pick_travel(0, "airship")
	await host.get_tree().process_frame
	var by_air: int = _leg_cost(window, "airship") + _leg_cost(window, "foot")
	TestFixtures.check(res, "an airship venture reprices the run",
		window.travel_total() == by_air and by_air >= on_foot,
		"total %d of %d" % [window.travel_total(), by_air])
	TestFixtures.check(res, "readiness follows the bank",
		window.ready_to_dispatch() == (by_air <= GameState.bank_notes),
		"ready %s cost %d bank %d" % [window.ready_to_dispatch(), by_air, GameState.bank_notes])
	window.pick_travel(0, "foot")
	window.clear_team()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Clear empties every slot", window.filled_count() == 0,
		"filled %d" % window.filled_count())
	var started: int = Time.get_ticks_msec()
	window.optimize()
	var spent: int = Time.get_ticks_msec() - started
	await host.get_tree().process_frame
	TestFixtures.check(res, "Optimize fills the required slots inside the budget",
		spent < 1500 and window.filled_count() >= view.merc_min,
		"%d ms filled %d of %d" % [spent, window.filled_count(), view.merc_min])
	var data: Dictionary = ContractPreview.preview(view, window.venture_mode,
		window.return_mode, window.team_size())
	var summed: float = float(data["travel_to_hours"]) + float(data["completion_hours"]) \
		+ float(data["return_hours"])
	TestFixtures.check(res, "the preview totals its three legs",
		is_equal_approx(float(data["total_hours"]), summed),
		"total %.2f of %.2f" % [float(data["total_hours"]), summed])
	TestFixtures.check(res, "the preview nets the travel costs off the reward",
		int(data["final_reward"]) == view.reward - int(data["travel_cost"]),
		"final %d reward %d cost %d" % [int(data["final_reward"]), view.reward,
		int(data["travel_cost"])])
	viewer.window().close()
	await host.get_tree().process_frame
	viewer.queue_free()


#D2: the eight preview rows off a standalone ContractPreview instance, not the live window, so
#the reward-below-cost and reward-above-cost scenarios stay exact and do not depend on the seed.
static func _case_preview_rows(res: Dictionary, host: Node) -> void:
	_fresh()
	TestFixtures.check(res, "days_text formats instant, hours and mixed spans",
		ContractPreview.days_text(0.0) == "Instant"
		and ContractPreview.days_text(10.0) == "0 Days, 10 Hours"
		and ContractPreview.days_text(48.0) == "2 Days, 0 Hours"
		and ContractPreview.days_text(38.4) == "1 Days, 14 Hours",
		"got %s / %s / %s / %s" % [ContractPreview.days_text(0.0), ContractPreview.days_text(10.0),
		ContractPreview.days_text(48.0), ContractPreview.days_text(38.4)])
	var preview_scene: PackedScene = preload("res://Scenes/GUI/Contracts/ContractPreview.tscn")
	var preview: ContractPreview = preview_scene.instantiate()
	host.add_child(preview)
	await host.get_tree().process_frame
	var order: Array[String] = ["TravelTo", "Completion", "Return", "TotalDays", "TravelCosts",
		"FinalReward", "MercBonus", "GuildCut"]
	var names: Array[String] = []
	for r: PreviewRow in preview.rows():
		names.append(String(r.name))
	TestFixtures.check(res, "eight preview rows exist in order",
		preview.row_count() == 8 and names == order, "names %s" % [names])
	var good_view: ContractView = ContractView.new()
	good_view.reward = 1000
	good_view.distance_km = 48
	good_view.merc_min = 1
	good_view.completion_hours = 10
	var foot: Dictionary = GuiTypes.travel_mode("foot")
	var good_data: Dictionary = ContractPreview.preview(good_view, foot, foot, 1)
	preview.set_preview(good_data)
	var cost_row: PreviewRow = preview.row("TravelCosts")
	TestFixtures.check(res, "the travel cost row reads a red negative with the glyph lit",
		cost_row.value_text() == "-%d" % int(good_data["travel_cost"])
		and cost_row.value_label.get_theme_color("font_color") == Color("#e8583f")
		and cost_row.glyph_node.visible,
		"value %s color %s glyph %s" % [cost_row.value_text(),
		cost_row.value_label.get_theme_color("font_color"), cost_row.glyph_node.visible])
	var bonus_row: PreviewRow = preview.row("MercBonus")
	TestFixtures.check(res, "the bonus caption carries the zero percent placeholder",
		bonus_row.caption_text() == "Mercenary Bonus (0%)",
		"caption '%s'" % bonus_row.caption_text())
	TestFixtures.check(res, "a positive run tints reward green and the bonus blue at 0 percent",
		int(good_data["final_reward"]) > 0
		and preview.row("FinalReward").value_label.get_theme_color("font_color") == Color("#6cc36a")
		and bonus_row.value_label.get_theme_color("font_color") == Color("#9cc6ef"),
		"final %d reward_color %s bonus_color %s" % [int(good_data["final_reward"]),
		preview.row("FinalReward").value_label.get_theme_color("font_color"),
		bonus_row.value_label.get_theme_color("font_color")])
	var poor_view: ContractView = ContractView.new()
	poor_view.reward = 1
	poor_view.distance_km = 48
	poor_view.merc_min = 1
	poor_view.completion_hours = 0
	var teleport: Dictionary = GuiTypes.travel_mode("teleport")
	var poor_data: Dictionary = ContractPreview.preview(poor_view, teleport, teleport, 1)
	preview.set_preview(poor_data)
	TestFixtures.check(res, "a losing run hands the whole loss to the guild",
		int(poor_data["final_reward"]) < 0
		and int(poor_data["guild_cut"]) == int(poor_data["final_reward"])
		and int(poor_data["merc_bonus"]) == 0,
		"final %d bonus %d cut %d" % [int(poor_data["final_reward"]), int(poor_data["merc_bonus"]),
		int(poor_data["guild_cut"])])
	TestFixtures.check(res, "the losing run tints final reward and guild cut red",
		preview.row("FinalReward").value_label.get_theme_color("font_color") == Color("#e8583f")
		and preview.row("GuildCut").value_label.get_theme_color("font_color") == Color("#e8583f"),
		"reward %s cut %s" % [preview.row("FinalReward").value_label.get_theme_color("font_color"),
		preview.row("GuildCut").value_label.get_theme_color("font_color")])
	preview.queue_free()


#D2: the summary meta line for the first open contract, off a standalone ContractSummary.
static func _case_summary_meta(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var summary_scene: PackedScene = preload("res://Scenes/GUI/Contracts/ContractSummary.tscn")
	var summary: ContractSummary = summary_scene.instantiate()
	host.add_child(summary)
	summary.set_contract(view)
	await host.get_tree().process_frame
	var expected: Array[String] = [view.type, "%d km" % view.distance_km,
		"Deadline " + TrynnCalendar.date_text(view.expires_minute)]
	TestFixtures.check(res, "the summary meta line reads type, distance and deadline",
		summary.meta_parts() == expected,
		"got %s wanted %s" % [summary.meta_parts(), expected])
	var dot1: ColorRect = summary.meta_dots()[0]
	var dot2: ColorRect = summary.meta_dots()[1]
	TestFixtures.check(res, "the summary badge takes the handoff tile size",
		summary.level_badge.size_mode == LevelBadge.SizeMode.TILE
		and summary.level_badge.plate_size == Vector2(44, 44)
		and summary.level_badge.custom_minimum_size == Vector2(44, 44),
		"mode %d plate %s min %s" % [summary.level_badge.size_mode,
		summary.level_badge.plate_size, summary.level_badge.custom_minimum_size])
	TestFixtures.check(res, "the meta dots are 3x3",
		dot1.custom_minimum_size == Vector2(3, 3) and dot2.custom_minimum_size == Vector2(3, 3),
		"dot1 %s dot2 %s" % [dot1.custom_minimum_size, dot2.custom_minimum_size])
	var tint := Color("#9cc6ef")
	TestFixtures.check(res, "every meta label is tinted the same blue",
		summary.type_label.get_theme_color("font_color").is_equal_approx(tint)
		and summary.km_label.get_theme_color("font_color").is_equal_approx(tint)
		and summary.deadline_label.get_theme_color("font_color").is_equal_approx(tint),
		"colors %s %s %s" % [summary.type_label.get_theme_color("font_color"),
		summary.km_label.get_theme_color("font_color"),
		summary.deadline_label.get_theme_color("font_color")])
	summary.queue_free()
	viewer.queue_free()


#Walks the confirm ladder of a dispatch window, pressing the button that carries it on.
static func _walk_dialogs(window: DispatchWindow, host: Node) -> Array[String]:
	var titles: Array[String] = []
	var guard: int = 0
	while guard < 6 and is_instance_valid(window) and window.confirm().visible:
		titles.append(window.confirm().title)
		window.confirm().press(window.confirm().button_count() - 1)
		await host.get_tree().process_frame
		guard += 1
	return titles


static func _case_commit(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _open_window(viewer, view, host)
	_fill_team(window)
	window.pick_travel(0, "foot")
	window.pick_travel(1, "foot")
	await host.get_tree().process_frame
	var team: Array[int] = window.team_uids()
	var runs: Array[ActiveRun] = []
	window.dispatched.connect(func(contract_run: ActiveRun) -> void: runs.append(contract_run))
	TestFixtures.check(res, "the team is legal before the press", window.ready_to_dispatch(),
		"hint %s" % window.hint_text())
	var payload: Dictionary = ContractPreview.preview(view, window.venture_mode,
		window.return_mode, team.size())
	var want_hours: float = roundf(float(payload.get("total_hours", 0.0)))
	window.dispatch_button.pressed.emit()
	await host.get_tree().process_frame
	var titles: Array[String] = []
	var receipt: int = -1
	var guard: int = 0
	while guard < 6 and is_instance_valid(window) and window.confirm().visible:
		titles.append(window.confirm().title)
		if window.confirm().title == "Team Dispatched!":
			receipt = window.confirm().severity()
		window.confirm().press(window.confirm().button_count() - 1)
		await host.get_tree().process_frame
		guard += 1
	TestFixtures.check(res, "the ladder ends on the recap and the receipt",
		titles.has("Dispatch This Team?") and titles.has("Team Dispatched!"),
		"titles %s" % str(titles))
	TestFixtures.check(res, "the receipt reads as a green one button dialog",
		receipt == ConfirmDialog.Severity.GREEN, "severity %d" % receipt)
	TestFixtures.check(res, "the run carries the rounded whole hours",
		runs.size() == 1 and is_equal_approx(runs[0].hours, want_hours)
		and is_equal_approx(runs[0].hours, floorf(runs[0].hours)),
		"hours %.4f wanted %.4f" % [runs[0].hours if not runs.is_empty() else -1.0, want_hours])
	TestFixtures.check(res, "dispatched carries the run of this posting",
		runs.size() == 1 and runs[0].entry_id == view.entry_id,
		"%d runs" % runs.size())
	var after: ContractView = null
	for row: ContractView in GameState.contracts:
		if row.entry_id == view.entry_id:
			after = row
	TestFixtures.check(res, "the posting turned active",
		after != null and after.status == GuiTypes.ContractStatus.ACTIVE,
		"status %d" % (after.status if after != null else -1))
	var busy: Array[int] = GameState.busy_uids()
	var all_busy: bool = not team.is_empty()
	for uid: int in team:
		if not busy.has(uid):
			all_busy = false
	TestFixtures.check(res, "the team reads as busy", all_busy, "team %s" % str(team))
	TestFixtures.check(res, "the dispatch window closed", not viewer.window().is_open(),
		"open %s" % viewer.window().is_open())
	TestFixtures.check(res, "the posting keeps its row",
		viewer.list().has_id(view.entry_id) and viewer.detail().entry_id() == view.entry_id,
		"detail %d" % viewer.detail().entry_id())
	TestFixtures.check(res, "the detail shows the crew and drops the decisions",
		viewer.detail().active_crew().portrait_count() == team.size()
		and not viewer.detail().decisions().accept_button.visible
		and not viewer.detail().decisions().reject_button.visible,
		"portraits %d of %d" % [viewer.detail().active_crew().portrait_count(), team.size()])
	var crew: ActiveCrew = viewer.detail().active_crew()
	var crew_box: PanelContainer = crew.portrait_box(0)
	var crew_style: StyleBoxFlat = null
	if crew_box != null:
		crew_style = crew_box.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "a crew column boxes the portrait and drops the name",
		crew_box != null and crew_box.get_child_count() == 1
		and crew_box.get_child(0) is MercPortrait and crew.portrait_box(team.size()) == null
		and _crew_stack_count(crew) == 2 and not _crew_has_name(crew)
		and crew_style != null
		and crew_style.bg_color.to_html(false) == ActiveCrew.BOX_BG.to_html(false)
		and crew_style.border_color.to_html(false) == ActiveCrew.BOX_RING.to_html(false)
		and crew_style.border_width_top == ActiveCrew.BOX_RING_WIDTH,
		"box %s stack %d named %s" % [crew_box, _crew_stack_count(crew),
		_crew_has_name(crew)])
	viewer.queue_free()


static func _case_night_queue(res: Dictionary, host: Node) -> void:
	_fresh()
	var busy_before: Array[int] = _busy_now()
	await GameState.process_until(NIGHT_MINUTE)
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _open_window(viewer, view, host)
	var team: Array[int] = _fill_team(window)
	window.pick_travel(0, "foot")
	window.pick_travel(1, "foot")
	await host.get_tree().process_frame
	var sent: bool = window.commit()
	await host.get_tree().process_frame
	await _walk_dialogs(window, host)
	TestFixtures.check(res, "a night dispatch is taken and queued",
		sent and GameState.queued.has(view.entry_id),
		"sent %s queued %s" % [sent, GameState.queued.has(view.entry_id)])
	var after: ContractView = null
	for row: ContractView in GameState.contracts:
		if row.entry_id == view.entry_id:
			after = row
	TestFixtures.check(res, "a queued posting still reads as active",
		after != null and after.status == GuiTypes.ContractStatus.ACTIVE,
		"status %d" % (after.status if after != null else -1))
	TestFixtures.check(res, "the status line names the 6:00 AM departure",
		viewer.detail().status_line().ends_with("Departs at 6:00 AM"),
		"status %s" % viewer.detail().status_line())
	TestFixtures.check(res, "a queued posting offers Cancel Dispatch",
		viewer.detail().decisions().cancel_button.visible, "cancel hidden")
	viewer.detail().decisions().cancel_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Cancel Dispatch asks first",
		viewer.confirm().visible and viewer.confirm().title == "Are you sure?",
		"title %s" % viewer.confirm().title)
	TestFixtures.check(res, "Cancel Dispatch asks in red",
		viewer.confirm().severity() == ConfirmDialog.Severity.RED,
		"severity %d" % viewer.confirm().severity())
	viewer.confirm().press(1)
	await host.get_tree().process_frame
	var back: ContractView = null
	for row: ContractView in GameState.contracts:
		if row.entry_id == view.entry_id:
			back = row
	var team_free: bool = true
	for uid: int in team:
		if GameState.busy_uids().has(uid):
			team_free = false
	TestFixtures.check(res, "the posting reopens and the team is free",
		back != null and back.status == GuiTypes.ContractStatus.AVAILABLE
		and not GameState.queued.has(view.entry_id)
		and _same_busy(busy_before) and team_free,
		"status %d queued %s busy %s was %s" % [(back.status if back != null else -1),
		GameState.queued.has(view.entry_id), str(_busy_now()), str(busy_before)])
	TestFixtures.check(res, "Cancel Dispatch goes away with the queue",
		not viewer.detail().decisions().cancel_button.visible
		and viewer.detail().decisions().accept_button.visible,
		"cancel %s" % viewer.detail().decisions().cancel_button.visible)
	viewer.queue_free()


#Item 26: a closed posting stays on the board for its month, behind its own filter option.
static func _case_show_closed(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var open_rows: int = viewer.list().row_count()
	var closed_id: int = _first_open(viewer).entry_id
	var entry: BoardEntry = GameState.board.entry(closed_id)
	entry.status = BoardEntry.STATUS_EXPIRED
	entry.closed_minute = CampaignClock.now()
	if entry.contract != null:
		entry.contract.status = "Expired"
	GameState.refresh_views()
	GameState.contracts_changed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "an expired posting hides while show_closed is off",
		not viewer.list().has_id(closed_id) and viewer.list().row_count() == open_rows - 1,
		"rows %d of %d" % [viewer.list().row_count(), open_rows - 1])
	var rules: Dictionary = viewer.list().filter_panel.filter()
	rules["show_expired"] = true
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	var row: ContractListItem = _row_of(viewer.list(), closed_id)
	TestFixtures.check(res, "the Expired option lists it again under its status strip",
		row != null
		and row.strip_text() == GuiTypes.status_text(GuiTypes.ContractStatus.EXPIRED),
		"strip %s" % (row.strip_text() if row != null else ""))
	viewer.select_entry(closed_id)
	await host.get_tree().process_frame
	var buttons: DecisionButtons = viewer.detail().decisions()
	TestFixtures.check(res, "a closed posting offers no decisions",
		not buttons.accept_button.visible and not buttons.reject_button.visible,
		"accept %s reject %s" % [buttons.accept_button.visible, buttons.reject_button.visible])
	var kept: ContractView = null
	for item: ContractView in GameState.contracts:
		if item.entry_id == closed_id:
			kept = item
	TestFixtures.check(res, "the view carries the minute the posting closed",
		kept != null and kept.closed_minute == entry.closed_minute,
		"closed %d" % (kept.closed_minute if kept != null else -1))
	TestFixtures.check(res, "an expired posting still reads its deadline date",
		kept != null and kept.expires_minute >= 0 and viewer.detail().date_line()
			== "Deadline " + TrynnCalendar.date_text(kept.expires_minute),
		"dates %s expires %d" % [viewer.detail().date_line(),
		kept.expires_minute if kept != null else -1])
	viewer.queue_free()


#D7: only a posting still on offer and near its deadline flashes, and only over its image box.
static func _case_pulse(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var open_view: ContractView = _first_open(viewer)
	var row: ContractListItem = _row_of(viewer.list(), open_view.entry_id)
	TestFixtures.check(res, "only an open posting near its deadline counts as urgent",
		row != null
		and ContractListItem.pulses(_urgent(GuiTypes.ContractStatus.AVAILABLE,
			GuiTypes.Urgency.HIGH))
		and not ContractListItem.pulses(_urgent(GuiTypes.ContractStatus.EXPIRED,
			GuiTypes.Urgency.HIGH))
		and not ContractListItem.pulses(_urgent(GuiTypes.ContractStatus.COMPLETED,
			GuiTypes.Urgency.HIGH))
		and not ContractListItem.pulses(_urgent(GuiTypes.ContractStatus.REJECTED,
			GuiTypes.Urgency.HIGH))
		and not ContractListItem.pulses(_urgent(GuiTypes.ContractStatus.ACTIVE,
			GuiTypes.Urgency.HIGH))
		and not ContractListItem.pulses(_urgent(GuiTypes.ContractStatus.AVAILABLE,
			GuiTypes.Urgency.LOW))
		and not ContractListItem.pulses(null),
		"row %s" % row)
	row.set_view(_urgent(GuiTypes.ContractStatus.EXPIRED, GuiTypes.Urgency.HIGH))
	await host.get_tree().process_frame
	TestFixtures.check(res, "a settled posting stops flashing and stops processing",
		not row.pulse.active and not row.pulse.is_processing()
		and is_equal_approx(row.pulse.color.a, 0.0),
		"active %s processing %s alpha %.2f" % [row.pulse.active, row.pulse.is_processing(),
		row.pulse.color.a])
	row.set_view(_urgent(GuiTypes.ContractStatus.AVAILABLE, GuiTypes.Urgency.HIGH))
	await host.get_tree().process_frame
	TestFixtures.check(res, "an open posting running out of time flashes",
		row.pulse.active and row.pulse.is_processing(),
		"active %s processing %s" % [row.pulse.active, row.pulse.is_processing()])
	await host.get_tree().process_frame
	var kids: Array[Node] = row.image.get_children()
	TestFixtures.check(res, "the pulse covers the image box alone, over everything on it",
		row.pulse.get_parent() == row.image and kids[kids.size() - 1] == row.pulse
		and row.pulse.get_global_rect() == row.image.get_global_rect()
		and row.pulse.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"pulse %s image %s row %s" % [row.pulse.get_global_rect(), row.image.get_global_rect(),
		row.get_global_rect()])
	viewer.queue_free()


#A sample posting in one status at one urgency; the row reads no more than these for the pulse.
static func _urgent(status: int, urgency: int) -> ContractView:
	var out: ContractView = ContractView.new()
	out.entry_id = 9001
	out.name = "Urgency Sample"
	out.status = status
	out.urgency = urgency
	return out


#Items 41 and 45: the status strip and the level badge on a row and on the dispatch summary.
static func _case_row_extras(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var row: ContractListItem = viewer.list().row_at(0)
	var view: ContractView = row.view
	TestFixtures.check(res, "every row carries a status strip in the status colour",
		row.strip_text() == view.shown_status_text()
		and row.strip_color() == view.shown_status_color(),
		"strip %s" % row.strip_text())
	TestFixtures.check(res, "every row carries the posting level",
		row.badge() != null and row.badge().level == view.contract_level,
		"badge %d of %d" % [row.badge().level, view.contract_level])
	var open_view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _open_window(viewer, open_view, host)
	TestFixtures.check(res, "the dispatch summary repeats the level badge",
		window.summary.badge() != null
		and window.summary.badge().level == open_view.contract_level,
		"badge %d of %d" % [window.summary.badge().level, open_view.contract_level])
	TestFixtures.check(res, "the summary level badge ignores mouse input",
		window.summary.badge().mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"filter %d" % window.summary.badge().mouse_filter)
	viewer.window().close()
	await host.get_tree().process_frame
	viewer.queue_free()


#Item 42: the shared hover tooltip the list opens over the row under the pointer.
static func _case_tooltip(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var tip: ContractTooltip = viewer.list().tooltip()
	TestFixtures.check(res, "the list owns one hover tooltip, hidden at rest",
		tip != null and not tip.visible, "tip %s" % (tip != null))
	var row: ContractListItem = viewer.list().row_at(0)
	var view: ContractView = row.view
	row.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hovering a row opens the tooltip on that posting",
		tip.visible and tip.view == view and tip.title_label.text == view.name,
		"title %s" % tip.title_label.text)
	TestFixtures.check(res, "the tooltip reads the posting at a glance",
		tip.body_label.text == ContractTooltip.body_text(view)
		and tip.difficulty_label.text == "Difficulty %s" % view.difficulty_name()
		and tip.issuer_label.text.begins_with("Issuer "),
		"difficulty %s" % tip.difficulty_label.text)
	TestFixtures.check(res, "the body leaves the difficulty to its own label",
		ContractTooltip.body_text(view).count("Difficulty") == 0,
		"body %s" % ContractTooltip.body_text(view).replace("\n", " | "))
	row.mouse_exited.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "leaving the row hides the tooltip", not tip.visible,
		"visible %s" % tip.visible)
	viewer.queue_free()


#Item 43: the payout tooltip says how far off the payday is.
static func _case_payout(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var tip: PayoutTooltip = viewer.detail().payout_tip
	tip.set_payout(100, 20, "Day 5", 3)
	TestFixtures.check(res, "the payout tip counts the days to the payday",
		tip.relative_text() == "3 Days From Now" and tip.expected_total() == "80 N",
		"relative %s total %s" % [tip.relative_text(), tip.expected_total()])
	tip.set_payout(100, 20, "Day 5", 1)
	TestFixtures.check(res, "a payday inside the day still reads one day out",
		tip.relative_text() == "1 Day From Now"
		and PayoutTooltip.days_text(0) == "1 Day From Now",
		"relative %s" % tip.relative_text())
	var window: DispatchWindow = await _open_window(viewer, view, host)
	_fill_team(window)
	window.pick_travel(0, "foot")
	window.pick_travel(1, "foot")
	await host.get_tree().process_frame
	window.commit()
	await host.get_tree().process_frame
	await _walk_dialogs(window, host)
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	var contract_run: ActiveRun = viewer.detail().run_of_view()
	viewer.detail().reward_label.mouse_entered.emit()
	await host.get_tree().process_frame
	var start: int = contract_run.depart_minute if contract_run.depart_minute >= 0 else contract_run.dispatched_minute
	var payday: int = start + int(contract_run.hours * 60.0)
	var days: int = TrynnCalendar.day_index(payday) - TrynnCalendar.day_index(CampaignClock.now())
	TestFixtures.check(res, "a live posting counts its own payday off today",
		tip.visible and tip.relative_text() == PayoutTooltip.days_text(days),
		"relative %s wanted %s" % [tip.relative_text(), PayoutTooltip.days_text(days)])
	viewer.queue_free()


#Items 36, 50 and 51: Clear, Optimize and Cancel ask before they throw team work away.
static func _case_team_controls(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	TestFixtures.check(res, "Clear is dead while the team is empty",
		window.clear_button.disabled and not window.confirm().visible,
		"disabled %s" % window.clear_button.disabled)
	window.clear_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Clear on an empty team asks nothing",
		not window.confirm().visible, "visible %s" % window.confirm().visible)
	window.optimize_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Optimize on an empty team fills the required slots without asking",
		not window.confirm().visible and window.filled_count() >= view.merc_min,
		"filled %d of %d" % [window.filled_count(), view.merc_min])
	TestFixtures.check(res, "Optimize pins slot 0 to Leader",
		window.roles[0] == DispatchLogic.LEADER_ROLE, "role %s" % window.roles[0])
	TestFixtures.check(res, "Optimize stays inside the required and the slot count",
		window.filled_count() >= view.merc_min and window.filled_count() <= window.slots,
		"filled %d min %d slots %d" % [window.filled_count(), view.merc_min, window.slots])
	var share: Dictionary = window._share()
	var beaten: int = 0
	for i: int in window.team.size():
		if i == 0 or window.team[i] == 0:
			continue
		var view_i: MercView = null
		for merc: MercView in window.candidates:
			if merc.uid == window.team[i]:
				view_i = merc
		if view_i == null:
			continue
		var mine: float = DispatchLogic.score(view_i, window.contract, window.roles[i], share)
		for role_name: String in TeamSlot.slot_roles():
			if DispatchLogic.score(view_i, window.contract, role_name, share) > mine + 0.0001:
				beaten += 1
	TestFixtures.check(res, "no role scores higher than the one Optimize gave the slot",
		beaten == 0, "%d slots could do better" % beaten)
	var by_hand: float = 0.0
	for lead_uid: int in window.team_uids():
		var lead_view: MercView = null
		for merc: MercView in window.candidates:
			if merc.uid == lead_uid:
				lead_view = merc
		if lead_view == null:
			continue
		var lead_share: Dictionary = DispatchLogic.leader_share(lead_view, window.contract)
		var total: float = DispatchLogic.score(lead_view, window.contract,
			DispatchLogic.LEADER_ROLE, {})
		for other_uid: int in window.team_uids():
			if other_uid == lead_uid:
				continue
			var other: MercView = null
			for merc: MercView in window.candidates:
				if merc.uid == other_uid:
					other = merc
			if other == null:
				continue
			var top: float = -1.0
			for role_name: String in TeamSlot.slot_roles():
				top = maxf(top, DispatchLogic.score(other, window.contract, role_name, lead_share))
			total += top
		by_hand = maxf(by_hand, total)
	var arranged: Dictionary = DispatchLogic.arrange(window.team_uids(), window.candidates,
		window.contract, TeamSlot.slot_roles())
	TestFixtures.check(res, "arrange finds the best fit any leader can reach",
		absf(float(arranged.get("fit", 0.0)) - by_hand) < 0.0001,
		"fit %.4f by hand %.4f" % [float(arranged.get("fit", 0.0)), by_hand])
	var trip: Dictionary = DispatchLogic.plan_travel(GuiTypes.TRAVEL_MODES, GameState.bank_notes,
		window.contract.reward, window.team_size(), window.contract.merc_min,
		window.contract.distance_km)
	var want_venture: String = str((trip.get("venture", {}) as Dictionary).get("key", "foot"))
	var want_return: String = str((trip.get("ret", {}) as Dictionary).get("key", "foot"))
	TestFixtures.check(res, "Optimize books the travel plan_travel returns",
		str(window.venture_mode.get("key", "")) == want_venture
		and str(window.return_mode.get("key", "")) == want_return,
		"got %s %s wanted %s %s" % [window.venture_mode.get("key", ""),
		window.return_mode.get("key", ""), want_venture, want_return])
	var floored: Array[int] = DispatchLogic.optimize(window.candidates, window.slots,
		func(uids: Array[int]) -> int: return OddsEstimator.odds(window.model, uids), 2)
	TestFixtures.check(res, "the optimize floor never hands back a team under its size",
		window.candidates.size() < 2 or floored.size() >= 2,
		"%d uids from %d candidates" % [floored.size(), window.candidates.size()])
	var shown: int = 0
	var filled: int = 0
	for i: int in window.team.size():
		if window.team[i] == 0:
			continue
		filled += 1
		if window.slot_at(i).role() == window.roles[i]:
			shown += 1
	TestFixtures.check(res, "every filled slot shows the role Optimize assigned",
		shown == filled, "%d of %d slots read back" % [shown, filled])
	window.clear_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Clear over a filled team warns in red",
		window.confirm().visible and window.confirm().message == CLEAR_TEXT
		and window.confirm().severity() == ConfirmDialog.Severity.RED,
		"message %s" % window.confirm().message)
	window.confirm().press(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "backing out of Clear keeps the team",
		window.filled_count() > 0 and not window.confirm().visible,
		"filled %d" % window.filled_count())
	window.optimize_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Optimize over a filled team warns in orange",
		window.confirm().visible and window.confirm().message == OPTIMIZE_TEXT
		and window.confirm().severity() == ConfirmDialog.Severity.ORANGE,
		"message %s" % window.confirm().message)
	window.confirm().press(0)
	await host.get_tree().process_frame
	window.cancel_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Cancel warns before it drops the changes",
		window.confirm().visible and window.confirm().message == CANCEL_TEXT
		and window.confirm().severity() == ConfirmDialog.Severity.RED,
		"message %s" % window.confirm().message)
	window.confirm().press(0)
	await host.get_tree().process_frame
	window.queue_free()
	viewer.queue_free()


#Items 46, 47 and 49: the team head count, the slot rings and the slot to slot swap.
static func _case_slots(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	TestFixtures.check(res, "the team head opens empty over the posting band",
		window.team_title.text == "Team" and window.team_count.text == "0 / 5, 2 required",
		"count %s" % window.team_count.text)
	TestFixtures.check(res, "slot 0 rings as the leader",
		window.slot_at(0).ring_state() == "leader"
		and window.slot_at(0).ring_color() == TeamSlot.LEADER_COLOR,
		"state %s" % window.slot_at(0).ring_state())
	TestFixtures.check(res, "an empty required slot rings dark orange",
		window.slot_at(1).ring_state() == "required"
		and window.slot_at(1).ring_color() == TeamSlot.REQUIRED_COLOR,
		"state %s" % window.slot_at(1).ring_state())
	TestFixtures.check(res, "an empty optional slot takes the dashed ring",
		window.slot_at(2).ring_state() == "optional"
		and window.slot_at(2).ring_color() == TeamSlot.OPTIONAL_COLOR,
		"state %s" % window.slot_at(2).ring_state())
	TestFixtures.check(res, "the dashed ring fades, the optional slot does not",
		is_equal_approx(window.slot_at(2).modulate.a, 1.0),
		"alpha %.2f" % window.slot_at(2).modulate.a)
	var first: int = window.roster_panel().first_free_row().merc_uid()
	window.place(first, 0)
	var second: int = window.roster_panel().first_free_row().merc_uid()
	window.place(second, 2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a filled slot rings blue",
		window.slot_at(2).ring_state() == "filled"
		and window.slot_at(2).ring_color() == TeamSlot.FILLED_COLOR,
		"state %s" % window.slot_at(2).ring_state())
	window.slot_at(1).set_drag_over(true)
	TestFixtures.check(res, "a slot under a drag rings green",
		window.slot_at(1).ring_state() == "over"
		and window.slot_at(1).ring_color() == TeamSlot.OVER_COLOR,
		"state %s" % window.slot_at(1).ring_state())
	window.slot_at(1).set_drag_over(false)
	TestFixtures.check(res, "the team count follows the filled slots",
		window.team_count.text == "2 / 5, 2 required", "count %s" % window.team_count.text)
	window.place(first, 1)
	var other_role: String = ""
	for role_name: String in GuiTypes.ROLES:
		if role_name != window.roles[2] and role_name != DispatchWindow.LEADER_ROLE:
			other_role = role_name
			break
	window.set_role(2, other_role)
	await host.get_tree().process_frame
	var role_one: String = window.roles[1]
	var role_two: String = window.roles[2]
	window.swap_slots(1, 2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a swap trades both the mercs and the roles",
		window.team[1] == second and window.team[2] == first
		and window.roles[1] == role_two and window.roles[2] == role_one,
		"roles %s %s" % [window.roles[1], window.roles[2]])
	TestFixtures.check(res, "a slot takes a slot payload or a merc payload",
		TeamSlot.accepts({"slot": 1}) and TeamSlot.accepts({"uid": 4})
		and not TeamSlot.accepts({}), "payload gate")
	var swaps: Array[int] = []
	window.slot_at(2).swapped.connect(func(from_slot: int, _to_slot: int) -> void:
		swaps.append(from_slot))
	window.slot_at(2)._drop_data(Vector2.ZERO, {"slot": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "dropping a slot on a slot swaps them back",
		swaps == [1] and window.team[1] == first and window.team[2] == second,
		"swaps %s" % str(swaps))
	var clicks: Array[int] = []
	var held: TeamSlot = window.slot_at(1)
	held.clicked.connect(func(index: int) -> void: clicks.append(index))
	held._gui_input(_left_button(true))
	TestFixtures.check(res, "a press on a filled slot leaves room for the drag",
		clicks.is_empty(), "clicks %s" % str(clicks))
	held._gui_input(_left_button(false))
	TestFixtures.check(res, "the release on a filled slot counts as the click",
		clicks == [1], "clicks %s" % str(clicks))
	held._get_drag_data(Vector2.ZERO)
	held.notification(Control.NOTIFICATION_DRAG_END)
	held._gui_input(_left_button(false))
	TestFixtures.check(res, "the release that ends a drag is no click",
		clicks == [1], "clicks %s" % str(clicks))
	window.queue_free()
	viewer.queue_free()


#Item 48: clicking a slot opens the merc picker, best fit first, with Remove on a full slot.
static func _case_picker(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	var picker: MercPicker = window.picker
	window.slot_at(1).clicked.emit(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "clicking a slot opens the picker on it",
		picker.visible and picker.slot == 1
		and picker.row_count() == window.candidates.size(),
		"rows %d of %d" % [picker.row_count(), window.candidates.size()])
	var scores: Dictionary = window.scores_for(1)
	var best: float = -1.0
	for uid: int in scores.keys():
		best = maxf(best, float(scores[uid]))
	var top: int = picker.row_uid(0)
	TestFixtures.check(res, "the picker lists the best fit for the role first",
		is_equal_approx(float(scores.get(top, -1.0)), best),
		"top %.3f of %.3f" % [float(scores.get(top, -1.0)), best])
	picker.pick(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking a row fills the slot and closes the picker",
		window.slot_at(1).merc_uid() == top and not picker.visible,
		"slot uid %d of %d" % [window.slot_at(1).merc_uid(), top])
	window.slot_at(2).clicked.emit(2)
	await host.get_tree().process_frame
	var at: int = -1
	for i: int in picker.row_count():
		if picker.row_uid(i) == top:
			at = i
	TestFixtures.check(res, "a merc already standing says which slot holds it",
		at >= 0 and picker.row_text(at).ends_with(", in slot 2"),
		"row %s" % (picker.row_text(at) if at >= 0 else ""))
	TestFixtures.check(res, "an empty slot offers no Remove", not picker.remove_button.visible,
		"remove shown")
	picker.hide()
	window.slot_at(1).clicked.emit(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a filled slot offers Remove", picker.remove_button.visible,
		"remove hidden")
	picker.press_remove()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Remove empties the slot", not window.slot_at(1).is_filled(),
		"slot uid %d" % window.slot_at(1).merc_uid())
	window.queue_free()
	viewer.queue_free()


#Items 51 and 52: the odds ladder and the recap the last dialog shows.
static func _case_dialogs(res: Dictionary, host: Node) -> void:
	_fresh()
	var busy_before: Array[int] = _busy_now()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	_fill_team(window)
	await host.get_tree().process_frame
	window._ask_next_step(10, "")
	await host.get_tree().process_frame
	TestFixtures.check(res, "very low odds warn in red",
		window.confirm().title == "Warning" and window.confirm().message == WARN_TEXT
		and window.confirm().severity() == ConfirmDialog.Severity.RED,
		"title %s" % window.confirm().title)
	window.confirm().press(0)
	await host.get_tree().process_frame
	window._ask_next_step(30, "")
	await host.get_tree().process_frame
	TestFixtures.check(res, "low odds caution in orange",
		window.confirm().title == "Caution" and window.confirm().message == CAUTION_TEXT
		and window.confirm().severity() == ConfirmDialog.Severity.ORANGE,
		"title %s" % window.confirm().title)
	window.confirm().press(0)
	await host.get_tree().process_frame
	window._ask_next_step(80, "")
	await host.get_tree().process_frame
	var dialog: ConfirmDialog = window.confirm()
	TestFixtures.check(res, "the recap names the posting and lists the team",
		dialog.title == "Dispatch This Team?" and dialog.message == view.name
		and dialog.severity() == ConfirmDialog.Severity.GREEN
		and dialog.team_row_count() == window.filled_count(),
		"rows %d of %d" % [dialog.team_row_count(), window.filled_count()])
	TestFixtures.check(res, "the recap carries the three dispatch figures",
		dialog.stat_row_count() == 3 and dialog.stat_value_text(0) == "80%"
		and dialog.button_count() == 2,
		"stats %d first %s" % [dialog.stat_row_count(), dialog.stat_value_text(0)])
	dialog.press(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "backing out of the recap dispatches nobody",
		not dialog.visible and _same_busy(busy_before),
		"busy %s was %s" % [str(_busy_now()), str(busy_before)])
	window.queue_free()
	viewer.queue_free()


#D1: the travel rows, the caption column, the dead bands, the foot numbers and the hover tip.
static func _case_travel_rows(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	await host.get_tree().process_frame
	var venture: TravelSelector = window.venture_selector
	var homeward: TravelSelector = window.return_selector
	TestFixtures.check(res, "both legs share one caption column no narrower than their text",
		absf(venture.caption_label.size.x - homeward.caption_label.size.x) <= 0.5
		and venture.caption_label.size.x >= venture.caption_label.get_minimum_size().x - 0.5
		and homeward.caption_label.size.x >= homeward.caption_label.get_minimum_size().x - 0.5,
		"venture %.1f of %.1f return %.1f of %.1f" % [venture.caption_label.size.x,
		venture.caption_label.get_minimum_size().x, homeward.caption_label.size.x,
		homeward.caption_label.get_minimum_size().x])
	var tiles: Array[TravelButton] = []
	for mode: Dictionary in GuiTypes.TRAVEL_MODES:
		var tile: TravelButton = venture.button_for(String(mode["key"]))
		if tile != null:
			tiles.append(tile)
	var tall: bool = tiles.size() == 6
	var even: bool = tall
	var spaced: bool = tall
	for i: int in tiles.size():
		if absf(tiles[i].size.y - 32.0) > 1.0:
			tall = false
		if absf(tiles[i].size.x - tiles[0].size.x) > 1.0:
			even = false
		if i == 0:
			continue
		var gap: float = tiles[i].global_position.x - tiles[i - 1].global_position.x \
			- tiles[i - 1].size.x
		if absf(gap - 10.0) > 1.0:
			spaced = false
	TestFixtures.check(res, "six travel tiles stand 32 tall at even widths 10 apart",
		tall and even and spaced, "tiles %d tall %s even %s spaced %s"
		% [tiles.size(), tall, even, spaced])
	TestFixtures.check(res, "both legs open on foot with nothing to clear",
		window.venture_selector.selected_key() == "foot"
		and window.return_selector.selected_key() == "foot" and not window.is_dirty(),
		"venture %s return %s dirty %s" % [window.venture_selector.selected_key(),
		window.return_selector.selected_key(), window.is_dirty()])
	window.pick_travel(0, "foot")
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking foot over foot leaves the form clean",
		not window.is_dirty(), "dirty %s" % window.is_dirty())
	window.pick_travel(0, "horse")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a faster venture makes the form dirty",
		window.is_dirty() and window.venture_selector.selected_key() == "horse",
		"key %s dirty %s" % [window.venture_selector.selected_key(), window.is_dirty()])
	window.pick_travel(0, "foot")
	await host.get_tree().process_frame
	var foot_leg: int = _leg_cost(window, "foot")
	var air_leg: int = _leg_cost(window, "airship")
	var held: int = GameState.bank_notes
	GameState.bank_notes = foot_leg + air_leg - 1
	window._refresh()
	await host.get_tree().process_frame
	var air_tile: TravelButton = window.return_selector.button_for("airship")
	TestFixtures.check(res, "a mode the other leg leaves no room for goes dead",
		air_tile.disabled and air_leg > GameState.bank_notes - foot_leg
		and air_leg < GameState.bank_notes,
		"disabled %s air %d foot %d bank %d" % [air_tile.disabled, air_leg, foot_leg,
		GameState.bank_notes])
	GameState.bank_notes = held
	window._refresh()
	await host.get_tree().process_frame
	var minutes: int = GameState.travel_minutes("foot", view.distance_km)
	var billed: int = maxi(window.team_size(), view.merc_min)
	var want: int = ceili(float(minutes) / 1440.0) * billed
	var foot_tile: TravelButton = venture.button_for("foot")
	TestFixtures.check(res, "foot bills one note per billed merc per travel day",
		foot_tile.cost_value() == want and foot_tile.minutes_value() == minutes,
		"cost %d of %d minutes %d of %d" % [foot_tile.cost_value(), want,
		foot_tile.minutes_value(), minutes])
	TestFixtures.check(res, "foot hours come off the campaign clock",
		is_equal_approx(foot_tile.hours_value(), float(minutes) / 60.0),
		"hours %.2f of %.2f" % [foot_tile.hours_value(), float(minutes) / 60.0])
	TestFixtures.check(res, "the tip spells a leg out in days and hours",
		TravelTip.duration_text(0) == "Instant"
		and TravelTip.duration_text(600) == "0 Days, 10 Hours"
		and TravelTip.duration_text(2940) == "2 Days, 1 Hours",
		"600 %s 2940 %s" % [TravelTip.duration_text(600), TravelTip.duration_text(2940)])
	var horse: TravelButton = venture.button_for("horse")
	var tip: TravelTip = venture.tip()
	tip.show_for(horse)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a hovered tile raises the 200 wide tip above itself",
		tip.visible and absf(tip.size.x - float(TravelTip.WIDTH)) <= 1.0
		and tip.global_position.y + tip.size.y <= horse.global_position.y,
		"visible %s width %.1f bottom %.1f top %.1f" % [tip.visible, tip.size.x,
		tip.global_position.y + tip.size.y, horse.global_position.y])
	TestFixtures.check(res, "the tip names the mode it stands over and its bill",
		tip.mode_text() == "BY HORSE" and tip.cost_text() == "%d" % horse.cost_value(),
		"name %s cost %s" % [tip.mode_text(), tip.cost_text()])
	tip.hide_tip()
	window.queue_free()
	viewer.queue_free()


#D1: the action bar reads the odds and gates Dispatch and Clear on the state of the form.
static func _case_action_bar(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	await host.get_tree().process_frame
	var bar: ActionBar = window.action_bar
	TestFixtures.check(res, "the dispatch window carries an action bar", bar is ActionBar,
		"bar %s" % bar)
	TestFixtures.check(res, "the three small actions measure 86 by 36",
		_is_size(bar.optimize_button, 86.0, 36.0) and _is_size(bar.clear_button, 86.0, 36.0)
		and _is_size(bar.cancel_button, 86.0, 36.0),
		"optimize %s clear %s cancel %s" % [bar.optimize_button.size, bar.clear_button.size,
		bar.cancel_button.size])
	TestFixtures.check(res, "the Dispatch tile measures 190 by 56",
		_is_size(bar.dispatch_button, 190.0, 56.0), "dispatch %s" % bar.dispatch_button.size)
	TestFixtures.check(res, "an empty team leaves Dispatch dead and Clear dim",
		bar.dispatch_button.disabled and bar.clear_button.disabled
		and is_equal_approx(bar.clear_button.modulate.a, ActionBar.CLEAR_DIM),
		"dispatch %s clear %s alpha %.2f" % [bar.dispatch_button.disabled,
		bar.clear_button.disabled, bar.clear_button.modulate.a])
	_fill_team(window)
	await host.get_tree().process_frame
	var odds: int = window.current_odds()
	var band: Color = GuiTypes.odds_color(odds)
	TestFixtures.check(res, "the odds label reads the window odds in its band colour",
		bar.odds_label.text == "%d%%" % odds
		and bar.odds_label.get_theme_color(&"font_color").is_equal_approx(band),
		"label %s odds %d colour %s" % [bar.odds_label.text, odds,
		bar.odds_label.get_theme_color(&"font_color")])
	TestFixtures.check(res, "a legal team turns Dispatch green and Clear live",
		not bar.dispatch_button.disabled
		and bar.dispatch_button.kind == &"go"
		and not bar.clear_button.disabled
		and is_equal_approx(bar.clear_button.modulate.a, 1.0),
		"dispatch %s clear %s alpha %.2f" % [bar.dispatch_button.disabled,
		bar.clear_button.disabled, bar.clear_button.modulate.a])
	TestFixtures.check(res, "the four action bar buttons are the shared BevelButton scene",
		bar.optimize_button is BevelButton and bar.clear_button is BevelButton
		and bar.cancel_button is BevelButton and bar.dispatch_button is BevelButton
		and bar.optimize_button.kind == &"blue" and bar.cancel_button.kind == &"danger"
		and bar.optimize_button.text == "Optimize" and bar.clear_button.text == "Clear"
		and bar.cancel_button.text == "Cancel" and bar.dispatch_button.text == "Dispatch",
		"optimize %s clear %s cancel %s dispatch %s" % [bar.optimize_button, bar.clear_button,
		bar.cancel_button, bar.dispatch_button])
	window.queue_free()
	viewer.queue_free()


#D1: every dispatch dialog answers safely on the first button and carries on with the last.
static func _case_dialog_kinds(res: Dictionary, host: Node) -> void:
	_fresh()
	var busy_before: Array[int] = _busy_now()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	var quit: Array[bool] = [false]
	window.cancelled.connect(func() -> void: quit[0] = true)
	window.cancel_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a clean form cancels with no dialog at all",
		quit[0] and not window.confirm().visible,
		"cancelled %s visible %s" % [quit[0], window.confirm().visible])
	_fill_team(window)
	await host.get_tree().process_frame
	window.optimize_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Optimize asks with Go Back beside an amber Continue",
		_dialog_reads(window.confirm(), ["Go Back", "Continue"],
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.WARN]),
		_dialog_text(window.confirm()))
	window.confirm().press(0)
	await host.get_tree().process_frame
	window.clear_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Clear asks with Cancel beside a red Yes",
		_dialog_reads(window.confirm(), ["Cancel", "Yes"],
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.BAD]),
		_dialog_text(window.confirm()))
	window.confirm().press(0)
	await host.get_tree().process_frame
	window.cancel_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Cancel over a filled team asks with Go Back beside a red Yes",
		_dialog_reads(window.confirm(), ["Go Back", "Yes"],
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.BAD]),
		_dialog_text(window.confirm()))
	window.confirm().press(0)
	await host.get_tree().process_frame
	window._ask_next_step(10, "")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the warning asks with Go Back beside a red Continue Anyway",
		_dialog_reads(window.confirm(), ["Go Back", "Continue Anyway"],
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.BAD]),
		_dialog_text(window.confirm()))
	window.confirm().press(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "backing out of the warning drops the ladder",
		not window.confirm().visible and _same_busy(busy_before),
		"visible %s busy %s was %s" % [window.confirm().visible, str(_busy_now()),
		str(busy_before)])
	window._ask_next_step(10, "")
	await host.get_tree().process_frame
	window.confirm().press(window.confirm().button_count() - 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "carrying the warning on lands on the recap",
		window.confirm().visible and window.confirm().title == "Dispatch This Team?"
		and window.confirm().title != "Caution",
		"title %s visible %s" % [window.confirm().title, window.confirm().visible])
	window.confirm().press(0)
	await host.get_tree().process_frame
	window._ask_next_step(30, "")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the caution asks with Go Back beside an amber Continue",
		_dialog_reads(window.confirm(), ["Go Back", "Continue"],
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.WARN]),
		_dialog_text(window.confirm()))
	window.confirm().press(window.confirm().button_count() - 1)
	await host.get_tree().process_frame
	var recap: ConfirmDialog = window.confirm()
	TestFixtures.check(res, "the caution carries on to the recap",
		recap.visible and recap.title == "Dispatch This Team?",
		"title %s visible %s" % [recap.title, recap.visible])
	TestFixtures.check(res, "the recap asks with Cancel beside a green Let's Go!",
		_dialog_reads(recap, ["Cancel", "Let's Go!"],
		[ConfirmDialog.Kind.NEUTRAL, ConfirmDialog.Kind.GO]), _dialog_text(recap))
	TestFixtures.check(res, "only the recap reward row draws a note glyph",
		recap.stat_has_glyph(2) and not recap.stat_has_glyph(0)
		and not recap.stat_has_glyph(1),
		"glyphs %s %s %s" % [recap.stat_has_glyph(0), recap.stat_has_glyph(1),
		recap.stat_has_glyph(2)])
	recap.press(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "backing out of the recap dispatches nobody",
		not recap.visible and _same_busy(busy_before),
		"busy %s was %s" % [str(_busy_now()), str(busy_before)])
	window._ask_next_step(80, "final")
	await host.get_tree().process_frame
	window.confirm().press(window.confirm().button_count() - 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the receipt stands on one green OK",
		_dialog_reads(window.confirm(), ["OK"], [ConfirmDialog.Kind.GO])
		and window.confirm().title == "Team Dispatched!",
		"title %s %s" % [window.confirm().title, _dialog_text(window.confirm())])
	window.confirm().press(0)
	await host.get_tree().process_frame
	if is_instance_valid(window):
		window.queue_free()
	viewer.queue_free()


static func _is_size(node: Control, wide: float, high: float) -> bool:
	return absf(node.size.x - wide) <= 1.0 and absf(node.size.y - high) <= 1.0


static func _dialog_reads(dialog: ConfirmDialog, labels: Array, kinds: Array) -> bool:
	if dialog == null or not dialog.visible or dialog.button_count() != labels.size():
		return false
	if absf(dialog.box.size.x - ConfirmDialog.BOX_WIDTH) > 0.5:
		return false
	var read: Array[String] = dialog.button_labels()
	for i: int in labels.size():
		if read[i] != String(labels[i]) or dialog.button_kind(i) != int(kinds[i]):
			return false
	return true


static func _dialog_text(dialog: ConfirmDialog) -> String:
	if dialog == null:
		return "no dialog"
	var kinds: Array[int] = []
	for i: int in dialog.button_count():
		kinds.append(dialog.button_kind(i))
	return "visible %s labels %s kinds %s width %.1f" % [dialog.visible,
		str(dialog.button_labels()), str(kinds), dialog.box.size.x]


#Item 27: a posting that closed behind the window fails the dispatch and is struck off.
static func _case_failed(res: Dictionary, host: Node) -> void:
	_fresh()
	var busy_before: Array[int] = _busy_now()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _open_window(viewer, view, host)
	var team: Array[int] = _fill_team(window)
	window.pick_travel(0, "foot")
	window.pick_travel(1, "foot")
	await host.get_tree().process_frame
	var lost: Array[int] = []
	window.failed.connect(func(entry_id: int) -> void: lost.append(entry_id))
	GameState.reject(view.entry_id)
	await host.get_tree().process_frame
	window.dispatch_button.pressed.emit()
	await host.get_tree().process_frame
	var titles: Array[String] = []
	var told: int = -1
	var guard: int = 0
	while guard < 6 and is_instance_valid(window) and window.confirm().visible:
		titles.append(window.confirm().title)
		if window.confirm().title == "Dispatch failed":
			told = window.confirm().severity()
		window.confirm().press(window.confirm().button_count() - 1)
		await host.get_tree().process_frame
		guard += 1
	TestFixtures.check(res, "a closed posting fails the dispatch in blue",
		titles.size() > 0 and titles[titles.size() - 1] == "Dispatch failed"
		and told == ConfirmDialog.Severity.INFO,
		"titles %s severity %d" % [str(titles), told])
	TestFixtures.check(res, "the failure names the posting it could not take",
		lost == [view.entry_id], "lost %s" % str(lost))
	var still: bool = false
	for row: ContractView in GameState.contracts:
		if row.entry_id == view.entry_id:
			still = true
	TestFixtures.check(res, "a failed posting is struck off the board",
		not still and GameState.board.entry(view.entry_id) == null,
		"listed %s" % still)
	var team_free: bool = true
	for uid: int in team:
		if GameState.busy_uids().has(uid):
			team_free = false
	TestFixtures.check(res, "nobody left and no notes were charged",
		_same_busy(busy_before) and team_free,
		"busy %s was %s" % [str(_busy_now()), str(busy_before)])
	TestFixtures.check(res, "the window closes and the viewer moves on",
		not viewer.window().is_open() and viewer.selected_id != view.entry_id,
		"open %s selected %d" % [viewer.window().is_open(), viewer.selected_id])
	viewer.queue_free()


#Walks the ladder on its last button until the named receipt is the dialog on screen.
static func _walk_to(window: DispatchWindow, title: String, host: Node) -> bool:
	var guard: int = 0
	while guard < 6 and is_instance_valid(window) and window.confirm().visible \
			and window.confirm().title != title:
		window.confirm().press(window.confirm().button_count() - 1)
		await host.get_tree().process_frame
		guard += 1
	return is_instance_valid(window) and window.confirm().visible \
		and window.confirm().title == title


#Edit 1: Esc on a receipt reports the dispatch the receipt already stands for.
static func _case_receipt_escape(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _open_window(viewer, view, host)
	_fill_team(window)
	window.pick_travel(0, "foot")
	window.pick_travel(1, "foot")
	await host.get_tree().process_frame
	var runs: Array[ActiveRun] = []
	window.dispatched.connect(func(contract_run: ActiveRun) -> void: runs.append(contract_run))
	window.dispatch_button.pressed.emit()
	await host.get_tree().process_frame
	var reached: bool = await _walk_to(window, "Team Dispatched!", host)
	var receipt: ConfirmDialog = window.confirm()
	TestFixtures.check(res, "the receipt stands above every other frame",
		reached and GuiFrameStack.top() == receipt, "reached %s" % reached)
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "Esc on the receipt still hands over the run",
		runs.size() == 1 and (not is_instance_valid(receipt) or not receipt.visible),
		"runs %d" % runs.size())
	viewer.queue_free()
	await host.get_tree().process_frame
	_fresh()
	var second_viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var lost_view: ContractView = _first_open(second_viewer)
	var failed_window: DispatchWindow = await _open_window(second_viewer, lost_view, host)
	_fill_team(failed_window)
	failed_window.pick_travel(0, "foot")
	failed_window.pick_travel(1, "foot")
	await host.get_tree().process_frame
	var lost: Array[int] = []
	failed_window.failed.connect(func(entry_id: int) -> void: lost.append(entry_id))
	GameState.reject(lost_view.entry_id)
	await host.get_tree().process_frame
	failed_window.dispatch_button.pressed.emit()
	await host.get_tree().process_frame
	var told: bool = await _walk_to(failed_window, "Dispatch failed", host)
	var notice: ConfirmDialog = failed_window.confirm()
	TestFixtures.check(res, "the failure notice stands above every other frame",
		told and GuiFrameStack.top() == notice, "told %s" % told)
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "Esc on the failure notice still names the lost posting",
		lost == [lost_view.entry_id]
		and (not is_instance_valid(notice) or not notice.visible),
		"lost %s" % str(lost))
	second_viewer.queue_free()


#Edit 3: the viewer walks the rows the player sees, not the board behind them.
static func _case_next_available(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var rules: Dictionary = viewer.list().filter_panel.filter()
	rules["show_expired"] = true
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	var ids: Array[int] = viewer.list().listed_ids()
	TestFixtures.check(res, "listed_ids reads the rows in the order they are drawn",
		ids.size() >= 3 and ids == _ids(viewer.list().listed()),
		"ids %d rows %d" % [ids.size(), viewer.list().row_count()])
	var middle: BoardEntry = GameState.board.entry(ids[1])
	middle.status = BoardEntry.STATUS_EXPIRED
	middle.closed_minute = CampaignClock.now()
	if middle.contract != null:
		middle.contract.status = "Expired"
	GameState.refresh_views()
	GameState.contracts_changed.emit()
	await host.get_tree().process_frame
	ids = viewer.list().listed_ids()
	TestFixtures.check(res, "a closed row keeps its place while its option is on",
		ids.size() >= 3 and ids[1] == middle.id, "ids %s" % str(ids))
	TestFixtures.check(res, "next_available steps over the closed row",
		viewer.next_available(ids[0]) == ids[2],
		"next %d wanted %d" % [viewer.next_available(ids[0]), ids[2]])
	viewer.queue_free()


#Round 5: the description tokens name the place, not the demonym.
static func _case_description_tokens(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var place: LocationData = LocationData.new()
	place.location_name = "Harrow"
	var filled: String = ContractGenerator.fill_description(
		"Rescue [target.name] from [location_a.name]", place, null)
	TestFixtures.check(res, "the description fills the location name token",
		filled == "Rescue [target.name] from Harrow", "text %s" % filled)


#Round 5: the roster row is the 68 px image card of the designer sheet.
static func _case_row_layout(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var row: ContractListItem = viewer.list().row_at(0)
	TestFixtures.check(res, "a roster row stands 68 px tall",
		row.custom_minimum_size.y >= 68.0, "height %.1f" % row.custom_minimum_size.y)
	var box: ContractImageBox = row.image_box()
	TestFixtures.check(res, "the row image box is 56 px square",
		box != null and box.size.x >= 56.0 and box.size.y >= 56.0,
		"size %s" % [box.size if box != null else Vector2.ZERO])
	TestFixtures.check(res, "the row status band sits on top of the image",
		absf(row.strip_label.get_parent().global_position.y - box.global_position.y) <= 1.0,
		"band %.1f image %.1f" % [row.strip_label.get_parent().global_position.y,
		box.global_position.y])
	TestFixtures.check(res, "the row reward reads the number alone",
		not row.reward_label.text.ends_with("N") and row.reward_label.text.is_valid_int(),
		"reward %s" % row.reward_label.text)
	row.set_selected(true)
	await host.get_tree().process_frame
	var box_style: StyleBoxFlat = row.get_theme_stylebox("normal") as StyleBoxFlat
	TestFixtures.check(res, "a selected row rings in orange",
		box_style != null and box_style.border_color == Color("#f28c28"),
		"edge %s" % [box_style.border_color if box_style != null else Color.BLACK])
	viewer.queue_free()


#Round 5: the detail page fits on one screen, with chips, flat cards and 54 px buttons.
static func _case_detail_layout(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var detail: ContractDetail = viewer.detail()
	TestFixtures.check(res, "the detail page carries no scroll of its own",
		detail.get_node_or_null("Scroll") == null, "scroll found")
	var buttons: DecisionButtons = detail.decisions()
	var bottom: float = buttons.global_position.y + buttons.size.y
	var limit: float = viewer.global_position.y + viewer.size.y
	TestFixtures.check(res, "the decision row fits inside the viewer",
		bottom <= limit + 0.5, "bottom %.1f limit %.1f" % [bottom, limit])
	TestFixtures.check(res, "both decision buttons stand 54 px tall",
		buttons.accept_button.size.y >= 54.0 and buttons.reject_button.size.y >= 54.0,
		"accept %.1f reject %.1f" % [buttons.accept_button.size.y,
		buttons.reject_button.size.y])
	TestFixtures.check(res, "the detail mark draws four pixels per art pixel",
		detail.status_mark().icon_rect.pixel_scale == ContractDetail.DETAIL_MARK_SCALE
		and ContractDetail.DETAIL_MARK_SCALE == 4,
		"scale %d" % detail.status_mark().icon_rect.pixel_scale)
	var first: RecommendedList = detail.list(0)
	TestFixtures.check(res, "a recommended entry rides on a slot chip",
		first.row_count() == 0 or first.chip_at(0) is SlotChip,
		"rows %d chip %s" % [first.row_count(), first.chip_at(0)])
	TestFixtures.check(res, "each recommended block keeps a scroll well",
		detail.recommended.size.y > 0.0 and first.well() is ScrollContainer
		and detail.list(1).well() is ScrollContainer
		and detail.list(2).well() is ScrollContainer,
		"height %.1f" % detail.recommended.size.y)
	var traditions: RecommendedList = detail.list(2)
	var trad_rows: int = traditions.row_count()
	TestFixtures.check(res, "a recommended tradition rides the shared module",
		trad_rows == 0 or (traditions.module_at(0) is TraditionModule
			and traditions.chip_at(0) == null),
		"rows %d module %s chip %s" % [trad_rows, traditions.module_at(0),
			traditions.chip_at(0)])
	var wide: bool = true
	var laid_out: bool = true
	for i: int in trad_rows:
		var module: TraditionModule = traditions.module_at(i)
		if module == null:
			wide = false
			continue
		if absf(module.size.x - traditions.rows.size.x) > 1.0:
			wide = false
		var mod_rect: Rect2 = module.get_global_rect()
		var sig_rect: Rect2 = module.sigil().get_global_rect()
		if not mod_rect.encloses(sig_rect):
			laid_out = false
		if sig_rect.end.x > module.name_label().global_position.x:
			laid_out = false
	TestFixtures.check(res, "every tradition module fills the well row", wide,
		"rows %d well %.1f first %.1f" % [trad_rows, traditions.rows.size.x,
			traditions.module_at(0).size.x if trad_rows > 0 else 0.0])
	TestFixtures.check(res, "every tradition module keeps its sigil left of the name", laid_out,
		"rows %d" % trad_rows)
	buttons.set_state(GuiTypes.ContractStatus.AVAILABLE, true)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a queued posting leaves Cancel Dispatch alone on the row",
		not buttons.accept_button.visible and not buttons.reject_button.visible
		and buttons.cancel_button.visible
		and buttons.cancel_button.size.x >= 0.9 * buttons.size.x,
		"cancel %.1f row %.1f" % [buttons.cancel_button.size.x, buttons.size.x])
	TestFixtures.check(res, "an open posting names its deadline date",
		detail.deadline_text().begins_with("Deadline "),
		"deadline %s" % detail.deadline_text())
	TestFixtures.check(res, "the stars carry the difficulty word as a hover tip",
		detail.stars.tooltip_text == view.difficulty_name(),
		"tip %s" % detail.stars.tooltip_text)
	var card: StatCard = detail.card(ContractDetail.CARD_URGENCY)
	TestFixtures.check(res, "the urgency card hides its accent bar and keeps its colour",
		not card.accent_bar.visible
		and card.accent_color() == GuiTypes.urgency_color(view.urgency),
		"visible %s colour %s" % [card.accent_bar.visible, str(card.accent_color())])
	var distance: StatCard = detail.card(ContractDetail.CARD_DISTANCE)
	TestFixtures.check(res, "the distance card puts its location beside the value",
		distance.note_inline_label.visible and not distance.note_label.visible,
		"inline %s stacked %s" % [distance.note_inline_label.visible,
		distance.note_label.visible])
	var note_top: float = distance.note_inline_label.global_position.y
	var value_top: float = distance.value_label.global_position.y
	TestFixtures.check(res, "the location shares the value's line",
		absf(note_top - value_top) <= 8.0,
		"note %.1f value %.1f" % [note_top, value_top])
	viewer.queue_free()


#Round 6 and A2: each decision button carries its own fill and a cream glyph.
static func _case_decision_colors(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var buttons: DecisionButtons = viewer.detail().decisions()
	var fills: Array[Color] = [DecisionButtons.ACCEPT_FILL, DecisionButtons.REJECT_FILL,
		DecisionButtons.CANCEL_FILL]
	var names: Array[String] = ["accept", "reject", "cancel"]
	var faces: Array[BevelButton] = [buttons.accept_button, buttons.reject_button,
		buttons.cancel_button]
	for i: int in faces.size():
		TestFixtures.check(res, "the %s button wears its own fill" % names[i],
			faces[i] is BevelButton and faces[i].fill == fills[i],
			"fill %s" % [faces[i].fill])
	TestFixtures.check(res, "the bevels follow each button's fill",
		buttons.accept_button.hi != buttons.reject_button.hi,
		"accept %s reject %s" % [buttons.accept_button.hi, buttons.reject_button.hi])
	var glyph: TextureRect = buttons.accept_button.get_node_or_null(
		DecisionButtons.GLYPH_NODE) as TextureRect
	var img: Image = null
	if glyph != null and glyph.texture != null:
		img = glyph.texture.get_image()
	var cream: int = 0
	var shade: int = 0
	var stray: int = 0
	if img != null:
		for y: int in img.get_height():
			for x: int in img.get_width():
				var px: Color = img.get_pixel(x, y)
				if px.a < 0.5:
					continue
				if px.is_equal_approx(DecisionButtons.GLYPH_COLOR):
					cream += 1
				elif px.is_equal_approx(DecisionButtons.SHADOW_COLOR):
					shade += 1
				else:
					stray += 1
	TestFixtures.check(res, "the accept glyph is drawn in the label cream over its own drop",
		cream > 0 and shade > 0 and stray == 0,
		"cream %d shade %d stray %d" % [cream, shade, stray])
	viewer.queue_free()


#S14: a drop lands anywhere on the slot and the drag carries a copy of the roster row.
static func _case_drag_ghost(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	var slot: TeamSlot = window.slot_at(1)
	var forwarded: Array[Control] = slot.forwarded_controls()
	TestFixtures.check(res, "the slot forwards drops from the controls that cover it",
		forwarded.has(slot.empty_button) and forwarded.has(slot.role_option)
		and forwarded.has(slot.remove_button),
		"forwarded %s" % [_names(forwarded)])
	var all_stop: bool = true
	for control: Control in forwarded:
		if control.mouse_filter != Control.MOUSE_FILTER_STOP:
			all_stop = false
	TestFixtures.check(res, "only the controls that would swallow a drop forward one",
		all_stop and not forwarded.is_empty(), "forwarded %s" % [_names(forwarded)])
	var missed: Array[Control] = []
	_stop_descendants(slot, forwarded, missed)
	TestFixtures.check(res, "no control under the slot is left to swallow a drop",
		missed.is_empty(), "missed %s" % [_names(missed)])
	var row: DispatchRosterItem = window.roster_panel().first_free_row()
	var ghost: MercDragGhost = MercDragGhost.build(row.view, 3.0, Vector2(240.0, 64.0),
		Vector2(30.0, 20.0))
	host.add_child(ghost)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the ghost carries a copy of the roster row",
		ghost.row() != null and ghost.row().name_label.text == row.view.name,
		"row %s" % [ghost.row()])
	TestFixtures.check(res, "the ghost row takes the size it was grabbed at",
		ghost.row().size == Vector2(240.0, 64.0), "size %s" % [ghost.row().size])
	TestFixtures.check(res, "the grab point stays under the cursor",
		ghost.row().position == Vector2(-30.0, -20.0), "position %s" % [ghost.row().position])
	TestFixtures.check(res, "the held module is nearly opaque and takes no mouse",
		is_equal_approx(ghost.modulate.a, MercDragGhost.GHOST_ALPHA)
		and ghost.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ghost.row().mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"alpha %.2f" % ghost.modulate.a)
	var ghost_box: StyleBoxFlat = ghost.box()
	TestFixtures.check(res, "the ghost wears its own module box and hides the status band",
		ghost_box != null
		and ghost_box.bg_color.to_html(false) == MercDragGhost.BOX_BG.to_html(false)
		and ghost_box.border_color.to_html(false) == MercDragGhost.BOX_RING.to_html(false)
		and ghost_box.border_width_top == MercDragGhost.BOX_RING_WIDTH
		and not ghost.row().status_panel.visible,
		"box %s band %s" % [ghost_box, ghost.row().status_panel.visible])
	ghost.queue_free()
	var far: MercDragGhost = MercDragGhost.build(row.view, 3.0, Vector2(240.0, 64.0),
		Vector2(500.0, 500.0))
	TestFixtures.check(res, "a grab past the row is pulled back to its corner",
		far.row().position == Vector2(-240.0, -64.0), "position %s" % [far.row().position])
	far.free()
	row._get_drag_data(Vector2(10.0, 10.0))
	TestFixtures.check(res, "the dragged roster row dims while it is held",
		row.is_held() and is_equal_approx(row.modulate.a, DispatchRosterItem.HELD_ALPHA),
		"held %s alpha %.2f" % [row.is_held(), row.modulate.a])
	row.notification(Control.NOTIFICATION_DRAG_END)
	TestFixtures.check(res, "the roster row comes back when the drag ends",
		not row.is_held() and is_equal_approx(row.modulate.a, 1.0),
		"held %s alpha %.2f" % [row.is_held(), row.modulate.a])
	window.place(row.merc_uid(), 1)
	await host.get_tree().process_frame
	slot._get_drag_data(Vector2(20.0, 20.0))
	TestFixtures.check(res, "the dragged slot dims while it is held",
		slot.is_held() and is_equal_approx(slot.filled_box.modulate.a, TeamSlot.HELD_ALPHA),
		"held %s alpha %.2f" % [slot.is_held(), slot.filled_box.modulate.a])
	slot.notification(Control.NOTIFICATION_DRAG_END)
	TestFixtures.check(res, "the slot comes back when the drag ends",
		not slot.is_held() and is_equal_approx(slot.filled_box.modulate.a, 1.0),
		"held %s alpha %.2f" % [slot.is_held(), slot.filled_box.modulate.a])
	window.queue_free()
	viewer.queue_free()


static func _names(controls: Array[Control]) -> Array[String]:
	var out: Array[String] = []
	for control: Control in controls:
		out.append(str(control.name))
	return out


#Every STOP Control under the slot that never took the forwarding, so none can eat a drop.
static func _stop_descendants(node: Node, known: Array[Control], missed: Array[Control]) -> void:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		if control.mouse_filter == Control.MOUSE_FILTER_STOP and not known.has(control):
			missed.append(control)
		_stop_descendants(control, known, missed)


#D3: the header band, the role dropdown, the empty prompt and the trait rows a slot now carries.
static func _case_slot_roles(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	await host.get_tree().process_frame
	var lead: TeamSlot = window.slot_at(0)
	var band: StyleBoxFlat = lead.leader_band.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "slot 0 wears the orange Leader band and carries no dropdown",
		lead.leader_band.visible and lead.leader_label.text == TeamSlot.LEADER_ROLE.to_upper()
		and band != null and band.bg_color.to_html(false) == TeamSlot.LEADER_COLOR.to_html(false)
		and not lead.role_option.visible and lead.role() == TeamSlot.LEADER_ROLE,
		"band %s" % lead.leader_label.text)
	TestFixtures.check(res, "the header band stands 24 px tall across the slot",
		is_equal_approx(lead.header.size.y, float(TeamSlot.HEADER_HEIGHT))
		and is_equal_approx(lead.header.size.x, lead.size.x - float(TeamSlot.RING_WIDTH) * 2.0),
		"head %s in %s" % [lead.header.size, lead.size])
	var below: TeamSlot = window.slot_at(1)
	var listed: Array[String] = []
	for i: int in below.role_option.item_count:
		listed.append(below.role_option.get_item_text(i))
	TestFixtures.check(res, "a slot below the leader lists the five roles with Support picked",
		listed.size() == 5 and listed == TeamSlot.slot_roles()
		and below.role() == TeamSlot.DEFAULT_ROLE and not below.leader_band.visible,
		"roles %s" % str(listed))
	var arrow: Texture2D = below.role_option.get_theme_icon("arrow")
	var hover: StyleBoxFlat = below.role_option.get_theme_stylebox("hover") as StyleBoxFlat
	TestFixtures.check(res, "the role dropdown wears a cream arrow clear of the X",
		below.role_option.has_theme_icon_override("arrow") and arrow != null
		and arrow.get_size() == Vector2(TeamSlot.ARROW_SIZE)
		and below.role_option.get_theme_constant("arrow_margin") >= 26,
		"arrow %s margin %d" % [arrow.get_size() if arrow != null else Vector2.ZERO,
		below.role_option.get_theme_constant("arrow_margin")])
	TestFixtures.check(res, "a pickable role wears the raised bevel and lights up on hover",
		below.bevel_top.visible and below.bevel_bottom.visible
		and not lead.bevel_top.visible and not lead.bevel_bottom.visible
		and is_equal_approx(below.bevel_top.size.y, 2.0)
		and is_equal_approx(below.bevel_bottom.size.y, 2.0)
		and hover != null and hover.bg_color.to_html(false) == "3b6fb6",
		"bevels %s %s hover %s" % [below.bevel_top.visible, lead.bevel_top.visible,
		hover.bg_color if hover != null else Color.BLACK])
	TestFixtures.check(res, "an empty slot shows the plus over the prompt",
		below.empty_button.visible and below.plus_label.text == "+"
		and below.plus_label.get_theme_color("font_color").to_html(false) == TeamSlot.DASH_COLOR.to_html(false)
		and below.prompt_label.text == TeamSlot.EMPTY_TEXT, "plus %s" % below.plus_label.text)
	TestFixtures.check(res, "slot 0 reads Required and tags the Leader in orange",
		lead.caption_label.text == TeamSlot.REQUIRED_TEXT and lead.caption_dot.visible
		and lead.caption_tag.visible and lead.caption_tag.text == TeamSlot.LEADER_ROLE
		and lead.caption_label.get_theme_color("font_color") == TeamSlot.LEADER_COLOR
		and lead.caption_dot.color.to_html(false) == TeamSlot.LEADER_COLOR.to_html(false),
		"caption %s" % lead.caption_label.text)
	var spare: TeamSlot = window.slot_at(2)
	TestFixtures.check(res, "a slot under merc_min reads Required, the slots past it Optional",
		below.caption_label.text == TeamSlot.REQUIRED_TEXT and not below.caption_tag.visible
		and below.caption_label.get_theme_color("font_color") == TeamSlot.LEADER_COLOR
		and spare.caption_label.text == "Optional"
		and spare.caption_label.get_theme_color("font_color") == TeamSlot.OPTIONAL_TEXT_COLOR,
		"slot 2 %s" % spare.caption_label.text)
	var first: int = window.roster_panel().first_free_row().merc_uid()
	window.place(first, 0)
	var second: int = window.roster_panel().first_free_row().merc_uid()
	window.place(second, 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a filled slot shows a 56 px portrait beside the badge",
		below.portrait.pixel_size == TeamSlot.PORTRAIT_SIZE and below.filled_box.visible
		and below.remove_button.visible and below.remove_button.text == "X"
		and below.remove_button.custom_minimum_size == Vector2(20, 20)
		and below.remove_button.size == Vector2(20, 20),
		"portrait %d" % below.portrait.pixel_size)
	var own_ok: bool = below.trait_rows().size() == TeamSlot.TRAIT_ROWS
	for row: TraitRow in below.trait_rows():
		if row.stars == null or row.is_shared():
			own_ok = false
		if row.name_label.has_theme_color_override("font_color"):
			own_ok = false
	TestFixtures.check(res, "a filled slot carries two trait rows, each with its stars",
		own_ok and below.traits_caption.visible and below.traits_caption.text == "Top Traits",
		"rows %d" % below.trait_rows().size())
	var below_view: MercView = window._view_of(second)
	TestFixtures.check(res, "a filled slot reads the first name and keeps the rest for the tooltip",
		below.name_label.text == TeamSlot.first_name(below_view.name)
		and not below.name_label.text.contains(" ")
		and below.tooltip_text.begins_with(below_view.name)
		and below.tooltip_text.contains("Level %d" % below_view.level)
		and below.tooltip_text.contains(below_view.tradition)
		and TeamSlot.first_name("Denbir Bulirga") == "Denbir"
		and TeamSlot.first_name("Solo") == "Solo" and TeamSlot.first_name("") == "",
		"shown '%s' of '%s'" % [below.name_label.text, below_view.name])
	var leader_view: MercView = window._view_of(first)
	var wanted: Array[Dictionary] = DispatchLogic.top_traits(leader_view, view, window.roles[1])
	var lent_ok: bool = below.divider.visible == (wanted.size() > 0)
	for i: int in below.shared_rows().size():
		var row: TraitRow = below.shared_rows()[i]
		if i >= wanted.size():
			if row.visible:
				lent_ok = false
			continue
		if not row.visible or row.trait_name() != str(wanted[i].get("name", "")):
			lent_ok = false
		if not row.is_shared() or not row.tooltip_text.contains(TraitRow.SHARED_TIP):
			lent_ok = false
		if row.name_label.get_theme_color("font_color").to_html(false) != "f28c28":
			lent_ok = false
	TestFixtures.check(res, "the leader lends their top traits to the slot below, named orange",
		lent_ok, "wanted %d first %s" % [wanted.size(), below.shared_rows()[0].trait_name()])
	TestFixtures.check(res, "the leader slot borrows nothing",
		not lead.divider.visible and not lead.shared_rows()[0].visible
		and not lead.shared_rows()[1].visible, "divider %s" % lead.divider.visible)
	var shown: int = 0
	for i: int in window.slot_count():
		if window.slot_at(i).visible:
			shown += 1
	TestFixtures.check(res, "five slots each hold the fixed 120 px column",
		shown == 5 and absf(below.size.x - float(TeamSlot.SLOT_WIDTH)) <= 0.5
		and below.get_combined_minimum_size().x <= float(TeamSlot.SLOT_WIDTH) + 0.5,
		"shown %d width %.1f min %.1f" % [shown, below.size.x,
		below.get_combined_minimum_size().x])
	below.clear_member()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a cleared slot drops the tooltip with the merc",
		below.tooltip_text.is_empty() and lead.tooltip_text.begins_with(leader_view.name),
		"empty '%s'" % below.tooltip_text)
	window.queue_free()
	viewer.queue_free()


#D7: the trait rows scroll inside the filled body, so a long list never pushes the slot open.
static func _case_trait_scroll(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	await host.get_tree().process_frame
	window.optimize()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var slot: TeamSlot = window.slot_at(1)
	var inside: bool = slot.traits_scroll.is_ancestor_of(slot.divider)
	for row: TraitRow in _all_trait_rows(slot):
		if not slot.traits_scroll.is_ancestor_of(row):
			inside = false
	TestFixtures.check(res, "the five trait rows and their divider live in the trait scroll",
		inside and slot.traits_scroll.mouse_filter == Control.MOUSE_FILTER_PASS
		and slot.traits_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and slot.traits_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"inside %s filter %d" % [inside, slot.traits_scroll.mouse_filter])
	TestFixtures.check(res, "the trait scroll bar takes the slot's drop forwarding",
		slot.forwarded_controls().has(slot.traits_scroll.get_v_scroll_bar()),
		"forwarded %s" % str(_names(slot.forwarded_controls())))
	var fits: bool = true
	var worst: String = ""
	for i: int in window.slot_count():
		var each: TeamSlot = window.slot_at(i)
		if not each.is_filled():
			continue
		var body: Control = each.filled_box.get_parent() as Control
		var want: float = each.filled_box.get_combined_minimum_size().y
		worst += " %d %.1f of %.1f" % [i, want, body.size.y]
		if want > body.size.y + 0.5:
			fits = false
	TestFixtures.check(res, "the filled stack asks for no more height than the body gives",
		fits and not worst.is_empty(), "filled%s" % worst)
	var bar: VScrollBar = slot.traits_scroll.get_v_scroll_bar()
	TestFixtures.check(res, "every trait name fits its column at 8 px or trims to an ellipsis",
		_names_fit(slot), "bar %.1f rows%s" % [bar.size.x, _trait_report(slot)])
	window.queue_free()
	viewer.queue_free()


#Both own rows and both lent rows of one slot, in the order the list holds them.
static func _all_trait_rows(slot: TeamSlot) -> Array[TraitRow]:
	var out: Array[TraitRow] = []
	for row: TraitRow in slot.trait_rows():
		out.append(row)
	for row: TraitRow in slot.shared_rows():
		out.append(row)
	return out


static func _names_fit(slot: TeamSlot) -> bool:
	for row: TraitRow in _all_trait_rows(slot):
		if not row.visible:
			continue
		if row.name_font_px() > TraitRow.NAME_FONT_PX:
			return false
		if row.name_font_px() < TraitRow.NAME_MIN_FONT_PX:
			return false
		if row.shown_name() == row.trait_name():
			continue
		if row.name_font_px() != TraitRow.NAME_MIN_FONT_PX:
			return false
		if not row.shown_name().ends_with(TraitRow.ELLIPSIS):
			return false
	return true


#The fit of each visible trait name, for the log: the size it settled on and what it shows.
static func _trait_report(slot: TeamSlot) -> String:
	var out: String = ""
	for row: TraitRow in _all_trait_rows(slot):
		if not row.visible:
			continue
		out += " [%d px %.1f wide '%s' of '%s']" % [row.name_font_px(), row.name_label.size.x,
			row.shown_name(), row.trait_name()]
	return out


#The role caption and the portrait box are all one crew column keeps.
static func _crew_stack_count(crew: ActiveCrew) -> int:
	if crew.columns.get_child_count() == 0:
		return -1
	return crew.columns.get_child(0).get_child(0).get_child_count()


static func _crew_has_name(crew: ActiveCrew) -> bool:
	if crew.columns.get_child_count() == 0:
		return false
	for child: Node in crew.columns.get_child(0).get_child(0).get_children():
		var label: Label = child as Label
		if label != null and label.theme_type_variation == &"ListSecondaryLabel":
			return true
	return false


#D3: the roster row grid, the marks an assigned row wears and the order the sort dropdown offers.
static func _case_roster_rows(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	await host.get_tree().process_frame
	var panel: DispatchRoster = window.roster_panel()
	var row: DispatchRosterItem = panel.row_at(0)
	TestFixtures.check(res, "a roster row carries a 48 px portrait beside a 40x48 badge",
		row.portrait.pixel_size == DispatchRosterItem.PORTRAIT_SIZE
		and row.badge().size_mode == LevelBadge.SizeMode.TILE
		and row.badge().plate_size == Vector2(40, 48) and row.badge().size == Vector2(40, 48),
		"portrait %d badge %s" % [row.portrait.pixel_size, row.badge().size])
	TestFixtures.check(res, "a roster row stands 56 tall",
		is_equal_approx(row.custom_minimum_size.y, 56.0) and is_equal_approx(row.size.y, 56.0),
		"min %.1f live %.1f" % [row.custom_minimum_size.y, row.size.y])
	TestFixtures.check(res, "the row stars read the fit against the General role",
		is_equal_approx(row.stars_value(),
			DispatchLogic.to_stars(DispatchLogic.score(row.view, view, "General", {}))),
		"stars %.2f" % row.stars_value())
	TestFixtures.check(res, "the sort row stands 26 tall beside a 40 px toggle, descending first",
		is_equal_approx(panel.sort_button.custom_minimum_size.y, 26.0)
		and panel.dir_toggle.custom_minimum_size == Vector2(40, 26) and panel.dir_toggle.descending,
		"sort %s dir %s" % [panel.sort_button.custom_minimum_size, panel.dir_toggle.descending])
	TestFixtures.check(res, "the sort list reads Best, Name A-Z, Level, Tradition A-Z",
		DispatchRoster.SORT_OPTIONS == ["Best", "Name A-Z", "Level", "Tradition A-Z"]
		and panel.sort_button.options == DispatchRoster.SORT_OPTIONS
		and DispatchRoster.Sort.LEVEL == 2 and DispatchRoster.Sort.TRADITION == 3,
		"options %s" % str(DispatchRoster.SORT_OPTIONS))
	panel.sort_button.selected = DispatchRoster.Sort.LEVEL
	panel.rebuild()
	await host.get_tree().process_frame
	var level_ok: bool = panel.row_count() > 1
	for i: int in maxi(panel.row_count() - 1, 0):
		if panel.row_at(i).view.level < panel.row_at(i + 1).view.level:
			level_ok = false
	panel.sort_button.selected = DispatchRoster.Sort.TRADITION
	panel.rebuild()
	await host.get_tree().process_frame
	var trad_ok: bool = panel.row_count() > 1
	for i: int in maxi(panel.row_count() - 1, 0):
		if panel.row_at(i).view.tradition < panel.row_at(i + 1).view.tradition:
			trad_ok = false
	TestFixtures.check(res, "Level and Tradition sort by the enum the new order names",
		level_ok and trad_ok, "level %s tradition %s" % [level_ok, trad_ok])
	panel.sort_button.selected = DispatchRoster.Sort.BEST
	panel.rebuild()
	await host.get_tree().process_frame
	var uid: int = panel.row_at(0).merc_uid()
	window.place(uid, 0)
	await host.get_tree().process_frame
	var taken: DispatchRosterItem = _roster_row(panel, uid)
	TestFixtures.check(res, "an assigned row dims to 0.6 and reads ASSIGNED in green",
		taken != null and taken.is_assigned()
		and is_equal_approx(DispatchRosterItem.ASSIGNED_ALPHA, 0.6)
		and is_equal_approx(taken.modulate.a, DispatchRosterItem.ASSIGNED_ALPHA)
		and taken.status_panel.visible
		and taken.status_text() == DispatchRosterItem.ASSIGNED_TEXT
		and taken.status_label.get_theme_color("font_color").to_html(false)
			== DispatchRosterItem.RING_COLOR.to_html(false),
		"alpha %.2f reads %s" % [taken.modulate.a if taken != null else -1.0,
		taken.status_text() if taken != null else "none"])
	var free_row: DispatchRosterItem = panel.first_free_row()
	TestFixtures.check(res, "a free row reads AVAILABLE in sky over its portrait",
		free_row != null and free_row.status_panel.visible
		and free_row.status_text() == DispatchRosterItem.AVAILABLE_TEXT
		and free_row.status_label.has_theme_color_override("font_color")
		and free_row.status_label.get_theme_color("font_color").to_html(false)
			== DispatchRosterItem.AVAILABLE_COLOR.to_html(false),
		"reads %s" % (free_row.status_text() if free_row != null else "none"))
	var strip: Rect2 = free_row.status_panel.get_global_rect()
	var face: Rect2 = free_row.portrait.get_global_rect()
	TestFixtures.check(res, "the band caps the portrait, full width and STATUS_HEIGHT tall",
		is_equal_approx(strip.position.x, face.position.x)
		and is_equal_approx(strip.position.y, face.position.y)
		and is_equal_approx(strip.size.x, face.size.x)
		and is_equal_approx(strip.size.y, float(DispatchRosterItem.STATUS_HEIGHT)),
		"band %s face %s" % [strip, face])
	var glyph: Font = free_row.status_label.get_theme_font("font")
	var reach: float = glyph.get_string_size(DispatchRosterItem.AVAILABLE_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT, -1, DispatchRosterItem.STATUS_FONT_PX).x
	TestFixtures.check(res, "AVAILABLE fits the portrait at STATUS_FONT_PX",
		reach <= face.size.x + 0.5 and DispatchRosterItem.STATUS_FONT_PX
			== free_row.status_label.get_theme_font_size("font_size"),
		"text %.1f px of %.1f at %d px" % [reach, face.size.x,
		DispatchRosterItem.STATUS_FONT_PX])
	TestFixtures.check(res, "the assigned ring is 3 px of the same green",
		DispatchRosterItem.RING_COLOR == Color("#6cc36a")
		and is_equal_approx(DispatchRosterItem.RING_WIDTH, 3.0),
		"ring %s" % DispatchRosterItem.RING_COLOR)
	window.queue_free()
	viewer.queue_free()


#D3: the picker is an overlay now, dimming the window behind a centred box.
static func _case_picker_overlay(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	var picker: MercPicker = window.picker
	TestFixtures.check(res, "the picker stays hidden until a slot asks for it",
		not picker.visible, "visible %s" % picker.visible)
	window.open_picker(0)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "the picker dims the window behind it",
		picker.visible and picker.backdrop.visible
		and picker.backdrop.color == Color(0.039216, 0.058824, 0.109804, 0.6),
		"backdrop %s" % picker.backdrop.color)
	var ring: StyleBoxFlat = picker.box.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the box is 380 wide inside a 520 cap behind an orange ring",
		is_equal_approx(picker.box.size.x, float(MercPicker.BOX_WIDTH))
		and picker.box.size.y <= float(MercPicker.BOX_HEIGHT) and ring != null
		and ring.border_color.to_html(false) == TeamSlot.LEADER_COLOR.to_html(false)
		and ring.border_width_top == 3,
		"box %s" % picker.box.size)
	var rows_ok: bool = picker.row_count() > 0
	for i: int in picker.row_count():
		var portrait: MercPortrait = picker.row_portrait(i)
		if portrait == null or portrait.pixel_size != MercPicker.PORTRAIT_SIZE:
			rows_ok = false
		if not picker.row_text(i).begins_with("LVL "):
			rows_ok = false
		if not is_equal_approx(picker.row_button(i).custom_minimum_size.y,
				float(MercPicker.ROW_HEIGHT)):
			rows_ok = false
	TestFixtures.check(res, "every picker row carries a 40 px portrait over the level line",
		rows_ok, "rows %d first %s" % [picker.row_count(), picker.row_text(0)])
	picker.close_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the X closes the picker", not picker.visible,
		"visible %s" % picker.visible)
	window.open_picker(0)
	await host.get_tree().process_frame
	picker._on_backdrop_input(_left_button(true))
	TestFixtures.check(res, "a click on the backdrop closes the picker", not picker.visible,
		"visible %s" % picker.visible)
	window.open_picker(0)
	await host.get_tree().process_frame
	var got: Array[int] = []
	picker.picked.connect(func(_uid: int, at: int) -> void: got.append(at))
	var top: int = picker.row_uid(0)
	picker.pick(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking a row still reports the uid and the slot",
		got == [0] and window.slot_at(0).merc_uid() == top and not picker.visible,
		"got %s uid %d" % [str(got), window.slot_at(0).merc_uid()])
	window.queue_free()
	viewer.queue_free()
#The centre column and its four panels fit the 1280 x 720 window inside its 20 px margin, with a
#full team and with an empty one.
static func _case_window_fit(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	var window: DispatchWindow = await _wide_window(view, host)
	window.optimize()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var centre: VBoxContainer = window.get_node("Margin/Columns/Centre") as VBoxContainer
	var travel: Control = window.get_node("Margin/Columns/Centre/TravelPanel") as Control
	var team: Control = window.get_node("Margin/Columns/Centre/TeamPanel") as Control
	TestFixtures.check(res, "the centre column asks for no more than the 692 px it gets",
		centre.get_combined_minimum_size().y <= 692.0 and centre.size.y <= 692.0,
		"min %.1f live %.1f" % [centre.get_combined_minimum_size().y, centre.size.y])
	var root_edge: float = window.get_global_rect().end.y - 14.0
	TestFixtures.check(res, "the action bar ends inside the window margin",
		window.action_bar.get_global_rect().end.y <= root_edge + 0.5,
		"bar %.1f limit %.1f" % [window.action_bar.get_global_rect().end.y, root_edge])
	var slots_in: bool = true
	var deepest: float = 0.0
	var filled: int = 0
	for i: int in window.slot_count():
		var slot: TeamSlot = window.slot_at(i)
		if not slot.is_filled():
			continue
		filled += 1
		deepest = maxf(deepest, slot.get_global_rect().end.y)
		if slot.get_global_rect().end.y > team.get_global_rect().end.y + 0.5:
			slots_in = false
	TestFixtures.check(res, "every filled slot ends inside the team panel",
		filled > 0 and slots_in,
		"filled %d slot %.1f panel %.1f" % [filled, deepest, team.get_global_rect().end.y])
	TestFixtures.check(res, "the four panels keep the prototype heights",
		window.summary.size.y <= 74.0 and travel.size.y <= 134.0
		and window.action_bar.size.y <= 91.0,
		"summary %.1f travel %.1f actions %.1f" % [window.summary.size.y, travel.size.y,
		window.action_bar.size.y])
	_check_widths(res, window, "full", true)
	window.clear_team()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "an empty team leaves the column inside the same 692 px",
		centre.get_combined_minimum_size().y <= 692.0 and centre.size.y <= 692.0,
		"min %.1f live %.1f" % [centre.get_combined_minimum_size().y, centre.size.y])
	TestFixtures.check(res, "an empty team keeps the action bar inside the margin",
		window.action_bar.get_global_rect().end.y <= root_edge + 0.5,
		"bar %.1f limit %.1f" % [window.action_bar.get_global_rect().end.y, root_edge])
	_check_widths(res, window, "empty", false)
	window.queue_free()
	viewer.queue_free()


#The widths the D6 fit rests on: the three columns, the fixed slot columns, the shared leg caption,
#the summary badge on the left, the stretched odds meter and the filled slot's face row.
static func _check_widths(res: Dictionary, window: DispatchWindow, tag: String,
		filled: bool) -> void:
	var columns: HBoxContainer = window.get_node("Margin/Columns") as HBoxContainer
	var left: Control = window.get_node("Margin/Columns/Left") as Control
	var centre: Control = window.get_node("Margin/Columns/Centre") as Control
	var right: Control = window.get_node("Margin/Columns/Right") as Control
	TestFixtures.check(res, "%s: the columns row stays inside the 1252 px it is given" % tag,
		columns.size.x <= 1252.5 and columns.get_combined_minimum_size().x <= 1252.0,
		"size %.1f min %.1f" % [columns.size.x, columns.get_combined_minimum_size().x])
	var gaps: float = float(columns.get_theme_constant("separation")) * 2.0
	var spare: float = columns.size.x - left.size.x - right.size.x - gaps
	TestFixtures.check(res, "%s: the centre column takes every px the side columns leave" % tag,
		absf(centre.size.x - spare) <= 0.5 and centre.size.x >= 730.0
		and centre.get_combined_minimum_size().x <= centre.size.x + 0.5,
		"centre %.1f spare %.1f min %.1f" % [centre.size.x, spare,
		centre.get_combined_minimum_size().x])
	var frame_edge: float = window.get_global_rect().end.x - 14.0
	TestFixtures.check(res, "%s: the preview column ends inside the window margin" % tag,
		right.get_global_rect().end.x <= frame_edge + 0.5
		and right.size.x >= right.get_combined_minimum_size().x - 0.5
		and right == window.preview_of(),
		"right %.1f limit %.1f width %.1f min %.1f" % [right.get_global_rect().end.x,
		frame_edge, right.size.x, right.get_combined_minimum_size().x])
	var slots_ok: bool = window.slot_count() > 0
	var seen: String = ""
	for i: int in window.slot_count():
		var slot: TeamSlot = window.slot_at(i)
		if absf(slot.size.x - float(TeamSlot.SLOT_WIDTH)) > 0.5:
			slots_ok = false
		if absf(slot.position.x - float(i * (TeamSlot.SLOT_WIDTH + 10))) > 0.5:
			slots_ok = false
		seen += " %d:%.0fx%.0f" % [i, slot.position.x, slot.size.x]
	var last: TeamSlot = window.slot_at(window.slot_count() - 1)
	TestFixtures.check(res, "%s: the slots hold their 120 px columns 10 px apart, left first" % tag,
		slots_ok and last.position.x + last.size.x <= window.slot_row.size.x + 0.5,
		"row %.1f slots%s" % [window.slot_row.size.x, seen])
	var out: Label = window.venture_selector.caption_label
	var back: Label = window.return_selector.caption_label
	TestFixtures.check(res, "%s: both legs share one caption column wide enough for the text" % tag,
		absf(out.size.x - back.size.x) <= 0.5
		and out.size.x >= out.get_minimum_size().x - 0.5
		and back.size.x >= back.get_minimum_size().x - 0.5,
		"venture %.1f of %.1f return %.1f of %.1f" % [out.size.x, out.get_minimum_size().x,
		back.size.x, back.get_minimum_size().x])
	var text_box: Control = window.summary.get_node("Pad/Rows/Text") as Control
	TestFixtures.check(res, "%s: the summary level badge stands left of the text block" % tag,
		window.summary.level_badge.position.x < text_box.position.x
		and window.summary.level_badge.size == Vector2(44, 44),
		"badge %.1f text %.1f size %s" % [window.summary.level_badge.position.x,
		text_box.position.x, str(window.summary.level_badge.size)])
	var meter: SuccessMeter = window.odds_meter()
	TestFixtures.check(res, "%s: the odds meter stretches into the width it is given" % tag,
		meter.stretch and meter.size.x >= 200.0 and meter.size.x <= 240.0,
		"stretch %s width %.1f" % [meter.stretch, meter.size.x])
	if not filled:
		return
	var first: TeamSlot = window.slot_at(0)
	var tradition: TraditionModule = first.tradition_module
	var name_text: Label = tradition.name_label()
	TestFixtures.check(res, "%s: the filled slot pairs a 56 px portrait with the 48 x 56 badge" % tag,
		first.is_filled() and first.portrait.size == Vector2(56, 56)
		and first.level_badge.size == Vector2(48, 56)
		and first.portrait.get_parent() == first.face_row
		and first.level_badge.get_parent() == first.face_row,
		"portrait %s badge %s" % [str(first.portrait.size), str(first.level_badge.size)])
	TestFixtures.check(res, "%s: the slot tradition line runs compact and unclipped" % tag,
		tradition.size_mode == TraditionModule.SizeMode.COMPACT and not name_text.clip_text
		and name_text.size.x >= name_text.get_minimum_size().x - 0.5,
		"mode %d name %.1f min %.1f" % [tradition.size_mode, name_text.size.x,
		name_text.get_minimum_size().x])


#A2: both decision faces wear the pinned fills, bevels, hover and pressed shades.
static func _case_decision_palettes(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var view: ContractView = _first_open(viewer)
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	var buttons: DecisionButtons = viewer.detail().decisions()
	var faces: Array[BevelButton] = [buttons.accept_button, buttons.reject_button]
	var names: Array[String] = ["Accept", "Reject"]
	var verbs: Array[String] = ["ACCEPT", "REJECT"]
	for i: int in faces.size():
		var row: Dictionary = DecisionButtons.PALETTES[i]
		TestFixtures.check(res, "%s wears its own hover and pressed shades" % names[i],
			faces[i].hover_fill == row["hover"] and faces[i].pressed_fill == row["pressed"],
			"hover %s pressed %s" % [faces[i].hover_fill, faces[i].pressed_fill])
		TestFixtures.check(res, "%s carries its bevel pair" % names[i],
			faces[i].hi == row["hi"] and faces[i].lo == row["lo"],
			"hi %s lo %s" % [faces[i].hi, faces[i].lo])
		var text: Label = buttons.label_of(faces[i])
		var face: HBoxContainer = faces[i].get_node_or_null(
			DecisionButtons.FACE_NODE) as HBoxContainer
		var glyph: TextureRect = faces[i].get_node_or_null(
			DecisionButtons.GLYPH_NODE) as TextureRect
		TestFixtures.check(res, "%s labels in cream over a 2 px shadow" % names[i],
			text != null and text.get_theme_color("font_color") == DecisionButtons.LABEL_COLOR
			and text.get_theme_color("font_shadow_color") == DecisionButtons.SHADOW_COLOR
			and text.get_theme_constant("shadow_offset_x") == DecisionButtons.SHADOW_PX
			and text.get_theme_constant("shadow_offset_y") == DecisionButtons.SHADOW_PX,
			"label %s" % ("none" if text == null else str(text.get_theme_color("font_color"))))
		TestFixtures.check(res, "%s reads its verb off the face label" % names[i],
			faces[i].text == "" and faces[i].icon == null and text != null
			and text.text == verbs[i] and face != null
			and face.get_theme_constant("separation") == DecisionButtons.FACE_GAP,
			"button %s label %s" % [faces[i].text, "none" if text == null else text.text])
		TestFixtures.check(res, "%s hands the whole face through to the button" % names[i],
			face != null and face.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and glyph != null and glyph.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and text != null and text.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"face %d glyph %d text %d" % [face.mouse_filter if face != null else -1,
			glyph.mouse_filter if glyph != null else -1,
			text.mouse_filter if text != null else -1])
	var accept_row: Dictionary = DecisionButtons.PALETTES[DecisionButtons.ACCEPT]
	var reject_row: Dictionary = DecisionButtons.PALETTES[DecisionButtons.REJECT]
	TestFixtures.check(res, "the two palettes read the colours README A2 pins",
		accept_row["fill"] == Color("#3f9a4a") and accept_row["hi"] == Color("#6cc36a")
		and accept_row["lo"] == Color("#2a6b32") and accept_row["hover"] == Color("#4fb05a")
		and accept_row["pressed"] == Color("#2a6b32")
		and reject_row["fill"] == Color("#b8402e") and reject_row["hi"] == Color("#e8583f")
		and reject_row["lo"] == Color("#7a2a1e") and reject_row["hover"] == Color("#cc4a36")
		and reject_row["pressed"] == Color("#7a2a1e"),
		"accept %s reject %s" % [accept_row["fill"], reject_row["fill"]])
	var accept_glyph: TextureRect = buttons.accept_button.get_node_or_null(
		DecisionButtons.GLYPH_NODE) as TextureRect
	var reject_glyph: TextureRect = buttons.reject_button.get_node_or_null(
		DecisionButtons.GLYPH_NODE) as TextureRect
	TestFixtures.check(res, "both glyphs are drawn and the focus ring is emptied",
		accept_glyph != null and accept_glyph.texture != null and accept_glyph.visible
		and reject_glyph != null and reject_glyph.texture != null and reject_glyph.visible
		and buttons.accept_button.get_theme_stylebox("focus") is StyleBoxEmpty,
		"accept %s reject %s" % [accept_glyph != null and accept_glyph.texture != null,
		reject_glyph != null and reject_glyph.texture != null])
	var cancel_text: Label = buttons.label_of(buttons.cancel_button)
	var cancel_glyph: TextureRect = buttons.cancel_button.get_node_or_null(
		DecisionButtons.GLYPH_NODE) as TextureRect
	TestFixtures.check(res, "Cancel Dispatch keeps its verb and shows no glyph",
		cancel_text != null and cancel_text.text == "CANCEL DISPATCH"
		and buttons.cancel_button.text == "" and cancel_glyph != null
		and cancel_glyph.texture == null and not cancel_glyph.visible,
		"label %s glyph %s" % ["none" if cancel_text == null else cancel_text.text,
		cancel_glyph.visible if cancel_glyph != null else true])
	TestFixtures.check(res, "all three decision buttons are the shared BevelButton scene",
		buttons.accept_button is BevelButton and buttons.reject_button is BevelButton
		and buttons.cancel_button is BevelButton
		and buttons.accept_button.edge == float(DecisionButtons.EDGE_PX)
		and buttons.reject_button.edge == float(DecisionButtons.EDGE_PX)
		and buttons.cancel_button.edge == float(DecisionButtons.EDGE_PX),
		"accept %s reject %s cancel %s" % [buttons.accept_button, buttons.reject_button,
		buttons.cancel_button])
	viewer.queue_free()


#I5: the four ways a settled posting reads, claimed or not, succeeded or failed.
static func _case_shown_status(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var ids: Array[int] = GameState.seed_results_preview()
	if not await _seeded(res, ids, viewer, host):
		return
	var won: ContractView = _view_by_id(ids[0])
	var lost: ContractView = _view_by_id(ids[1])
	TestFixtures.check(res, "the fixture settles one success and one failure",
		won != null and lost != null and won.outcome == "Succeeded" and lost.outcome == "Failed"
		and won.status == GuiTypes.ContractStatus.COMPLETED
		and lost.status == GuiTypes.ContractStatus.COMPLETED,
		"won %s lost %s" % [won.outcome if won != null else "",
		lost.outcome if lost != null else ""])
	TestFixtures.check(res, "an unclaimed posting reads Complete in orange whichever way it went",
		won.is_unclaimed() and lost.is_unclaimed()
		and won.shown_status() == GuiTypes.ContractStatus.COMPLETED
		and lost.shown_status() == GuiTypes.ContractStatus.COMPLETED
		and won.shown_status_text() == "Complete" and lost.shown_status_text() == "Complete"
		and won.shown_status_color() == Color("#f28c28")
		and lost.shown_status_color() == Color("#f28c28"),
		"won %s lost %s" % [won.shown_status_text(), lost.shown_status_text()])
	TestFixtures.check(res, "an unclaimed posting wears the bang mark",
		won.shown_mark() == StatusMark.Mark.BANG and lost.shown_mark() == StatusMark.Mark.BANG
		and StatusMark.icon_of(StatusMark.Mark.BANG) == StatusMark.ICON_BANG,
		"won %d lost %d" % [won.shown_mark(), lost.shown_mark()])
	TestFixtures.check(res, "an unclaimed posting answers to the Unclaimed Results option",
		ContractList.filter_key(won) == ContractList.UNCLAIMED_KEY
		and ContractList.filter_key(lost) == ContractList.UNCLAIMED_KEY,
		"won %s lost %s" % [ContractList.filter_key(won), ContractList.filter_key(lost)])
	GameState.mark_seen(ids[0])
	GameState.mark_seen(ids[1])
	await host.get_tree().process_frame
	TestFixtures.check(res, "a claimed success stays Completed under the check mark",
		not won.is_unclaimed() and won.shown_status() == GuiTypes.ContractStatus.COMPLETED
		and won.shown_status_text() == GuiTypes.status_text(GuiTypes.ContractStatus.COMPLETED)
		and won.shown_status_color() == GuiTypes.status_color(GuiTypes.ContractStatus.COMPLETED)
		and won.shown_mark() == StatusMark.Mark.CHECK,
		"status %s mark %d" % [won.shown_status_text(), won.shown_mark()])
	TestFixtures.check(res, "a claimed failure turns Failed and red under the skull",
		not lost.is_unclaimed() and lost.shown_status() == GuiTypes.ContractStatus.FAILED
		and lost.shown_status_text() == "Failed"
		and lost.shown_status_color() == Color("#e8583f")
		and lost.shown_mark() == StatusMark.Mark.SKULL
		and StatusMark.icon_of(StatusMark.Mark.SKULL) == StatusMark.ICON_SKULL,
		"status %s mark %d" % [lost.shown_status_text(), lost.shown_mark()])
	TestFixtures.check(res, "the board never stores FAILED: only the display status turns",
		lost.status == GuiTypes.ContractStatus.COMPLETED
		and GameState.board.entry(ids[1]).status == BoardEntry.STATUS_FAILED,
		"view %d entry %s" % [lost.status, GameState.board.entry(ids[1]).status])
	TestFixtures.check(res, "a claimed posting answers to its own status option",
		ContractList.filter_key(won) == "show_completed"
		and ContractList.filter_key(lost) == "show_failed",
		"won %s lost %s" % [ContractList.filter_key(won), ContractList.filter_key(lost)])
	viewer.queue_free()


#I5: the unclaimed row keeps its colour; a claimed failure greys out with the skull and the date.
static func _case_result_rows(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var ids: Array[int] = GameState.seed_results_preview()
	if not await _seeded(res, ids, viewer, host):
		return
	var lost_id: int = ids[1]
	var view: ContractView = _view_by_id(lost_id)
	var row: ContractListItem = _row_of(viewer.list(), lost_id)
	TestFixtures.check(res, "an unclaimed posting lists at full colour under an orange Complete",
		row != null and row.strip_text() == "Complete"
		and row.strip_color() == Color("#f28c28") and row.mark.kind == StatusMark.Mark.BANG
		and row.modulate == Color.WHITE,
		"strip %s mark %d" % [row.strip_text() if row != null else "",
		row.mark.kind if row != null else -1])
	viewer.detail().set_view(view)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the unclaimed detail reads Complete over the bang and the date",
		viewer.detail().status_line() == "Complete"
		and viewer.detail().status_mark().kind == StatusMark.Mark.BANG
		and viewer.detail().date_line() == "Completed on %s"
			% TrynnCalendar.date_text(view.closed_minute),
		"status %s dates %s" % [viewer.detail().status_line(), viewer.detail().date_line()])
	GameState.mark_seen(lost_id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a claimed failure leaves the board with the Failed option off",
		not viewer.list().has_id(lost_id) and not viewer.list().filter_panel.show_failed,
		"listed %s" % viewer.list().has_id(lost_id))
	var rules: Dictionary = viewer.list().filter_panel.filter()
	rules["show_failed"] = true
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	row = _row_of(viewer.list(), lost_id)
	TestFixtures.check(res, "the Failed option greys the row under a red Failed and the skull",
		row != null and row.strip_text() == "Failed"
		and row.strip_color() == Color("#e8583f") and row.mark.kind == StatusMark.Mark.SKULL
		and row.modulate == ContractListItem.CLOSED_TINT,
		"strip %s mark %d" % [row.strip_text() if row != null else "",
		row.mark.kind if row != null else -1])
	viewer.detail().set_view(_view_by_id(lost_id))
	await host.get_tree().process_frame
	TestFixtures.check(res, "the claimed failure detail reads Failed on its closing date",
		viewer.detail().status_line() == "Failed"
		and viewer.detail().status_mark().kind == StatusMark.Mark.SKULL
		and viewer.detail().date_line() == "Failed on %s"
			% TrynnCalendar.date_text(view.closed_minute)
		and not viewer.detail().decisions().accept_button.visible,
		"status %s dates %s" % [viewer.detail().status_line(), viewer.detail().date_line()])
	GameState.mark_seen(ids[0])
	rules = viewer.list().filter_panel.filter()
	rules["show_completed"] = true
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	var won_row: ContractListItem = _row_of(viewer.list(), ids[0])
	TestFixtures.check(res, "a claimed success greys out under Completed and the check",
		won_row != null
		and won_row.strip_text() == GuiTypes.status_text(GuiTypes.ContractStatus.COMPLETED)
		and won_row.mark.kind == StatusMark.Mark.CHECK
		and won_row.modulate == ContractListItem.CLOSED_TINT,
		"strip %s mark %d" % [won_row.strip_text() if won_row != null else "",
		won_row.mark.kind if won_row != null else -1])
	viewer.queue_free()


#I5: the pay tooltip gives nothing away before the results are claimed, then reads the final pay.
static func _case_pay_rows(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var ids: Array[int] = GameState.seed_results_preview()
	if not await _seeded(res, ids, viewer, host):
		return
	var lost_id: int = ids[1]
	var tip: PayoutTooltip = viewer.detail().payout_tooltip()
	viewer.detail().set_view(_view_by_id(lost_id))
	await host.get_tree().process_frame
	viewer.detail().reward_label.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the pay tooltip stays shut while the results sit unopened",
		not tip.visible, "visible %s" % tip.visible)
	GameState.mark_seen(lost_id)
	await host.get_tree().process_frame
	viewer.detail().set_view(_view_by_id(lost_id))
	await host.get_tree().process_frame
	viewer.detail().reward_label.mouse_entered.emit()
	await host.get_tree().process_frame
	var result: ContractResultData = GameState.result_of(lost_id)
	TestFixtures.check(res, "a claimed posting opens the final pay results",
		tip.visible and tip.is_results() and tip.title_text() == PayoutTooltip.RESULT_TITLE,
		"visible %s title %s" % [tip.visible, tip.title_text()])
	var names: Array[String] = [tip.reward_name.text, tip.expenses_name.text,
		tip.total_name.text, tip.payday_name.text]
	TestFixtures.check(res, "the four rows are renamed for the results",
		names == PayoutTooltip.RESULT_NAMES and not tip.relative_label.visible,
		"names %s" % str(names))
	TestFixtures.check(res, "a failed posting forfeits the reward and still carries the cost",
		result != null and result.reward == 0
		and tip.reward_label.text == PayoutTooltip.notes_text(0)
		and tip.expenses_label.text == PayoutTooltip.notes_text(-result.expenses)
		and tip.expected_total() == PayoutTooltip.notes_text(-result.bonus())
		and tip.guild_income() == PayoutTooltip.notes_text(result.guild_share()),
		"reward %s expenses %s guild %s" % [tip.reward_label.text, tip.expenses_label.text,
		tip.guild_income()])
	GameState.mark_seen(ids[0])
	await host.get_tree().process_frame
	viewer.detail().set_view(_view_by_id(ids[0]))
	await host.get_tree().process_frame
	viewer.detail().reward_label.mouse_entered.emit()
	await host.get_tree().process_frame
	var won: ContractResultData = GameState.result_of(ids[0])
	TestFixtures.check(res, "a claimed success reads the pay it brought in",
		tip.visible and won != null and won.reward > 0
		and tip.reward_label.text == PayoutTooltip.notes_text(won.reward)
		and tip.guild_income() == PayoutTooltip.notes_text(won.guild_share()),
		"reward %s guild %s" % [tip.reward_label.text, tip.guild_income()])
	viewer.queue_free()


#Item 6: the seven status options, their order, the indent and the defaults.
static func _case_filter_options(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var panel: ContractFilterPanel = viewer.list().filter_panel
	var wanted: Array[String] = ["Available", "Active", "Completed", "Failed",
		"Unclaimed Results", "Rejected", "Expired"]
	TestFixtures.check(res, "the filter lists the seven status options in order",
		panel.row_labels() == wanted, "labels %s" % str(panel.row_labels()))
	TestFixtures.check(res, "Unclaimed Results sits indented under the two outcomes",
		panel.indent_of("show_unclaimed") == ContractFilterPanel.INDENT_PX
		and panel.indent_of("show_completed") == 0 and panel.indent_of("show_failed") == 0,
		"unclaimed %d completed %d" % [panel.indent_of("show_unclaimed"),
		panel.indent_of("show_completed")])
	var starts: Dictionary = {"show_available": true, "show_active": true,
		"show_completed": false, "show_failed": false, "show_unclaimed": true,
		"show_rejected": false, "show_expired": false}
	var flags: Dictionary = panel.flags()
	var starts_ok: bool = flags.size() == starts.size()
	for key: String in starts:
		var want: bool = bool(starts[key])
		if bool(flags.get(key, not want)) != want:
			starts_ok = false
		if bool(ContractList.DEFAULT_SHOWN.get(key, not want)) != want:
			starts_ok = false
	TestFixtures.check(res, "only Available, Active and Unclaimed Results start on", starts_ok,
		"flags %s" % str(flags))
	TestFixtures.check(res, "the old option Completed (Unclaimed) is gone",
		not panel.row_labels().has("Completed (Unclaimed)")
		and not panel.filter().has("show_closed")
		and ContractFilterPanel.OPTIONS.size() == starts.size(),
		"labels %s" % str(panel.row_labels()))
	TestFixtures.check(res, "each check row mirrors its own export",
		panel.row_of("show_available") != null and panel.row_of("show_available").on
		and panel.row_of("show_failed") != null and not panel.row_of("show_failed").on
		and panel.row_of("show_unclaimed").on,
		"available %s failed %s" % [panel.row_of("show_available").on,
		panel.row_of("show_failed").on])
	panel.row_of("show_failed").toggled.emit(true)
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing a row writes its export and the list follows",
		panel.show_failed and bool(viewer.list().filter.get("show_failed", false)),
		"export %s list %s" % [panel.show_failed,
		viewer.list().filter.get("show_failed", false)])
	panel.reset()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Reset puts the seven options back to the defaults",
		not panel.show_failed and panel.show_available and panel.show_active
		and panel.show_unclaimed and not panel.show_completed and not panel.show_rejected
		and not panel.show_expired,
		"failed %s completed %s" % [panel.show_failed, panel.show_completed])
	viewer.queue_free()


#Item 8: select_entry shows a posting the filter hides, and hide_list drops the board column.
static func _case_reveal(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var hidden_id: int = _first_open(viewer).entry_id
	var entry: BoardEntry = GameState.board.entry(hidden_id)
	entry.status = BoardEntry.STATUS_REJECTED
	entry.closed_minute = CampaignClock.now()
	if entry.contract != null:
		entry.contract.status = "Rejected"
	GameState.refresh_views()
	GameState.contracts_changed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a rejected posting starts hidden",
		not viewer.list().has_id(hidden_id) and not viewer.list().filter_panel.show_rejected,
		"listed %s" % viewer.list().has_id(hidden_id))
	var before: Array[int] = viewer.list().listed_ids()
	viewer.select_entry(hidden_id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "select_entry turns that posting's own option on and selects it",
		viewer.list().has_id(hidden_id) and viewer.list().filter_panel.show_rejected
		and viewer.detail().entry_id() == hidden_id and viewer.selected_id == hidden_id,
		"listed %s detail %d" % [viewer.list().has_id(hidden_id), viewer.detail().entry_id()])
	var kept: bool = true
	for id: int in before:
		if not viewer.list().has_id(id):
			kept = false
	TestFixtures.check(res, "revealing one posting drops nothing else and opens no other option",
		kept and viewer.list().filter_panel.show_available
		and not viewer.list().filter_panel.show_expired
		and not viewer.list().filter_panel.show_failed,
		"rows %d of %d" % [viewer.list().row_count(), before.size() + 1])
	viewer.hide_list = true
	await host.get_tree().process_frame
	TestFixtures.check(res, "hide_list drops the board column and keeps the detail",
		not viewer.list().visible and viewer.detail().visible,
		"list %s detail %s" % [viewer.list().visible, viewer.detail().visible])
	viewer.hide_list = false
	await host.get_tree().process_frame
	TestFixtures.check(res, "the board column comes back", viewer.list().visible,
		"list %s" % viewer.list().visible)
	viewer.queue_free()


#Item 7: the results panel opens over the viewer, and without that scene the row is marked read.
static func _case_results_host(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var ids: Array[int] = GameState.seed_results_preview()
	if not await _seeded(res, ids, viewer, host):
		return
	var has_scene: bool = ResourceLoader.exists(ContractViewer.RESULTS_SCENE)
	viewer.select_entry(ids[0])
	await host.get_tree().process_frame
	if has_scene:
		TestFixtures.check(res, "an unclaimed posting opens the results panel over the viewer",
			viewer.window().is_open() and viewer.window().current() != null,
			"open %s" % viewer.window().is_open())
		viewer.window().close()
		await host.get_tree().process_frame
	else:
		TestFixtures.check(res, "with no results scene the posting is simply marked read",
			not viewer.window().is_open() and not GameState.is_unclaimed(ids[0])
			and GameState.has_result(ids[0]),
			"open %s unclaimed %s" % [viewer.window().is_open(),
			GameState.is_unclaimed(ids[0])])
	viewer.results_scene = _stub_results_scene()
	viewer.select_entry(ids[1])
	await host.get_tree().process_frame
	var panel: Node = viewer.window().current()
	TestFixtures.check(res, "the host hands the result to the panel it opens",
		viewer.window().is_open() and panel != null and panel.has_method("show_result")
		and panel.get("shown") == GameState.result_of(ids[1]),
		"open %s panel %s" % [viewer.window().is_open(), panel])
	TestFixtures.check(res, "the posting is claimed as soon as the panel opens",
		not GameState.is_unclaimed(ids[1]) and GameState.has_result(ids[1]),
		"unclaimed %s" % GameState.is_unclaimed(ids[1]))
	panel.call("finish")
	await host.get_tree().process_frame
	TestFixtures.check(res, "finished closes the panel and marks the result read",
		not viewer.window().is_open() and not GameState.is_unclaimed(ids[1])
		and GameState.has_result(ids[1]),
		"open %s unclaimed %s" % [viewer.window().is_open(), GameState.is_unclaimed(ids[1])])
	TestFixtures.check(res, "GX4D-01 the claimed failure stays selected and its Failed option turns on",
		viewer.selected_id == ids[1] and viewer.list().has_id(ids[1])
		and viewer.list().filter_panel.show_failed and _row_of(viewer.list(), ids[1]) != null,
		"selected %d listed %s failed %s" % [viewer.selected_id, viewer.list().has_id(ids[1]),
		viewer.list().filter_panel.show_failed])
	var rules: Dictionary = viewer.list().filter_panel.filter()
	rules["show_failed"] = false
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	TestFixtures.check(res, "turning the Failed option back off hides the row without moving the selection",
		not viewer.list().has_id(ids[1]) and viewer.selected_id == ids[1],
		"listed %s selected %d" % [viewer.list().has_id(ids[1]), viewer.selected_id])
	rules["show_failed"] = true
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Failed option brings the claimed posting back",
		viewer.list().has_id(ids[1]) and _row_of(viewer.list(), ids[1]) != null,
		"listed %s" % viewer.list().has_id(ids[1]))
	viewer.queue_free()


#GX2D-01: a dismissed results panel still claims the posting, so no row is left that nobody can
#open again (PROTO selectContract 686).
static func _case_results_dismiss(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var ids: Array[int] = GameState.seed_results_preview()
	if not await _seeded(res, ids, viewer, host):
		return
	viewer.results_scene = _stub_results_scene()
	viewer.select_entry(ids[0])
	await host.get_tree().process_frame
	TestFixtures.check(res, "the panel opens over the viewer on an unclaimed posting",
		viewer.window().is_open() and viewer.window().current() != null,
		"open %s" % viewer.window().is_open())
	viewer.window().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a dismissed panel leaves the posting claimed",
		not GameState.is_unclaimed(ids[0]) and GameState.has_result(ids[0])
		and not viewer.window().is_open(),
		"unclaimed %s open %s" % [GameState.is_unclaimed(ids[0]), viewer.window().is_open()])
	var rules: Dictionary = viewer.list().filter_panel.filter()
	rules["show_completed"] = true
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	var row: ContractListItem = _row_of(viewer.list(), ids[0])
	TestFixtures.check(res, "the dismissed row trades the bang for its own mark",
		row != null and row.mark.kind == StatusMark.Mark.CHECK,
		"mark %d" % (row.mark.kind if row != null else -1))
	viewer.select_entry(ids[1])
	await host.get_tree().process_frame
	var panel: Node = viewer.window().current()
	if panel != null and panel.has_method("finish"):
		panel.call("finish")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the finished path still closes the panel",
		not viewer.window().is_open() and not GameState.is_unclaimed(ids[1])
		and GameState.has_result(ids[1]),
		"open %s unclaimed %s" % [viewer.window().is_open(), GameState.is_unclaimed(ids[1])])
	viewer.queue_free()


#I6: the shared direction toggle wears its direction, and the retired DirToggle alias is gone.
static func _case_sort_toggle(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var toggle: SortDirToggle = viewer.list().dir_toggle
	var down: Dictionary = SortDirToggle.LOOKS[true]
	var up: Dictionary = SortDirToggle.LOOKS[false]
	TestFixtures.check(res, "the list direction button is a SortDirToggle 40 x 26",
		toggle is SortDirToggle and toggle.custom_minimum_size == Vector2(40, 26)
		and SortDirToggle.TOGGLE_SIZE == Vector2(40, 26),
		"size %s" % str(toggle.custom_minimum_size))
	TestFixtures.check(res, "descending wears the orange fill and names itself",
		toggle.descending and toggle.fill_color() == Color("#f28c28")
		and down["hi"] == Color("#ffb266") and down["lo"] == Color("#b85a12")
		and down["lit"] == Color("#0a0f1c") and down["dim"] == Color("#7a4a1a")
		and toggle.tooltip_text == "Highest to lowest",
		"fill %s tip %s" % [toggle.fill_color(), toggle.tooltip_text])
	var seen: Array[bool] = []
	toggle.direction_changed.connect(func(on: bool) -> void: seen.append(on))
	toggle.toggle()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the flip reports itself once and turns the button blue",
		seen.size() == 1 and not seen[0] and not toggle.descending
		and toggle.fill_color() == Color("#2b4f8a")
		and up["hi"] == Color("#3b6fb6") and up["lo"] == Color("#1f3560")
		and up["lit"] == Color("#f3ead7") and up["dim"] == Color("#5e7699")
		and toggle.tooltip_text == "Lowest to highest",
		"seen %s fill %s" % [str(seen), toggle.fill_color()])
	var box: StyleBoxFlat = toggle.get_theme_stylebox("normal") as StyleBoxFlat
	TestFixtures.check(res, "the toggle carries its own box behind a 3 px black outline",
		box != null and box.bg_color == up["fill"] and box.border_color == Color("#0a0f1c")
		and box.border_width_left == 3 and box.border_width_bottom == 3,
		"box %s" % [box.bg_color if box != null else Color.BLACK])
	TestFixtures.check(res, "the arrows stand 5 px wide and 7 px tall",
		is_equal_approx(SortDirToggle.TRI_WIDTH, 5.0)
		and is_equal_approx(SortDirToggle.TRI_HEIGHT, 7.0)
		and SortDirToggle.TRI_SHAPE.size() == 7,
		"shape %s" % str(SortDirToggle.TRI_SHAPE))
	toggle.toggle()
	await host.get_tree().process_frame
	TestFixtures.check(res, "flipping back reports descending and restores the orange",
		seen.size() == 2 and seen[1] and toggle.descending
		and toggle.fill_color() == down["fill"],
		"seen %s fill %s" % [str(seen), toggle.fill_color()])
	TestFixtures.check(res, "DirToggle is retired and the Contracts list hosts the shared scene",
		not ResourceLoader.exists(OLD_DIR_TOGGLE_SCENE)
		and toggle.scene_file_path == SORT_DIR_TOGGLE_SCENE,
		"alias exists %s scene %s" % [ResourceLoader.exists(OLD_DIR_TOGGLE_SCENE),
			toggle.scene_file_path])
	viewer.queue_free()


#GX4D-01: select_entry on an unclaimed posting under the default filter leaves that posting
#selected, listed and shown once its results are claimed, for both outcomes (PROTO applyOpen 703).
static func _case_claim_keeps_selection(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var ids: Array[int] = GameState.seed_results_preview()
	if not await _seeded(res, ids, viewer, host):
		return
	var won_id: int = ids[0]
	var lost_id: int = ids[1]
	viewer.results_scene = _stub_results_scene()
	viewer.select_entry(lost_id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "GX4D-01 an unclaimed failed posting stays selected once claimed",
		viewer.selected_id == lost_id and viewer.list().has_id(lost_id)
		and viewer.list().filter_panel.show_failed and viewer.detail().entry_id() == lost_id
		and not GameState.is_unclaimed(lost_id),
		"selected %d listed %s failed %s detail %d" % [viewer.selected_id,
		viewer.list().has_id(lost_id), viewer.list().filter_panel.show_failed,
		viewer.detail().entry_id()])
	viewer.select_entry(won_id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "GX4D-01 an unclaimed completed posting stays selected once claimed",
		viewer.selected_id == won_id and viewer.list().has_id(won_id)
		and viewer.list().filter_panel.show_completed and viewer.detail().entry_id() == won_id
		and not GameState.is_unclaimed(won_id),
		"selected %d listed %s completed %s detail %d" % [viewer.selected_id,
		viewer.list().has_id(won_id), viewer.list().filter_panel.show_completed,
		viewer.detail().entry_id()])
	viewer.queue_free()


#GX4D-01: with no results scene at all, open_results takes its fallback branch (the posting is
#simply marked read); the same narrow reveal still applies there.
static func _case_claim_no_scene_fallback(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var ids: Array[int] = GameState.seed_results_preview()
	if not await _seeded(res, ids, viewer, host):
		return
	var lost_id: int = ids[1]
	viewer.results_scene = _blank_results_scene()
	viewer.select_entry(lost_id)
	await host.get_tree().process_frame
	TestFixtures.check(res,
		"GX4D-01 the no-scene fallback still claims the posting and keeps it selected",
		not viewer.window().is_open() and not GameState.is_unclaimed(lost_id)
		and viewer.selected_id == lost_id and viewer.list().has_id(lost_id)
		and viewer.list().filter_panel.show_failed and viewer.detail().entry_id() == lost_id,
		"open %s selected %d listed %s" % [viewer.window().is_open(), viewer.selected_id,
		viewer.list().has_id(lost_id)])
	viewer.queue_free()


#GX4D-01: the repair is narrow (build note 2). A rebuild from roster_changed, not from a claim,
#never switches a filter option the player turned off back on, and still falls back to first_id().
static func _case_claim_selection_narrow(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: ContractViewer = _viewer(host)
	await host.get_tree().process_frame
	var ids: Array[int] = GameState.seed_results_preview()
	if not await _seeded(res, ids, viewer, host):
		return
	var lost_id: int = ids[1]
	viewer.results_scene = _stub_results_scene()
	viewer.select_entry(lost_id)
	await host.get_tree().process_frame
	if not viewer.list().filter_panel.show_failed or viewer.selected_id != lost_id:
		TestFixtures.check(res, "GX4D-01 setup: the claim reveals the failed posting first", false,
			"selected %d failed %s" % [viewer.selected_id, viewer.list().filter_panel.show_failed])
		viewer.queue_free()
		return
	var rules: Dictionary = viewer.list().filter_panel.filter()
	rules["show_failed"] = false
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	GameState.roster_changed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res,
		"GX4D-01 a roster rebuild never switches a filter the player turned off back on",
		not viewer.list().filter_panel.show_failed and viewer.selected_id != lost_id
		and viewer.selected_id == viewer.list().first_id(),
		"failed %s selected %d first %d" % [viewer.list().filter_panel.show_failed,
		viewer.selected_id, viewer.list().first_id()])
	viewer.queue_free()


#GX4F-08: the bonus placeholder moved into BenefitsManager's PLACEHOLDER block; bonus_pct()
#forwards to it and the value stays the fixed 0 of a benefit nothing has set yet.
static func _case_bonus_pct_placeholder(res: Dictionary) -> void:
	TestFixtures.check(res,
		"GX4F-08 ContractPreview.bonus_pct reads BenefitsManager.DEFAULT_BONUS_PCT",
		ContractPreview.bonus_pct() == BenefitsManager.DEFAULT_BONUS_PCT
		and BenefitsManager.DEFAULT_BONUS_PCT == 0,
		"bonus_pct %d placeholder %d" % [ContractPreview.bonus_pct(),
		BenefitsManager.DEFAULT_BONUS_PCT])


#True when the results fixture settled two postings; it reports and cleans up when it did not.
static func _seeded(res: Dictionary, ids: Array[int], viewer: ContractViewer,
		host: Node) -> bool:
	if ids.size() == 2:
		await host.get_tree().process_frame
		return true
	TestFixtures.check(res, "the results fixture settles two postings", false,
		"ids %s" % str(ids))
	viewer.queue_free()
	return false


#The live view of one posting, or null when the board never listed it.
static func _view_by_id(entry_id: int) -> ContractView:
	for view: ContractView in GameState.contracts:
		if view.entry_id == entry_id:
			return view
	return null


#A stand-in for the results panel: it answers show_result and reports finished on demand, so the
#host can be exercised on a copy where Scenes/GUI/Results does not exist yet.
static func _stub_results_scene() -> PackedScene:
	var lines: Array[String] = [
		"extends Control",
		"",
		"signal finished(entry_id: int)",
		"",
		"var shown: ContractResultData = null",
		"",
		"func show_result(result: ContractResultData) -> void:",
		"\tshown = result",
		"",
		"func finish() -> void:",
		"\tfinished.emit(shown.entry_id if shown != null else -1)",
	]
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines)
	script.reload()
	var node: Control = Control.new()
	node.name = "ResultsStub"
	node.set_script(script)
	var scene: PackedScene = PackedScene.new()
	scene.pack(node)
	node.free()
	return scene


#A results-panel stand-in with no show_result method, so open_results takes its no-scene branch.
static func _blank_results_scene() -> PackedScene:
	var node: Control = Control.new()
	node.name = "BlankStub"
	var scene: PackedScene = PackedScene.new()
	scene.pack(node)
	node.free()
	return scene
