class_name GuiSortTests

#README I6 and Part J step 15: one sort direction button, SortDirToggle.tscn, built once and
#instanced by every list. Eight lists: Contracts, Dispatch, Merc roster, Clients, Finance Loans,
#Finance Payroll, Hiring and Promotions. Each case opens the screen that hosts the list the way
#its own suite does, finds the direction button and checks its look, its size, its flip and that
#the list carries no second direction control. A last case compares the eight buttons with
#each other. Run: the headless harness flag gui-sort-tests.

const SORT_DIR_TOGGLE_SCENE: String = "res://Scenes/GUI/Shared/SortDirToggle.tscn"
#README lines 544-547: the button's own size and paint, read as literals so a check of them
#cannot pass by quietly comparing against the class's own constant instead.
const README_SIZE: Vector2 = Vector2(40.0, 26.0)
const DOWN_FILL: Color = Color("#f28c28")
const DOWN_TIP: String = "Highest to lowest"
const UP_FILL: Color = Color("#2b4f8a")
const UP_TIP: String = "Lowest to highest"
#The bevel palette of each direction: fill, hi, lo and the lit arrow colour.
const DOWN_PALETTE: Array[Color] = [DOWN_FILL, Color("#ffb266"), Color("#b85a12"), Color("#0a0f1c")]
const UP_PALETTE: Array[Color] = [UP_FILL, Color("#3b6fb6"), Color("#1f3560"), Color("#f3ead7")]
const DIRECTION_WORDS: Array[String] = ["dir", "direction", "asc", "desc"]

const CONTRACT_VIEWER: PackedScene = preload("res://Scenes/GUI/Contracts/ContractViewer.tscn")
const MERC_VIEWER: PackedScene = preload("res://Scenes/GUI/Mercs/MercViewer.tscn")
const CLIENT_VIEWER: PackedScene = preload("res://Scenes/GUI/Clients/ClientViewer.tscn")
const LOANS_TAB: PackedScene = preload("res://Scenes/GUI/Finance/Loans/LoansTab.tscn")
const PAYROLL_TAB: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/PayrollTab.tscn")
const PROMO_VIEWER: PackedScene = preload("res://Scenes/GUI/Promotions/PromotionsViewer.tscn")
#Clients: ClientRegistry._before pins a client that never had a contract (recency < 0) to the
#tail of the list in both directions, so a recency of -1 is excluded before the flip check
#compares key values; see _open_clients.
const CLIENTS_SENTINEL: int = -1
#Dispatch: the two start mercs tie on fit stars, so the list runs on a roster of ten whose stars differ.
const DISPATCH_ROSTER: int = 10


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_lists(res, host)
	await _case_all_toggles(res, host)
	await _case_row_hover(res, host)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.max_out()
	LegalManager.reset()
	PromotionsManager.reset()
	FinanceManager.reset()
	BenefitsManager.reset()
	CampaignClock.reset()
	GuiFrameStack.clear()
	return TestFixtures.summarize(res, "GUI SORT")


#The fixture every case starts from: a fresh, paused game on the same seed.
static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


#The start posts one contract, too few to sort or to give two clients a history, so the board is topped
#up to its target on Enterprise the way the 8:00 refill does.
static func _fill_board() -> void:
	SubscriptionManager.max_out()
	GameState.board.refill(CampaignClock.now(), SubscriptionManager.max_contracts())
	GameState.refresh_views()


#True when every value of the array equals the first one.
static func _all_equal(values: Array) -> bool:
	for i: int in range(1, values.size()):
		if values[i] != values[0]:
			return false
	return true


#Same values regardless of order, so a flip that only reorders rows still passes.
static func _same_multiset(a: Array, b: Array) -> bool:
	var sa: Array = a.duplicate()
	sa.sort()
	var sb: Array = b.duplicate()
	sb.sort()
	return sa == sb


static func _reversed_copy(values: Array) -> Array:
	var out: Array = values.duplicate()
	out.reverse()
	return out


#values with sentinel removed, order kept, so a pinned-last entry cannot break a reversal check.
static func _without_sentinel(values: Array, sentinel: Variant) -> Array:
	if sentinel == null:
		return values.duplicate()
	var out: Array = []
	for v: Variant in values:
		if v != sentinel:
			out.append(v)
	return out


static func _distinct_count(values: Array) -> int:
	var seen: Array = []
	for v: Variant in values:
		if not seen.has(v):
			seen.append(v)
	return seen.size()


