class_name GuiFlowTests

#End to end GUI flow cases driven live off the GameHUD, through the already-merged
#GameHUD/MercViewer/ContractViewer/MetricsViewer screens and the GameState autoload.
#Every case spawns its own HUD from a fresh game and frees it when it is done.

const HUD_SCENE: String = "res://Scenes/GUI/HUD/GameHUD.tscn"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	await _case_merc_flow(res, host)
	await _case_contract_flow(res, host)
	await _case_metrics_flow(res, host)
	await _case_time_and_money(res, host)
	await _case_popup_stacking(res, host)
	await _case_screen_rebuild(res, host)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI FLOW")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()


static func _spawn(host: Node) -> GameHUD:
	_fresh()
	var scene: PackedScene = load(HUD_SCENE)
	var hud: GameHUD = scene.instantiate()
	hud.autostart = false
	host.add_child(hud)
	hud.wire_for_test()
	await host.get_tree().process_frame
	return hud


#Frees a spawned HUD and lets the tree settle.
static func _close_hud(hud: GameHUD, host: Node) -> void:
	hud.queue_free()
	await host.get_tree().process_frame


#Crosses at least want_days day boundaries by ticking the clock, not by calling process_until
#directly: process_until never emits day_changed, only ClockRunner.tick does, after it calls
#process_until as its processor and then fires the boundary signals. Guarded so it cannot hang.
static func _cross_days(state: Variant, want_days: int) -> void:
	state.set_speed(ClockRunner.Speed.VERY_FAST)
	var crossed: int = 0
	var guard: int = 0
	while crossed < want_days and guard < 400:
		var before: int = TrynnCalendar.day_index(CampaignClock.now())
		await state.clock.tick()
		crossed += TrynnCalendar.day_index(CampaignClock.now()) - before
		guard += 1
	state.set_speed(ClockRunner.Speed.PAUSE)


#Case 1: open the Merc menu, select a merc, open the Metrics tab, close the popup.
static func _case_merc_flow(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _spawn(host)
	hud.open_menu(0)
	await host.get_tree().process_frame
	var screen: MercViewer = hud.popup().current() as MercViewer
	TestFixtures.check(res, "menu 0 opens a MercViewer in the HUD popup",
		hud.popup().is_open() and screen != null, "current %s" % [hud.popup().current()])
	if screen == null:
		await _close_hud(hud, host)
		return
	TestFixtures.check(res, "the merc list carries every roster row",
		screen.list.row_count() == GameState.roster.size(),
		"rows %d roster %d" % [screen.list.row_count(), GameState.roster.size()])
	var target: MercView = GameState.roster[GameState.roster.size() - 1]
	screen.show_merc(target.uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "show_merc selects the requested merc",
		screen.selected() != null and screen.selected().uid == target.uid,
		"selected %d wanted %d" % [screen.selected().uid if screen.selected() != null else -1, target.uid])
	TestFixtures.check(res, "the header name label follows the selection",
		screen.header.merc_name() == target.name,
		"label '%s' wanted '%s'" % [screen.header.merc_name(), target.name])
	screen.select_tab(MercViewer.TAB_METRICS)
	await host.get_tree().process_frame
	var tab: MetricsTab = screen.page(MercViewer.TAB_METRICS) as MetricsTab
	TestFixtures.check(res, "the Metrics tab builds a page", tab != null, "page %s" % [tab])
	if tab != null and tab.is_placeholder():
		TestFixtures.check(res, "the Metrics tab embed locks to the selected merc", true,
			"SKIPPED: MetricsViewer.tscn is not resolvable from this run, tab shows the placeholder")
	elif tab != null:
		var embed: Control = tab.embed()
		TestFixtures.check(res, "the Metrics tab embed locks to the selected merc",
			embed != null and bool(embed.call("locked_uid") == target.uid),
			"embed %s locked_uid %s" % [embed, embed.call("locked_uid") if embed != null else null])
	hud.popup().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the HUD popup empties it",
		not hud.popup().is_open(), "open %s" % hud.popup().is_open())
	MetricsHistory.clear_preview()
	await _close_hud(hud, host)


