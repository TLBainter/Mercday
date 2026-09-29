class_name GuiClickJBTests
extends RefCounted

#Run: the headless harness flag gui-click-jb-tests, after the bare argument separator.
#Click-through of README Part J, steps 9 to 14: the Job Ads list, the End Campaign refund, View
#Applicants, the HUD bell and the unclaimed contract row, the results timeline of the seeded
#failure and the seeded success, and the settled row they leave behind. Every case drives the
#real screens through the helpers they expose, because a click never reaches a button headless.

const PROMO_SCENE: PackedScene = preload("res://Scenes/GUI/Promotions/PromotionsViewer.tscn")
const HUD_SCENE: String = "res://Scenes/GUI/HUD/GameHUD.tscn"
const BANK: int = 20000

#README J9: nine job ads, eight shown while Show Concluded is off, seven with Show Infinite off.
const JOB_TOTAL: int = 9
const SHOWN_DEFAULT: int = 8
const SHOWN_NO_INFINITE: int = 7
const TEXT_DEFAULT: String = "8 of 9 shown"
const TEXT_ALL: String = "9 of 9 shown"
const TEXT_NO_INFINITE: String = "7 of 9 shown"
const CONCLUDED_ID: int = 8
const INFINITE_IDS: Array[int] = [3, 9]
const FIXED_ID: int = 1
const WOM_ID: int = 7
const LABEL_ACTIVE: String = "Active"
const LABEL_CUSTOM: String = "Custom"
const RING_PLAIN: Color = Color("#3b6fb6")
const RING_CUSTOM: Color = Color("#f28c28")
const MUTED: Color = Color("#5e7699")
#How far a drawn pixel may stand from the tone it was painted in.
const TONE_SLACK: float = 0.01
const RING_DONE: Color = Color("#1f3560")
const CONCLUDED_TEXT: String = "Concluded"
const END_RED: Color = Color("#ff3b2f")
const END_HOVER: Color = Color("#ff6a55")
const END_OFFSET: int = 4
const SORT_KEYS: Array[StringName] = [&"start", &"left", &"success", &"method", &"cost"]
const SORT_LABELS: Array[String] = ["Start Date", "Time Remaining", "Success Rate",
	"Campaign Method", "Cost"]

#README I3: the End dialog wording and the toast.
const WOM_NOTE: String = "not refunded"
const END_CTA_PLAIN: String = "End Campaign"
const TOAST_TAIL: String = "notes refunded."

#README J11 and I4: campaign 1 sent one of the eight applicants.
const VIA_ID: int = 1
const VIA_TEXT: String = "1 of 8 applicants shown"
const APPLICANT_TOTAL: int = 8
const FROM_KEY: String = "from"

#README I2 and I5: both contract rows read one title and wear the alert mark.
const NOTICE_TITLE: String = "Contract Complete"
const TITLE_ORANGE: Color = Color("#f28c28")
const UNCLAIMED_TEXT: String = "Complete"
const FAILED_TEXT: String = "Failed"
const FAILED_COLOR: Color = Color("#e8583f")
const FAILED_DATE: String = "Failed on %s"
const UNCLAIMED_OPTION: String = "Unclaimed Results"
const FAILED_OPTION: String = "Failed"
const FAILED_FILTER_KEY: String = "show_failed"

#README J13 and I5: the seconds the step reads the panel at.
const T_BARS: float = 0.8
const T_FATES: float = 1.2
const T_VERDICT: float = 2.3
const T_SHRINK: float = 3.2
const T_DOCKED: float = 3.75
const T_XP: float = 6.0
const TICK: float = 0.01
const SLACK: float = 2.0

#README I5: the verdict, the fates and the money labels.
const FAILURE_TEXT: String = "FAILURE"
const SUCCESS_TEXT: String = "SUCCESS!"
const SUCCESS_COLOR: Color = Color("#6cc36a")
const RING_DEAD: Color = Color("#a83a28")
const RING_CAPTURED: Color = Color("#b8862a")
const FORFEIT_LABEL: String = "Reward (Forfeited)"
const COST_LABEL: String = "Total Cost"
const EARNED_LABEL: String = "Notes Earned"
const BLANK_XP: String = "-"
const FAIL_XP_PCT: int = 35
const BONUS_PCT: int = 10
const CONTINUE_BLUE: Color = Color("#2b4f8a")
const CONTINUE_GREEN: Color = Color("#6cc36a")
const FATE_ORDER: Array[int] = [ResultMemberData.Fate.ALIVE, ResultMemberData.Fate.DEAD,
	ResultMemberData.Fate.CAPTURED, ResultMemberData.Fate.ALIVE]

#GX4D-R07: Contract Viewer.dc.html line 829 (the pending glyph, ASCII as three dots) and line 390
#(the MVP ring and badge gold), read here instead of ResultsTimeline's own constants.
const PENDING_GLYPH: String = "..."
const MVP_GOLD: Color = Color("#f2d33d")


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_j09_counts(res, host)
	await _case_j09_sorts(res, host)
	await _case_j10_end(res, host)
	await _case_j11_applicants(res, host)
	await _case_j12_bell(res, host)
	await _case_j12_list(res, host)
	await _case_j13_failure(res, host)
	await _case_j13_success(res, host)
	await _case_j14_after(res, host)
	GuiFrameStack.clear()
	NotificationCenter.reset()
	BenefitsManager.reset()
	SubscriptionManager.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI CLICK JB")


#A new game with the seeded campaigns, the seeded applicants and a bank no price gate can trip.
static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	SubscriptionManager.set_entitlements(_full_ent())
	LegalManager.reset()
	PromotionsManager.reset()
	NotificationCenter.reset()
	BenefitsManager.reset()
	GameState.bank_notes = BANK


static func _full_ent() -> Dictionary:
	return {"promotions": true, "oddJobs": 2, "adDirect": true, "adRadio": true,
		"adSponsor": true, "maxPromoDays": 30, "jobPostings": true, "guildPromo": true}


static func _promo(host: Node) -> PromotionsViewer:
	var viewer: PromotionsViewer = PROMO_SCENE.instantiate() as PromotionsViewer
	host.add_child(viewer)
	return viewer


static func _hud(host: Node) -> GameHUD:
	var scene: PackedScene = load(HUD_SCENE)
	var hud: GameHUD = scene.instantiate() as GameHUD
	hud.autostart = false
	host.add_child(hud)
	hud.wire_for_test()
	return hud


static func _ring_of(viewer: PromotionsViewer) -> Color:
	var style: StyleBox = viewer.toolbar().filter_button.get_theme_stylebox(&"normal")
	var flat: StyleBoxFlat = style as StyleBoxFlat
	return Color.BLACK if flat == null else flat.border_color


static func _shown_ids(viewer: PromotionsViewer) -> Array[int]:
	var out: Array[int] = []
	var list_node: CampaignList = viewer.campaign_list()
	for i: int in list_node.card_count():
		var card: CampaignCard = list_node.card_at(i)
		if card != null:
			out.append(card.campaign_id())
	return out


#GX4D-R02: the value read straight off the campaign row for one sort key, the way the card would
#print it or a count taken straight from the row; never PromotionsManager.campaign_sort_value or
#campaigns_sorted, since those are the ordering code under test.
static func _row_sort_value(campaign: CampaignData, key: StringName, today: int) -> float:
	if campaign == null:
		return 0.0
	match key:
		&"left":
			return float(campaign.days_left(today))
		&"success":
			return float(PromotionsManager.results_of(campaign)) \
				/ float(maxi(1, campaign.run_days(today))) * 7.0
		&"method":
			return -float(CampaignTypeDefs.keys().find(campaign.type_key))
		&"cost":
			return float(campaign.total_committed(today))
	return float(campaign.day_started)