#The four colours a toggle's bevel body paints with: fill, hi, lo and the lit arrow colour.
static func _palette_of(toggle: SortDirToggle) -> Array[Color]:
	return [toggle.fill, toggle.hi, toggle.lo, toggle.text_color]


static func _all_palettes_ok(palettes: Array, want: Array[Color]) -> bool:
	for colors: Array in palettes:
		if colors != want:
			return false
	return true


static func _looks_like_direction(button: Button) -> bool:
	var name_lower: String = String(button.name).to_lower()
	for word: String in DIRECTION_WORDS:
		if name_lower.contains(word):
			return true
	var script: Script = button.get_script() as Script
	if script != null:
		var path_lower: String = String(script.resource_path).to_lower()
		for word: String in DIRECTION_WORDS:
			if path_lower.contains(word):
				return true
	return false


#The count of direction controls anywhere under root: every SortDirToggle instance, plus any
#other Button whose name or script reads as a direction control, so a case can prove there is
#exactly one and it is the shared one.
static func _count_direction_controls(node: Node) -> int:
	var total: int = 0
	for button: Node in GuiAcceptTests._collect(node, Button):
		if button is SortDirToggle or _looks_like_direction(button as Button):
			total += 1
	return total


#The shared body of every per-list case: scene identity, size, the flip and the count, then
#both looks last. data carries "toggle", "root", "order" (row identities), "keys" (the values
#the list actually sorts by, in the same order as "order") and an optional "sentinel" value
#that never takes part in the reversal (a pinned-last placeholder, see _open_clients).
static func _verify_toggle(res: Dictionary, label: String, data: Dictionary) -> void:
	var toggle: SortDirToggle = data.get("toggle") as SortDirToggle
	if toggle == null:
		TestFixtures.check(res, "%s has a direction toggle to verify" % label, false,
			"toggle is null")
		return
	var root: Node = data["root"] as Node
	var order: Callable = data["order"] as Callable
	var keys: Callable = data["keys"] as Callable
	var sentinel: Variant = data.get("sentinel")
	TestFixtures.check(res, "%s toggle is a SortDirToggle instanced from the shared scene" % label,
		toggle.scene_file_path == SORT_DIR_TOGGLE_SCENE,
		"scene_file_path '%s'" % toggle.scene_file_path)
	TestFixtures.check(res, "%s toggle is sized 40 by 26" % label,
		toggle.custom_minimum_size == README_SIZE and toggle.size == README_SIZE,
		"min %s size %s" % [toggle.custom_minimum_size, toggle.size])
	var start_desc: bool = toggle.descending
	var before_ids: Array = order.call() as Array
	var before_keys: Array = keys.call() as Array
	var seen: Array[bool] = []
	toggle.direction_changed.connect(func(on: bool) -> void: seen.append(on))
	toggle.toggle()
	await root.get_tree().process_frame
	var after_ids: Array = order.call() as Array
	var after_keys: Array = keys.call() as Array
	TestFixtures.check(res, "%s toggle() emits direction_changed once and keeps every row" % label,
		seen.size() == 1 and seen[0] == (not start_desc) and toggle.descending == (not start_desc)
		and before_ids.size() >= 2 and _same_multiset(before_ids, after_ids),
		"before %s after %s seen %s" % [before_ids, after_ids, seen])
	var before_cmp: Array = _without_sentinel(before_keys, sentinel)
	var after_cmp: Array = _without_sentinel(after_keys, sentinel)
	TestFixtures.check(res, "%s flip reverses the key values the list is sorted by" % label,
		_distinct_count(before_cmp) >= 2 and after_cmp.size() == before_cmp.size()
		and after_cmp == _reversed_copy(before_cmp),
		"before %s after %s" % [before_cmp, after_cmp])
	toggle.descending = true
	TestFixtures.check(res, "%s toggle descending wears the orange fill and its tooltip" % label,
		toggle.fill_color() == DOWN_FILL and toggle.tooltip_text == DOWN_TIP,
		"fill %s tip '%s'" % [toggle.fill_color(), toggle.tooltip_text])
	toggle.descending = false
	TestFixtures.check(res, "%s toggle ascending wears the blue fill and its tooltip" % label,
		toggle.fill_color() == UP_FILL and toggle.tooltip_text == UP_TIP,
		"fill %s tip '%s'" % [toggle.fill_color(), toggle.tooltip_text])
	toggle.descending = start_desc
	var stray: int = _count_direction_controls(root)
	TestFixtures.check(res, "%s list holds no second direction control" % label,
		stray == 1, "count %d" % stray)


