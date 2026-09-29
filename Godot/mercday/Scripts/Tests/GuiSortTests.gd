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
const EDGE_COLOR: Color = Color("#0a0f1c")
const EDGE_PX: int = 3
const DIRECTION_WORDS: Array[String] = ["dir", "direction", "asc", "desc"]

const CONTRACT_VIEWER: PackedScene = preload("res://Scenes/GUI/Contracts/ContractViewer.tscn")
const MERC_VIEWER: PackedScene = preload("res://Scenes/GUI/Mercs/MercViewer.tscn")
const CLIENT_VIEWER: PackedScene = preload("res://Scenes/GUI/Clients/ClientViewer.tscn")
const LOANS_TAB: PackedScene = preload("res://Scenes/GUI/Finance/Loans/LoansTab.tscn")
const PAYROLL_TAB: PackedScene = preload("res://Scenes/GUI/Finance/Payroll/PayrollTab.tscn")
const HIRING_TAB: PackedScene = preload("res://Scenes/GUI/Finance/Hiring/HiringTab.tscn")
const PROMO_VIEWER: PackedScene = preload("res://Scenes/GUI/Promotions/PromotionsViewer.tscn")
const HIRING_PAGE_SIZE: Vector2 = Vector2(1280.0, 720.0)
#Clients: ClientRegistry._before pins a client that never had a contract (recency < 0) to the
#tail of the list in both directions, so a recency of -1 is excluded before the flip check
#compares key values; see _open_clients.
const CLIENTS_SENTINEL: int = -1


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_contracts(res, host)
	await _case_dispatch(res, host)
	await _case_merc(res, host)
	await _case_clients(res, host)
	await _case_loans(res, host)
	await _case_payroll(res, host)
	await _case_hiring(res, host)
	await _case_promotions(res, host)
	await _case_all_toggles(res, host)
	await _case_row_hover(res, host)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.reset()
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


#True when a normal stylebox paints exactly the literal fill, edge color and edge width.
static func _stylebox_ok(box: StyleBoxFlat, fill: Color) -> bool:
	return box != null and box.bg_color == fill and box.border_color == EDGE_COLOR \
		and box.border_width_left == EDGE_PX and box.border_width_top == EDGE_PX \
		and box.border_width_right == EDGE_PX and box.border_width_bottom == EDGE_PX


static func _all_styleboxes_ok(boxes: Array, fill: Color) -> bool:
	for box: StyleBoxFlat in boxes:
		if not _stylebox_ok(box as StyleBoxFlat, fill):
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
	if node is SortDirToggle:
		total += 1
	elif node is Button and _looks_like_direction(node as Button):
		total += 1
	for child: Node in node.get_children():
		total += _count_direction_controls(child)
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


static func _close_contracts(screen: Node) -> void:
	screen.queue_free()


static func _first_open_id(viewer: ContractViewer) -> int:
	for view: ContractView in viewer.list().listed():
		if view.status == GuiTypes.ContractStatus.AVAILABLE:
			return view.entry_id
	return -1


static func _open_dispatch(host: Node) -> Dictionary:
	_fresh()
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
	#Sort.BEST ranks by an internal, non-public score; DispatchRosterItem.stars_value() is the
	#public value built from that same score (DispatchLogic.to_stars), so it moves with it.
	var keys: Callable = func() -> Array:
		var out: Array = []
		var uids: Array = roster.shown_uids()
		for i: int in uids.size():
			var item: DispatchRosterItem = roster.row_at(i)
			out.append(item.stars_value() if item != null else 0.0)
		return out
	return {"toggle": roster.dir_toggle, "root": roster, "order": order, "keys": keys,
		"screen": viewer}


static func _close_dispatch(screen: Node) -> void:
	screen.queue_free()


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


static func _close_merc(screen: Node) -> void:
	screen.queue_free()


static func _open_clients(host: Node) -> Dictionary:
	_fresh()
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


static func _close_clients(screen: Node) -> void:
	screen.queue_free()


static func _open_loans(host: Node) -> Dictionary:
	_fresh()
	FinanceManager.reset()
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
	SubscriptionManager.reset()
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
	SubscriptionManager.reset()


