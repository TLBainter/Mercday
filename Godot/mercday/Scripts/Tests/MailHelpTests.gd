class_name MailHelpTests

#Mail M6: the seven Mail HelpTarget tags on each scene alone, hud_mail in the HUD scope and the Mail ids in the
#MailViewer frame scope, including a rebuilt block, a two-block thread and a bill. Run under gui-mail-tests.

const VIEWER_SCENE: PackedScene = preload("res://Scenes/GUI/Mail/MailViewer.tscn")
const LIST_SCENE: PackedScene = preload("res://Scenes/GUI/Mail/MailList.tscn")
const TABS_PATH: NodePath = ^"Margin/Columns/Left/TabsWrap/Tabs"
const IDS: Array[StringName] = [&"hud_mail", &"mail_tabs", &"mail_list", &"mail_sender", &"mail_options",
	&"mail_vac", &"mail_bill"]
const VIEW_IDS: Array[StringName] = [&"mail_tabs", &"mail_list", &"mail_sender", &"mail_options", &"mail_vac"]


static func run(res: Dictionary, host: Node) -> void:
	MailEffectsTests._boot_with([])
	MailCenter._due.clear()
	if GameState.mercs.is_empty():
		TestFixtures.check(res, "M6 Mail help tags", false, "no merc")
		return
	await _case_live(res, host)
	var hud: GameHUD = await MercdaveScopeCases.spawn(host)
	_case_hud(res, hud)
	await _case_viewer(res, host, hud)
	await MailViewTests._close(host, hud)
	await TestFixtures.frames(host, 2)


#Every HelpTarget under root whose hint is id.
static func _tags(root: Node, id: StringName) -> Array[HelpTarget]:
	var out: Array[HelpTarget] = []
	for node: Node in root.get_tree().get_nodes_in_group(HelpTarget.GROUP):
		var link: HelpTarget = node as HelpTarget
		if link != null and root.is_ancestor_of(link) and link.hint_id() == id:
			out.append(link)
	return out


#Item 4: each tagged scene instanced on its own; after one frame its tag is in the tree with a hint and a control.
static func _case_live(res: Dictionary, host: Node) -> void:
	var bill: MailInstance = MailCenter.deliver(&"B1")
	var ask: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST, &"", MailBlockTests._request())
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	var viewer: MailViewer = VIEWER_SCENE.instantiate() as MailViewer
	var list: MailList = LIST_SCENE.instantiate() as MailList
	var reader: MailReader = MailBlockTests.READER_SCENE.instantiate() as MailReader
	var vac: MailBlock = (MailReader.BLOCKS[MailInstance.KIND_VACATION] as PackedScene).instantiate() as MailBlock
	var bill_block: MailBlock = (MailReader.BLOCKS[MailInstance.KIND_BILL] as PackedScene).instantiate() as MailBlock
	var alone: Array[Node] = [viewer, list, reader, vac, bill_block]
	for scene: Node in alone:
		host.add_child(scene)
	vac.set_mail(ask)
	bill_block.set_mail(bill)
	await host.get_tree().process_frame
	var want: Dictionary = {&"hud_mail": [hud, hud.mail_button], &"mail_tabs": [viewer, viewer.get_node(TABS_PATH)],
		&"mail_list": [list, list], &"mail_sender": [reader, reader.from_label],
		&"mail_options": [reader, reader.options], &"mail_vac": [vac, vac], &"mail_bill": [bill_block, bill_block]}
	var fails: Array[String] = []
	for id: StringName in IDS:
		var pair: Array = want[id]
		var links: Array[HelpTarget] = _tags(pair[0] as Node, id)
		var link: HelpTarget = links[0] if links.size() == 1 else null
		var in_tree: bool = link != null and link.is_inside_tree()
		var has_hint: bool = link != null and link.hint != null
		var box: Control = link.control() if link != null else null
		var ok: bool = in_tree and has_hint and box != null and box == pair[1]
		print("MAIL HELP live %s: tags %d in_tree %s hint %s control %s ok %s" % [id, links.size(), in_tree, has_hint,
			String(box.name) if box != null else "null", ok])
		if not ok:
			fails.append(String(id))
	TestFixtures.check(res, "M6 each tagged Mail scene alone: one HelpTarget in the tree with its hint on its control",
		fails.is_empty(), "fails %s" % [fails])
	for scene: Node in alone:
		scene.queue_free()
	hud.queue_free()
	await TestFixtures.frames(host, 2)


#Item 2a: with no frame open hud_mail is present and on screen on the Mail button, as hud_bell is on its slot.
static func _case_hud(res: Dictionary, hud: GameHUD) -> void:
	var scope: Dictionary = HintScope.collect(hud)
	var present: Array = scope["present"] as Array
	var shown: Array = scope["visible"] as Array
	var controls: Dictionary = scope["controls"] as Dictionary
	TestFixtures.check(res, "M6 hud_mail is in the HUD scope as hud_bell is: present, on screen and on its own slot",
		GuiFrameStack.top() == null and present.has(&"hud_mail") and present.has(&"hud_bell") and shown.has(&"hud_mail")
		and shown.has(&"hud_bell") and controls.get(&"hud_mail") == hud.mail_button
		and controls.get(&"hud_bell") == hud.bell_slot, "present %s visible %s top %s bell shown %s" % [present, shown,
		GuiFrameStack.top().get_path() if GuiFrameStack.top() != null else NodePath(), hud.bell_slot.is_visible_in_tree()])


