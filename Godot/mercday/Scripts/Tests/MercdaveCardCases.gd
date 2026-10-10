class_name MercdaveCardCases

#MercdaveUiTests card checks 4-11 and 13, the card face parts of 8 and 15, on a spawned GameHUD.
#CardPlacement is checked on fixed rects in a 1280 x 644 band.

const TIER_SCENE: String = "res://Scenes/GUI/Subscription/UpgradeTierDialog.tscn"
const SHADER_PATH: String = "res://Scenes/GUI/Mercdave/DevilNoise.gdshader"
const HINT_DIR_TAG: String = "path=\"res://Resources/Mercdave/Hints/"
const HELP_SCRIPT: String = "res://Scripts/GUI/Mercdave/HelpTarget.gd"
const ROOT_INSTANCE: String = "instance=ExtResource(\""
const AREA: Rect2 = Rect2(0, 0, 1280, 644)
const CARD_H: float = 150.0
const MARGIN: float = 12.0
const MORE_TEXT: String = "probe more text"
const HUD_TAGS: int = 19
const DEVIL_FACE: int = 20
#Ids with no control to tag yet; an entry goes when its control is built. scene_PhysicalStats: the merc
#viewer's Physical Attributes fields are not built (MercLocks.K_PHYSICAL is tabled only).
const PENDING_IDS: Array[String] = ["scene_PhysicalStats"]
const TILE_IDS: Array[StringName] = [&"menu_mercs", &"menu_contracts", &"menu_clients", &"menu_promotions", &"menu_mercday",
	&"menu_finance", &"menu_legal", &"menu_bazaar", &"menu_metrics"]
const OUTER_IDS: Array[StringName] = [&"menu_mercs", &"menu_clients", &"menu_promotions", &"menu_finance", &"menu_legal",
	&"menu_metrics"]


static func run(res: Dictionary, host: Node) -> void:
	_case_placement(res)
	_case_coverage(res)
	var hud: GameHUD = await MercdaveScopeCases.spawn(host)
	var layer: MercdaveLayer = MercdaveScopeCases.layer_of(hud)
	var card: HintCard = layer.card
	Mercdave.toggle()
	await TestFixtures.frames(host, 2)
	var style: StyleBox = card.get_theme_stylebox(&"panel")
	var wide: bool = is_equal_approx(card.size.x, CardPlacement.DOCK_W) or is_equal_approx(card.size.x, CardPlacement.FREE_W)
	TestFixtures.check(res, "6 HUD card is 344 beside its target or 384 at a spot, 12 px content margins",
		card.visible and wide and style != null
			and is_equal_approx(style.get_margin(SIDE_LEFT), MARGIN) and is_equal_approx(style.get_margin(SIDE_TOP), MARGIN)
			and is_equal_approx(style.get_margin(SIDE_RIGHT), MARGIN) and is_equal_approx(style.get_margin(SIDE_BOTTOM), MARGIN),
		"visible %s size %s" % [card.visible, card.size])
	TestFixtures.check(res, "6 the open card holds campaign time",
		card.visible and GameState.is_time_held(), "visible %s held %s" % [card.visible, GameState.is_time_held()])
	var library: SoundLibrary = UiSfx.click_library(card.ok)
	TestFixtures.check(res, "6 the card buttons click with the default click set",
		card.ok.click_sfx == null and card.next_hint.click_sfx == null and card.tell_more.click_sfx == null
			and library == UiSfx.config.click and library != UiSfx.config.mercdave_click,
		"library %s" % (library.resource_path.get_file() if library != null else "none"))
	await _case_hud_cards(res, host, layer)
	await _case_tier(res, host, layer)
	await _case_buttons(res, host, hud, layer)
	await _case_bell(res, host, hud, layer)
	await _case_lock(res, host, hud, layer)
	await _case_viewer(res, host, hud, layer)
	if Mercdave.card_open:
		Mercdave.toggle()
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "6 the closed card lets time run again",
		not card.visible and not GameState.is_time_held(), "visible %s held %s" % [card.visible, GameState.is_time_held()])
	hud.queue_free()
	await TestFixtures.frames(host, 2)