static func _hiring_ent() -> Dictionary:
	return {"promotions": true, "oddJobs": 2, "adDirect": true, "adRadio": true,
		"adSponsor": true, "maxPromoDays": 30, "jobPostings": true, "guildPromo": true}


static func _open_hiring(host: Node) -> Dictionary:
	_fresh()
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	SubscriptionManager.set_entitlements(_hiring_ent())
	LegalManager.reset()
	PromotionsManager.reset()
	var page: HiringTab = HIRING_TAB.instantiate() as HiringTab
	page.custom_minimum_size = HIRING_PAGE_SIZE
	host.add_child(page)
	page.size = HIRING_PAGE_SIZE
	for _i: int in 3:
		await host.get_tree().process_frame
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
	SubscriptionManager.reset()
	LegalManager.reset()
	PromotionsManager.reset()


static func _open_promotions(host: Node) -> Dictionary:
	_fresh()
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	SubscriptionManager.set_entitlements(_hiring_ent())
	LegalManager.reset()
	PromotionsManager.reset()
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


static func _close_promotions(screen: Node) -> void:
	GuiFrameStack.clear()
	screen.queue_free()
	SubscriptionManager.reset()
	LegalManager.reset()
	PromotionsManager.reset()


static func _case_contracts(res: Dictionary, host: Node) -> void:
	var data: Dictionary = await _open_contracts(host)
	await _verify_toggle(res, "Contracts", data)
	_close_contracts(data["screen"] as Node)


static func _case_dispatch(res: Dictionary, host: Node) -> void:
	var data: Dictionary = await _open_dispatch(host)
	if data["toggle"] == null:
		TestFixtures.check(res, "Dispatch opens a dispatch window to read its toggle", false,
			"no open contract to accept")
		_close_dispatch(data["screen"] as Node)
		return
	await _verify_toggle(res, "Dispatch", data)
	_close_dispatch(data["screen"] as Node)


static func _case_merc(res: Dictionary, host: Node) -> void:
	var data: Dictionary = await _open_merc(host)
	await _verify_toggle(res, "Merc roster", data)
	_close_merc(data["screen"] as Node)


static func _case_clients(res: Dictionary, host: Node) -> void:
	var data: Dictionary = await _open_clients(host)
	await _verify_toggle(res, "Clients", data)
	_close_clients(data["screen"] as Node)


static func _case_loans(res: Dictionary, host: Node) -> void:
	var data: Dictionary = await _open_loans(host)
	await _verify_toggle(res, "Finance Loans", data)
	_close_loans(data["screen"] as Node)


static func _case_payroll(res: Dictionary, host: Node) -> void:
	var data: Dictionary = await _open_payroll(host)
	await _verify_toggle(res, "Finance Payroll", data)
	_close_payroll(data["screen"] as Node)


static func _case_hiring(res: Dictionary, host: Node) -> void:
	var data: Dictionary = await _open_hiring(host)
	await _verify_toggle(res, "Hiring", data)
	_close_hiring(data["screen"] as Node)


static func _case_promotions(res: Dictionary, host: Node) -> void:
	var data: Dictionary = await _open_promotions(host)
	await _verify_toggle(res, "Promotions", data)
	_close_promotions(data["screen"] as Node)


#Reads the script, the scene path, the size and both looks of one toggle into the parallel
#arrays, plus the raw normal stylebox of each look so the cross-list case can check the paint
#independently of fill_color() (which reads the same LOOKS table _refresh() paints from).
#min_sizes holds custom_minimum_size and sizes holds the actual rendered size, so a row that
#stretches the toggle past its minimum still fails the cross-list size check.
static func _collect_look(data: Dictionary, scripts: Array, scene_paths: Array, min_sizes: Array,
		sizes: Array, down_fills: Array, down_tips: Array, up_fills: Array, up_tips: Array,
		down_boxes: Array, up_boxes: Array) -> void:
	var toggle: SortDirToggle = data["toggle"] as SortDirToggle
	scripts.append(toggle.get_script())
	scene_paths.append(toggle.scene_file_path)
	min_sizes.append(toggle.custom_minimum_size)
	sizes.append(toggle.size)
	toggle.descending = true
	down_fills.append(toggle.fill_color())
	down_tips.append(toggle.tooltip_text)
	down_boxes.append(toggle.get_theme_stylebox("normal") as StyleBoxFlat)
	toggle.descending = false
	up_fills.append(toggle.fill_color())
	up_tips.append(toggle.tooltip_text)
	up_boxes.append(toggle.get_theme_stylebox("normal") as StyleBoxFlat)