static func _open_contracts(host: Node) -> Dictionary:
	_fresh()
	_fill_board()
	var viewer: ContractViewer = CONTRACT_VIEWER.instantiate() as ContractViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	var list: ContractList = viewer.list()
	var order: Callable = func() -> Array: return list.listed_ids()
	#The default sort is Sort.DIFFICULTY (ContractList.gd); ContractView.difficulty is public.
	var keys: Callable = func() -> Array:
		var out: Array = []
		var ids: Array = list.listed_ids()
		for i: int in ids.size():
			var item: ContractListItem = list.row_at(i)
			out.append(item.view.difficulty if item != null and item.view != null else 0.0)
		return out
	return {"toggle": list.dir_toggle, "root": list, "order": order, "keys": keys,
		"screen": viewer}


static func _first_open_id(viewer: ContractViewer) -> int:
	for view: ContractView in viewer.list().listed():
		if view.status == GuiTypes.ContractStatus.AVAILABLE:
			return view.entry_id
	return -1


static func _open_dispatch(host: Node) -> Dictionary:
	_fresh()
	_fill_board()
	TestFixtures.add_mercs(DISPATCH_ROSTER - GameState.mercs.size())
	var viewer: ContractViewer = CONTRACT_VIEWER.instantiate() as ContractViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	var entry_id: int = _first_open_id(viewer)
	var roster: DispatchRoster = null
	if entry_id >= 0:
		viewer.select_entry(entry_id)
		await host.get_tree().process_frame
		viewer.detail().decisions().accept_button.pressed.emit()
		await host.get_tree().process_frame
		var window: DispatchWindow = viewer.window().current() as DispatchWindow
		if window != null:
			roster = window.roster_panel()
	if roster == null:
		return {"toggle": null, "root": viewer, "order": func() -> Array: return [],
			"keys": func() -> Array: return [], "screen": viewer}
	var order: Callable = func() -> Array: return roster.shown_uids()
	#Sort.BEST ranks by the solo net; DispatchRosterItem.stars_value() is MatchScore.stars of that
	#same net, and stars never fall as the net rises, so the keys move with it.
	var keys: Callable = func() -> Array:
		var out: Array = []
		var uids: Array = roster.shown_uids()
		for i: int in uids.size():
			var item: DispatchRosterItem = roster.row_at(i)
			out.append(item.stars_value() if item != null else 0.0)
		return out
	return {"toggle": roster.dir_toggle, "root": roster, "order": order, "keys": keys,
		"screen": viewer}


static func _open_merc(host: Node) -> Dictionary:
	_fresh()
	var screen: MercViewer = MERC_VIEWER.instantiate() as MercViewer
	host.add_child(screen)
	await host.get_tree().process_frame
	var list: MercList = screen.list
	#The default sort is Sort.AVAILABLE (MercList._rank), but a fresh roster has every merc
	#AVAILABLE (no one dispatched or resting yet) and a fresh roster's recruits are also all
	#level 1, so neither column carries variance to reverse. SortButton.pick() is the same
	#call a click on the sort dropdown makes (it sets selected and emits sort_changed, which
	#MercList._on_sort_changed listens to), so picking Sort.NAME here drives a real resort
	#onto a column that is unique per merc by construction (no two rows share a name).
	list.sort_button.pick(MercList.Sort.NAME)
	await host.get_tree().process_frame
	var order: Callable = func() -> Array:
		var out: Array = []
		for row: MercListItem in list.rows():
			out.append(row.uid)
		return out
	#MercList._before reads a.name/b.name for Sort.NAME; MercListItem.view is public.
	var keys: Callable = func() -> Array:
		var out: Array = []
		for row: MercListItem in list.rows():
			out.append(row.view.name if row.view != null else "")
		return out
	return {"toggle": list.dir_toggle, "root": list, "order": order, "keys": keys,
		"screen": screen}