#True when the shown order agrees with the sort value read off the campaign row.
static func _ordered(ids: Array[int], key: StringName, ascending: bool) -> bool:
	var today: int = GameState.day()
	for i: int in range(1, ids.size()):
		var before: CampaignData = PromotionsManager.campaign_of(ids[i - 1])
		var after: CampaignData = PromotionsManager.campaign_of(ids[i])
		if before == null or after == null:
			return false
		var left: float = _row_sort_value(before, key, today)
		var right: float = _row_sort_value(after, key, today)
		if is_equal_approx(left, right):
			continue
		if ascending and left > right:
			return false
		if not ascending and left < right:
			return false
	return true


#True when every pair of campaigns that sort the same leaves the newer id in front.
static func _ties_newest_first(ids: Array[int], key: StringName) -> bool:
	var today: int = GameState.day()
	for i: int in range(1, ids.size()):
		var before: CampaignData = PromotionsManager.campaign_of(ids[i - 1])
		var after: CampaignData = PromotionsManager.campaign_of(ids[i])
		if before == null or after == null:
			return false
		var left: float = _row_sort_value(before, key, today)
		var right: float = _row_sort_value(after, key, today)
		if is_equal_approx(left, right) and before.id < after.id:
			return false
	return true


static func _same_set(left: Array[int], right: Array[int]) -> bool:
	if left.size() != right.size():
		return false
	for value: int in left:
		if not right.has(value):
			return false
	return true


static func _view_of(entry_id: int) -> ContractView:
	for view: ContractView in GameState.contracts:
		if view.entry_id == entry_id:
			return view
	return null


static func _row_of(list_node: ContractList, entry_id: int) -> ContractListItem:
	for i: int in list_node.row_count():
		var row: ContractListItem = list_node.row_at(i)
		if row != null and row.entry_id() == entry_id:
			return row
	return null


static func _face_of(card: NotificationItem) -> TextureRect:
	if card == null:
		return null
	var glyph: Control = card.icon_glyph()
	if glyph == null:
		return null
	return glyph.get_node_or_null("Face") as TextureRect


static func _fates_of(result: ContractResultData) -> Array[int]:
	var out: Array[int] = []
	for member: ResultMemberData in result.members:
		out.append(member.fate)
	return out


#The centre of the verdict box in the coordinates of the overlay it lives in.
static func _verdict_center(panel_node: ContractResults) -> Vector2:
	var box: VerdictBox = panel_node.verdict_box()
	return box.position + box.size / 2.0


static func _dock_rect(panel_node: ContractResults) -> Rect2:
	var slot: Control = panel_node.dock_slot
	var origin: Vector2 = slot.get_global_rect().position - panel_node.overlay.global_position
	return Rect2(origin, slot.size)


#The XP a living merc takes on this contract when nothing went wrong.
static func _full_xp(result: ContractResultData) -> int:
	var per: float = result.difficulty * float(GameState.RESULT_XP_PER_DIFF)
	return GameState.RESULT_XP_BASE + int(round(per))