#Part J step 15, the last case: the eight direction toggles compared with each other. Every
#aggregate check is guarded by size() == 8 so a screen that failed to hand back a toggle cannot
#make _all_equal() pass vacuously on a short or empty array.
static func _case_all_toggles(res: Dictionary, host: Node) -> void:
	var scripts: Array = []
	var scene_paths: Array = []
	var min_sizes: Array = []
	var sizes: Array = []
	var down_fills: Array = []
	var down_tips: Array = []
	var up_fills: Array = []
	var up_tips: Array = []
	var down_boxes: Array = []
	var up_boxes: Array = []
	var d0: Dictionary = await _open_contracts(host)
	_collect_look(d0, scripts, scene_paths, min_sizes, sizes, down_fills, down_tips, up_fills,
		up_tips, down_boxes, up_boxes)
	_close_contracts(d0["screen"] as Node)
	var d1: Dictionary = await _open_dispatch(host)
	if d1["toggle"] != null:
		_collect_look(d1, scripts, scene_paths, min_sizes, sizes, down_fills, down_tips, up_fills,
			up_tips, down_boxes, up_boxes)
	else:
		TestFixtures.check(res, "Dispatch has a direction toggle to compare with the rest", false,
			"no open contract to accept")
	_close_dispatch(d1["screen"] as Node)
	var d2: Dictionary = await _open_merc(host)
	_collect_look(d2, scripts, scene_paths, min_sizes, sizes, down_fills, down_tips, up_fills,
		up_tips, down_boxes, up_boxes)
	_close_merc(d2["screen"] as Node)
	var d3: Dictionary = await _open_clients(host)
	_collect_look(d3, scripts, scene_paths, min_sizes, sizes, down_fills, down_tips, up_fills,
		up_tips, down_boxes, up_boxes)
	_close_clients(d3["screen"] as Node)
	var d4: Dictionary = await _open_loans(host)
	_collect_look(d4, scripts, scene_paths, min_sizes, sizes, down_fills, down_tips, up_fills,
		up_tips, down_boxes, up_boxes)
	_close_loans(d4["screen"] as Node)
	var d5: Dictionary = await _open_payroll(host)
	_collect_look(d5, scripts, scene_paths, min_sizes, sizes, down_fills, down_tips, up_fills,
		up_tips, down_boxes, up_boxes)
	_close_payroll(d5["screen"] as Node)
	var d6: Dictionary = await _open_hiring(host)
	_collect_look(d6, scripts, scene_paths, min_sizes, sizes, down_fills, down_tips, up_fills,
		up_tips, down_boxes, up_boxes)
	_close_hiring(d6["screen"] as Node)
	var d7: Dictionary = await _open_promotions(host)
	_collect_look(d7, scripts, scene_paths, min_sizes, sizes, down_fills, down_tips, up_fills,
		up_tips, down_boxes, up_boxes)
	_close_promotions(d7["screen"] as Node)
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
	TestFixtures.check(res, "the eight direction toggles paint the literal descending stylebox",
		down_boxes.size() == 8 and _all_styleboxes_ok(down_boxes, DOWN_FILL),
		"fills %s" % [down_boxes.map(func(b: StyleBoxFlat) -> Color: return b.bg_color if b != null else Color.BLACK)])
	TestFixtures.check(res, "the eight direction toggles paint the literal ascending stylebox",
		up_boxes.size() == 8 and _all_styleboxes_ok(up_boxes, UP_FILL),
		"fills %s" % [up_boxes.map(func(b: StyleBoxFlat) -> Color: return b.bg_color if b != null else Color.BLACK)])


#Item 13: a hovered sort row darkens and turns its label orange instead of losing its background.
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