#Items 2b-2e: the Inbox opened through hud.open_mail on a vacation mail, then a rebuild, a thread and a bill.
static func _case_viewer(res: Dictionary, host: Node, hud: GameHUD) -> void:
	var req: VacationRequest = MailBlockTests._request()
	var ask: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST, &"", req)
	var view: MailViewer = hud.open_mail(ask.id) as MailViewer
	await MercdaveScopeCases.settle(host)
	if view == null:
		TestFixtures.check(res, "M6 hud.open_mail opens the MailViewer", false, "no viewer")
		return
	var scope: Dictionary = HintScope.collect(hud)
	var present: Array = scope["present"] as Array
	var misses: Array[String] = []
	for id: StringName in VIEW_IDS:
		var box: Control = (scope["controls"] as Dictionary).get(id, null) as Control
		if not present.has(id) or box == null or not box.is_inside_tree():
			misses.append(String(id))
	TestFixtures.check(res, "M6 the MailViewer frame scope holds the tabs, list, sender, options and vacation block tags",
		scope["root"] == GuiFrameStack.top() and misses.is_empty() and not present.has(&"hud_mail")
		and not present.has(&"mail_bill"), "present %s misses %s" % [present, misses])
	var before: Array[MailBlock] = MailBlockTests._blocks_of(view.reader)
	var old_id: int = before[0].get_instance_id() if before.size() == 1 else 0
	before.clear()
	view.reader.show_mail(ask.id)
	await host.get_tree().process_frame
	var fresh: Array[MailBlock] = MailBlockTests._blocks_of(view.reader)
	var vac_box: Control = (HintScope.collect(hud)["controls"] as Dictionary).get(&"mail_vac", null) as Control
	TestFixtures.check(res, "M6 after a second show_mail of the same mail mail_vac points at the new block",
		old_id != 0 and fresh.size() == 1 and fresh[0].get_instance_id() != old_id and vac_box == fresh[0],
		"old %d new %d tag on new %s" % [old_id, fresh[0].get_instance_id() if fresh.size() == 1 else 0,
		vac_box == fresh[0] if fresh.size() == 1 else false])
	await _check_thread(res, host, hud, view, ask, req)
	await _check_bill(res, host, hud, view)


#Item 2d: two vacation blocks in one thread scan without error and give mail_vac once.
static func _check_thread(res: Dictionary, host: Node, hud: GameHUD, view: MailViewer, ask: MailInstance,
		req: VacationRequest) -> void:
	var nudge: MailInstance = MailCenter.deliver(MailCatalog.VAC_REMIND, ask.id, req)
	var sink: MercdaveScopeCases.WarnLog = MercdaveScopeCases.WarnLog.new()
	OS.add_logger(sink)
	view.select_mail(nudge.id)
	await MercdaveScopeCases.settle(host)
	var scope: Dictionary = HintScope.collect(hud)
	OS.remove_logger(sink)
	var thread: Array[MailBlock] = MailBlockTests._blocks_of(view.reader)
	var count: int = (scope["present"] as Array).count(&"mail_vac")
	var box: Control = (scope["controls"] as Dictionary).get(&"mail_vac", null) as Control
	var at: int = thread.find(box) if box is MailBlock else -1
	var which: String = "none"
	if at >= 0:
		which = "request mail" if thread[at].mail == ask else "reminder mail"
	print("MAIL HELP thread: mail_vac points at block %d of %d (%s)" % [at + 1, thread.size(), which])
	TestFixtures.check(res, "M6 a thread of two vacation mails scans with no error and holds mail_vac exactly once",
		sink.errors == 0 and thread.size() == 2 and count == 1 and at >= 0,
		"errors %d blocks %d count %d at %d (%s)" % [sink.errors, thread.size(), count, at, which])


#Item 2e: a bill mail gives mail_bill on its BillBlock.
static func _check_bill(res: Dictionary, host: Node, hud: GameHUD, view: MailViewer) -> void:
	var bill: MailInstance = MailCenter.deliver(&"B1")
	view.select_mail(bill.id)
	await MercdaveScopeCases.settle(host)
	var scope: Dictionary = HintScope.collect(hud)
	var present: Array = scope["present"] as Array
	var blocks: Array[MailBlock] = MailBlockTests._blocks_of(view.reader)
	var box: Control = (scope["controls"] as Dictionary).get(&"mail_bill", null) as Control
	TestFixtures.check(res, "M6 a bill mail gives mail_bill on its BillBlock and no mail_vac",
		blocks.size() == 1 and blocks[0] is BillBlock and box == blocks[0] and present.has(&"mail_bill")
		and not present.has(&"mail_vac"), "blocks %d present %s" % [blocks.size(), present])