static func _case_placement(res: Dictionary) -> void:
	var none: Array[Rect2] = []
	var right: Rect2 = CardPlacement.place(CARD_H, Rect2(300, 100, 400, 300), none, -1, none, AREA)
	var left: Rect2 = CardPlacement.place(CARD_H, Rect2(800, 100, 400, 300), none, -1, none, AREA)
	var full: Rect2 = CardPlacement.place(CARD_H, AREA, none, -1, none, AREA)
	TestFixtures.check(res, "4 docks 344 wide right of the box +16, left when no room, spots for a full-screen frame",
		right.position.is_equal_approx(Vector2(716, 100)) and is_equal_approx(right.size.x, CardPlacement.DOCK_W)
			and is_equal_approx(left.position.x, 440.0) and is_equal_approx(full.size.x, CardPlacement.FREE_W)
			and CardPlacement.SPOTS.has(full.position),
		"right %s left %s full %s" % [right, left, full])
	var marks: Array[Rect2] = [Rect2(900, 500, 100, 50)]
	var under: float = CardPlacement.score(Rect2(CardPlacement.SPOTS[0], Vector2(CardPlacement.FREE_W, CARD_H)), marks, 0, none)
	var pick: Rect2 = CardPlacement.place(CARD_H, Rect2(), marks, 0, none, AREA)
	var controls: Array[Rect2] = [Rect2(540, 494, 344, 150)]
	var dodge: Rect2 = CardPlacement.place(CARD_H, Rect2(), marks, 0, controls, AREA)
	TestFixtures.check(res, "5 beside the target: left first, then above when a control sits under the left candidate",
		is_equal_approx(under, 3.0) and pick.is_equal_approx(Rect2(540, 486, 344, 150))
			and dodge.is_equal_approx(Rect2(900, 334, 344, 150)),
		"under %.2f pick %s dodge %s" % [under, pick, dodge])
	var tiles: Array[Rect2] = []
	for y: float in [90.0, 268.0, 446.0]:
		for x: float in [382.0, 560.0, 738.0]:
			tiles.append(Rect2(x, y, 160, 160))
	var pick6: Rect2 = CardPlacement.place(CARD_H, Rect2(), tiles, 6, tiles, AREA)
	var pick7: Rect2 = CardPlacement.place(CARD_H, Rect2(), tiles, 7, tiles, AREA)
	var whole: Array[Rect2] = [AREA]
	var fallback: Rect2 = CardPlacement.place(CARD_H, Rect2(), whole, 0, none, AREA)
	TestFixtures.check(res, "5 a bottom-left tile gets the card at its left; a bottom-centre tile falls to a spot",
		pick6.is_equal_approx(Rect2(22, 446, 344, 150)) and CardPlacement.SPOTS.has(pick7.position)
			and is_equal_approx(pick7.size.x, CardPlacement.FREE_W) and CardPlacement.SPOTS.has(fallback.position),
		"tile 6 %s tile 7 %s fallback %s" % [pick6, pick7, fallback])
	var two: Array[Rect2] = [Rect2(300, 100, 160, 160), Rect2(700, 100, 200, 160)]
	var two_far: Array[Rect2] = [Rect2(300, 100, 160, 160), Rect2(740, 100, 200, 160)]
	var one: Array[Rect2] = [Rect2(300, 100, 160, 160)]
	var slot: Rect2 = Rect2(476, 100, 344, 150)
	var heavy_near: bool = CardPlacement.heavy(slot, two, 0)
	var heavy_far: bool = CardPlacement.heavy(slot, two_far, 0)
	var heavy_own: bool = CardPlacement.heavy(Rect2(300, 100, 344, 150), one, 0)
	var pair: Array[Rect2] = [Rect2(300, 100, 160, 160), Rect2(476, 100, 160, 160)]
	var dropped: Rect2 = CardPlacement.place(CARD_H, Rect2(), pair, 0, none, AREA)
	TestFixtures.check(res, "5 a beside slot covering over half of another mark is skipped; the shown mark never counts",
		heavy_near and not heavy_far and not heavy_own and dropped.is_equal_approx(Rect2(300, 276, 344, 150)),
		"near %s (%.3f) far %s (%.3f) own %s placed %s" % [heavy_near,
			slot.intersection(two[1]).get_area() / two[1].get_area(), heavy_far,
			slot.intersection(two_far[1]).get_area() / two_far[1].get_area(), heavy_own, dropped])
	var bar: Array[Rect2] = [Rect2(600, 656, 80, 30), Rect2(1200, 656, 60, 30)]
	var over: Rect2 = CardPlacement.place(CARD_H, Rect2(), bar, 0, tiles, AREA)
	var edge: Rect2 = CardPlacement.place(CARD_H, Rect2(), bar, 1, tiles, AREA)
	var covered: Array[Rect2] = [over]
	var tall_bar: Rect2 = CardPlacement.place(200.0, Rect2(), bar, 0, covered, AREA)
	var short_bar: Rect2 = CardPlacement.place(100.0, Rect2(), bar, 0, tiles, AREA)
	TestFixtures.check(res,
		"5 a target below the band gets a 344 card on the band edge, left edge on the item, whatever it covers",
		over.is_equal_approx(Rect2(600, 494, 344, 150)) and edge.is_equal_approx(Rect2(936, 494, 344, 150))
			and tall_bar.is_equal_approx(Rect2(600, 444, 344, 200))
			and short_bar.is_equal_approx(Rect2(600, 544, 344, 100)),
		"over %s edge %s tall %s short %s" % [over, edge, tall_bar, short_bar])
	var low: Rect2 = CardPlacement.clamp_top(Rect2(0, 600, 384, 100), AREA)
	var tall: Rect2 = CardPlacement.clamp_top(Rect2(0, 600, 384, 200), AREA)
	TestFixtures.check(res, "5 the top is clamped to 644-158 (or 644 less a taller card)",
		is_equal_approx(low.position.y, 486.0) and is_equal_approx(tall.position.y, 444.0),
		"low %s tall %s" % [low.position, tall.position])