static func _open_clients(host: Node) -> Dictionary:
	_fresh()
	_fill_board()
	var screen: ClientViewer = CLIENT_VIEWER.instantiate() as ClientViewer
	host.add_child(screen)
	await host.get_tree().process_frame
	var list: ClientList = screen.list
	#A fresh company has no contract history, so every client's recency is still the -1
	#sentinel (ClientData.recency) and the default "recent" sort has nothing to reverse.
	#ClientData.recency is a plain public var (same one ClientRegistry.from_game() sets from
	#view.entry_id on a real contract), so giving two rows distinct, real recency values is
	#the same shape of fact a real contract history would produce. SortButton.pick(0) re-picks
	#the already-selected "recent" key, which still emits sort_changed and drives a real
	#resort (ClientList._on_query -> query_changed -> ClientViewer refetches), so the picked
	#values are the ones actually on screen when the toggle check runs.
	var rows: Array[ClientListItem] = list.rows()
	var seeded: int = 0
	for row: ClientListItem in rows:
		if row.client != null and seeded < 2:
			row.client.recency = 5 if seeded == 0 else 12
			seeded += 1
	list.sort_button.pick(0)
	await host.get_tree().process_frame
	var order: Callable = func() -> Array:
		var out: Array = []
		for row: ClientListItem in list.rows():
			out.append(row.client_key())
		return out
	#ClientRegistry._before pins recency < 0 (never contracted) to the tail in both
	#directions, so CLIENTS_SENTINEL drops those rows before the reversal compare.
	var keys: Callable = func() -> Array:
		var out: Array = []
		for row: ClientListItem in list.rows():
			out.append(row.client.recency if row.client != null else CLIENTS_SENTINEL)
		return out
	return {"toggle": list.dir_toggle, "root": list, "order": order, "keys": keys,
		"sentinel": CLIENTS_SENTINEL, "screen": screen}


static func _open_loans(host: Node) -> Dictionary:
	_fresh()
	FinanceManager.reset()
	GuiLoanTests._seed_fixture()
	var tab: LoansTab = LOANS_TAB.instantiate() as LoansTab
	host.add_child(tab)
	await host.get_tree().process_frame
	var order: Callable = func() -> Array: return tab.row_ids()
	#SORT_KEYS[0] is "monthly" (LoanRows.gd); LoansTab has no public per-row reader, so this
	#reads the same "metrics.monthly" field LoanRows.apply()'s comparator sorts on.
	var keys: Callable = func() -> Array:
		var out: Array = []
		for row: Dictionary in tab._rows:
			var metrics: Dictionary = row.get("metrics", {})
			out.append(float(metrics.get("monthly", 0)))
		return out
	return {"toggle": tab.direction_toggle(), "root": tab, "order": order, "keys": keys,
		"screen": tab}


static func _close_loans(screen: Node) -> void:
	screen.queue_free()
	FinanceManager.reset()


static func _open_payroll(host: Node) -> Dictionary:
	_fresh()
	BenefitsManager.reset()
	SubscriptionManager.max_out()
	var page: PayrollTab = PAYROLL_TAB.instantiate() as PayrollTab
	host.add_child(page)
	await host.get_tree().process_frame
	page.refresh()
	await host.get_tree().process_frame
	var order: Callable = func() -> Array:
		var out: Array = []
		for i: int in page.row_count():
			out.append(page.row_uid(i))
		return out
	#SORT_KEYS[0] is "salary" (PayrollTab.gd); PayrollTab has no public per-row reader, so this
	#reads the same "salary" field _before()'s default branch sorts on.
	var keys: Callable = func() -> Array:
		var out: Array = []
		for i: int in page.row_count():
			out.append(float(page._rows[i].get("salary", 0)))
		return out
	return {"toggle": page.dir_toggle, "root": page, "order": order, "keys": keys,
		"screen": page}


static func _close_payroll(screen: Node) -> void:
	screen.queue_free()
	BenefitsManager.reset()
	SubscriptionManager.max_out()


static func _open_hiring(host: Node) -> Dictionary:
	var page: HiringTab = await GuiHiringTests._open(host, GuiAdsTests._full_ent())
	var order: Callable = func() -> Array: return page.card_ids()
	#The default sort is &"fit" (HiringTab._sort); ApplicantData.fit is public and is the exact
	#field applicants_filtered()'s comparator reads for that key.
	var keys: Callable = func() -> Array:
		var out: Array = []
		for id: int in page.card_ids():
			var applicant: ApplicantData = PromotionsManager.applicant_of(id)
			out.append(applicant.fit if applicant != null else 0.0)
		return out
	return {"toggle": page.sort_toggle(), "root": page, "order": order, "keys": keys,
		"screen": page}


static func _close_hiring(screen: Node) -> void:
	screen.queue_free()
	_reset_promo_state()


