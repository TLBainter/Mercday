class_name MainMenuToggleTests

#Escape toggle of the main menu grid. Run: the headless harness flag main-menu-toggle-tests.

const HUD_SCENE: String = "res://Scenes/GUI/HUD/GameHUD.tscn"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_toggle(res, host)
	await _case_frame_open(res, host)
	await _case_signal(res, host)
	await _case_null_paths(res, host)
	return TestFixtures.summarize(res, "MAIN MENU TOGGLE")


static func _boot(host: Node) -> GameHUD:
	GuiFrameStack.clear()
	var hud: GameHUD = (load(HUD_SCENE) as PackedScene).instantiate()
	hud.autostart = false
	host.add_child(hud)
	hud.wire_for_test()
	await host.get_tree().process_frame
	return hud


static func _esc(toggle: MainMenuToggle) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	toggle._unhandled_input(ev)


static func _case_toggle(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _boot(host)
	var toggle: MainMenuToggle = hud.get_node("Root/MainMenuToggle") as MainMenuToggle
	var grid: Control = hud.get_node("Root/MenuGrid") as Control
	var desc: Control = hud.get_node("Root/Description") as Control
	var map: MapView = hud.get_node("Root/MapView") as MapView
	TestFixtures.check(res, "the toggle node exists", toggle != null, "toggle %s" % toggle)
	TestFixtures.check(res, "the menu starts visible",
		toggle.is_menu_visible() and grid.visible and map.is_menu_open(),
		"state %s grid %s open %s" % [toggle.is_menu_visible(), grid.visible, map.is_menu_open()])
	_esc(toggle)
	TestFixtures.check(res, "ESC at depth 0 hides the grid and the description",
		not grid.visible and not desc.visible and not toggle.is_menu_visible(),
		"grid %s desc %s" % [grid.visible, desc.visible])
	TestFixtures.check(res, "ESC at depth 0 tells the map the menu is closed",
		not map.is_menu_open(), "open %s" % map.is_menu_open())
	if MapData.has_bake():
		TestFixtures.check(res, "the map is unlocked while the menu is hidden",
			not map.is_locked(), "locked %s" % map.is_locked())
	_esc(toggle)
	TestFixtures.check(res, "a second ESC shows the grid and the description",
		grid.visible and desc.visible and toggle.is_menu_visible() and map.is_menu_open(),
		"grid %s desc %s open %s" % [grid.visible, desc.visible, map.is_menu_open()])
	if MapData.has_bake():
		TestFixtures.check(res, "the map is locked while the menu is shown",
			map.is_locked(), "locked %s" % map.is_locked())
		TestFixtures.check(res, "the gate keeps rendering while only the menu is shown",
			not map.gate().is_locked(), "gate locked %s" % map.gate().is_locked())
	hud.queue_free()
	GuiFrameStack.clear()


static func _case_frame_open(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _boot(host)
	var toggle: MainMenuToggle = hud.get_node("Root/MainMenuToggle") as MainMenuToggle
	var map: MapView = hud.get_node("Root/MapView") as MapView
	var frame: Control = Control.new()
	host.add_child(frame)
	GuiFrameStack.push(frame)
	if MapData.has_bake():
		TestFixtures.check(res, "a frame locks input and the gate",
			map.is_locked() and map.gate().is_locked(),
			"locked %s gate %s" % [map.is_locked(), map.gate().is_locked()])
	_esc(toggle)
	TestFixtures.check(res, "ESC with a frame open does not toggle",
		toggle.is_menu_visible(), "visible %s" % toggle.is_menu_visible())
	GuiFrameStack.remove(frame)
	if MapData.has_bake():
		TestFixtures.check(res, "removing the frame frees the gate while the menu still locks input",
			not map.gate().is_locked() and map.is_locked(),
			"locked %s gate %s" % [map.is_locked(), map.gate().is_locked()])
	frame.queue_free()
	hud.queue_free()
	GuiFrameStack.clear()


static func _case_signal(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _boot(host)
	var toggle: MainMenuToggle = hud.get_node("Root/MainMenuToggle") as MainMenuToggle
	var seen: Array[bool] = []
	toggle.toggled.connect(func(v: bool) -> void: seen.append(v))
	_esc(toggle)
	_esc(toggle)
	toggle.set_menu_visible(true)
	TestFixtures.check(res, "toggled fires with the new value and not on a no-op",
		seen == [false, true], "seen %s" % [seen])
	hud.queue_free()
	GuiFrameStack.clear()


static func _case_null_paths(res: Dictionary, host: Node) -> void:
	var toggle: MainMenuToggle = MainMenuToggle.new()
	host.add_child(toggle)
	await host.get_tree().process_frame
	toggle.set_menu_visible(false)
	toggle.set_menu_visible(true)
	_esc(toggle)
	TestFixtures.check(res, "unset node paths do not crash and the state still flips",
		not toggle.is_menu_visible(), "visible %s" % toggle.is_menu_visible())
	toggle.queue_free()
	GuiFrameStack.clear()