#Each HUD hint in turn: the card clears its target and sits beside it or at a spot; outer tiles get one beside.
static func _case_hud_cards(res: Dictionary, host: Node, layer: MercdaveLayer) -> void:
	var tiles: Array[Rect2] = []
	for id: StringName in TILE_IDS:
		var tile: Control = layer.control_for(id)
		if tile != null:
			tiles.append(tile.get_global_rect())
	var shown_ids: Array[StringName] = Mercdave.marks.duplicate()
	if Mercdave.card_open and HintBook.is_valid(Mercdave.current):
		shown_ids.push_front(Mercdave.current)
	var covering: Array[StringName] = []
	var far: Array[StringName] = []
	var spotted: Array[StringName] = []
	var outer_bad: Array[StringName] = []
	var legal_left: bool = false
	var band: Rect2 = CardPlacement.band(layer.get_viewport_rect().size)
	var bar: Array[StringName] = []
	var bar_bad: Array[StringName] = []
	for id: StringName in shown_ids:
		Mercdave.show_hint(id)
		await TestFixtures.frames(host, 2)
		var box: Control = layer.control_for(id)
		if box == null:
			covering.append(id)
			continue
		var target: Rect2 = box.get_global_rect()
		var card: Rect2 = layer.card.get_global_rect()
		var near: bool = CardPlacement.gap(card, target) <= CardPlacement.DOCK_GAP + 1.0
		if card.intersects(target):
			covering.append(id)
		if target.position.y >= band.end.y:
			var x: float = clampf(target.position.x, band.position.x, band.end.x - CardPlacement.DOCK_W)
			var y: float = band.end.y - card.size.y
			bar.append(id)
			if not (is_equal_approx(card.size.x, CardPlacement.DOCK_W) and is_equal_approx(card.position.x, x)
					and is_equal_approx(card.position.y, y) and is_equal_approx(card.end.y, band.end.y)):
				bar_bad.append(id)
			continue
		if not near and not CardPlacement.SPOTS.has(card.position):
			far.append(id)
		if not near:
			spotted.append(id)
		if OUTER_IDS.has(id):
			var clear: bool = near
			for tile: Rect2 in tiles:
				clear = clear and not card.intersects(tile)
			if not clear:
				outer_bad.append(id)
		if id == &"menu_legal":
			legal_left = is_equal_approx(card.end.x, target.position.x - CardPlacement.DOCK_GAP)
	Mercdave.close()
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "5 every HUD hint card clears its target and sits beside it or at a spot",
		covering.is_empty() and far.is_empty() and not tiles.is_empty(),
		"covering %s far %s at a spot %s" % [covering, far, spotted])
	TestFixtures.check(res, "5 the six outer tiles get an adjacent card; menu_legal sits at its left",
		outer_bad.is_empty() and legal_left and tiles.size() == TILE_IDS.size(),
		"outer bad %s legal left %s tiles %d at a spot %s" % [outer_bad, legal_left, tiles.size(), spotted])
	TestFixtures.check(res,
		"5 the six bottom bar hints get a 344 card on the band edge over the HUD, left edge on the item",
		bar.size() == 6 and bar_bad.is_empty(),
		"bar %s bad %s at a spot %s" % [bar, bar_bad, spotted])