static func _reset_promo_state() -> void:
	SubscriptionManager.max_out()
	LegalManager.reset()
	PromotionsManager.reset()


static func _open_promotions(host: Node) -> Dictionary:
	GuiHiringTests._fresh(GuiAdsTests._full_ent())
	_launch_later_ad()
	var viewer: PromotionsViewer = PROMO_VIEWER.instantiate() as PromotionsViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	await host.get_tree().process_frame
	var order: Callable = func() -> Array:
		var out: Array = []
		for card: CampaignCard in viewer.campaign_list().cards:
			out.append(card.campaign_id())
		return out
	#CAMPAIGN_SORT_DEFAULT is &"start"; PromotionsManager.campaign_sort_value() is the public
	#function the list's own comparator calls, read straight off the public card.campaign.
	var keys: Callable = func() -> Array:
		var out: Array = []
		var today: int = CampaignClock.now()
		for card: CampaignCard in viewer.campaign_list().cards:
			out.append(PromotionsManager.campaign_sort_value(card.campaign,
				PromotionsManager.CAMPAIGN_SORT_DEFAULT, today))
		return out
	return {"toggle": viewer.toolbar().dir_toggle, "root": viewer, "order": order, "keys": keys,
		"screen": viewer}


#The board's job ads all start on one day, so one more launched today gives the start sort two values.
static func _launch_later_ad() -> void:
	var bank: int = GameState.bank_notes
	GameState.bank_notes = GuiHiringTests.RICH
	if TestFixtures.launch_campaign({"type": &"flyers", "days": GuiHiringTests.BOARD_DAYS}) == null:
		push_error("_launch_later_ad could not launch a Flyers job ad")
	GameState.bank_notes = bank


static func _close_promotions(screen: Node) -> void:
	GuiFrameStack.clear()
	screen.queue_free()
	_reset_promo_state()


#The eight lists in screen order. A list without a "close" entry is closed by freeing its screen.
static func _lists() -> Array[Dictionary]:
	return [
		{"label": "Contracts", "open": _open_contracts},
		{"label": "Dispatch", "open": _open_dispatch},
		{"label": "Merc roster", "open": _open_merc},
		{"label": "Clients", "open": _open_clients},
		{"label": "Finance Loans", "open": _open_loans, "close": _close_loans},
		{"label": "Finance Payroll", "open": _open_payroll, "close": _close_payroll},
		{"label": "Hiring", "open": _open_hiring, "close": _close_hiring},
		{"label": "Promotions", "open": _open_promotions, "close": _close_promotions},
	]


static func _close_list(list: Dictionary, data: Dictionary) -> void:
	var screen: Node = data["screen"] as Node
	if list.has("close"):
		(list["close"] as Callable).call(screen)
	else:
		screen.queue_free()


static func _case_lists(res: Dictionary, host: Node) -> void:
	for list: Dictionary in _lists():
		var data: Dictionary = await (list["open"] as Callable).call(host)
		await _verify_toggle(res, list["label"] as String, data)
		_close_list(list, data)


#One toggle's script, scene, sizes and both looks, plus the bevel palette of each look so the
#cross-list case checks the paint against literals independently of fill_color().
#min_size is custom_minimum_size and size the rendered size, so a stretched row still fails.
static func _look_of(toggle: SortDirToggle) -> Dictionary:
	var look: Dictionary = {"script": toggle.get_script(), "scene": toggle.scene_file_path,
		"min_size": toggle.custom_minimum_size, "size": toggle.size}
	toggle.descending = true
	look["down_fill"] = toggle.fill_color()
	look["down_tip"] = toggle.tooltip_text
	look["down_pal"] = _palette_of(toggle)
	toggle.descending = false
	look["up_fill"] = toggle.fill_color()
	look["up_tip"] = toggle.tooltip_text
	look["up_pal"] = _palette_of(toggle)
	return look


static func _column(looks: Array[Dictionary], key: String) -> Array:
	var out: Array = []
	for look: Dictionary in looks:
		out.append(look[key])
	return out


