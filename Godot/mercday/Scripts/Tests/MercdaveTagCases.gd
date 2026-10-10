class_name MercdaveTagCases

#MercdaveUiTests Stage 4 closing cases: every HelpTarget a scene file declares lives when that scene stands
#alone, the markers that sit on each other, and the HintScope.collect cost on the largest fixture screens.

const HUD_SCENE: String = "res://Scenes/GUI/HUD/GameHUD.tscn"
const VAC_BLOCK: String = "res://Scenes/GUI/Mail/VacationRequestBlock.tscn"
const BILL_BLOCK: String = "res://Scenes/GUI/Mail/BillBlock.tscn"
const MAIL_DIALOG: String = "res://Scenes/GUI/Calendar/MailDialog.tscn"
#Scenes with no tag of their own that host tagged child scenes; looked at for markers that sit on each other.
const HOSTS: Array[String] = ["res://Scenes/GUI/Metrics/MetricsViewer.tscn",
	"res://Scenes/GUI/Calendar/OrderDialog.tscn"]
#Scene path -> why the live check cannot stand it alone.
const SKIP: Dictionary = {}
const NEAR: float = 16.0
const CALLS: int = 200
const SCROLL_STEP: float = 40.0
const BOARD_TYPE: String = "Military"


static func run(res: Dictionary, host: Node) -> void:
	MailEffectsTests._boot_with([])
	MailCenter._due.clear()
	if GameState.mercs.is_empty():
		TestFixtures.check(res, "10 live tags: the fixture campaign has a merc", false, "no merc")
		return
	var ask: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST, &"", MailBlockTests._request())
	var mails: Dictionary = {VAC_BLOCK: ask, BILL_BLOCK: MailCenter.deliver(&"B1")}
	var pairs: Array[String] = []
	var hidden: Dictionary = {}
	await _case_live(res, host, mails, pairs, hidden)
	await _case_hosts(host, ask, pairs, hidden)
	print("MERCDAVE UI 3 markers within %d px of each other, both targets shown (%d): %s"
		% [int(NEAR), pairs.size(), "; ".join(pairs)])
	print("MERCDAVE UI 3 near pairs with a hidden target, per scene (not laid out, not listed): %s" % [hidden])
	await _case_cost(host)
	MailEffectsTests._boot_real()


#Item 1: each scene file that declares a HelpTarget, instanced under host; after one frame every tag it
#declares is in the tree with its hint and a control. Visible is never asked (a DropPanel target is hidden).
static func _case_live(res: Dictionary, host: Node, mails: Dictionary, pairs: Array[String], hidden: Dictionary) -> void:
	var tagged: Dictionary = {}
	var helped: Dictionary = {}
	var bases: Dictionary = {}
	MercdaveCardCases._scan_scenes("res://Scenes", tagged, helped, bases)
	var scenes: Array[String] = []
	for path: String in helped:
		scenes.append(path)
	scenes.sort()
	var per_id: Dictionary = {}
	var dead: Array[String] = []
	var noisy: Array[String] = []
	var nodes: int = 0
	var sink: MercdaveScopeCases.WarnLog = MercdaveScopeCases.WarnLog.new()
	OS.add_logger(sink)
	for path: String in scenes:
		var declared: Array[NodePath] = _declared(path, per_id)
		nodes += declared.size()
		if SKIP.has(path):
			continue
		var errors_before: int = sink.errors
		var root: Node = _stand(host, path, mails)
		await TestFixtures.frames(host, 1)
		for at: NodePath in declared:
			var link: HelpTarget = root.get_node_or_null(at) as HelpTarget
			if link == null or not link.is_inside_tree() or link.hint == null or link.control() == null:
				dead.append("%s:%s" % [path.get_file(), at])
		if sink.errors > errors_before:
			noisy.append("%s %d" % [path.get_file(), sink.errors - errors_before])
		_pairs(path.get_file(), root, pairs, hidden)
		root.queue_free()
		await TestFixtures.frames(host, 1)
	OS.remove_logger(sink)
	var repeated: Array[String] = []
	for id: String in per_id:
		if int(per_id[id]) > 1:
			repeated.append("%s %d" % [id, per_id[id]])
	print("MERCDAVE UI 10 live: %d HelpTarget nodes (by script) in %d scenes, %d distinct ids; repeated %s; skip %s"
		% [nodes, scenes.size(), per_id.size(), repeated, SKIP])
	print("MERCDAVE UI 10 live: scenes that logged errors standing alone %s" % [noisy])
	TestFixtures.check(res, "10 every HelpTarget a scene declares lives with the scene alone: in the tree, hint, control",
		dead.is_empty() and nodes > 0 and not per_id.has(""), "nodes %d dead %s" % [nodes, dead])
	var wrong: Array[String] = []
	for id: StringName in HintBook.ids():
		if per_id.has(String(id)) == MercdaveCardCases.PENDING_IDS.has(String(id)):
			wrong.append(String(id))
	TestFixtures.check(res, "10 every hint id outside the pending list is the hint of a HelpTarget node and no pending id is",
		wrong.is_empty(), "untagged or pending tagged %s" % [wrong])