#Hard: every hint id outside PENDING_IDS has a HelpTarget in a scene and no pending id has one.
static func _case_coverage(res: Dictionary) -> void:
	var tagged: Dictionary = {}
	var helped: Dictionary = {}
	var bases: Dictionary = {}
	_scan_scenes("res://Scenes", tagged, helped, bases)
	var leaks: Array[String] = []
	for scene: String in bases:
		if helped.has(bases[scene]):
			leaks.append("%s from %s" % [scene.get_file(), String(bases[scene]).get_file()])
	TestFixtures.check(res, "10 no scene inherits a HelpTarget from the scene it extends",
		leaks.is_empty(), "leaks %s" % [leaks])
	var unknown: Array[String] = []
	for id: String in tagged:
		if not HintBook.ids().has(StringName(id)):
			unknown.append(id)
	var untagged: PackedStringArray = PackedStringArray()
	for id: StringName in HintBook.ids():
		if not tagged.has(String(id)) and not PENDING_IDS.has(String(id)):
			untagged.append(String(id))
	var pending_tagged: Array[String] = []
	for pending: String in PENDING_IDS:
		if tagged.has(pending):
			pending_tagged.append(pending)
	print("MERCDAVE UI 10 hint ids no HelpTarget references (%d): %s; pending %s" % [untagged.size(),
		", ".join(untagged), PENDING_IDS])
	TestFixtures.check(res, "10 every hint id outside the pending list has a HelpTarget in a scene and no pending id has one",
		untagged.is_empty() and pending_tagged.is_empty(), "untagged %s pending tagged %s" % [untagged, pending_tagged])
	TestFixtures.check(res, "10 every hint a scene links is a shipped id and the HUD tags are in place",
		unknown.is_empty() and tagged.size() >= HUD_TAGS, "tagged %d unknown %s" % [tagged.size(), unknown])