#Part J step 15, the last case: the eight direction toggles compared with each other. Every
#aggregate check is guarded by size() == 8 so a screen that failed to hand back a toggle cannot
#make _all_equal() pass vacuously on a short or empty array.
static func _case_all_toggles(res: Dictionary, host: Node) -> void:
	var looks: Array[Dictionary] = []
	for list: Dictionary in _lists():
		var data: Dictionary = await (list["open"] as Callable).call(host)
		var toggle: SortDirToggle = data["toggle"] as SortDirToggle
		if toggle != null:
			looks.append(_look_of(toggle))
		else:
			TestFixtures.check(res, "%s has a direction toggle to compare with the rest"
				% list["label"], false, "toggle is null")
		_close_list(list, data)
	var scripts: Array = _column(looks, "script")
	var scene_paths: Array = _column(looks, "scene")
	var min_sizes: Array = _column(looks, "min_size")
	var sizes: Array = _column(looks, "size")
	var down_fills: Array = _column(looks, "down_fill")
	var down_tips: Array = _column(looks, "down_tip")
	var up_fills: Array = _column(looks, "up_fill")
	var up_tips: Array = _column(looks, "up_tip")
	var down_pals: Array = _column(looks, "down_pal")
	var up_pals: Array = _column(looks, "up_pal")
	TestFixtures.check(res, "the eight direction toggles share the same script",
		scripts.size() == 8 and _all_equal(scripts), "%d scripts" % scripts.size())
	TestFixtures.check(res, "the eight direction toggles share the same scene path",
		scene_paths.size() == 8 and _all_equal(scene_paths), "%s" % [scene_paths])
	TestFixtures.check(res, "the eight direction toggles are all sized 40 by 26",
		min_sizes.size() == 8 and sizes.size() == 8 and _all_equal(min_sizes)
		and _all_equal(sizes) and min_sizes[0] == README_SIZE and sizes[0] == README_SIZE,
		"min %s size %s" % [min_sizes, sizes])
	TestFixtures.check(res, "the eight direction toggles wear the same descending look",
		down_fills.size() == 8 and _all_equal(down_fills) and _all_equal(down_tips),
		"%s %s" % [down_fills, down_tips])
	TestFixtures.check(res, "the eight direction toggles wear the same ascending look",
		up_fills.size() == 8 and _all_equal(up_fills) and _all_equal(up_tips),
		"%s %s" % [up_fills, up_tips])
	TestFixtures.check(res, "the eight direction toggles paint the literal descending palette",
		down_pals.size() == 8 and _all_palettes_ok(down_pals, DOWN_PALETTE),
		"palettes %s" % [down_pals])
	TestFixtures.check(res, "the eight direction toggles paint the literal ascending palette",
		up_pals.size() == 8 and _all_palettes_ok(up_pals, UP_PALETTE),
		"palettes %s" % [up_pals])


#A hovered sort row darkens and turns its label orange instead of losing its background.
static func _case_row_hover(res: Dictionary, host: Node) -> void:
	var plain := Button.new()
	var picked := Button.new()
	host.add_child(plain)
	host.add_child(picked)
	SortButton.style_row(plain, false)
	SortButton.style_row(picked, true)
	await host.get_tree().process_frame
	var hover_box: StyleBoxFlat = plain.get_theme_stylebox(&"hover") as StyleBoxFlat
	var idle_box: StyleBoxFlat = plain.get_theme_stylebox(&"normal") as StyleBoxFlat
	TestFixtures.check(res, "a hovered row still paints a background",
		hover_box != null and idle_box != null and hover_box.bg_color.a > 0.0,
		"%s" % (hover_box.bg_color.to_html(false) if hover_box != null else "none"))
	if hover_box == null or idle_box == null:
		plain.queue_free()
		picked.queue_free()
		return
	TestFixtures.check(res, "the hovered background is darker than the resting row",
		hover_box.bg_color.get_luminance() < idle_box.bg_color.get_luminance(),
		"hover %s idle %s" % [hover_box.bg_color.to_html(false), idle_box.bg_color.to_html(false)])
	TestFixtures.check(res, "a hovered label turns orange",
		plain.get_theme_color(&"font_hover_color") == SortButton.ROW_HOVER_COLOR
		and plain.get_theme_color(&"font_color") == SortButton.ROW_COLOR,
		plain.get_theme_color(&"font_hover_color").to_html(false))
	TestFixtures.check(res, "the picked row keeps its own colours under the pointer",
		picked.get_theme_color(&"font_hover_color") == SortButton.ROW_PICKED_COLOR
		and picked.get_theme_stylebox(&"hover") == picked.get_theme_stylebox(&"normal"),
		picked.get_theme_color(&"font_hover_color").to_html(false))
	plain.queue_free()
	picked.queue_free()