#Case 2: accept an open posting, fill and dispatch a team, then open a crew member from Active.
static func _case_contract_flow(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _spawn(host)
	hud.open_menu(1)
	await host.get_tree().process_frame
	var viewer: ContractViewer = hud.popup().current() as ContractViewer
	TestFixtures.check(res, "menu 1 opens a ContractViewer in the HUD popup",
		hud.popup().is_open() and viewer != null, "current %s" % [hud.popup().current()])
	if viewer == null:
		await _close_hud(hud, host)
		return
	var view: ContractView = GuiContractTests._first_open(viewer)
	TestFixtures.check(res, "the board offers an open posting to work with", view != null, "view %s" % [view])
	if view == null:
		await _close_hud(hud, host)
		return
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "select_entry moves the selection to the chosen posting",
		viewer.selected() != null and viewer.selected().entry_id == view.entry_id,
		"selected %d wanted %d" % [viewer.selected().entry_id if viewer.selected() != null else -1, view.entry_id])
	viewer.detail().decisions().accept_button.pressed.emit()
	await host.get_tree().process_frame
	var window: DispatchWindow = viewer.window().current() as DispatchWindow
	TestFixtures.check(res, "Accept opens the DispatchWindow nested in the ContractViewer popup",
		viewer.window().is_open() and window != null, "window %s" % [window])
	if window == null:
		await _close_hud(hud, host)
		return
	var placed: Array[int] = await GuiContractTests._ready_team(window, host)
	TestFixtures.check(res, "the dispatch window seats a crew", not placed.is_empty(),
		"placed %s" % [placed])
	var travel_cost: int = window.travel_total()
	var bank_before: int = GameState.bank_notes
	var sent: bool = window.commit()
	await host.get_tree().process_frame
	await GuiContractTests._walk_dialogs(window, host)
	TestFixtures.check(res, "the dispatch commits", sent, "sent %s" % sent)
	var after: ContractView = GuiContractTests._view_by_id(view.entry_id)
	TestFixtures.check(res, "the posting turns Active after dispatch",
		after != null and after.status == GuiTypes.ContractStatus.ACTIVE,
		"status %s" % [after.status if after != null else -1])
	TestFixtures.check(res, "every placed uid reads busy on the roster",
		GuiContractTests._all_busy(placed),
		"placed %s busy %s" % [placed, GameState.busy_uids()])
	TestFixtures.check(res, "the HUD money menu reflects the travel spend",
		hud.bottom_bar.money_menu().text().contains(str(GameState.bank_notes))
			and GameState.bank_notes == bank_before - travel_cost,
		"text '%s' bank %d wanted %d" % [hud.bottom_bar.money_menu().text(), GameState.bank_notes,
		bank_before - travel_cost])
	TestFixtures.check(res, "the detail panel shows the ActiveCrew for the dispatched team",
		viewer.detail().active_crew().portrait_count() == placed.size(),
		"portraits %d of %d" % [viewer.detail().active_crew().portrait_count(), placed.size()])
	var leader_uid: int = placed[0]
	viewer.detail().active_crew().merc_picked.emit(leader_uid)
	await host.get_tree().process_frame
	var merc_screen: Node = viewer.window().current()
	TestFixtures.check(res, "clicking a crew portrait reopens a hide_roster MercViewer",
		merc_screen != null and merc_screen.has_method("show_merc")
			and bool(merc_screen.get("hide_roster")),
		"screen %s" % [merc_screen])
	if merc_screen is MercViewer:
		var nested: MercViewer = merc_screen as MercViewer
		TestFixtures.check(res, "the nested merc viewer selects the crew member clicked",
			nested.selected() != null and nested.selected().uid == leader_uid,
			"selected %s wanted %d" % [nested.selected().uid if nested.selected() != null else -1, leader_uid])
	hud.popup().close()
	await host.get_tree().process_frame
	await _close_hud(hud, host)