static func _scan_scenes(dir_path: String, tagged: Dictionary, helped: Dictionary, bases: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan_scenes(dir_path.path_join(sub), tagged, helped, bases)
	for file: String in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var scene: String = dir_path.path_join(file)
		var text: String = FileAccess.get_file_as_string(scene)
		if text.contains(HELP_SCRIPT):
			helped[scene] = true
		var base: String = _root_base(text)
		if not base.is_empty():
			bases[scene] = base
		var at: int = text.find(HINT_DIR_TAG)
		while at >= 0:
			var start: int = at + HINT_DIR_TAG.length()
			var stop: int = text.find(".tres", start)
			if stop > start:
				tagged[text.substr(start, stop - start)] = true
			at = text.find(HINT_DIR_TAG, start)


#The scene a .tscn extends: the path of the ext_resource its root node instances, or "".
static func _root_base(text: String) -> String:
	var head_at: int = text.find("[node ")
	if head_at < 0:
		return ""
	var head_end: int = text.find("\n", head_at)
	if head_end < 0:
		head_end = text.length()
	var head: String = text.substr(head_at, head_end - head_at)
	var id_at: int = head.find(ROOT_INSTANCE)
	if id_at < 0 or head.contains(" parent="):
		return ""
	id_at += ROOT_INSTANCE.length()
	var key: String = " id=\"%s\"" % head.substr(id_at, head.find("\"", id_at) - id_at)
	for line: String in text.split("\n"):
		if line.begins_with("[ext_resource") and line.contains(key):
			var path_at: int = line.find("path=\"") + 6
			return line.substr(path_at, line.find("\"", path_at) - path_at)
	return ""


static func _case_tier(res: Dictionary, host: Node, layer: MercdaveLayer) -> void:
	var tier: UpgradeTierDialog = (load(TIER_SCENE) as PackedScene).instantiate()
	host.add_child(tier)
	await TestFixtures.frames(host, 2)
	#The dialog's own hint (D4b tag) is read first so its scope opens on sys_none.
	Mercdave.show_hint(&"scene_TierPopup")
	Mercdave.ok()
	var sink: MercdaveScopeCases.WarnLog = MercdaveScopeCases.WarnLog.new()
	OS.add_logger(sink)
	tier.open_for("promotions")
	await MercdaveScopeCases.settle(host)
	if not Mercdave.card_open:
		Mercdave.toggle()
	await TestFixtures.frames(host, 3)
	OS.remove_logger(sink)
	var box: Rect2 = tier.get_global_rect()
	var at: Rect2 = layer.card.get_global_rect()
	TestFixtures.check(res, "4 UpgradeTierDialog open: the card docks 344 wide 16 px beside its box with no script error",
		GuiFrameStack.top() == tier and layer.card.visible and is_equal_approx(at.size.x, CardPlacement.DOCK_W)
			and not at.intersects(box) and sink.errors == 0
			and (is_equal_approx(at.position.x, box.end.x + 16.0) or is_equal_approx(at.end.x, box.position.x - 16.0)),
		"box %s card %s errors %d" % [box, at, sink.errors])
	var card: HintCard = layer.card
	TestFixtures.check(res, "13 sys_none card is titled Mercdave with Ok only",
		Mercdave.current == HintBook.SYS_NONE and card.title.text == HintCard.TITLE_NONE and card.ok.visible
			and not card.next_hint.visible and not card.tell_more.visible and not card.step.visible,
		"current %s title %s" % [Mercdave.current, card.title.text])
	tier.close()
	tier.queue_free()
	await MercdaveScopeCases.settle(host)


static func _case_buttons(res: Dictionary, host: Node, hud: GameHUD, layer: MercdaveLayer) -> void:
	Mercdave.reset_for_tests()
	var card: HintCard = layer.card
	var win: SubWindow = hud.popup()
	var content: Control = win.open(MercdaveScopeCases.probe(MercdaveScopeCases.PROBE_A)) as Control
	var ids: Array[StringName] = MercdaveScopeCases.fresh_ids(2)
	MercdaveScopeCases.target(content, ids[0], Rect2(40, 40, 120, 40))
	await MercdaveScopeCases.settle(host)
	Mercdave.toggle()
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "13 one mark: Next Hint hidden, step 1 of 1",
		Mercdave.current == ids[0] and card.visible and not card.next_hint.visible and card.step.text == "1 of 1",
		"current %s next %s step %s" % [Mercdave.current, card.next_hint.visible, card.step.text])
	MercdaveScopeCases.target(content, ids[1], Rect2(40, 120, 120, 40))
	var row: Dictionary = HintBook.row(ids[0])
	var had: bool = row.has("more")
	var kept: Variant = row.get("more", "")
	row["more"] = MORE_TEXT
	Mercdave.reset_for_tests()
	await MercdaveScopeCases.settle(host)
	Mercdave.show_hint(ids[0])
	await TestFixtures.frames(host, 2)
	var tell: Rect2 = card.tell_more.get_global_rect()
	var next: Rect2 = card.next_hint.get_global_rect()
	var ok: Rect2 = card.ok.get_global_rect()
	TestFixtures.check(res, "7 Ok sits right of Next Hint and Tell Me More by x extents",
		card.tell_more.visible and card.next_hint.visible and tell.end.x <= next.position.x + 0.5
			and next.end.x <= ok.position.x + 0.5 and card.step.text == "1 of 2",
		"tell %s next %s ok %s" % [tell, next, ok])
	#A second card: the layer sets its own card back to the width of the spot it picked on every resize.
	var docked: HintCard = (load(card.scene_file_path) as PackedScene).instantiate() as HintCard
	host.add_child(docked)
	docked.custom_minimum_size.x = CardPlacement.DOCK_W
	docked.reset_size()
	await TestFixtures.frames(host, 1)
	var row_min: float = (docked.ok.get_parent() as Control).get_combined_minimum_size().x
	TestFixtures.check(res, "4 a docked card with Tell Me More, Next Hint and Ok shown stays 344 wide",
		docked.tell_more.visible and docked.next_hint.visible and is_equal_approx(docked.size.x, CardPlacement.DOCK_W),
		"card %.2f wide, buttons row minimum %.2f" % [docked.size.x, row_min])
	docked.queue_free()
	card.tell_more.pressed.emit()
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "13 Tell Me More shows the more text and hides itself after the press",
		Mercdave.showing_more and not card.tell_more.visible and card.body.text == MORE_TEXT,
		"more %s visible %s" % [Mercdave.showing_more, card.tell_more.visible])
	if had:
		row["more"] = kept
	else:
		row.erase("more")
	await _case_hover(res, host, card)
	await _case_card_devil(res, host, card, ids[0])
	win.close()
	await MercdaveScopeCases.settle(host)