#True when every drawn pixel of the texture carries the same tone in all three channels.
static func _is_grey(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var img: Image = tex.get_image()
	if img == null:
		return false
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			if absf(px.r - px.g) > TONE_SLACK or absf(px.g - px.b) > TONE_SLACK:
				return false
	return true


#README J9: "Job Ads: 8 of 9 shown; Show Concluded -> 9 (Campaign 8 grayed); Show Infinite off
#-> 7." The three counts stack: Show Concluded stays on while Show Infinite goes off.
static func _case_j09_counts(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: PromotionsViewer = _promo(host)
	await host.get_tree().process_frame
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	await host.get_tree().process_frame
	var list_node: CampaignList = viewer.campaign_list()
	TestFixtures.check(res, "J9 the Job Ads tab lists 8 of the 9 seeded campaigns",
		viewer.card_count() == SHOWN_DEFAULT, "cards %d" % viewer.card_count())
	TestFixtures.check(res, "J9 the header reads 8 of 9 shown",
		viewer.shown_text() == TEXT_DEFAULT, viewer.shown_text())
	TestFixtures.check(res, "J9 the concluded campaign is out of the default list",
		list_node.card_for(CONCLUDED_ID) == null, str(_shown_ids(viewer)))
	TestFixtures.check(res, "J9 the filter button reads Active at the defaults",
		viewer.toolbar().filter_text() == LABEL_ACTIVE, viewer.toolbar().filter_text())
	TestFixtures.check(res, "J9 the filter button wears the plain ring at the defaults",
		_ring_of(viewer).is_equal_approx(RING_PLAIN), str(_ring_of(viewer)))
	viewer.toolbar().press_row(true)
	await host.get_tree().process_frame
	TestFixtures.check(res, "J9 Show Concluded lifts the list to all nine campaigns",
		viewer.card_count() == JOB_TOTAL, "cards %d" % viewer.card_count())
	TestFixtures.check(res, "J9 the header reads 9 of 9 shown with Show Concluded on",
		viewer.shown_text() == TEXT_ALL, viewer.shown_text())
	TestFixtures.check(res, "J9 the filter button reads Custom once a filter is moved",
		viewer.toolbar().filter_text() == LABEL_CUSTOM, viewer.toolbar().filter_text())
	TestFixtures.check(res, "J9 the filter button wears the orange ring once a filter is moved",
		_ring_of(viewer).is_equal_approx(RING_CUSTOM), str(_ring_of(viewer)))
	var done_card: CampaignCard = list_node.card_for(CONCLUDED_ID)
	TestFixtures.check(res, "J9 Campaign 8 joins the list and reads as concluded",
		done_card != null and done_card.is_concluded(), "card %s" % str(done_card != null))
	if done_card != null:
		var tint: Color = done_card.name_label.get_theme_color(&"font_color")
		TestFixtures.check(res, "J9 the concluded card greys its campaign name",
			tint.is_equal_approx(MUTED), str(tint))
		var box: StyleBoxFlat = done_card.icon_box.get_theme_stylebox(&"panel") as StyleBoxFlat
		TestFixtures.check(res, "J9 the concluded card greys the ring around its icon",
			box != null and box.border_color.is_equal_approx(RING_DONE),
			"" if box == null else str(box.border_color))
		TestFixtures.check(res, "J9 the concluded card draws its method icon in grey",
			_is_grey(done_card.icon.texture), "grey %s" % str(_is_grey(done_card.icon.texture)))
		var live_card: CampaignCard = list_node.card_for(FIXED_ID)
		TestFixtures.check(res, "J9 a live card of the same method keeps a different icon",
			live_card != null and live_card.icon.texture != done_card.icon.texture,
			"live %s" % str(live_card != null))
		TestFixtures.check(res, "J9 the concluded card reads Concluded where the time stands",
			done_card.left_text() == CONCLUDED_TEXT, done_card.left_text())
		TestFixtures.check(res, "J9 the concluded card offers no End Campaign button",
			not done_card.has_end(), "end %s" % str(done_card.has_end()))
		TestFixtures.check(res, "J9 the concluded job ad still offers View Applicants",
			done_card.has_view(), "view %s" % str(done_card.has_view()))
	viewer.toolbar().press_row(false)
	await host.get_tree().process_frame
	TestFixtures.check(res, "J9 Show Infinite off leaves seven campaigns",
		viewer.card_count() == SHOWN_NO_INFINITE, "cards %d" % viewer.card_count())
	TestFixtures.check(res, "J9 the header reads 7 of 9 shown with Show Infinite off",
		viewer.shown_text() == TEXT_NO_INFINITE, viewer.shown_text())
	var kept: Array[int] = _shown_ids(viewer)
	TestFixtures.check(res, "J9 Show Infinite off drops both infinite campaigns",
		not kept.has(INFINITE_IDS[0]) and not kept.has(INFINITE_IDS[1]), str(kept))
	viewer.set_filter(AdsToolbar.DEFAULT_CONCLUDED, AdsToolbar.DEFAULT_INFINITE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "J9 the defaults come back to eight cards and the Active button",
		viewer.card_count() == SHOWN_DEFAULT and viewer.toolbar().filter_text() == LABEL_ACTIVE,
		"%d %s" % [viewer.card_count(), viewer.toolbar().filter_text()])
	GuiFrameStack.clear()
	viewer.queue_free()
	await host.get_tree().process_frame


#README J9: "Every sort works both directions." The order is read against the value the campaign
#row itself carries for that key (GX4D-R02), so the case never copies an order out of the code.
static func _case_j09_sorts(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: PromotionsViewer = _promo(host)
	await host.get_tree().process_frame
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	await host.get_tree().process_frame
	for i: int in SORT_KEYS.size():
		var key: StringName = SORT_KEYS[i]
		var caption: String = SORT_LABELS[i]
		viewer.pick_sort(key)
		await host.get_tree().process_frame
		var first_up: bool = viewer.toolbar().ascending()
		var first_ids: Array[int] = _shown_ids(viewer)
		viewer.toggle_direction()
		await host.get_tree().process_frame
		var second_up: bool = viewer.toolbar().ascending()
		var second_ids: Array[int] = _shown_ids(viewer)
		TestFixtures.check(res, "J9 the sort %s runs the cards one way" % caption,
			_ordered(first_ids, key, first_up), "%s %s" % [str(first_up), str(first_ids)])
		TestFixtures.check(res, "J9 the sort %s runs the cards the other way" % caption,
			second_up != first_up and _ordered(second_ids, key, second_up),
			"%s %s" % [str(second_up), str(second_ids)])
		TestFixtures.check(res, "J9 the sort %s keeps the same eight cards" % caption,
			_same_set(first_ids, second_ids) and first_ids.size() == SHOWN_DEFAULT,
			"%d %d" % [first_ids.size(), second_ids.size()])
		TestFixtures.check(res, "J9 the sort %s turns the list around" % caption,
			first_ids != second_ids, str(second_ids))
		TestFixtures.check(res, "J9 the sort %s gives a tie to the newer campaign" % caption,
			_ties_newest_first(first_ids, key) and _ties_newest_first(second_ids, key),
			"%s %s" % [str(first_ids), str(second_ids)])
		viewer.toggle_direction()
		await host.get_tree().process_frame
	#GX4D-R02: no seeded pair shares a start day, so one is forced here and undone after. FIXED_ID
	#takes WOM_ID's later start day (never WOM_ID taking the older one, which would run past its
	#own seeded days and drop it from the default list as concluded).
	var tie_a: CampaignData = PromotionsManager.campaign_of(FIXED_ID)
	var tie_b: CampaignData = PromotionsManager.campaign_of(WOM_ID)
	if tie_a != null and tie_b != null:
		var tie_a_started: int = tie_a.day_started
		var tie_b_started: int = tie_b.day_started
		tie_a.day_started = tie_b_started
		viewer.pick_sort(&"start")
		await host.get_tree().process_frame
		var tie_ids: Array[int] = _shown_ids(viewer)
		TestFixtures.check(res, "J9 a forced Start Date tie still gives it to the newer campaign",
			tie_ids.has(tie_a.id) and tie_ids.has(tie_b.id) and _ties_newest_first(tie_ids, &"start"),
			str(tie_ids))
		tie_a.day_started = tie_a_started
		tie_b.day_started = tie_b_started
	else:
		TestFixtures.check(res, "J9 setup: the Start Date tie campaigns exist",
			false, "%s %s" % [str(tie_a != null), str(tie_b != null)])
	GuiFrameStack.clear()
	viewer.queue_free()
	await host.get_tree().process_frame


#README J10: "End Campaign (underlined): refund = unused days; Word of Mouth no refund."
static func _case_j10_end(res: Dictionary, host: Node) -> void:
	_fresh()
	var viewer: PromotionsViewer = _promo(host)
	await host.get_tree().process_frame
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	await host.get_tree().process_frame
	var card: CampaignCard = viewer.campaign_list().card_for(FIXED_ID)
	TestFixtures.check(res, "J10 the live campaign card carries an End Campaign button",
		card != null and card.has_end(), "card %s" % str(card != null))
	if card == null:
		GuiFrameStack.clear()
		viewer.queue_free()
		await host.get_tree().process_frame
		return
	TestFixtures.check(res, "J10 End Campaign is a text button that is always underlined",
		card.end_button.underline == LinkButton.UNDERLINE_MODE_ALWAYS,
		"mode %d" % card.end_button.underline)
	var ink: Color = card.end_button.get_theme_color(&"font_color")
	var hot: Color = card.end_button.get_theme_color(&"font_hover_color")
	TestFixtures.check(res, "J10 End Campaign is written in red and brightens under the pointer",
		ink.is_equal_approx(END_RED) and hot.is_equal_approx(END_HOVER),
		"%s %s" % [str(ink), str(hot)])
	TestFixtures.check(res, "J10 the End Campaign underline stands clear of the caption",
		card.end_button.get_theme_constant(&"underline_spacing") == END_OFFSET,
		"gap %d" % card.end_button.get_theme_constant(&"underline_spacing"))
	#GX4D-R04: the name read off the card itself, before End removes it from the board.
	var card_name: String = card.name_label.text
	var campaign: CampaignData = PromotionsManager.campaign_of(FIXED_ID)
	var today: int = GameState.day()
	#GX4D-R01: the days left computed from the row's own days and start day, not
	#campaign.unused_days(), which is the code under test.
	var unused: int = maxi(0, campaign.days - maxi(0, today - campaign.day_started))
	var refund: int = campaign.budget_remaining(today)
	TestFixtures.check(res, "J10 the refund of a fixed campaign is its day price times the days left",
		refund == campaign.per_day * unused and unused > 0,
		"%d %d %d" % [refund, campaign.per_day, unused])
	viewer.press_end(FIXED_ID)
	await host.get_tree().process_frame
	var dlg: ConfirmDialog = viewer.confirm()
	TestFixtures.check(res, "J10 End Campaign asks before it stops the campaign",
		dlg != null and dlg.visible, "open %s" % str(dlg != null and dlg.visible))
	var title: String = "" if dlg == null else dlg.title_label.text
	TestFixtures.check(res, "J10 the question names the campaign it would end",
		title.contains(PromotionsManager.campaign_name(FIXED_ID)) and title.ends_with("?"), title)
	var body: String = "" if dlg == null else dlg.message_label.text
	var flat: String = body.replace(",", "")
	TestFixtures.check(res, "J10 the body names the refund and the unused days",
		flat.contains(str(refund)) and flat.contains("%d unused day" % unused), body)
	var labels: Array[String] = [] if dlg == null else dlg.button_labels()
	var cta: String = "" if labels.size() < 2 else labels[1]
	TestFixtures.check(res, "J10 the confirm button names the refund",
		cta.begins_with("End") and cta.replace(",", "").contains(str(refund)), cta)
	var bank: int = GameState.bank_notes
	var before: int = viewer.card_count()
	viewer.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "J10 the ended campaign leaves the list",
		viewer.campaign_list().card_for(FIXED_ID) == null and viewer.card_count() == before - 1,
		"cards %d" % viewer.card_count())
	TestFixtures.check(res, "J10 the bank rises by the refund",
		GameState.bank_notes == bank + refund, "%d %d" % [GameState.bank_notes, bank + refund])
	TestFixtures.check(res, "J10 the toast names the campaign and the notes it gave back",
		viewer.notice_shown() and viewer.notice_text().ends_with(TOAST_TAIL)
		and viewer.notice_text().contains(card_name)
		and viewer.notice_text().replace(",", "").contains(str(refund)), viewer.notice_text())
	var wom_preview: Dictionary = PromotionsManager.end_preview(WOM_ID)
	TestFixtures.check(res, "J10 a Word of Mouth campaign gives no refund",
		int(wom_preview.get("refund", -1)) == 0 and bool(wom_preview.get("crew_paid", false)),
		str(wom_preview))
	var wom_bank: int = GameState.bank_notes
	viewer.press_end(WOM_ID)
	await host.get_tree().process_frame
	var wom_body: String = "" if dlg == null else dlg.message_label.text
	TestFixtures.check(res, "J10 the Word of Mouth question says the merc pay is not refunded",
		wom_body.contains(WOM_NOTE), wom_body)
	var wom_labels: Array[String] = [] if dlg == null else dlg.button_labels()
	TestFixtures.check(res, "J10 the Word of Mouth confirm button names no amount",
		wom_labels.size() > 1 and wom_labels[1] == END_CTA_PLAIN, str(wom_labels))
	viewer.press_confirm()
	await host.get_tree().process_frame
	TestFixtures.check(res, "J10 ending a Word of Mouth campaign leaves the bank alone",
		GameState.bank_notes == wom_bank and viewer.campaign_list().card_for(WOM_ID) == null,
		"%d %d" % [GameState.bank_notes, wom_bank])
	TestFixtures.check(res, "J10 a campaign that already ran out cannot be ended",
		not bool(PromotionsManager.end_preview(CONCLUDED_ID).get("ok", true)),
		str(PromotionsManager.end_preview(CONCLUDED_ID)))
	#GX4D-R06: README line 494, the day price times the days left in the paid month, computed
	#from the seeded row's per_day and start day rather than campaign.unused_days().
	var infinite_campaign: CampaignData = PromotionsManager.campaign_of(INFINITE_IDS[0])
	var infinite_used: int = maxi(0, today - infinite_campaign.day_started)
	var infinite_left: int = CampaignTypeDefs.BILL_DAYS - infinite_used % CampaignTypeDefs.BILL_DAYS
	var infinite_refund: int = infinite_campaign.per_day * infinite_left
	var infinite: Dictionary = PromotionsManager.end_preview(INFINITE_IDS[0])
	var infinite_body: String = viewer.end_body(infinite)
	TestFixtures.check(res, "J10 an infinite campaign refunds the rest of the month it is paid for",
		infinite_body.contains(PromotionsViewer.MONTH_TAIL) and infinite_refund > 0
		and infinite_body.replace(",", "").contains(str(infinite_refund)),
		infinite_body)
	GuiFrameStack.clear()
	viewer.queue_free()
	await host.get_tree().process_frame


#README J11: "View Applicants -> Finance > Hiring filtered to that campaign."
static func _case_j11_applicants(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud: GameHUD = _hud(host)
	await host.get_tree().process_frame
	var promo: PromotionsViewer = hud.open_viewer(&"promotions") as PromotionsViewer
	await host.get_tree().process_frame
	TestFixtures.check(res, "J11 the HUD opens My Promotions", promo != null,
		"opened %s" % str(promo != null))
	if promo == null:
		hud.queue_free()
		await host.get_tree().process_frame
		return
	promo.open_tab(PromotionsViewer.JOB_KEY)
	await host.get_tree().process_frame
	promo.press_view(VIA_ID)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var finance: FinanceViewer = hud.popup().current() as FinanceViewer
	TestFixtures.check(res, "J11 View Applicants swaps the window over to My Finance",
		finance != null, "finance %s" % str(finance != null))
	if finance == null:
		hud.queue_free()
		await host.get_tree().process_frame
		return
	TestFixtures.check(res, "J11 My Finance comes up on the Hiring tab",
		finance.current_tab() == FinanceViewer.HIRING_KEY, str(finance.current_tab()))
	var hiring: HiringTab = finance.page(FinanceViewer.HIRING_KEY) as HiringTab
	await host.get_tree().process_frame
	TestFixtures.check(res, "J11 the Hiring page is built", hiring != null,
		"page %s" % str(hiring != null))
	if hiring == null:
		hud.queue_free()
		await host.get_tree().process_frame
		return
	var raw: Variant = hiring.filter_panel().value_of(FROM_KEY)
	var via: Array = []
	if raw is Array:
		via = raw
	TestFixtures.check(res, "J11 the Applied Via filter holds that campaign alone",
		via.size() == 1 and int(via[0]) == VIA_ID, str(via))
	TestFixtures.check(res, "J11 only the applicants of that campaign are listed",
		hiring.shown_count() == 1 and hiring.total_count() == APPLICANT_TOTAL,
		"%d %d" % [hiring.shown_count(), hiring.total_count()])
	TestFixtures.check(res, "J11 the header reads 1 of 8 applicants shown",
		hiring.count_text() == VIA_TEXT, hiring.count_text())
	var ids: Array[int] = hiring.card_ids()
	var listed: ApplicantData = null if ids.is_empty() else PromotionsManager.applicant_of(ids[0])
	TestFixtures.check(res, "J11 the one listed applicant came from that campaign",
		listed != null and listed.campaign_id == VIA_ID,
		"%s" % ("none" if listed == null else str(listed.campaign_id)))
	TestFixtures.check(res, "J11 the stored filter is handed over once",
		GameState.hire_filter.is_empty(), str(GameState.hire_filter))
	hud.popup().close()
	await host.get_tree().process_frame
	var again: FinanceViewer = hud.open_viewer(&"finance") as FinanceViewer
	await host.get_tree().process_frame
	if again != null:
		again.open_hiring()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var second: HiringTab = null
	if again != null:
		second = again.page(FinanceViewer.HIRING_KEY) as HiringTab
	var back: Variant = null if second == null else second.filter_panel().value_of(FROM_KEY)
	var back_via: Array = []
	if back is Array:
		back_via = back
	TestFixtures.check(res, "J11 a second visit to Hiring opens with no campaign filter",
		second != null and back_via.is_empty(), str(back_via))
	TestFixtures.check(res, "J11 a second visit to Hiring lists every applicant again",
		second != null and second.shown_count() == APPLICANT_TOTAL,
		"%d" % (0 if second == null else second.shown_count()))
	GuiFrameStack.clear()
	hud.queue_free()
	await host.get_tree().process_frame


#README J12: "HUD bell: both contract notifications read "Contract Complete" with "!"."
static func _case_j12_bell(res: Dictionary, host: Node) -> void:
	_fresh()
	var ids: Array[int] = GameState.seed_results_preview()
	TestFixtures.check(res, "J12 the game seeds one finished contract and one failed one",
		ids.size() == 2 and GameState.has_result(ids[0]) and GameState.has_result(ids[1]),
		str(ids))
	if ids.size() != 2:
		return
	var hud: GameHUD = _hud(host)
	await host.get_tree().process_frame
	var bell: NotificationBell = hud.bell() as NotificationBell
	TestFixtures.check(res, "J12 the HUD carries a notification bell", bell != null,
		"bell %s" % str(bell != null))
	if bell == null:
		hud.queue_free()
		await host.get_tree().process_frame
		return
	var won: NotificationData = NotificationCenter.latest(NotificationData.TYPE_CONTRACT_COMPLETED,
		ids[0])
	var lost: NotificationData = NotificationCenter.latest(NotificationData.TYPE_CONTRACT_FAILED,
		ids[1])
	TestFixtures.check(res, "J12 both finished contracts leave a row in the bell",
		won != null and lost != null, "%s %s" % [str(won != null), str(lost != null)])
	if won == null or lost == null:
		hud.queue_free()
		await host.get_tree().process_frame
		return
	bell.open_panel()
	await host.get_tree().process_frame
	TestFixtures.check(res, "J12 the bell opens its panel", bell.panel_open(),
		"open %s" % str(bell.panel_open()))
	var rows: Array[NotificationItem] = []
	var won_card: NotificationItem = bell.panel().card_for(won.id)
	var lost_card: NotificationItem = bell.panel().card_for(lost.id)
	if won_card != null:
		rows.append(won_card)
	if lost_card != null:
		rows.append(lost_card)
	TestFixtures.check(res, "J12 both rows are drawn in the panel", rows.size() == 2,
		"cards %d" % rows.size())
	TestFixtures.check(res, "J12 both rows read Contract Complete",
		won.title_text() == NOTICE_TITLE and lost.title_text() == NOTICE_TITLE,
		"%s %s" % [won.title_text(), lost.title_text()])
	for card: NotificationItem in rows:
		var label: Label = card.get_node(card.title_label_path) as Label
		var tint: Color = Color.BLACK if label == null else label.get_theme_color(&"font_color")
		TestFixtures.check(res, "J12 the row titled %s is written in orange" % card.name,
			label != null and label.text == NOTICE_TITLE and tint.is_equal_approx(TITLE_ORANGE),
			"%s %s" % ["" if label == null else label.text, str(tint)])
		var face: TextureRect = _face_of(card)
		var want: Texture2D = Icons.baked("alert", NotificationItem.MARK_SCALE, Icons.MODE_PLAIN)
		var art: String = "none" if face == null or face.texture == null \
			else str(face.texture.get_size())
		TestFixtures.check(res, "J12 the row titled %s wears the alert mark" % card.name,
			face != null and face.texture == want, art)
	TestFixtures.check(res, "J12 both rows carry the same informational urgency",
		won.urgency == lost.urgency and won.urgency == NotificationData.Urgency.INFORMATIONAL,
		"%d %d" % [won.urgency, lost.urgency])
	var won_kind: String = NotificationData.kind_for(won.type)
	var lost_kind: String = NotificationData.kind_for(lost.type)
	TestFixtures.check(res, "J12 both rows are filed under the same notification kind",
		won_kind == lost_kind and won_kind == "Contract", "%s %s" % [won_kind, lost_kind])
	var unread: int = NotificationCenter.unread_count()
	bell.press_item(lost.id)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var viewer: ContractViewer = hud.popup().current() as ContractViewer
	TestFixtures.check(res, "J12 pressing a row opens the Contract Viewer", viewer != null,
		"viewer %s" % str(viewer != null))
	var shown: ContractResults = null
	if viewer != null:
		shown = viewer.window().current() as ContractResults
	var told: ContractResultData = null if shown == null else shown.result()
	TestFixtures.check(res, "J12 pressing a row brings up the results of that contract",
		told != null and told.entry_id == ids[1],
		"%d" % (-1 if told == null else told.entry_id))
	TestFixtures.check(res, "J12 the Contract Viewer stays on the contract the row names",
		viewer != null and viewer.selected_id == ids[1],
		"%d" % (0 if viewer == null else viewer.selected_id))
	TestFixtures.check(res, "J12 the row that was pressed counts as read",
		NotificationCenter.unread_count() == unread - 1,
		"%d %d" % [NotificationCenter.unread_count(), unread])
	GuiFrameStack.clear()
	hud.queue_free()
	await host.get_tree().process_frame
	#GX4D-R05: pressing the completed row opens its own results too, from a fresh bell panel.
	var hud2: GameHUD = _hud(host)
	await host.get_tree().process_frame
	var bell2: NotificationBell = hud2.bell() as NotificationBell
	TestFixtures.check(res, "J12 a fresh bell panel still carries the completed contract's row",
		bell2 != null, "bell %s" % str(bell2 != null))
	if bell2 == null:
		hud2.queue_free()
		await host.get_tree().process_frame
		return
	bell2.open_panel()
	await host.get_tree().process_frame
	var won_unread: int = NotificationCenter.unread_count()
	bell2.press_item(won.id)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var viewer2: ContractViewer = hud2.popup().current() as ContractViewer
	TestFixtures.check(res, "J12 pressing the completed row opens the Contract Viewer",
		viewer2 != null, "viewer %s" % str(viewer2 != null))
	var shown2: ContractResults = null
	if viewer2 != null:
		shown2 = viewer2.window().current() as ContractResults
	var told2: ContractResultData = null if shown2 == null else shown2.result()
	TestFixtures.check(res, "J12 pressing the completed row brings up its own results",
		told2 != null and told2.entry_id == ids[0],
		"%d" % (-1 if told2 == null else told2.entry_id))
	TestFixtures.check(res, "J12 the Contract Viewer stays on the completed contract",
		viewer2 != null and viewer2.selected_id == ids[0],
		"%d" % (0 if viewer2 == null else viewer2.selected_id))
	TestFixtures.check(res, "J12 the completed row that was pressed counts as read",
		NotificationCenter.unread_count() == won_unread - 1,
		"%d %d" % [NotificationCenter.unread_count(), won_unread])
	GuiFrameStack.clear()
	hud2.queue_free()
	await host.get_tree().process_frame


#README J12: "Contract list: unclaimed shows "Complete" + "!", no tooltip." README I5 adds that
#it appears only under "Unclaimed Results".
static func _case_j12_list(res: Dictionary, host: Node) -> void:
	_fresh()
	var ids: Array[int] = GameState.seed_results_preview()
	if ids.size() != 2:
		TestFixtures.check(res, "J12 the game seeds the two finished contracts", false, str(ids))
		return
	var hud: GameHUD = _hud(host)
	await host.get_tree().process_frame
	var viewer: ContractViewer = hud.open_viewer(&"contracts") as ContractViewer
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var view: ContractView = _view_of(ids[1])
	TestFixtures.check(res, "J12 the failed contract is on the board and still unclaimed",
		viewer != null and view != null and view.is_unclaimed(),
		"%s" % str(view != null and view.is_unclaimed()))
	if viewer == null or view == null:
		hud.queue_free()
		await host.get_tree().process_frame
		return
	TestFixtures.check(res, "J12 an unclaimed result reads Complete and gives nothing away",
		view.shown_status_text() == UNCLAIMED_TEXT, view.shown_status_text())
	TestFixtures.check(res, "J12 an unclaimed result is written in orange",
		view.shown_status_color().is_equal_approx(TITLE_ORANGE), str(view.shown_status_color()))
	TestFixtures.check(res, "J12 an unclaimed result wears the bang mark",
		view.shown_mark() == StatusMark.Mark.BANG, "%d" % view.shown_mark())
	var row: ContractListItem = _row_of(viewer.list(), ids[1])
	TestFixtures.check(res, "J12 the unclaimed row stands in the list by default",
		row != null, "row %s" % str(row != null))
	if row != null:
		TestFixtures.check(res, "J12 the list row reads Complete in orange",
			row.strip_text() == UNCLAIMED_TEXT and row.strip_color().is_equal_approx(TITLE_ORANGE),
			"%s %s" % [row.strip_text(), str(row.strip_color())])
		TestFixtures.check(res, "J12 the list row wears the bang mark",
			row.mark.kind == StatusMark.Mark.BANG, "%d" % row.mark.kind)
		TestFixtures.check(res, "J12 the unclaimed row is not greyed out like a settled one",
			row.modulate.is_equal_approx(Color.WHITE), str(row.modulate))
	TestFixtures.check(res, "J12 an unclaimed result is filed under Unclaimed Results",
		ContractList.filter_key(view) == ContractList.UNCLAIMED_KEY, ContractList.filter_key(view))
	var panel_row: FilterCheckRow = viewer.list().filter_panel.row_of(ContractList.UNCLAIMED_KEY)
	TestFixtures.check(res, "J12 the filter option of that key reads Unclaimed Results",
		panel_row != null and panel_row.label == UNCLAIMED_OPTION,
		"" if panel_row == null else panel_row.label)
	var rules: Dictionary = viewer.list().filter_panel.filter().duplicate(true)
	rules[ContractList.UNCLAIMED_KEY] = false
	rules["show_completed"] = true
	rules[FAILED_FILTER_KEY] = true
	var without: Array[ContractView] = ContractList.filtered(GameState.contracts, rules)
	TestFixtures.check(res, "J12 an unclaimed result stays out of Completed and Failed",
		not without.has(view), "listed %d" % without.size())
	viewer.detail().set_view(view)
	await host.get_tree().process_frame
	viewer.detail().reward_label.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "J12 an unclaimed result shows no pay tooltip on its reward",
		not viewer.detail().payout_tooltip().visible,
		"shown %s" % str(viewer.detail().payout_tooltip().visible))
	TestFixtures.check(res, "J12 the detail of an unclaimed result wears the bang mark too",
		viewer.detail().status_mark().kind == StatusMark.Mark.BANG,
		"%d" % viewer.detail().status_mark().kind)
	GuiFrameStack.clear()
	hud.queue_free()
	await host.get_tree().process_frame


#Only the sign and the digits of a money label, so a case never copies the money format.
static func _digits(text: String) -> String:
	var out: String = ""
	for ch: String in text:
		if ch == "-" or (ch >= "0" and ch <= "9"):
			out += ch
	return out


#Opens the results of one seeded contract through the HUD and hands the panel back.
static func _open_results(host: Node, hud: GameHUD, entry_id: int) -> ContractResults:
	var viewer: ContractViewer = hud.open_viewer(&"contracts") as ContractViewer
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if viewer == null:
		return null
	viewer.select_entry(entry_id)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return viewer.window().current() as ContractResults


#README J13: "Open Contract 15: bars -> fates (skull, bars) -> FAILURE slams, shrinks, docks
#above "Contract Complete" -> XP -> Total Cost -168 -> notes leave HUD money -> Continue enables."
static func _case_j13_failure(res: Dictionary, host: Node) -> void:
	_fresh()
	var ids: Array[int] = GameState.seed_results_preview()
	if ids.size() != 2:
		TestFixtures.check(res, "J13 the game seeds the failed contract", false, str(ids))
		return
	var hud: GameHUD = _hud(host)
	await host.get_tree().process_frame
	var panel: ContractResults = await _open_results(host, hud, ids[1])
	var result: ContractResultData = GameState.result_of(ids[1])
	TestFixtures.check(res, "J13 opening the failed contract brings its results up",
		panel != null and result != null and result.failed,
		"%s" % str(panel != null and result != null))
	if panel == null or result == null:
		GuiFrameStack.clear()
		hud.queue_free()
		await host.get_tree().process_frame
		return
	TestFixtures.check(res, "J13 the results panel is laid out", panel.overlay.size.x > 0.0,
		str(panel.overlay.size))
	TestFixtures.check(res, "J13 the failed contract sent four mercs out",
		result.members.size() == 4, "members %d" % result.members.size())
	panel.set_time(0.0)
	TestFixtures.check(res, "J13 the title gives nothing away before the verdict",
		panel.title_label.text == NOTICE_TITLE and panel.title_color().is_equal_approx(TITLE_ORANGE),
		"%s %s" % [panel.title_label.text, str(panel.title_color())])
	TestFixtures.check(res, "J13 Continue is dead until the tally ends",
		not panel.continue_ready(), "ready %s" % str(panel.continue_ready()))
	panel.set_time(T_BARS)
	var first: ResultRow = panel.row_of(0)
	var dead: ResultRow = panel.row_of(1)
	TestFixtures.check(res, "J13 the panel draws one row per merc",
		panel.rows().size() == result.members.size(), "rows %d" % panel.rows().size())
	TestFixtures.check(res, "J13 the bars are still draining while the fates are held back",
		dead != null and dead.bar_fill("HP") > 0.0 and dead.bar_fill("HP") < 1.0,
		"%f" % (0.0 if dead == null else dead.bar_fill("HP")))
	TestFixtures.check(res, "J13 no fate is told while the bars run",
		first != null and first.status_text() == PENDING_GLYPH
		and not first.overlay_shown(), "" if first == null else first.status_text())
	TestFixtures.check(res, "J13 the verdict is off screen while the bars run",
		not panel.verdict_box().visible, "shown %s" % str(panel.verdict_box().visible))
	panel.set_time(T_FATES + TICK)
	TestFixtures.check(res, "J13 the crew comes back alive, deceased, captured and alive",
		_fates_of(result) == FATE_ORDER, str(_fates_of(result)))
	for i: int in result.members.size():
		var row: ResultRow = panel.row_of(i)
		var member: ResultMemberData = result.members[i]
		TestFixtures.check(res, "J13 row %d reads the fate of its merc" % i,
			row != null and row.status_text() == member.fate_name(),
			"" if row == null else row.status_text())
		TestFixtures.check(res, "J13 row %d marks a merc that did not walk away" % i,
			row != null and row.overlay_shown() == (member.fate != ResultMemberData.Fate.ALIVE),
			"overlay %s" % str(row != null and row.overlay_shown()))
	TestFixtures.check(res, "J13 the deceased merc is ringed in red",
		dead != null and dead.ring_color().is_equal_approx(RING_DEAD),
		"" if dead == null else str(dead.ring_color()))
	var taken: ResultRow = panel.row_of(2)
	TestFixtures.check(res, "J13 the captured merc is ringed in amber",
		taken != null and taken.ring_color().is_equal_approx(RING_CAPTURED),
		"" if taken == null else str(taken.ring_color()))
	TestFixtures.check(res, "J13 the verdict still waits while the fates are read",
		not panel.verdict_box().visible, "shown %s" % str(panel.verdict_box().visible))
	panel.set_time(T_VERDICT - TICK)
	TestFixtures.check(res, "J13 the verdict holds off until its moment",
		not panel.verdict_box().visible, "shown %s" % str(panel.verdict_box().visible))
	panel.set_time(T_VERDICT + TICK)
	var box: VerdictBox = panel.verdict_box()
	TestFixtures.check(res, "J13 the verdict slams in and reads FAILURE",
		box.visible and box.modulate.a > 0.0 and box.verdict_text() == FAILURE_TEXT,
		"%s %f" % [box.verdict_text(), box.modulate.a])
	TestFixtures.check(res, "J13 the verdict is written in the failure red",
		box.verdict_color().is_equal_approx(FAILED_COLOR), str(box.verdict_color()))
	var middle: Vector2 = panel.overlay.size / 2.0
	TestFixtures.check(res, "J13 the verdict lands in the middle of the panel",
		_verdict_center(panel).distance_to(middle) <= SLACK,
		"%s %s" % [str(_verdict_center(panel)), str(middle)])
	var big: float = box.scale.x
	panel.set_time(T_SHRINK)
	TestFixtures.check(res, "J13 the verdict shrinks before it leaves the middle",
		box.scale.x < big and _verdict_center(panel).distance_to(middle) <= SLACK,
		"%f %f" % [box.scale.x, big])
	TestFixtures.check(res, "J13 the forfeited reward is named once the verdict is told",
		panel.notes().reward_label_text() == FORFEIT_LABEL, panel.notes().reward_label_text())
	panel.set_time(T_DOCKED)
	var dock: Rect2 = _dock_rect(panel)
	var center: Vector2 = _verdict_center(panel)
	TestFixtures.check(res, "J13 the verdict docks in the slot of the header",
		absf(center.y - dock.get_center().y) <= SLACK
		and absf(center.x - box.size.x * box.scale.x / 2.0 - dock.position.x) <= SLACK,
		"%s %s" % [str(center), str(dock)])
	TestFixtures.check(res, "J13 the dock slot stands above the words Contract Complete",
		panel.dock_slot.get_global_rect().end.y
		<= panel.title_label.get_global_rect().position.y + SLACK,
		"%f %f" % [panel.dock_slot.get_global_rect().end.y,
		panel.title_label.get_global_rect().position.y])
	TestFixtures.check(res, "J13 the title takes the failure red once the verdict docks",
		panel.title_color().is_equal_approx(FAILED_COLOR), str(panel.title_color()))
	panel.set_time(T_XP)
	var full: int = _full_xp(result)
	var owed: int = int(round(float(full) * float(FAIL_XP_PCT) / 100.0))
	for i: int in result.members.size():
		var row: ResultRow = panel.row_of(i)
		var member: ResultMemberData = result.members[i]
		if member.alive():
			TestFixtures.check(res, "J13 the merc of row %d takes the failure share of XP" % i,
				member.xp_gained == owed and owed > 0 and owed < full,
				"%d %d %d" % [member.xp_gained, owed, full])
			TestFixtures.check(res, "J13 row %d shows the XP it gained" % i,
				row != null and row.xp_text() == "+%d XP" % member.xp_gained,
				"" if row == null else row.xp_text())
		else:
			TestFixtures.check(res, "J13 the merc of row %d takes no XP at all" % i,
				member.xp_gained == 0, "%d" % member.xp_gained)
			TestFixtures.check(res, "J13 row %d leaves the XP column blank" % i,
				row != null and row.xp_text() == BLANK_XP,
				"" if row == null else row.xp_text())
	panel.set_time(ResultsTimeline.NET_END)
	TestFixtures.check(res, "J13 the reward of a failed contract counts nothing",
		_digits(panel.notes().reward_text()) == "0", panel.notes().reward_text())
	TestFixtures.check(res, "J13 the tally is named Total Cost on a failure",
		panel.notes().net_label_text() == COST_LABEL, panel.notes().net_label_text())
	TestFixtures.check(res, "J13 the total cost is the expenses, owed and not earned",
		_digits(panel.notes().net_text()) == "-%d" % result.expenses and result.expenses > 0,
		"%s %d" % [panel.notes().net_text(), result.expenses])
	TestFixtures.check(res, "J13 the total cost is written in the failure red",
		panel.notes().net_color().is_equal_approx(FAILED_COLOR), str(panel.notes().net_color()))
	TestFixtures.check(res, "J13 a failed contract pays no merc bonus",
		not panel.notes().bonus_shown() and result.bonus() == 0, "%d" % result.bonus())
	#GX4D-R03: README line 539 and DATA_DELTA.md line 242, no MVP on a failure.
	var fail_badges: int = 0
	var fail_gold_rings: int = 0
	for i: int in result.members.size():
		var row: ResultRow = panel.row_of(i)
		if row == null:
			continue
		if row.mvp_shown():
			fail_badges += 1
		if row.ring_color().is_equal_approx(MVP_GOLD):
			fail_gold_rings += 1
	TestFixtures.check(res, "J13 a failed contract crowns no MVP",
		fail_badges == 0, "badges %d" % fail_badges)
	TestFixtures.check(res, "J13 no row of a failed contract wears the gold MVP ring",
		fail_gold_rings == 0, "gold %d" % fail_gold_rings)
	panel.set_time(ResultsTimeline.end_time(result))
	await host.get_tree().process_frame
	var fly: MoneyFly = hud.money_fly()
	TestFixtures.check(res, "J13 the notes leave the HUD money counter",
		fly != null and fly.is_flying() and fly.amount() == -result.expenses,
		"%d" % (0 if fly == null else fly.amount()))
	var counter: MoneyMenu = null if fly == null else fly.counter()
	TestFixtures.check(res, "J13 the money counter turns to the losing red",
		counter != null and counter.tint().is_equal_approx(FAILED_COLOR),
		"" if counter == null else str(counter.tint()))
	TestFixtures.check(res, "J13 Continue is still dead while the notes fly",
		not panel.continue_ready(), "ready %s" % str(panel.continue_ready()))
	panel.set_time(ResultsTimeline.total_time(result))
	TestFixtures.check(res, "J13 Continue wakes up at the end of the tally",
		panel.continue_ready() and panel.is_finished(), "ready %s" % str(panel.continue_ready()))
	var style: Color = panel.continue_style()
	TestFixtures.check(res, "J13 Continue is the shared BevelButton scene, blue after a failure",
		panel.continue_button is BevelButton and style.is_equal_approx(CONTINUE_BLUE),
		str(style))
	GuiFrameStack.clear()
	hud.queue_free()
	await host.get_tree().process_frame


#README J13: "Open Contract 12: same with SUCCESS!, MVP, bonus payout."
static func _case_j13_success(res: Dictionary, host: Node) -> void:
	_fresh()
	BenefitsManager.set_benefit("contract", BONUS_PCT)
	var ids: Array[int] = GameState.seed_results_preview()
	if ids.size() != 2:
		TestFixtures.check(res, "J13 the game seeds the finished contract", false, str(ids))
		BenefitsManager.reset()
		return
	var hud: GameHUD = _hud(host)
	await host.get_tree().process_frame
	var panel: ContractResults = await _open_results(host, hud, ids[0])
	var result: ContractResultData = GameState.result_of(ids[0])
	TestFixtures.check(res, "J13 opening the finished contract brings its results up",
		panel != null and result != null and not result.failed,
		"%s" % str(panel != null and result != null))
	if panel == null or result == null:
		GuiFrameStack.clear()
		hud.queue_free()
		BenefitsManager.reset()
		await host.get_tree().process_frame
		return
	panel.set_time(T_FATES + TICK)
	var lost: int = 0
	for member: ResultMemberData in result.members:
		if not member.alive():
			lost += 1
	TestFixtures.check(res, "J13 the crew of the finished contract all came home",
		lost == 0, "lost %d" % lost)
	panel.set_time(T_VERDICT + TICK)
	var box: VerdictBox = panel.verdict_box()
	TestFixtures.check(res, "J13 the verdict of the finished contract reads SUCCESS",
		box.visible and box.verdict_text() == SUCCESS_TEXT, box.verdict_text())
	TestFixtures.check(res, "J13 the winning verdict is written in green",
		box.verdict_color().is_equal_approx(SUCCESS_COLOR), str(box.verdict_color()))
	panel.set_time(ResultsTimeline.TOLD + TICK)
	var badges: int = 0
	var gold: int = 0
	for i: int in result.members.size():
		var row: ResultRow = panel.row_of(i)
		if row == null:
			continue
		if row.mvp_shown():
			badges += 1
		if row.ring_color().is_equal_approx(MVP_GOLD):
			gold += 1
	TestFixtures.check(res, "J13 one merc of the winning crew wears the MVP badge",
		badges == 1, "badges %d" % badges)
	TestFixtures.check(res, "J13 the MVP is the merc ringed in gold", gold == 1, "gold %d" % gold)
	panel.set_time(ResultsTimeline.total_time(result))
	TestFixtures.check(res, "J13 a won contract pays its mercs a bonus",
		result.bonus() > 0 and result.bonus_pct == BONUS_PCT,
		"%d %d" % [result.bonus(), result.bonus_pct])
	TestFixtures.check(res, "J13 the bonus payout shows in the money box",
		panel.notes().bonus_shown()
		and _digits(panel.notes().bonus_text()) == "-%d" % result.bonus(),
		panel.notes().bonus_text())
	TestFixtures.check(res, "J13 the tally of a won contract is named Notes Earned",
		panel.notes().net_label_text() == EARNED_LABEL, panel.notes().net_label_text())
	TestFixtures.check(res, "J13 the notes earned are the reward less the expenses and the bonus",
		_digits(panel.notes().net_text()) == str(result.guild_share()) and result.guild_share() > 0,
		"%s %d" % [panel.notes().net_text(), result.guild_share()])
	TestFixtures.check(res, "J13 the notes earned are written in green",
		panel.notes().net_color().is_equal_approx(SUCCESS_COLOR), str(panel.notes().net_color()))
	var fly: MoneyFly = hud.money_fly()
	TestFixtures.check(res, "J13 the guild share flies into the HUD money counter",
		fly != null and fly.amount() == result.guild_share(),
		"%d" % (0 if fly == null else fly.amount()))
	var style: Color = panel.continue_style()
	TestFixtures.check(res, "J13 Continue is the shared BevelButton scene, green after a win",
		panel.continue_ready() and panel.continue_button is BevelButton
		and style.is_equal_approx(CONTINUE_GREEN),
		str(style))
	GuiFrameStack.clear()
	hud.queue_free()
	BenefitsManager.reset()
	await host.get_tree().process_frame


#README J14: "After viewing: Contract 15 shows the red skull, "Failed", "Failed on", and the pay
#tooltip."
static func _case_j14_after(res: Dictionary, host: Node) -> void:
	_fresh()
	var ids: Array[int] = GameState.seed_results_preview()
	if ids.size() != 2:
		TestFixtures.check(res, "J14 the game seeds the failed contract", false, str(ids))
		return
	var hud: GameHUD = _hud(host)
	await host.get_tree().process_frame
	var viewer: ContractViewer = hud.open_viewer(&"contracts") as ContractViewer
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "J14 the Contract Viewer opens", viewer != null,
		"viewer %s" % str(viewer != null))
	if viewer == null:
		GuiFrameStack.clear()
		hud.queue_free()
		await host.get_tree().process_frame
		return
	viewer.select_entry(ids[1])
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var panel: ContractResults = viewer.window().current() as ContractResults
	var result: ContractResultData = GameState.result_of(ids[1])
	if panel == null or result == null:
		TestFixtures.check(res, "J14 the results of the failed contract open", false, "no panel")
		GuiFrameStack.clear()
		hud.queue_free()
		await host.get_tree().process_frame
		return
	panel.skip_to_end()
	panel.press_continue()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var view: ContractView = _view_of(ids[1])
	TestFixtures.check(res, "J14 the contract counts as read once the results were viewed",
		view != null and not view.is_unclaimed() and not GameState.is_unclaimed(ids[1]),
		"%s" % str(view != null and not view.is_unclaimed()))
	if view == null:
		GuiFrameStack.clear()
		hud.queue_free()
		await host.get_tree().process_frame
		return
	TestFixtures.check(res, "J14 the contract now reads Failed",
		view.shown_status_text() == FAILED_TEXT, view.shown_status_text())
	TestFixtures.check(res, "J14 the failed contract is written in red",
		view.shown_status_color().is_equal_approx(FAILED_COLOR), str(view.shown_status_color()))
	TestFixtures.check(res, "J14 the failed contract wears the skull",
		view.shown_mark() == StatusMark.Mark.FAILED, "%d" % view.shown_mark())
	TestFixtures.check(res, "J14 the failed contract leaves the Unclaimed Results shelf",
		ContractList.filter_key(view) == FAILED_FILTER_KEY, ContractList.filter_key(view))
	#GX4D-01: the claim keeps the posting on the board; its own Failed option turns on for it.
	TestFixtures.check(res,
		"J14 a settled failure stays on the board with its own Failed option now on",
		_row_of(viewer.list(), ids[1]) != null and viewer.list().filter_panel.show_failed,
		"row %s failed %s" % [str(_row_of(viewer.list(), ids[1]) != null),
		viewer.list().filter_panel.show_failed])
	var rules: Dictionary = viewer.list().filter_panel.filter().duplicate(true)
	rules[FAILED_FILTER_KEY] = true
	viewer.list().filter_panel.set_filter(rules)
	await host.get_tree().process_frame
	var row: ContractListItem = _row_of(viewer.list(), ids[1])
	TestFixtures.check(res, "J14 the filter Failed brings the contract back to the board",
		row != null, "row %s" % str(row != null))
	if row != null:
		TestFixtures.check(res, "J14 the list row reads Failed in red",
			row.strip_text() == FAILED_TEXT and row.strip_color().is_equal_approx(FAILED_COLOR),
			"%s %s" % [row.strip_text(), str(row.strip_color())])
		TestFixtures.check(res, "J14 the list row wears the skull",
			row.mark.kind == StatusMark.Mark.FAILED, "%d" % row.mark.kind)
		TestFixtures.check(res, "J14 a settled row is greyed down",
			row.modulate.is_equal_approx(ContractListItem.CLOSED_TINT), str(row.modulate))
	var panel_row: FilterCheckRow = viewer.list().filter_panel.row_of(FAILED_FILTER_KEY)
	TestFixtures.check(res, "J14 the filter option of that key reads Failed",
		panel_row != null and panel_row.label == FAILED_OPTION,
		"" if panel_row == null else panel_row.label)
	viewer.detail().set_view(view)
	await host.get_tree().process_frame
	TestFixtures.check(res, "J14 the detail reads Failed and wears the skull",
		viewer.detail().status_line() == FAILED_TEXT
		and viewer.detail().status_mark().kind == StatusMark.Mark.FAILED,
		"%s %d" % [viewer.detail().status_line(), viewer.detail().status_mark().kind])
	TestFixtures.check(res, "J14 the detail dates the failure",
		viewer.detail().date_line() == FAILED_DATE % TrynnCalendar.date_text(view.closed_minute),
		viewer.detail().date_line())
	viewer.detail().reward_label.mouse_entered.emit()
	await host.get_tree().process_frame
	var tip: PayoutTooltip = viewer.detail().payout_tooltip()
	TestFixtures.check(res, "J14 the reward now opens the pay results tooltip",
		tip.visible and tip.is_results(), "shown %s" % str(tip.visible))
	TestFixtures.check(res, "J14 the tooltip shows the forfeited reward as nothing",
		_digits(tip.reward_label.text) == "0", tip.reward_label.text)
	TestFixtures.check(res, "J14 the tooltip shows the expenses the guild carried",
		_digits(tip.expenses_label.text) == "-%d" % result.expenses, tip.expenses_label.text)
	GuiFrameStack.clear()
	hud.queue_free()
	await host.get_tree().process_frame