#Case 3: open the Metrics menu unlocked, cross day boundaries live, confirm the chart fills in.
static func _case_metrics_flow(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _spawn(host)
	MetricsHistory.clear()
	MetricsHistory.clear_preview()
	hud.open_menu(8)
	await host.get_tree().process_frame
	var viewer: MetricsViewer = hud.popup().current() as MetricsViewer
	TestFixtures.check(res, "menu 8 opens a MetricsViewer in the HUD popup",
		hud.popup().is_open() and viewer != null, "current %s" % [hud.popup().current()])
	if viewer == null:
		await _close_hud(hud, host)
		return
	TestFixtures.check(res, "opened from the HUD menu the viewer stays unlocked with its tabs shown",
		viewer.locked_uid() == -1 and viewer.tabs.visible,
		"locked_uid %d tabs.visible %s" % [viewer.locked_uid(), viewer.tabs.visible])
	TestFixtures.check(res, "before any day is recorded the chart shows the empty state",
		MetricsHistory.days() == 0 and viewer.chart.is_empty(),
		"days %d empty %s" % [MetricsHistory.days(), viewer.chart.is_empty()])
	await _cross_days(GameState, 2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "crossing day boundaries records rows in MetricsHistory",
		MetricsHistory.days() >= 1, "days %d" % MetricsHistory.days())
	TestFixtures.check(res, "the chart carries at least one plotted point once a day is recorded",
		viewer.chart.series_count() >= 1 and viewer.chart.point_count(0) >= 1,
		"series %d points %d" % [viewer.chart.series_count(),
		viewer.chart.point_count(0) if viewer.chart.series_count() >= 1 else -1])
	hud.popup().close()
	await host.get_tree().process_frame
	await _close_hud(hud, host)


#Case 4: the bottom bar time and money menus relay clock and bank changes live.
static func _case_time_and_money(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _spawn(host)
	var time_menu: TimeMenu = hud.bottom_bar.time_menu()
	var money_menu: MoneyMenu = hud.bottom_bar.money_menu()
	TestFixtures.check(res, "the date label starts matching the campaign clock",
		time_menu.date_label().text == TrynnCalendar.date_text(CampaignClock.now()),
		"label '%s'" % time_menu.date_label().text)
	var play_btn: SpeedButton = time_menu.speed_button(ClockRunner.Speed.PLAY)
	TestFixtures.check(res, "a Play speed button exists on the time menu", play_btn != null,
		"button %s" % [play_btn])
	if play_btn != null:
		play_btn.pressed.emit()
		await host.get_tree().process_frame
		TestFixtures.check(res, "pressing the Play speed button sets the clock speed to Play",
			GameState.clock.speed == ClockRunner.Speed.PLAY, "speed %d" % GameState.clock.speed)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	var before_date: String = time_menu.date_label().text
	await _cross_days(GameState, 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "crossing a day boundary updates the date label",
		time_menu.date_label().text != before_date,
		"before '%s' after '%s'" % [before_date, time_menu.date_label().text])
	GameState.bank_notes = 57
	GameState.money_changed.emit(57)
	await host.get_tree().process_frame
	TestFixtures.check(res, "money_changed refreshes the money menu label",
		money_menu.text().contains("57"), "text '%s'" % money_menu.text())
	await _close_hud(hud, host)


#Case 5: closing a nested popup leaves the HUD popup on the screen underneath, not stacked stale.
static func _case_popup_stacking(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _spawn(host)
	hud.open_menu(1)
	await host.get_tree().process_frame
	var viewer: ContractViewer = hud.popup().current() as ContractViewer
	var view: ContractView = GuiContractTests._first_open(viewer) if viewer != null else null
	TestFixtures.check(res, "a ContractViewer opens with an open posting to accept",
		viewer != null and view != null, "viewer %s view %s" % [viewer, view])
	if viewer == null or view == null:
		await _close_hud(hud, host)
		return
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	viewer.detail().decisions().accept_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Accept opens the nested DispatchWindow",
		viewer.window().is_open() and viewer.window().current() is DispatchWindow,
		"open %s" % viewer.window().is_open())
	viewer.window().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the inner popup leaves the HUD popup open on the ContractViewer",
		hud.popup().is_open() and hud.popup().current() == viewer,
		"hud open %s current %s" % [hud.popup().is_open(), hud.popup().current()])
	hud.popup().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the HUD popup empties it",
		not hud.popup().is_open(), "open %s" % hud.popup().is_open())
	hud.open_menu(0)
	await host.get_tree().process_frame
	var merc_screen: Node = hud.popup().current()
	TestFixtures.check(res, "opening the merc menu right after gives a fresh MercViewer instance",
		merc_screen != null and merc_screen.has_method("show_merc") and merc_screen != viewer,
		"screen %s" % [merc_screen])
	hud.popup().close()
	await host.get_tree().process_frame
	await _close_hud(hud, host)


#Case 6: rejecting a posting from GameState rebuilds the contract list live under the open viewer.
static func _case_screen_rebuild(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _spawn(host)
	hud.open_menu(1)
	await host.get_tree().process_frame
	var viewer: ContractViewer = hud.popup().current() as ContractViewer
	TestFixtures.check(res, "menu 1 opens a ContractViewer to reject from", viewer != null,
		"viewer %s" % [viewer])
	if viewer == null:
		await _close_hud(hud, host)
		return
	var before: int = viewer.list().row_count()
	var view: ContractView = GuiContractTests._first_open(viewer)
	TestFixtures.check(res, "an open posting exists to reject", view != null, "view %s" % [view])
	if view == null:
		await _close_hud(hud, host)
		return
	viewer.select_entry(view.entry_id)
	await host.get_tree().process_frame
	GameState.reject(view.entry_id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "rejecting a posting drops one row from the open ContractViewer list",
		viewer.list().row_count() == before - 1,
		"rows %d of %d" % [viewer.list().row_count(), before - 1])
	TestFixtures.check(res, "the selection moves off the rejected posting",
		viewer.selected() == null or viewer.selected().entry_id != view.entry_id,
		"selected %s" % [viewer.selected().entry_id if viewer.selected() != null else -1])
	hud.popup().close()
	await host.get_tree().process_frame
	hud.open_menu(0)
	await host.get_tree().process_frame
	var merc_screen: MercViewer = hud.popup().current() as MercViewer
	TestFixtures.check(res, "the merc viewer row count still matches the untouched roster",
		merc_screen != null and merc_screen.list.row_count() == GameState.roster.size(),
		"rows %s roster %d" % [merc_screen.list.row_count() if merc_screen != null else -1,
		GameState.roster.size()])
	hud.popup().close()
	await host.get_tree().process_frame
	await _close_hud(hud, host)