#Real pointer motion: the card body, then Ok, keeps the +5 face; a point off the card drops it.
static func _case_hover(res: Dictionary, host: Node, card: HintCard) -> void:
	var rect: Rect2 = card.get_global_rect()
	var off_at: Vector2 = Vector2(4, 4) if not rect.has_point(Vector2(4, 4)) else rect.end + Vector2(8, 8)
	await _move(host, off_at)
	await _move(host, rect.position + Vector2(MARGIN, MARGIN) * 0.5)
	var on_body: bool = card.face.hovered and card.face.level() == MercdaveFace.HOVER_FACE
	await _move(host, card.ok.get_global_rect().get_center())
	var on_ok: bool = card.face.hovered and card.face.level() == MercdaveFace.HOVER_FACE
	await _move(host, off_at)
	TestFixtures.check(res, "8 pointer over the card body then Ok shows the +5 face; moving off restores the hint face",
		on_body and on_ok and not card.face.hovered and card.face.level() == Mercdave.face_level(),
		"body %s ok %s after %s" % [on_body, on_ok, card.face.hovered])


static func _move(host: Node, at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	host.get_viewport().push_input(motion, true)
	await TestFixtures.frames(host, 1)


static func _case_card_devil(res: Dictionary, host: Node, card: HintCard, id: StringName) -> void:
	var hint: MercdaveHint = HintBook.hint(id)
	var kept: int = hint.face
	hint.face = DEVIL_FACE
	Mercdave.show_hint(id)
	await TestFixtures.frames(host, 2)
	var mat: ShaderMaterial = card.face.art.material as ShaderMaterial
	var devil_ok: bool = mat != null and mat.shader != null and mat.shader.resource_path == SHADER_PATH
	hint.face = 2
	Mercdave.show_hint(id)
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "15 the card face takes the DevilNoise material on a devil hint and drops it on face 2",
		devil_ok and card.face.art.material == null, "devil %s after %s" % [devil_ok, card.face.art.material])
	hint.face = kept


static func _case_bell(res: Dictionary, host: Node, hud: GameHUD, layer: MercdaveLayer) -> void:
	var bell: NotificationBell = hud.bell() as NotificationBell
	if bell == null:
		TestFixtures.check(res, "9 the HUD has a NotificationBell", false, "no bell")
		return
	bell.open_panel()
	await MercdaveScopeCases.settle(host)
	if not Mercdave.card_open:
		Mercdave.toggle()
	await TestFixtures.frames(host, 2)
	layer.card.global_position = Vector2(16, 300)
	var on_card: Vector2 = layer.card.get_global_rect().get_center()
	var away: Vector2 = Vector2(640, 600)
	var clear: bool = not bell.panel().get_global_rect().has_point(on_card)
	bell._input(_click(on_card))
	var kept: bool = bell.panel_open()
	Mercdave.close()
	await TestFixtures.frames(host, 1)
	clear = clear and not MercdaveLayer.has_point(away)
	bell._input(_click(away))
	TestFixtures.check(res, "9 a click on the card leaves the notification panel open; a click elsewhere closes it",
		clear and kept and not bell.panel_open(), "clear %s kept %s open %s" % [clear, kept, bell.panel_open()])
	bell.close_panel()
	await MercdaveScopeCases.settle(host)


static func _case_lock(res: Dictionary, host: Node, hud: GameHUD, layer: MercdaveLayer) -> void:
	var dialog: FeatureLockDialog = hud.open_lock_dialog(&"promotions")
	if dialog == null:
		TestFixtures.check(res, "11 the promotions FeatureLockDialog opens", false, "no dialog")
		return
	await MercdaveScopeCases.settle(host)
	if not Mercdave.card_open:
		Mercdave.toggle()
	await TestFixtures.frames(host, 3)
	var opened: bool = layer.card.visible
	var at: Vector2 = layer.card.ok.get_global_rect().get_center()
	host.get_viewport().push_input(_click(at), true)
	host.get_viewport().push_input(_click(at, false), true)
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "11 FeatureLockDialog open: clicking Ok closes the card and the dialog stays open",
		opened and not Mercdave.card_open and not layer.card.visible and dialog.visible,
		"opened %s card %s dialog %s" % [opened, Mercdave.card_open, dialog.visible])
	dialog.close()
	await MercdaveScopeCases.settle(host)