#The paths (from the scene root) of the nodes a scene file declares with the HelpTarget script; counts each id.
static func _declared(path: String, per_id: Dictionary) -> Array[NodePath]:
	var out: Array[NodePath] = []
	var state: SceneState = (load(path) as PackedScene).get_state()
	for i: int in state.get_node_count():
		var help: bool = false
		var id: String = ""
		for p: int in state.get_node_property_count(i):
			var prop: StringName = state.get_node_property_name(i, p)
			var value: Variant = state.get_node_property_value(i, p)
			if prop == &"script" and value is Script:
				help = (value as Script).resource_path == MercdaveCardCases.HELP_SCRIPT
			elif prop == &"hint" and value is MercdaveHint:
				id = String((value as MercdaveHint).id())
		if help:
			out.append(state.get_node_path(i))
			per_id[id] = int(per_id.get(id, 0)) + 1
	return out


static func _stand(host: Node, path: String, mails: Dictionary) -> Node:
	if path == HUD_SCENE:
		return GuiHudTests.spawn_hud(host)
	var root: Node = (load(path) as PackedScene).instantiate()
	host.add_child(root)
	if mails.has(path):
		(root as MailBlock).set_mail(mails[path] as MailInstance)
	return root


#Item 3: pairs of live tags under root with different ids whose targets start less than NEAR px apart.
#A pair with a target not visible in the tree is not listed: it adds 1 to hidden[label].
static func _pairs(label: String, root: Node, out: Array[String], hidden: Dictionary) -> void:
	var links: Array[HelpTarget] = []
	for node: Node in root.get_tree().get_nodes_in_group(HelpTarget.GROUP):
		var link: HelpTarget = node as HelpTarget
		if link != null and root.is_ancestor_of(link) and link.hint != null and link.control() != null:
			links.append(link)
	for i: int in links.size():
		for j: int in range(i + 1, links.size()):
			var a: HelpTarget = links[i]
			var b: HelpTarget = links[j]
			var at_a: Vector2 = a.control().get_global_rect().position
			var at_b: Vector2 = b.control().get_global_rect().position
			if a.hint_id() == b.hint_id() or absf(at_a.x - at_b.x) >= NEAR or absf(at_a.y - at_b.y) >= NEAR:
				continue
			if not (a.control().is_visible_in_tree() and b.control().is_visible_in_tree()):
				hidden[label] = int(hidden.get(label, 0)) + 1
				continue
			var line: String = "%s: %s %s / %s %s" % [label, a.hint_id(), at_a, b.hint_id(), at_b]
			if not out.has(line):
				out.append(line)


