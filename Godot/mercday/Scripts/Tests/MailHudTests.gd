class_name MailHudTests

#Mail stage M5: the HUD MailButton (dot, slot, open state), the request_open route and the delivery sound.

const SCREEN: Rect2 = Rect2(0, 0, 1280, 720)


static func run(res: Dictionary, host: Node) -> void:
	await _case_dot(res, host)
	await _case_slot(res, host)
	await _case_sound(res, host)
	await _case_spam(res, host)
	await _case_route(res, host)
	await _case_unpress(res, host)


static func _rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [GuiMailTests._cells("H1", "mercday"),
		GuiMailTests._cells("H2", "mercday", {"Folder": "News"}),
		GuiMailTests._cells("H3", "mercday", {"Folder": "Bills"}),
		GuiMailTests._cells("H4", "mercday", {"Folder": "Spam"})]
	return rows


static func _boot(host: Node) -> GameHUD:
	MailEffectsTests._boot_with(_rows())
	MailCenter._due.clear()
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	return hud


static func _done(hud: GameHUD, host: Node) -> void:
	hud.popup().close()
	hud.queue_free()
	await host.get_tree().process_frame


#Test 42.
static func _case_dot(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _boot(host)
	var btn: MailButton = hud.mail_button
	var empty_ok: bool = MailCenter.unread() == 0 and not btn.dot_visible()
	var first: MailInstance = MailCenter.deliver(&"H1")
	var live_ok: bool = MailCenter.unread() > 0 and btn.dot_visible()
	MailCenter.mark_read(first.id)
	var read_ok: bool = MailCenter.unread() == 0 and not btn.dot_visible()
	var second: MailInstance = MailCenter.deliver(&"H2")
	var second_ok: bool = btn.dot_visible()
	MailCenter.archive(second.id)
	var archived_ok: bool = MailCenter.unread() == 0 and not btn.dot_visible()
	TestFixtures.check(res, "mail button dot follows unread() > 0 through deliver, read and archive",
		empty_ok and live_ok and read_ok and second_ok and archived_ok,
		"empty %s live %s read %s second %s archived %s" % [empty_ok, live_ok, read_ok, second_ok, archived_ok])
	await _done(hud, host)


#Test 43.
static func _case_slot(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _boot(host)
	var mail_rect: Rect2 = hud.mail_button.get_global_rect()
	var bell_rect: Rect2 = hud.bell_slot.get_global_rect()
	var gear_rect: Rect2 = hud.settings_button.get_global_rect()
	var apart: bool = (not mail_rect.intersects(bell_rect) and not mail_rect.intersects(gear_rect)
		and not bell_rect.intersects(gear_rect))
	var inside: bool = SCREEN.encloses(mail_rect) and SCREEN.encloses(bell_rect) and SCREEN.encloses(gear_rect)
	var screen_ok: bool = hud.root.get_viewport_rect() == SCREEN
	var clear: bool = (not mail_rect.intersects(hud.menu_grid.get_global_rect())
		and not mail_rect.intersects(hud.description_label.get_global_rect())
		and not mail_rect.intersects(hud.bottom_bar.get_global_rect()))
	TestFixtures.check(res, "mail button sits left of the bell, 56 x 56, with no overlap at 1280 x 720",
		screen_ok and mail_rect.end.x <= bell_rect.position.x
			and absf(mail_rect.position.y - bell_rect.position.y) <= 1.0
			and mail_rect.size == Vector2(56, 56) and apart and inside and clear,
		"screen %s mail %s bell %s gear %s clear %s" % [hud.root.get_viewport_rect(), mail_rect, bell_rect, gear_rect,
			clear])
	TestFixtures.check(res, "mail button reads the mail glyph and the Mail tooltip",
		hud.mail_button.icon_rect.icon_id == "mail" and hud.mail_button.icon_rect.texture != null
			and hud.mail_button.tooltip_text == MailButton.MAIL_TIP,
		"id %s tip %s" % [hud.mail_button.icon_rect.icon_id, hud.mail_button.tooltip_text])
	await _done(hud, host)


#Test 44.
static func _case_sound(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _boot(host)
	await host.get_tree().process_frame
	var heard := SoundTests.PlayLog.new()
	AudioManager.played.connect(heard.record)
	MailCenter.deliver(&"H1")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	AudioManager.played.disconnect(heard.record)
	var cfg: SfxConfig = GameSfx.config
	var bus: String = AudioManager.bus_or_master(String(cfg.event_bus))
	var on_bus: bool = false
	for i: int in heard.size():
		if cfg.message_basic.sounds.has(heard.streams[i]):
			on_bus = heard.buses[i] == bus
	TestFixtures.check(res, "a delivered mail plays message_basic once on the event bus at the notice volume",
		heard.hits(cfg.message_basic) == 1 and on_bus
			and is_equal_approx(heard.volume_of(cfg.message_basic), GameSfx.NOTICE_DB),
		heard.text())
	await _done(hud, host)


#Card 735: spam arrives silent and never lights the HUD dot; a live non-spam row still does.
static func _case_spam(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _boot(host)
	await host.get_tree().process_frame
	var heard := SoundTests.PlayLog.new()
	AudioManager.played.connect(heard.record)
	var spam: MailInstance = MailCenter.deliver(&"H4")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	AudioManager.played.disconnect(heard.record)
	var hits: int = heard.hits(GameSfx.config.message_basic)
	var dark: bool = spam != null and spam.folder == &"spam" and not spam.read and not hud.mail_button.dot_visible()
	MailCenter.deliver(&"H1")
	var lit: bool = hud.mail_button.dot_visible()
	TestFixtures.check(res, "an unread Spam row plays no message_basic and leaves the dot off; an Inbox row lights it",
		hits == 0 and dark and lit, "hits %d dark %s lit %s" % [hits, dark, lit])
	await _done(hud, host)


#Test 45.
static func _case_route(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _boot(host)
	var news: MailInstance = MailCenter.deliver(&"H2")
	MailCenter.deliver(&"H1")
	MailCenter.request_open(news.id)
	await host.get_tree().process_frame
	var view: MailViewer = hud.popup().current() as MailViewer
	var row: MailRow = view.list.row_for(news.id) if view != null else null
	TestFixtures.check(res, "request_open(id) opens MailViewer on the mail's folder with its row selected and read",
		view != null and view.current_tab() == news.folder and view.selected_id() == news.id
			and row != null and row.selected and news.read and hud.mail_button.button_pressed,
		"view %s tab %s selected %s row %s read %s pressed %s" % [view != null,
			view.current_tab() if view != null else &"", view.selected_id() if view != null else &"",
			row != null and row.selected, news.read, hud.mail_button.button_pressed])
	var first_id: int = view.get_instance_id() if view != null else 0
	var bill: MailInstance = MailCenter.deliver(&"H3")
	MailCenter.archive(bill.id)
	MailCenter.request_open(bill.id)
	await host.get_tree().process_frame
	var again: MailViewer = hud.popup().current() as MailViewer
	TestFixtures.check(res, "request_open on an archived mail shows the archived list and keeps the button pressed",
		again != null and again.get_instance_id() != first_id and again.showing_archived()
			and again.selected_id() == bill.id and again.current_tab() == bill.folder and hud.mail_button.button_pressed,
		"view %s archived %s pressed %s" % [again != null, again.showing_archived() if again != null else false,
			hud.mail_button.button_pressed])
	await _done(hud, host)


#Test 52 and the other ways the Inbox leaves.
static func _case_unpress(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _boot(host)
	var btn: MailButton = hud.mail_button
	btn.button_pressed = true
	await host.get_tree().process_frame
	var opened: bool = (hud.popup().current() is MailViewer and btn.button_pressed
		and btn.icon_rect.tint == SettingsButton.GLYPH_ON)
	hud.open_viewer(&"finance")
	await host.get_tree().process_frame
	TestFixtures.check(res, "mail button is unpressed after open_viewer(&\"finance\") replaces the Inbox",
		opened and not btn.button_pressed and btn.icon_rect.tint == SettingsButton.GLYPH_IDLE
			and not (hud.popup().current() is MailViewer),
		"opened %s pressed %s tint %s" % [opened, btn.button_pressed, btn.icon_rect.tint])
	hud.open_mail()
	await host.get_tree().process_frame
	hud.popup().close()
	await host.get_tree().process_frame
	var closed_ok: bool = not btn.button_pressed
	btn.button_pressed = true
	await host.get_tree().process_frame
	btn.button_pressed = false
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the Inbox or toggling the mail button off unpresses it and closes the view",
		closed_ok and not btn.button_pressed and hud.popup().current() == null,
		"after close %s after toggle %s current %s" % [closed_ok, btn.button_pressed, hud.popup().current()])
	await _done(hud, host)