#The merc viewer's top-left CGN tile: the card opens beside it; moving the tile moves the card.
static func _case_viewer(res: Dictionary, host: Node, hud: GameHUD, layer: MercdaveLayer) -> void:
	var viewer: MercViewer = hud.open_viewer(&"mercs") as MercViewer
	if viewer == null:
		TestFixtures.check(res, "6 the mercs viewer opens", false, "no viewer")
		return
	viewer.select_tab(MercViewer.TAB_NAMES.find(&"overview"))
	await MercdaveScopeCases.settle(host)
	Mercdave.show_hint(&"scene_AttributeBox")
	await MercdaveScopeCases.settle(host)
	var tile: Control = layer.control_for(&"scene_AttributeBox")
	var band: Rect2 = CardPlacement.band(layer.get_viewport_rect().size)
	var target: Rect2 = tile.get_global_rect() if tile != null else Rect2()
	var card: Rect2 = layer.card.get_global_rect()
	TestFixtures.check(res, "6 a top-left viewer tile gets the card beside it, not in the far corner",
		tile != null and layer.card.visible and not card.intersects(target) and CardPlacement.gap(card, target) <= 40.0
			and band.encloses(card),
		"tile %s card %s candidates %s" % [target, card, _scores(layer, target, band)])
	TestFixtures.check(res, "6 the card keeps its anchor after the mark leaves",
		tile != null and Mercdave.current == &"scene_AttributeBox" and not Mercdave.marks.has(&"scene_AttributeBox")
			and layer.card.visible and not card.intersects(target) and CardPlacement.gap(card, target) <= 40.0,
		"current %s marks %d gap %.1f" % [Mercdave.current, Mercdave.marks.size(), CardPlacement.gap(card, target)])
	var was: Vector2 = layer.card.global_position
	var moved: Rect2 = Rect2()
	if tile != null:
		tile.position += Vector2(0, 200)
		await TestFixtures.frames(host, 2)
		moved = tile.get_global_rect()
	var now: Rect2 = layer.card.get_global_rect()
	TestFixtures.check(res, "6 the card re-places itself when the shown target moves",
		tile != null and not now.position.is_equal_approx(was) and not now.intersects(moved),
		"was %s now %s target %s" % [was, now, moved])
	if tile != null:
		tile.position -= Vector2(0, 200)
	Mercdave.close()
	hud.popup().close()
	await MercdaveScopeCases.settle(host)


#"name score gap" for every candidate CardPlacement.place weighs, with the marks and controls the layer passes.
static func _scores(layer: MercdaveLayer, target: Rect2, band: Rect2) -> String:
	var marks: Array[Rect2] = []
	for id: StringName in Mercdave.marks:
		var box: Control = layer.control_for(id)
		marks.append(box.get_global_rect() if box != null else Rect2())
	var current: int = Mercdave.marks.find(Mercdave.current)
	var shown: Control = layer.control_for(Mercdave.current)
	if current < 0 and shown != null:
		marks.append(shown.get_global_rect())
		current = marks.size() - 1
	var scope: Node = layer._root if is_instance_valid(layer._root) else layer.get_parent()
	var controls: Array[Rect2] = HintScope.control_rects(scope, layer)
	var card_h: float = layer.card.size.y
	var names: Array[String] = []
	var rects: Array[Rect2] = []
	var sides: Array[Rect2] = CardPlacement.beside(target, card_h, band) if target.has_area() else ([] as Array[Rect2])
	for rect: Rect2 in sides:
		names.append("beside%d%s" % [rects.size(), " heavy" if CardPlacement.heavy(rect, marks, current) else ""])
		rects.append(rect)
	for i: int in CardPlacement.SPOTS.size():
		names.append("spot%d" % i)
		rects.append(Rect2(CardPlacement.SPOTS[i], Vector2(CardPlacement.FREE_W, card_h)))
	var out: Array[String] = []
	for i: int in rects.size():
		out.append("%s %s %.2f %.2f" % [names[i], rects[i].position, CardPlacement.score(rects[i], marks, current,
			controls), CardPlacement.gap(rects[i], target) / CardPlacement.NEAR_UNIT])
	return "; ".join(out)


static func _click(at: Vector2, down: bool = true) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	click.position = at
	click.global_position = at
	return click