#Items 6 and 8: the hosts with no tag of their own, and the Calendar MailDialog opened on a vacation mail.
static func _case_hosts(host: Node, ask: MailInstance, pairs: Array[String], hidden: Dictionary) -> void:
	for path: String in HOSTS:
		var root: Node = (load(path) as PackedScene).instantiate()
		host.add_child(root)
		await TestFixtures.frames(host, 1)
		_pairs(path.get_file(), root, pairs, hidden)
		root.queue_free()
		await TestFixtures.frames(host, 1)
	var dialog: MailDialog = (load(MAIL_DIALOG) as PackedScene).instantiate() as MailDialog
	host.add_child(dialog)
	dialog.open_for(ask.id)
	await TestFixtures.frames(host, 2)
	_pairs("MailDialog.tscn open on a vacation mail", dialog, pairs, hidden)
	dialog.close()
	dialog.queue_free()
	await TestFixtures.frames(host, 2)


#Item 2: help_targets nodes, the mean usec of one HintScope.collect and one scroll step of the main list.
static func _case_cost(host: Node) -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()
	TestFixtures.add_mercs(SubscriptionManager.max_mercs() - GameState.mercs.size())
	for _i: int in SubscriptionManager.max_contracts() - GameState.contracts.size():
		GameState.board.post(ContractGenerator.generate(BOARD_TYPE), CampaignClock.now())
	GameState.refresh_views()
	var hud: GameHUD = await MercdaveScopeCases.spawn(host)
	print("MERCDAVE UI 2 scan cost: roster %d mercs, contracts %d; %d collect calls per screen"
		% [GameState.mercs.size(), GameState.contracts.size(), CALLS])
	var mercs: MercViewer = hud.open_viewer(&"mercs") as MercViewer
	await MercdaveScopeCases.settle(host)
	if mercs != null:
		_measure(hud, "merc list", mercs.list)
		for tab: int in MercViewer.TAB_NAMES.size():
			mercs.select_tab(tab)
			await MercdaveScopeCases.settle(host)
			_measure(hud, "merc page %s" % MercViewer.TAB_NAMES[tab], mercs.page(tab))
	var finance: FinanceViewer = hud.open_viewer(&"finance") as FinanceViewer
	await MercdaveScopeCases.settle(host)
	if finance != null:
		finance.open_tab(&"payroll")
		await MercdaveScopeCases.settle(host)
		_measure(hud, "payroll list", finance.page(&"payroll"))
	var board: ContractViewer = hud.open_viewer(&"contracts") as ContractViewer
	await MercdaveScopeCases.settle(host)
	if board != null:
		_measure(hud, "contract board", board.list())
	hud.popup().close()
	hud.queue_free()
	await TestFixtures.frames(host, 2)


static func _measure(hud: GameHUD, label: String, area: Node) -> void:
	var count: int = hud.get_tree().get_nodes_in_group(HelpTarget.GROUP).size()
	var start: int = Time.get_ticks_usec()
	for _i: int in CALLS:
		HintScope.collect(hud)
	var mean: float = (Time.get_ticks_usec() - start) / float(CALLS)
	var step: String = "no scroll"
	var scroll: ScrollContainer = _main_scroll(area)
	if scroll != null:
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		var was: float = bar.value
		var span: float = bar.max_value - bar.page
		var t0: int = Time.get_ticks_usec()
		bar.value = minf(was + SCROLL_STEP, span)
		var spent: int = Time.get_ticks_usec() - t0
		step = "%d usec (range %d px)" % [spent, int(span)] if span > was else "no range"
		bar.value = was
	print("MERCDAVE UI 2 scan cost %s: help_targets %d, collect mean %.1f usec, scroll step %s"
		% [label, count, mean, step])


#The ScrollContainer under area (itself included) with the longest vertical range, or null.
static func _main_scroll(area: Node) -> ScrollContainer:
	if area == null:
		return null
	var best: ScrollContainer = null
	var best_span: float = -1.0
	var queue: Array[Node] = [area]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		var scroll: ScrollContainer = node as ScrollContainer
		if scroll != null:
			var bar: VScrollBar = scroll.get_v_scroll_bar()
			if bar.max_value - bar.page > best_span:
				best_span = bar.max_value - bar.page
				best = scroll
		queue.append_array(node.get_children())
	return best
