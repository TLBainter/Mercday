class_name GuiAdsTests
extends RefCounted

#Run: the headless harness flag gui-ads-tests, after the bare argument separator.
#The My Promotions window: the two ad tabs, the mode lock behind a tab the guild has not bought,
#the campaign toolbar, the campaign cards, the End Campaign dialog and the New Campaign builder.
#Every case drives the public helpers of the screen, because a click never reaches a button
#headless. The campaign rules themselves are GuiPromoTests; this suite reads what the screen shows.

const VIEWER: PackedScene = preload("res://Scenes/GUI/Promotions/PromotionsViewer.tscn")
const BOARD_SCENE: String = "res://Scenes/GUI/Contracts/ContractViewer.tscn"
#Enough notes that no case trips the price gate by accident.
const BANK: int = 20000
#lay_board launches six job ads and one promo; ad 1 has run out and ad 2 is Infinite.
const JOB_TOTAL: int = 6
const JOB_SHOWN: int = 5
const PROMO_TOTAL: int = 1
const CONCLUDED_ID: int = 1
const INFINITE_ID: int = 2
const FIXED_ID: int = 3
const WOM_ID: int = 5
const PROMO_ID: int = 6
const YOUNG_ID: int = 7
const LIVE_JOB_IDS: Array[int] = [3, 4, 5, 7]
#The live job ad the View Applicants checks press.
const VIEW_ID: int = FIXED_ID
const BOOST: int = 25
const CARD_CELLS: int = 20
#A board with no campaigns numbers its first launch 1.
const FIRST_NEW_ID: int = 1
const FIRST_NEW_NAME: String = "Campaign 1"
#The day lay_board leaves the clock on: a new game starts on day 122.
const BOARD_DAY: int = 141
#How far a drawn pixel may stand from the palette tone it was painted in.
const TONE_SLACK: float = 0.01
#How far a laid out edge may stand from the edge it is compared with.
const EDGE_SLACK: float = 0.5
#The crew case offers three mercs to a crew with two seats.
const CREW_ROSTER: int = 3


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh(_full_ent())
	await host.get_tree().process_frame
	var viewer: PromotionsViewer = VIEWER.instantiate() as PromotionsViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	_case_tabs(res, viewer)
	_case_mode_lock(res, viewer)
	_case_counts(res, viewer)
	_case_sorts(res, viewer)
	_case_cards(res, viewer)
	await _case_contract_board(res, host)
	_case_end_flow(res, viewer)
	_case_builder(res, viewer)
	_case_types(res, viewer)
	_case_duration(res, viewer)
	_case_job_target(res, viewer)
	_case_guild_target(res, viewer)
	_case_crew(res, viewer)
	_case_reasons(res, viewer)
	_case_launch(res, viewer)
	_case_bevel_sweep(res, viewer)
	_case_glyphs(res, viewer)
	await _case_fit(res, viewer, host)
	await _case_builder_fit(res, viewer, host)
	await _case_guild_builder_fit(res, viewer, host)
	GuiFrameStack.clear()
	viewer.queue_free()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.max_out()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI ADS")


#A new game with no campaigns and one entitlement table laid over a bare Enterprise plan.
static func _fresh(ent: Dictionary = {}) -> void:
	GuiPromoTests._fresh(ent)
	GameState.bank_notes = BANK


#Seven campaigns launched on staggered days, the clock then run on to BOARD_DAY: 1 Flyers 5 days (run
#out), 2 Radio Infinite, 3 Flyers 30 days, 4 Radio 10 days and 5 Word of Mouth 10 days launched on one
#day, 6 a 14 day Flyers guild promo and 7 Radio 25 days a day old. The bank is put back at BANK.
#The promo's one contract is posted by hand because pass_days runs no 8:00 round.
static func lay_board() -> void:
	var cap: Variant = SubscriptionManager.entitlements().get("maxPromoDays", 0)
	var crew: Array[int] = []
	for merc: MercenaryData in TestFixtures.add_mercs(2):
		crew.append(merc.merc_uid)
	GameState.bank_notes = BANK * 10
	_launch({"type": &"flyers", "days": 5})
	SubscriptionManager.set_entitlements({"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE})
	_launch({"type": &"radio", "infinite": true})
	SubscriptionManager.set_entitlements({"maxPromoDays": cap})
	TestFixtures.pass_days(7)
	_land([1, 2, 2])
	_launch({"type": &"flyers", "days": 30})
	TestFixtures.pass_days(4)
	_land([2, 3])
	_launch({"type": &"radio", "days": 10})
	_launch({"type": &"wom", "days": 10, "crew": crew})
	TestFixtures.pass_days(5)
	_land([2, 3, 4, 5, 2, 3])
	_launch({"type": &"flyers", "mode": CampaignData.MODE_PROMO, "days": 14})
	TestFixtures.pass_days(2)
	_land([4, 5, 2])
	_launch({"type": &"radio", "days": 25})
	TestFixtures.pass_days(1)
	_land([3])
	var military: Array[String] = ["Military"]
	var anywhere: Array[String] = []
	if GameState.post_campaign_contract(
			ContractGenerator.generate_for(military, anywhere, 0.5, 5.0), PROMO_ID, true) == null:
		push_error("lay_board could not post the promo contract")
	PromotionsManager.credit_contract(PROMO_ID)
	GameState.bank_notes = BANK


#Lands one job applicant per listed campaign id, in order, the way the old three day arrivals fell.
static func _land(ids: Array[int]) -> void:
	for id: int in ids:
		PromotionsManager.land_applicant(PromotionsManager.campaign_of(id))


static func _launch(spec: Dictionary) -> void:
	if TestFixtures.launch_campaign(spec) == null:
		push_error("lay_board could not launch %s" % [spec])


#Every method and both tabs bought, with promos capped at a month.
static func _full_ent() -> Dictionary:
	var out: Dictionary = GuiPromoTests._launch_ent()
	out["adRadio"] = true
	return out


#The full table with the given keys set over it.
static func _ent_with(overrides: Dictionary) -> Dictionary:
	var out: Dictionary = _full_ent()
	out.merge(overrides, true)
	return out


static func _infinite_ent() -> Dictionary:
	return _ent_with({"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE})


static func _ids(viewer: PromotionsViewer) -> Array[int]:
	var out: Array[int] = []
	for card: CampaignCard in viewer.campaign_list().cards:
		out.append(card.campaign_id())
	return out


#True when the cards stand in the order the header sort asks for, ties to the newer campaign.
static func _ordered(viewer: PromotionsViewer, up: bool) -> bool:
	var today: int = GameState.day()
	var ids: Array[int] = _ids(viewer)
	var last: float = 0.0
	var last_id: int = 0
	for i: int in range(ids.size()):
		var campaign: CampaignData = PromotionsManager.campaign_of(ids[i])
		var value: float = PromotionsManager.campaign_sort_value(campaign, viewer.sort_key, today)
		if i > 0:
			if is_equal_approx(value, last):
				if ids[i] > last_id:
					return false
			elif up and value < last:
				return false
			elif not up and value > last:
				return false
		last = value
		last_id = ids[i]
	return ids.size() > 1


#Case 1: the two tabs, the heading each one carries and the campaigns behind it.
static func _case_tabs(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	lay_board()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	TestFixtures.check(res, "the window opens on Job Ads under its own heading",
		viewer.current_tab() == PromotionsViewer.JOB_KEY and viewer.mode_key() == "job"
		and viewer.title_text() == PromotionsViewer.JOB_TITLE
		and viewer.desc_text() == PromotionsViewer.JOB_DESC, viewer.title_text())
	TestFixtures.check(res, "the Job tab reads as the live one and the Guild tab does not",
		viewer.tab_button(PromotionsViewer.JOB_KEY).active
		and not viewer.tab_button(PromotionsViewer.PROMO_KEY).active, "job is active")
	var guild_tab: TabButton = viewer.tab_button(PromotionsViewer.PROMO_KEY)
	TestFixtures.check(res, "both tabs carry the caption and the hover line of the prototype",
		viewer.tab_button(PromotionsViewer.JOB_KEY).label == PromotionsViewer.JOB_TITLE
		and viewer.tab_button(PromotionsViewer.JOB_KEY).description == "Ads that bring mercs to your door"
		and guild_tab.label == PromotionsViewer.PROMO_TITLE
		and guild_tab.description == "Ads that bring contracts to your door", guild_tab.label)
	TestFixtures.check(res, "the Job tab holds the six job ads the board launched",
		PromotionsManager.campaign_count("job") == JOB_TOTAL and viewer.card_count() == JOB_SHOWN,
		"%d of %d" % [viewer.card_count(), PromotionsManager.campaign_count("job")])
	viewer.press_tab(PromotionsViewer.PROMO_KEY)
	TestFixtures.check(res, "pressing the Guild tab moves the heading and the line under it",
		viewer.current_tab() == PromotionsViewer.PROMO_KEY and viewer.mode_key() == "promo"
		and viewer.title_text() == PromotionsViewer.PROMO_TITLE
		and viewer.desc_text() == PromotionsViewer.PROMO_DESC, viewer.title_text())
	TestFixtures.check(res, "the Guild tab is the live one now",
		viewer.tab_button(PromotionsViewer.PROMO_KEY).active
		and not viewer.tab_button(PromotionsViewer.JOB_KEY).active, "guild is active")
	TestFixtures.check(res, "the Guild tab lists the guild promo campaign on its own",
		viewer.card_count() == PROMO_TOTAL and viewer.card_names() == ["Campaign %d" % PROMO_ID]
		and PromotionsManager.campaign_count("promo") == PROMO_TOTAL,
		"%s" % [viewer.card_names()])
	TestFixtures.check(res, "each tab answers to the PromotionsManager mode key it sorts on",
		viewer.tab_strip.index_of(PromotionsViewer.JOB_KEY) == 0
		and viewer.tab_strip.index_of(PromotionsViewer.PROMO_KEY) == 1,
		"job and promo")
	viewer.open_tab(&"nonsense")
	TestFixtures.check(res, "a tab key the screen does not know falls back to Job Ads",
		viewer.current_tab() == PromotionsViewer.JOB_KEY and viewer.mode_key() == "job",
		viewer.mode_key())
	TestFixtures.check(res, "the new-campaign button names the tab it stands under",
		viewer.new_shown() and viewer.new_label() == CampaignList.NEW_JOB, viewer.new_label())
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	TestFixtures.check(res, "the Guild tab asks for a guild promo campaign instead",
		viewer.new_shown() and viewer.new_label() == CampaignList.NEW_PROMO, viewer.new_label())
	viewer.open_tab(PromotionsViewer.JOB_KEY)


#Case 2: the block a tab the guild has not bought shows, and what it offers to sell.
static func _case_mode_lock(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	TestFixtures.check(res, "a bare plan locks the Job Ads tab and hides the header tools",
		viewer.mode_locked() and viewer.lock_shown() and not viewer.toolbar_shown()
		and not viewer.new_shown() and viewer.card_count() == 0,
		"%d cards" % [viewer.card_count()])
	TestFixtures.check(res, "the locked Job tab says which feature is missing",
		viewer.lock_block().text() == "Job Postings are locked.", viewer.lock_block().text())
	var job_lock: FeatureLock = viewer.lock_block().lock_button()
	TestFixtures.check(res, "the Job lock points at the one Promotions tier that opens it",
		job_lock.feature == "Job Postings" and job_lock.upgrade == "Promotions"
		and job_lock.upgrade_id == "promotions" and job_lock.tier == 1 and job_lock.tiers == 1,
		"%s tier %d of %d" % [job_lock.upgrade, job_lock.tier, job_lock.tiers])
	TestFixtures.check(res, "the lock block reads as a Locked label the reader can press",
		job_lock.label == ModeLock.LOCK_LABEL and job_lock.verb == ModeLock.LOCK_VERB,
		"%s / %s" % [job_lock.label, job_lock.verb])
	viewer.press_new()
	TestFixtures.check(res, "no builder opens from behind a locked tab",
		not viewer.builder().is_open(), "the builder stays shut")
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	var promo_lock: FeatureLock = viewer.lock_block().lock_button()
	TestFixtures.check(res, "the locked Guild tab sells the first of the four Guild Promo tiers",
		viewer.mode_locked() and viewer.lock_block().text() == "Guild Promotion is locked."
		and promo_lock.feature == "Guild Promotion" and promo_lock.upgrade == "Guild Promo"
		and promo_lock.upgrade_id == "guildpromo" and promo_lock.tier == 1
		and promo_lock.tiers == 4, "%s tier %d of %d" % [promo_lock.upgrade, promo_lock.tier,
		promo_lock.tiers])
	_fresh(_full_ent())
	lay_board()
	SubscriptionManager.set_entitlements({"guildPromo": false})
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	TestFixtures.check(res, "buying Job Postings opens the Job tab and its campaign list",
		not viewer.mode_locked() and not viewer.lock_shown() and viewer.toolbar_shown()
		and viewer.new_shown() and viewer.card_count() == JOB_SHOWN,
		"%d cards" % [viewer.card_count()])
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	TestFixtures.check(res, "Job Postings alone leaves the Guild tab locked",
		viewer.mode_locked() and viewer.lock_shown() and viewer.card_count() == 0,
		viewer.lock_block().text())
	_fresh(_full_ent())
	lay_board()
	SubscriptionManager.set_entitlements({"jobPostings": false})
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	TestFixtures.check(res, "buying Guild Promotion opens the Guild tab on its own",
		not viewer.mode_locked() and not viewer.lock_shown() and viewer.toolbar_shown()
		and viewer.new_label() == CampaignList.NEW_PROMO
		and viewer.card_count() == PROMO_TOTAL, "%d cards" % [viewer.card_count()])
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	TestFixtures.check(res, "Guild Promotion alone leaves the Job tab locked",
		viewer.mode_locked() and viewer.lock_block().text() == "Job Postings are locked.",
		viewer.lock_block().text())
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	var job_open: bool = not viewer.mode_locked()
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	TestFixtures.check(res, "both features together leave neither tab locked",
		job_open and not viewer.mode_locked() and not viewer.lock_shown(), "both tabs are open")
	TestFixtures.check(res, "an unknown mode key has no lock row to show",
		PromotionsManager.mode_lock("nonsense").is_empty()
		and not PromotionsManager.mode_unlocked("nonsense", _full_ent()), "no such tab")
	viewer.open_tab(PromotionsViewer.JOB_KEY)


#Case 3: the count line, the two show toggles and the empty lines under them.
static func _case_counts(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	lay_board()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.set_filter(AdsToolbar.DEFAULT_CONCLUDED, AdsToolbar.DEFAULT_INFINITE)
	TestFixtures.check(res, "the header counts the cards the filters leave standing",
		viewer.card_count() == JOB_SHOWN and viewer.shown_text() == "5 of 6 shown",
		viewer.shown_text())
	TestFixtures.check(res, "the filter field reads Active while both toggles sit at default",
		viewer.toolbar().filter_text() == AdsToolbar.LABEL_ACTIVE
		and not viewer.show_concluded and viewer.show_infinite,
		viewer.toolbar().filter_text())
	TestFixtures.check(res, "the ad that ran out is the one the default filter holds back",
		viewer.campaign_list().card_for(CONCLUDED_ID) == null
		and PromotionsManager.campaign_of(CONCLUDED_ID).is_concluded(GameState.day()), "ad 1 has run out")
	viewer.toolbar().press_row(true)
	TestFixtures.check(res, "pressing Show Concluded brings the finished ad back",
		viewer.show_concluded and viewer.card_count() == JOB_TOTAL
		and viewer.shown_text() == "6 of 6 shown"
		and viewer.campaign_list().card_for(CONCLUDED_ID) != null, viewer.shown_text())
	TestFixtures.check(res, "a toggle off its default marks the filter field Custom",
		viewer.toolbar().filter_text() == AdsToolbar.LABEL_CUSTOM,
		viewer.toolbar().filter_text())
	viewer.toolbar().press_row(false)
	TestFixtures.check(res, "turning Show Infinite off drops the Infinite ad",
		not viewer.show_infinite and viewer.card_count() == JOB_TOTAL - 1
		and viewer.campaign_list().card_for(INFINITE_ID) == null, viewer.shown_text())
	viewer.set_filter(false, false)
	TestFixtures.check(res, "neither toggle on leaves the four fixed ads still running",
		viewer.card_count() == LIVE_JOB_IDS.size() and _ids(viewer).size() == LIVE_JOB_IDS.size(),
		"%s" % [_ids(viewer)])
	viewer.set_filter(AdsToolbar.DEFAULT_CONCLUDED, AdsToolbar.DEFAULT_INFINITE)
	TestFixtures.check(res, "putting both toggles back reads Active again",
		viewer.toolbar().filter_text() == AdsToolbar.LABEL_ACTIVE and viewer.card_count() == JOB_SHOWN,
		viewer.shown_text())
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	TestFixtures.check(res, "the Guild tab counts its own campaigns only",
		viewer.card_count() == PROMO_TOTAL and viewer.shown_text() == "1 of 1 shown",
		viewer.shown_text())
	PromotionsManager.end(PROMO_ID)
	TestFixtures.check(res, "a Guild tab with nothing running says so",
		viewer.card_count() == 0 and viewer.campaign_list().empty_shown()
		and viewer.empty_text() == CampaignList.EMPTY_PROMO, viewer.empty_text())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	for id: int in LIVE_JOB_IDS:
		PromotionsManager.end(id)
	viewer.set_filter(false, false)
	TestFixtures.check(res, "filters that leave a full list empty say the filters did it",
		viewer.card_count() == 0 and viewer.campaign_list().empty_shown()
		and viewer.empty_text() == CampaignList.EMPTY_FILTERS
		and PromotionsManager.campaign_count("job") == 2, viewer.empty_text())
	viewer.set_filter(true, true)
	TestFixtures.check(res, "the run out ad and the Infinite one are still on the list",
		viewer.card_count() == 2 and viewer.shown_text() == "2 of 2 shown",
		"%s" % [_ids(viewer)])
	viewer.set_filter(AdsToolbar.DEFAULT_CONCLUDED, AdsToolbar.DEFAULT_INFINITE)


#Case 4: the five header sorts, each one read in both directions.
static func _case_sorts(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	lay_board()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.set_filter(AdsToolbar.DEFAULT_CONCLUDED, AdsToolbar.DEFAULT_INFINITE)
	TestFixtures.check(res, "the list opens on Start Date with the newest ad at the top",
		viewer.sort_key == PromotionsManager.CAMPAIGN_SORT_DEFAULT and not viewer.ascending
		and _ids(viewer) == [YOUNG_ID, WOM_ID, 4, FIXED_ID, INFINITE_ID], "%s" % [_ids(viewer)])
	viewer.toggle_direction()
	TestFixtures.check(res, "the arrow turns the same sort around, ties still to the newer ad",
		viewer.ascending and _ids(viewer) == [INFINITE_ID, FIXED_ID, WOM_ID, 4, YOUNG_ID],
		"%s" % [_ids(viewer)])
	viewer.toggle_direction()
	for row: Dictionary in PromotionsManager.CAMPAIGN_SORTS:
		var key: StringName = StringName(row["key"])
		var label: String = String(row["label"])
		viewer.pick_sort(key)
		TestFixtures.check(res, "%s sorts the cards downward" % label,
			viewer.sort_key == key and viewer.toolbar().sort_key() == key
			and not viewer.ascending and _ordered(viewer, false)
			and viewer.card_count() == JOB_SHOWN, "%s: %s" % [label, _ids(viewer)])
		var down: Array[int] = _ids(viewer)
		viewer.toggle_direction()
		TestFixtures.check(res, "%s sorts the cards upward" % label,
			viewer.ascending and _ordered(viewer, true) and viewer.card_count() == JOB_SHOWN
			and _ids(viewer) != down, "%s: %s" % [label, _ids(viewer)])
		viewer.toggle_direction()
	TestFixtures.check(res, "every sort the header offers has a label of its own",
		PromotionsManager.CAMPAIGN_SORTS.size() == 5
		and PromotionsManager.campaign_sort_label(&"start") == "Start Date"
		and PromotionsManager.campaign_sort_label(&"nonsense") == "",
		"%d sorts" % [PromotionsManager.CAMPAIGN_SORTS.size()])
	viewer.pick_sort(&"nonsense")
	TestFixtures.check(res, "a sort key the header does not know changes nothing",
		viewer.sort_key == &"cost" and viewer.card_count() == JOB_SHOWN, String(viewer.sort_key))
	viewer.pick_sort(PromotionsManager.CAMPAIGN_SORT_DEFAULT)


#Case 5: what one campaign card says, for a fixed ad, an Infinite one, a crew ad and a dead one.
static func _case_cards(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	lay_board()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.set_filter(true, true)
	var today: int = GameState.day()
	var fixed: CampaignCard = viewer.campaign_list().card_for(FIXED_ID)
	TestFixtures.check(res, "a fixed ad names its method and the day it went out",
		fixed != null and fixed.method_text() == "Flyers"
		and fixed.started_text() == "12 days ago"
		and fixed.started_tooltip() == GuiDates.day_text(today - 12), fixed.started_text())
	TestFixtures.check(res, "a fixed ad counts the days it has left",
		fixed.left_caption() == CampaignCard.LEFT_LABEL and fixed.left_text() == "18 days"
		and not fixed.is_concluded(), fixed.left_text())
	TestFixtures.check(res, "the time bar fills with the share of the run still to come",
		is_equal_approx(fixed.ratio(), 0.6) and fixed.filled_cells() == 12,
		"%.2f, %d cells" % [fixed.ratio(), fixed.filled_cells()])
	TestFixtures.check(res, "a fixed ad prices what it spent and what it still holds",
		fixed.campaign.spent_so_far(today) == 60 and fixed.campaign.budget_remaining(today) == 90
		and fixed.campaign.total_committed(today) == 150,
		"spent %d" % [fixed.campaign.spent_so_far(today)])
	TestFixtures.check(res, "a job ad counts its applicants and offers to show them",
		fixed.results_caption() == CampaignCard.JOB_RESULTS and fixed.results_text() == "4"
		and fixed.has_view() and fixed.has_end(), fixed.results_text())
	TestFixtures.check(res, "the End control is the underlined red link of the prototype",
		fixed.end_button.get_class() == "LinkButton"
		and fixed.end_button.underline == LinkButton.UNDERLINE_MODE_ALWAYS
		and fixed.end_button.get_theme_color(&"font_color") == CampaignCard.END_COLOR
		and fixed.end_button.get_theme_color(&"font_hover_color") == CampaignCard.END_HOVER,
		"%s in %s" % [fixed.end_button.get_class(),
		fixed.end_button.get_theme_color(&"font_color").to_html(false)])
	var ended: Array[int] = []
	var end_watcher: Callable = func(campaign_id: int) -> void:
		ended.append(campaign_id)
	fixed.end_pressed.connect(end_watcher)
	fixed.press_end()
	fixed.end_pressed.disconnect(end_watcher)
	viewer.press_cancel()
	TestFixtures.check(res, "the End link still reports the ad it belongs to",
		ended == [FIXED_ID] and not viewer.confirm().visible, "%s" % [ended])
	var forever: CampaignCard = viewer.campaign_list().card_for(INFINITE_ID)
	TestFixtures.check(res, "an Infinite ad is billed monthly and never counts down",
		forever.left_caption() == CampaignCard.BILLED_LABEL
		and forever.left_text() == CampaignCard.INFINITE_TEXT
		and is_equal_approx(forever.ratio(), 1.0) and forever.filled_cells() == CARD_CELLS,
		forever.left_text())
	TestFixtures.check(res, "an Infinite ad holds the days it already paid for up to its next bill",
		forever.method_text() == "Radio" and forever.campaign.budget_remaining(today) == 1600
		and forever.results_text() == "6" and forever.has_end(),
		"%d notes left" % [forever.campaign.budget_remaining(today)])
	var crew: CampaignCard = viewer.campaign_list().card_for(WOM_ID)
	TestFixtures.check(res, "a Word of Mouth ad paid its crew once and holds no budget",
		crew.method_text() == "Word of Mouth" and crew.campaign.spent_so_far(today) == 50
		and crew.campaign.budget_remaining(today) == 0 and crew.left_text() == "2 days",
		"spent %d" % [crew.campaign.spent_so_far(today)])
	var over: CampaignCard = viewer.campaign_list().card_for(CONCLUDED_ID)
	TestFixtures.check(res, "an ad that ran out reads Concluded with an empty bar",
		over.is_concluded() and over.left_text() == CampaignCard.CONCLUDED_TEXT
		and is_equal_approx(over.ratio(), 0.0) and over.filled_cells() == 0, over.left_text())
	TestFixtures.check(res, "a concluded card drops the End link but keeps its applicants",
		not over.has_end() and over.has_view() and over.results_text() == "1"
		and over.campaign.budget_remaining(today) == 0, over.results_text())
	var young: CampaignCard = viewer.campaign_list().card_for(YOUNG_ID)
	TestFixtures.check(res, "an ad one day old says so in the singular",
		young.started_text() == "1 day ago" and young.campaign_id() == YOUNG_ID,
		young.started_text())
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	var promo: CampaignCard = viewer.campaign_list().card_for(PROMO_ID)
	TestFixtures.check(res, "a guild promo counts contracts and offers to show them",
		promo.results_caption() == CampaignCard.PROMO_RESULTS and promo.results_text() == "1"
		and promo.has_view() and promo.view_button.text == "View Contracts"
		and promo.view_text() == CampaignCard.VIEW_CONTRACTS_TEXT and promo.has_end(),
		"%s, %s" % [promo.results_caption(), promo.view_button.text])
	var opened: Array[int] = []
	var opener: Callable = func(campaign_id: int) -> void:
		opened.append(campaign_id)
	viewer.view_contracts.connect(opener)
	viewer.press_view(PROMO_ID)
	viewer.view_contracts.disconnect(opener)
	var taken: Dictionary = GameState.take_contract_filter()
	TestFixtures.check(res, "View Contracts reports the promo and leaves its filter for the board",
		opened == [PROMO_ID] and int(taken.get("campaign", 0)) == PROMO_ID, "%s, %s" % [opened, taken])
	var seen: Array[int] = []
	var watcher: Callable = func(campaign_id: int) -> void:
		seen.append(campaign_id)
	viewer.view_applicants.connect(watcher)
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_view(VIEW_ID)
	viewer.view_applicants.disconnect(watcher)
	TestFixtures.check(res, "View Applicants reports the ad the reader pressed",
		seen == [VIEW_ID], "%s" % [seen])
	var window: ViewerPopup = viewer.popup()
	var content: Node = window.current() if window != null else null
	var shell: FinanceViewer = content as FinanceViewer
	TestFixtures.check(res, "View Applicants opens the hiring only Finance window over Promotions",
		window != null and window.is_open() and window.get_parent() == viewer and shell != null
		and shell.hiring_only and shell.fixed_campaign == VIEW_ID, "%s, %s" % [window, content])
	viewer.view_applicants.connect(watcher)
	viewer.press_view(VIEW_ID)
	viewer.view_applicants.disconnect(watcher)
	TestFixtures.check(res, "a second press while the window is open opens no second window",
		viewer.popup() == window and seen == [VIEW_ID], "%s, %s" % [viewer.popup(), seen])
	if window != null:
		window.close()
	TestFixtures.check(res, "closing the window clears it from the screen", viewer.popup() == null,
		"%s" % [viewer.popup()])
	viewer.set_filter(AdsToolbar.DEFAULT_CONCLUDED, AdsToolbar.DEFAULT_INFINITE)


#Case 5b: the contract board a promo's View Contracts opens, held to that campaign's postings.
static func _case_contract_board(res: Dictionary, host: Node) -> void:
	_fresh(_full_ent())
	lay_board()
	var military: Array[String] = ["Military"]
	var anywhere: Array[String] = []
	var second: BoardEntry = GameState.post_campaign_contract(
		ContractGenerator.generate_for(military, anywhere, 0.5, 5.0), PROMO_ID, true)
	var rejected: bool = second != null and GameState.reject(second.id)
	var tagged: Array[int] = _entry_ids(GameState.campaign_contracts(PROMO_ID))
	PromotionsManager.view_contracts(PROMO_ID)
	var board: ContractViewer = (load(BOARD_SCENE) as PackedScene).instantiate() as ContractViewer
	host.add_child(board)
	await host.get_tree().process_frame
	var shown: Array[int] = _entry_ids(board.list().listed())
	TestFixtures.check(res, "the board opens on the promo's two postings and nothing else",
		rejected and tagged.size() == 2 and shown == tagged and board.campaign_filter == PROMO_ID
		and GameState.contract_filter.is_empty() and GameState.contracts.size() > tagged.size(),
		"%s of %s" % [shown, tagged])
	var flags: Dictionary = board.list().filter_panel.flags()
	TestFixtures.check(res, "the campaign board turns every status option on, rejected included",
		not flags.is_empty() and not flags.values().has(false)
		and bool(board.list().filter.get("show_rejected", false))
		and board.selected_id == board.list().first_id() and board.list().has_id(board.selected_id),
		"%s, selected %d" % [flags, board.selected_id])
	board.show_campaign(0)
	var everything: Array[int] = _entry_ids(board.list().listed())
	TestFixtures.check(res, "clearing the campaign filter lists the whole board again",
		board.campaign_filter == 0 and everything.size() > tagged.size() and tagged.size() == 2
		and everything.has(tagged[0]) and everything.has(tagged[1]),
		"%d listed" % everything.size())
	board.queue_free()
	await host.get_tree().process_frame


#The entry ids of a set of postings, lowest first.
static func _entry_ids(views: Array[ContractView]) -> Array[int]:
	var out: Array[int] = []
	for view: ContractView in views:
		out.append(view.entry_id)
	out.sort()
	return out


#Case 6: the End Campaign dialog, with a refund, without one and on an ad nobody can end.
static func _case_end_flow(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	lay_board()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.set_filter(true, true)
	var fixed: Dictionary = PromotionsManager.end_preview(FIXED_ID)
	viewer.press_end(FIXED_ID)
	TestFixtures.check(res, "the End link opens a red dialog with a Cancel and an End button",
		viewer.confirm().visible and viewer.confirm().button_count() == 2
		and viewer.confirm().severity() == ConfirmDialog.Severity.RED
		and viewer.confirm().button_labels()[0] == PromotionsViewer.END_CANCEL,
		"%s" % [viewer.confirm().button_labels()])
	TestFixtures.check(res, "the dialog counts the unused days and the notes they hand back",
		viewer.end_body(fixed)
		== "The campaign stops now. You get 90 notes back for the 18 unused days."
		and viewer.end_cta(fixed) == "End - Refund 90 n"
		and viewer.confirm().button_labels()[1] == "End - Refund 90 n", viewer.end_body(fixed))
	viewer.press_cancel()
	TestFixtures.check(res, "cancelling leaves the ad running and the bank alone",
		not viewer.confirm().visible and PromotionsManager.campaign_of(FIXED_ID) != null
		and GameState.bank_notes == BANK and viewer.card_count() == JOB_TOTAL,
		"bank %d" % [GameState.bank_notes])
	viewer.press_end(FIXED_ID)
	viewer.press_confirm()
	TestFixtures.check(res, "confirming ends the ad, refunds the days and drops the card",
		PromotionsManager.campaign_of(FIXED_ID) == null and GameState.bank_notes == BANK + 90
		and viewer.campaign_list().card_for(FIXED_ID) == null and viewer.card_count() == JOB_TOTAL - 1,
		"bank %d" % [GameState.bank_notes])
	TestFixtures.check(res, "the screen says what ended and how much came back",
		viewer.notice_shown() and viewer.notice_text() == "Campaign 3 ended. 90 notes refunded.",
		viewer.notice_text())
	var crew: Dictionary = PromotionsManager.end_preview(WOM_ID)
	viewer.press_end(WOM_ID)
	TestFixtures.check(res, "a Word of Mouth ad warns the crew pay is already spent",
		bool(crew["crew_paid"]) and int(crew["refund"]) == 0
		and viewer.end_body(crew) == PromotionsViewer.END_WOM
		and viewer.end_cta(crew) == PromotionsViewer.END_CTA_PLAIN, viewer.end_body(crew))
	viewer.press_confirm()
	TestFixtures.check(res, "ending a crew ad takes the card away and hands nothing back",
		PromotionsManager.campaign_of(WOM_ID) == null and GameState.bank_notes == BANK + 90
		and viewer.notice_text() == "Campaign 3 ended. 90 notes refunded.",
		"bank %d" % [GameState.bank_notes])
	var forever: Dictionary = PromotionsManager.end_preview(INFINITE_ID)
	viewer.press_end(INFINITE_ID)
	TestFixtures.check(res, "an Infinite ad hands back the days it paid for up to its next bill",
		viewer.end_body(forever) == "The campaign stops now. You get 1,600 notes back for the"
		+ " 20 unused days left in this month."
		and viewer.end_cta(forever) == "End - Refund 1,600 n", viewer.end_body(forever))
	viewer.press_confirm()
	TestFixtures.check(res, "the Infinite refund lands and the monthly bill goes with it",
		GameState.bank_notes == BANK + 1690 and PromotionsManager.infinite_count() == 0
		and viewer.notice_text() == "Campaign 2 ended. 1,600 notes refunded.",
		"bank %d, %s" % [GameState.bank_notes, viewer.notice_text()])
	viewer.press_end(CONCLUDED_ID)
	TestFixtures.check(res, "an ad that already ran out opens no dialog at all",
		not viewer.confirm().visible and PromotionsManager.campaign_of(CONCLUDED_ID) != null,
		"ad 1 stays on the list")
	viewer.press_end(99)
	TestFixtures.check(res, "an id no campaign carries opens no dialog either",
		not viewer.confirm().visible, "nothing to end")
	viewer.set_filter(AdsToolbar.DEFAULT_CONCLUDED, AdsToolbar.DEFAULT_INFINITE)


#Case 7: what the New Campaign builder holds the moment it opens.
static func _case_builder(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	TestFixtures.check(res, "the builder opens on the tab that called it",
		builder.is_open() and builder.mode() == CampaignData.MODE_JOB
		and builder.title_text() == CampaignBuilder.TITLE_JOB
		and builder.target_title_text() == CampaignBuilder.TARGET_JOB, builder.title_text())
	TestFixtures.check(res, "it opens on Flyers with all five methods listed",
		builder.type_key() == &"flyers" and builder.type_rows().size() == 5
		and builder.type_row(&"flyers") != null, String(builder.type_key()))
	TestFixtures.check(res, "the name field shows the next campaign number until one is typed",
		builder.campaign_name() == "" and builder.name_shown() == FIRST_NEW_NAME
		and builder.count_text() == "0 / 64", builder.name_shown())
	var duration: DurationControl = builder.duration_control()
	TestFixtures.check(res, "the duration opens at five days",
		duration.unit_key() == CampaignTypeDefs.UNIT_DAYS and duration.quantity() == 5
		and duration.days() == 5 and not duration.is_infinite(),
		"%d %s" % [duration.quantity(), duration.unit_key()])
	TestFixtures.check(res, "the footer prices the five days, all due now",
		builder.cost() == 25 and builder.cost_note_text() == "5 / day x 5 days, all due now"
		and not builder.chip_shown(), builder.cost_note_text())
	TestFixtures.check(res, "a job campaign shows the merc filters and no crew",
		builder.job_shown() and not builder.guild_shown() and not builder.crew_shown(),
		"merc filters are up")
	TestFixtures.check(res, "nothing stands in the way of launching the default campaign",
		builder.reason_text() == "" and builder.launch_enabled(), builder.reason_text())
	var footer: HBoxContainer = builder.launch_button.get_parent() as HBoxContainer
	TestFixtures.check(res, "the footer packs its cost and Launch button to the right",
		footer != null and footer.name == &"Footer" and footer.alignment == BoxContainer.ALIGNMENT_END,
		str(footer))
	var draft: CampaignData = builder.draft()
	TestFixtures.check(res, "the draft carries the method, the mode and the run it shows",
		draft.type_key == &"flyers" and draft.mode == CampaignData.MODE_JOB and draft.days == 5
		and draft.unit_key == CampaignTypeDefs.UNIT_DAYS and not draft.infinite
		and not draft.is_launched(), "%s for %d days" % [draft.type_key, draft.days])
	builder.set_campaign_name("Spring Push")
	TestFixtures.check(res, "a typed name replaces the placeholder and counts its letters",
		builder.campaign_name() == "Spring Push" and builder.name_shown() == "Spring Push"
		and builder.count_text() == "11 / 64" and builder.draft().name == "Spring Push",
		builder.count_text())
	builder.set_campaign_name("x".repeat(CampaignBuilder.NAME_MAX + 20))
	TestFixtures.check(res, "a name longer than the field allows is cut to the limit",
		builder.campaign_name().length() == CampaignBuilder.NAME_MAX
		and builder.count_text() == "64 / 64", builder.count_text())
	builder.set_campaign_name("")
	builder.press_name()
	TestFixtures.check(res, "the name field opens the naming dialog",
		builder.naming() and builder.name_shown() == FIRST_NEW_NAME, builder.name_shown())
	var rows_z: int = 0
	for row: TypeRow in builder.type_rows():
		rows_z = maxi(rows_z, canvas_z(row))
	var dialog_z: int = canvas_z(builder.name_dialog)
	TestFixtures.check(res, "the naming dialog draws above the lifted type rows",
		builder.name_dialog.z_index > TypeRow.TOP_Z and dialog_z > rows_z,
		"dialog %d rows %d" % [dialog_z, rows_z])
	TestFixtures.check(res, "the builder closes with the sheet X and fits the band",
		builder.close_button.text == ""
		and builder.close_button.icon == CloseX.icon(CloseX.SCALE_WINDOW)
		and builder.close_button.custom_minimum_size == CloseX.size(CloseX.SCALE_WINDOW)
		and CampaignBuilder.MODAL_SIZE == Vector2(1190, 628)
		and CampaignBuilder.MODAL_SIZE.y <= 644.0,
		"%s at %s" % [CampaignBuilder.MODAL_SIZE, builder.close_button.custom_minimum_size])
	builder.press_close()
	TestFixtures.check(res, "closing the builder puts the screen back",
		not builder.is_open() and viewer.card_count() == 0, "%d cards" % [viewer.card_count()])



#Case 8: the Campaign Type column, its locks and the Effect the boost lifts.
static func _case_types(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	var rows: Array[TypeRow] = builder.type_rows()
	var keys: Array[StringName] = []
	var stars_ok: bool = true
	var layer_ok: bool = true
	for i: int in range(rows.size()):
		keys.append(rows[i].key())
		stars_ok = stars_ok and is_equal_approx(rows[i].quality(), float(i + 1))
		layer_ok = layer_ok and rows[i].z_index == TypeRow.TOP_Z - i
	TestFixtures.check(res, "the five methods stand in the design prototype order",
		keys == CampaignTypeDefs.keys() and rows.size() == 5, "%s" % [keys])
	TestFixtures.check(res, "each method keeps its quality stars and its own layer",
		stars_ok and layer_ok, "stars %s layers %s" % [stars_ok, layer_ok])
	var direct: TypeRow = builder.type_row(&"direct")
	builder.pick_type(&"direct")
	TestFixtures.check(res, "Direct Sale dims on the Job Ads side and refuses the pick",
		direct.is_blocked() and not direct.is_pickable()
		and is_equal_approx(direct.dim_alpha(), TypeRow.BLOCKED_ALPHA)
		and direct.tooltip_text == TypeRow.BLOCKED_TIP and builder.type_key() == &"flyers",
		String(builder.type_key()))
	TestFixtures.check(res, "the stars and the Effect column hand their clicks to the row",
		direct.stars.mouse_filter == Control.MOUSE_FILTER_PASS
		and direct.effect_box.mouse_filter == Control.MOUSE_FILTER_PASS
		and direct.stars.tooltip_text == TypeRow.QUALITY_TIP
		and direct.effect_box.tooltip_text != "",
		"stars %d, effect %d" % [direct.stars.mouse_filter, direct.effect_box.mouse_filter])
	var lines: Array[String] = []
	var effect_ok: bool = true
	var ent: Dictionary = SubscriptionManager.entitlements()
	for row: TypeRow in rows:
		lines.append(row.effect_line())
		var want: String = CampaignTypeDefs.effect_text(row.key(), ent)
		effect_ok = effect_ok and row.effect_line() == want
	TestFixtures.check(res, "the Effect column reads the base rate of every method",
		effect_ok and lines == ["Varies", "2%", "9%", "12%", "15%"], "%s" % [lines])
	TestFixtures.check(res, "a crew method reads Varies in sky and a priced one green",
		builder.type_row(&"wom").effect_color() == TypeRow.SKY
		and builder.type_row(&"flyers").effect_color() == TypeRow.GREEN,
		"%s" % [builder.type_row(&"wom").effect_color()])
	TestFixtures.check(res, "no Marketing Agency means no boost header",
		not builder.boost_label.visible, "boost header is down")
	builder.press_close()
	_fresh(_ent_with({"adBoost": BOOST}))
	viewer.press_new()
	TestFixtures.check(res, "the boost header names the lift the agency gives",
		builder.boost_label.visible
		and builder.boost_label.text == CampaignBuilder.BOOST_HEAD % BOOST,
		builder.boost_label.text)
	TestFixtures.check(res, "the boost lifts every priced Effect and leaves Varies alone",
		builder.type_row(&"flyers").effect_line() == "2.5%"
		and builder.type_row(&"radio").effect_line() == "15%"
		and builder.type_row(&"wom").effect_line() == "Varies",
		builder.type_row(&"flyers").effect_line())
	builder.press_close()
	_fresh(_ent_with({"adRadio": false}))
	viewer.press_new()
	var radio: TypeRow = builder.type_row(&"radio")
	builder.pick_type(&"radio")
	TestFixtures.check(res, "a method the guild has not bought wears its lock and refuses",
		radio.is_locked() and not radio.is_pickable() and radio.lock_button().visible
		and is_equal_approx(radio.dim_alpha(), TypeRow.LOCKED_ALPHA)
		and builder.type_key() == &"flyers", String(builder.type_key()))
	TestFixtures.check(res, "the method lock points at the tier that opens it",
		radio.lock_button().upgrade_id == "promomethods" and radio.lock_button().tier == 2
		and radio.lock_button().tiers == 3, radio.lock_button().upgrade_id)
	builder.press_close()
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	viewer.press_new()
	builder.pick_type(&"direct")
	TestFixtures.check(res, "Direct Sale opens once the builder is on the Guild Promo side",
		builder.type_row(&"direct").is_pickable() and builder.type_key() == &"direct"
		and builder.title_text() == CampaignBuilder.TITLE_PROMO
		and builder.target_title_text() == CampaignBuilder.TARGET_PROMO
		and builder.guild_shown() and not builder.job_shown(), builder.title_text())
	builder.press_close()
	viewer.open_tab(PromotionsViewer.JOB_KEY)


#Case 9: the duration stepper, its units, the cap they ride on and the Infinite bill.
static func _case_duration(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	var dur: DurationControl = builder.duration_control()
	var ent: Dictionary = SubscriptionManager.entitlements()
	var picker: UnitDropdown = dur.unit_picker()
	TestFixtures.check(res, "a thirty day cap opens days, weeks and months but not Infinite",
		not picker.row_locked(CampaignTypeDefs.UNIT_DAYS)
		and not picker.row_locked(CampaignTypeDefs.UNIT_WEEKS)
		and not picker.row_locked(CampaignTypeDefs.UNIT_MONTHS)
		and picker.row_locked(CampaignTypeDefs.UNIT_INFINITE), dur.hint_text())
	TestFixtures.check(res, "each unit holds as many of itself as the cap allows",
		CampaignTypeDefs.unit_qty_max(CampaignTypeDefs.UNIT_DAYS, ent) == 30
		and CampaignTypeDefs.unit_qty_max(CampaignTypeDefs.UNIT_WEEKS, ent) == 4
		and CampaignTypeDefs.unit_qty_max(CampaignTypeDefs.UNIT_MONTHS, ent) == 1
		and dur.max_quantity() == 30, "%d days" % [dur.max_quantity()])
	TestFixtures.check(res, "the hint over the stepper names the cap",
		dur.hint_text() == "Up to 30 days" and not dur.stepper_disabled(), dur.hint_text())
	TestFixtures.check(res, "only a unit the cap has not reached carries a lock",
		picker.lock_for(CampaignTypeDefs.UNIT_DAYS) == null
		and picker.lock_for(CampaignTypeDefs.UNIT_INFINITE) != null
		and picker.lock_for(CampaignTypeDefs.UNIT_INFINITE).visible
		and picker.lock_for(CampaignTypeDefs.UNIT_INFINITE).tier == 5, "the Infinite row locks")
	var want_up: ImageTexture = Icons.tinted("caret_up", UnitDropdown.CARET_COLOR, 2, true)
	var want_down: ImageTexture = Icons.tinted("caret_down", UnitDropdown.CARET_COLOR, 2, true)
	picker.open_popup()
	var open_state: bool = picker.popup_open()
	var open_tex: Texture2D = picker.caret.texture
	picker.close_popup()
	var shut_tex: Texture2D = picker.caret.texture
	TestFixtures.check(res, "the unit dropdown caret is a texture",
		picker.caret is TextureRect and shut_tex == want_down
		and open_tex == (want_up if open_state else want_down)
		and want_up.get_size() == Vector2(10, 6) and want_down.get_size() == Vector2(10, 6)
		and want_up != want_down,
		"open %s, shut %s" % [open_state, shut_tex == want_down])
	builder.pick_unit(CampaignTypeDefs.UNIT_MONTHS)
	TestFixtures.check(res, "picking months trims the quantity to the one month the cap holds",
		dur.unit_key() == CampaignTypeDefs.UNIT_MONTHS and dur.quantity() == 1
		and dur.days() == 30 and builder.cost() == 150
		and builder.cost_note_text() == "5 / day x 30 days, all due now" and not builder.chip_shown(),
		builder.cost_note_text())
	builder.pick_unit(CampaignTypeDefs.UNIT_INFINITE)
	TestFixtures.check(res, "the locked Infinite row does not take the field",
		dur.unit_key() == CampaignTypeDefs.UNIT_MONTHS and not dur.is_infinite(),
		String(dur.unit_key()))
	builder.pick_unit(CampaignTypeDefs.UNIT_DAYS)
	builder.set_quantity(5)
	TestFixtures.check(res, "back on days the stepper holds the five it opened with",
		dur.unit_key() == CampaignTypeDefs.UNIT_DAYS and dur.days() == 5
		and builder.cost() == 25, "%d notes" % [builder.cost()])
	builder.press_close()
	TestFixtures.pass_days(11)
	viewer.press_new()
	builder.pick_unit(CampaignTypeDefs.UNIT_MONTHS)
	var gap: int = PromotionsManager.first_bill_days(GameState.day(), 30)
	var bill_on: String = builder.bill_ordinal()
	TestFixtures.check(res, "a month that outruns the first bill pays to that bill now and is billed the rest later",
		gap == 28 and builder.cost() == 5 * gap and builder.cost_text() == "150" and builder.chip_shown()
		and builder.cost_note_text() == "5 / day x 30 days, %d now for %d days to the %s" % [5 * gap, gap, bill_on]
		and builder.chip_label.text == "Billed monthly on the %s" % bill_on,
		"%d days | %s | %d" % [gap, builder.cost_note_text(), builder.cost()])
	builder.press_close()
	_fresh(_ent_with({"maxPromoDays": 10}))
	viewer.press_new()
	TestFixtures.check(res, "a ten day cap keeps months shut and cuts the day count",
		picker.row_locked(CampaignTypeDefs.UNIT_MONTHS)
		and not picker.row_locked(CampaignTypeDefs.UNIT_WEEKS)
		and dur.max_quantity() == 10 and dur.hint_text() == "Up to 10 days", dur.hint_text())
	builder.press_close()
	_fresh(_infinite_ent())
	viewer.press_new()
	builder.pick_type(&"radio")
	builder.pick_unit(CampaignTypeDefs.UNIT_INFINITE)
	TestFixtures.check(res, "an unlimited cap drops the hint and opens the Infinite row",
		dur.hint_text() == DurationControl.NO_LIMIT and dur.is_infinite()
		and dur.quantity() == 1 and dur.days() == 0 and dur.stepper_disabled(),
		dur.hint_text())
	TestFixtures.check(res, "an Infinite run greys the whole stepper out",
		is_equal_approx(dur.quantity_stepper().modulate.a, DurationControl.INFINITE_ALPHA),
		"alpha %.2f" % [dur.quantity_stepper().modulate.a])
	var first: int = PromotionsManager.first_charge(&"radio", GameState.day())
	var first_days: int = PromotionsManager.first_bill_days(GameState.day())
	var on: String = builder.bill_ordinal()
	TestFixtures.check(res, "an Infinite run shows its month, charges the days to its first bill and names the bill day",
		builder.cost() == first and first == 80 * first_days and first == 3120
		and builder.cost_text() == "2,400 / month" and builder.chip_shown()
		and builder.cost_note_text() == "80 / day, %d now for %d days to the %s" % [first, first_days, on]

		and builder.chip_label.text == "Billed monthly on the %s" % on,
		"%s | %s | %d" % [builder.cost_text(), builder.cost_note_text(), builder.cost()])
	builder.pick_unit(CampaignTypeDefs.UNIT_DAYS)
	TestFixtures.check(res, "back on a fixed run the monthly chip and the suffix go",
		not builder.chip_shown() and builder.cost_text() == "80" and builder.cost() == 80
		and dur.quantity() == 1, builder.cost_text())
	TestFixtures.check(res, "back on a fixed run the stepper is drawn at full strength again",
		is_equal_approx(dur.quantity_stepper().modulate.a, 1.0),
		"alpha %.2f" % [dur.quantity_stepper().modulate.a])
	builder.press_close()
	var steps: Array[int] = []
	var step_watcher: Callable = func(qty: int) -> void:
		steps.append(qty)
	dur.quantity_changed.connect(step_watcher)
	dur.set_ent({"maxPromoDays": 7})
	dur.set_quantity(30)
	TestFixtures.check(res, "a quantity over the cap is pulled down to the cap as it is set",
		dur.quantity() == 7 and dur.days() == 7 and int(dur.quantity_stepper().value) == 7,
		"%d days on the stepper %d" % [dur.quantity(), int(dur.quantity_stepper().value)])
	dur.set_ent({"maxPromoDays": 3})
	TestFixtures.check(res, "a cap that drops under the standing quantity pulls it down too",
		dur.quantity() == 3 and dur.days() == 3 and int(dur.quantity_stepper().value) == 3,
		"%d days on the stepper %d" % [dur.quantity(), int(dur.quantity_stepper().value)])
	dur.set_quantity(0)
	TestFixtures.check(res, "a quantity under the floor is lifted to the shortest run",
		dur.quantity() == CampaignTypeDefs.MIN_DAYS, "%d days" % [dur.quantity()])
	dur.quantity_changed.disconnect(step_watcher)
	TestFixtures.check(res, "fitting the quantity to the cap sends no quantity signal",
		steps.is_empty(), "%s" % [steps])


#Case 10: the merc filters a job ad targets with.
static func _case_job_target(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	var panel: TraitFilterPanel = builder.job_panel()
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs(false)
	var keys: Array[StringName] = []
	for def: Dictionary in defs:
		keys.append(StringName(def["key"]))
	var built: Array[StringName] = []
	for section: FilterSection in panel.sections():
		built.append(section.def_key())
	TestFixtures.check(res, "the job ad targets mercs through the builder filter set",
		built == keys and keys.size() == defs.size() and keys[0] == &"salary"
		and keys[keys.size() - 1] == &"wile", "%d rows" % [built.size()])
	TestFixtures.check(res, "the panel says a job ad cannot ask for a level",
		panel.footer_note == CampaignBuilder.JOB_NOTE and panel.active_total() == 0,
		panel.footer_note)
	var sdef: Dictionary = TraitFilterDefs.find(defs, &"salary")
	var step: float = float(sdef["step"])
	var low: float = step * 2.0
	var high: float = float(sdef["max"]) - step
	builder.set_filter_value(&"salary", [low, high])
	var held: Variant = panel.value_of("salary")
	var pair: Array = held if held is Array else []
	TestFixtures.check(res, "a salary band the reader sets reaches the panel",
		pair.size() == 2 and is_equal_approx(float(pair[0]), low)
		and is_equal_approx(float(pair[1]), high) and panel.active_total() == 1,
		"%s" % [pair])
	var draft: Variant = builder.draft().filters.get(&"salary", null)
	var sent: Array = draft if draft is Array else []
	TestFixtures.check(res, "the draft carries the band the campaign goes out with",
		sent.size() == 2 and is_equal_approx(float(sent[0]), low)
		and is_equal_approx(float(sent[1]), high), "%s" % [sent])
	TestFixtures.check(res, "a row the plan has not paid for stays locked and counts nothing",
		panel.section_for("ancestry").is_locked()
		and TraitFilterDefs.locked(TraitFilterDefs.find(defs, &"ancestry"),
			SubscriptionManager.entitlements()), "ancestry is locked")
	panel.press_clear()
	TestFixtures.check(res, "Clear puts every row back to the value that filters nothing",
		panel.active_total() == 0 and builder.draft().filters.has(&"salary"),
		"%d rows active" % [panel.active_total()])
	builder.press_close()
	_fresh(_ent_with({"hiringDiscrim": true}))
	viewer.press_new()
	TestFixtures.check(res, "the same row opens once the plan carries it",
		not builder.job_panel().section_for("ancestry").is_locked(),
		"ancestry is open")
	builder.press_close()


#Case 11: who a Guild Promo campaign reaches, and the rows the plan or the law shuts.
static func _case_guild_target(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	var guild: GuildTargeting = builder.guild_panel()
	TestFixtures.check(res, "a Flyers promo asks for no sponsor and can go out as it stands",
		guild.section_keys() == [GuildTargeting.DIFF_KEY, GuildTargeting.TYPE_KEY,
		GuildTargeting.LOC_KEY] and guild.section_for(GuildTargeting.TARGET_KEY) == null
		and builder.launch_enabled(), "%s" % [guild.section_keys()])
	TestFixtures.check(res, "the panel says a promo cannot ask for a level or a reward",
		guild.note_text() == GuildTargeting.NOTE_TEXT, guild.note_text())
	builder.pick_type(&"direct")
	TestFixtures.check(res, "Direct Sale asks who to advertise to before it can launch",
		guild.section_for(GuildTargeting.TARGET_KEY) != null and not guild.has_target()
		and builder.reason_text() == "Choose who to advertise to.", builder.reason_text())
	builder.pick_target([TraitFilterDefs.name_at("Company", 0)])
	TestFixtures.check(res, "picking the company clears the reason and rides in the draft",
		guild.has_target() and guild.target_index() == 0 and builder.reason_text() == ""
		and builder.draft().sponsor_target == TraitFilterDefs.name_at("Company", 0),
		guild.target_text())
	builder.pick_target([TraitFilterDefs.name_at("Company", 2),
		TraitFilterDefs.name_at("Company", 0), TraitFilterDefs.name_at("Company", 4)])
	TestFixtures.check(res, "Direct Sale takes every company it is handed",
		guild.target_keys() == ["Company 1", "Company 3", "Company 5"]
		and guild.target_indices() == [0, 2, 4]
		and guild.target_text() == "Company 1, Company 3, Company 5", guild.target_text())
	builder.pick_target([TraitFilterDefs.name_at("Company", 4),
		TraitFilterDefs.name_at("Company", 0)])
	var multi: CampaignData = builder.draft()
	TestFixtures.check(res, "dropping one company leaves two ascending indices in the draft",
		multi.advertise_targets == [0, 4] and multi.sponsor_index == 0
		and multi.sponsor_target == "Company 1, Company 5"
		and multi.advertise_to == CampaignData.TO_COMPANY, multi.sponsor_target)
	guild.set_sel(multi.filters)
	guild.setup(&"direct", SubscriptionManager.entitlements())
	TestFixtures.check(res, "reopening the panel on that draft restores both picks",
		guild.has_target() and guild.target_indices() == [0, 4]
		and builder.draft().advertise_targets == [0, 4], "%s" % [guild.target_indices()])
	builder.pick_type(&"sponsor")
	TestFixtures.check(res, "Sponsorship asks for its sponsor and takes one place only",
		builder.reason_text() == "Choose who to sponsor."
		and guild.tile_for(GuildTargeting.LOC_KEY, 0).single, builder.reason_text())
	builder.pick_target([TraitFilterDefs.name_at("Company", 1),
		TraitFilterDefs.name_at("Company", 3)])
	TestFixtures.check(res, "Sponsorship keeps the last of several picks",
		guild.target_keys() == ["Company 4"] and guild.target_indices() == [3]
		and builder.draft().advertise_targets == [3], guild.target_text())
	builder.pick_type(&"direct")
	TestFixtures.check(res, "switching the method drops every target pick",
		not guild.has_target() and guild.target_indices().is_empty()
		and builder.draft().advertise_targets.is_empty()
		and builder.reason_text() == "Choose who to advertise to.", builder.reason_text())
	builder.pick_type(&"radio")
	TestFixtures.check(res, "Radio marks the towns no mast reaches",
		guild.tile_for(GuildTargeting.LOC_KEY, 0).is_blocked()
		and guild.tile_for(GuildTargeting.LOC_KEY, 0).disabled_reason
		== GuildTargeting.NO_RADIO
		and not guild.tile_for(GuildTargeting.LOC_KEY, 2).is_blocked(),
		guild.tile_for(GuildTargeting.LOC_KEY, 0).disabled_reason)
	builder.pick_type(&"flyers")
	TestFixtures.check(res, "a town with no Operations Permit is marked as well",
		guild.tile_for(GuildTargeting.LOC_KEY, 1).is_blocked()
		and guild.tile_for(GuildTargeting.LOC_KEY, 1).disabled_reason
		== TraitFilterDefs.NO_PERMIT_NOTE
		and not guild.tile_for(GuildTargeting.LOC_KEY, 0).is_blocked(),
		guild.tile_for(GuildTargeting.LOC_KEY, 1).disabled_reason)
	builder.toggle_location(0)
	TestFixtures.check(res, "a picked town reaches the panel and the draft",
		guild.locations() == [0] and builder.draft().locations == [0]
		and builder.launch_enabled(), "%s" % [guild.locations()])
	var defs: Array[Dictionary] = TraitFilterDefs.contract_defs(&"flyers")
	var ent: Dictionary = SubscriptionManager.entitlements()
	var band: Array = TraitFilterDefs.find(defs, GuildTargeting.DIFF_KEY).get("row_locks", [])
	TestFixtures.check(res, "both difficulty rows stay locked until the tiers are bought",
		band.size() == 2 and TraitFilterDefs.locked(band[0], ent)
		and TraitFilterDefs.locked(band[1], ent), "%d rows" % [band.size()])
	TestFixtures.check(res, "the contract type row stays locked as well",
		guild.section_for(GuildTargeting.TYPE_KEY).is_locked()
		and TraitFilterDefs.locked(TraitFilterDefs.find(defs, GuildTargeting.TYPE_KEY), ent),
		"the type row is locked")
	builder.press_close()
	viewer.open_tab(PromotionsViewer.JOB_KEY)


#Case 12: the Word of Mouth crew, the seats Odd Jobs sells and the pay it takes.
static func _case_crew(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	TestFixtures.add_mercs(CREW_ROSTER - GameState.mercs.size())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	builder.pick_type(&"wom")
	var crew: OddJobCrew = builder.crew_module()
	var rows: Array[Dictionary] = crew.candidates
	TestFixtures.check(res, "Word of Mouth puts the crew block up with the seats Odd Jobs sells",
		builder.crew_shown() and crew.max_mercs == 2 and not crew.locked
		and rows.size() >= 3, "%d mercs to pick from" % [rows.size()])
	TestFixtures.check(res, "an empty crew cannot go out and costs nothing",
		builder.reason_text() == "Add at least one merc." and builder.cost() == 0
		and builder.cost_note_text() == CampaignBuilder.COST_WOM, builder.reason_text())
	var one: Array[int] = [int(rows[0]["id"])]
	builder.set_crew(one, PromotionsManager.default_pay())
	TestFixtures.check(res, "one merc at the standard pay prices the whole campaign",
		builder.cost() == 25 and builder.reason_text() == "" and not builder.chip_shown()
		and builder.draft().crew == one, "%d notes" % [builder.cost()])
	var three: Array[int] = [int(rows[0]["id"]), int(rows[1]["id"]), int(rows[2]["id"])]
	builder.set_crew(three, PromotionsManager.default_pay())
	TestFixtures.check(res, "a crew over the seats Odd Jobs holds loses the extra seat",
		crew.team.size() == 2 and builder.draft().crew.size() == 2 and builder.cost() == 50
		and builder.reason_text() == "", "%d seats" % [builder.draft().crew.size()])
	var two: Array[int] = [three[0], three[1]]
	builder.set_crew(two, 40)
	TestFixtures.check(res, "a full crew at a raised pay prices every seat",
		builder.cost() == 80 and builder.reason_text() == ""
		and builder.draft().pay_per == 40, "%d notes" % [builder.cost()])
	builder.press_close()
	_fresh(_ent_with({"oddJobs": 0}))
	viewer.press_new()
	builder.pick_type(&"wom")
	TestFixtures.check(res, "with no Odd Job seats the method itself stays shut",
		builder.type_row(&"wom").is_locked() and builder.type_key() == &"flyers"
		and not builder.crew_shown(), String(builder.type_key()))
	builder.press_close()


#Case 13: every reason the footer gives for a campaign that cannot go out.
static func _case_reasons(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	TestFixtures.check(res, "nothing to launch and an unknown method each say so",
		_why(null) == "No campaign."
		and _why(GuiPromoTests._campaign(&"nope", CampaignData.MODE_JOB, 5)) == "Unknown campaign type.",
		_why(GuiPromoTests._campaign(&"nope", CampaignData.MODE_JOB, 5)))
	TestFixtures.check(res, "a guild-only method refuses a job ad",
		_why(GuiPromoTests._campaign(&"direct", CampaignData.MODE_JOB, 5))
		== "Direct Sale is for Guild Promo only.",
		_why(GuiPromoTests._campaign(&"direct", CampaignData.MODE_JOB, 5)))
	var short_run: CampaignData = GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 0)
	var long_run: CampaignData = GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 40)
	TestFixtures.check(res, "a run of no days and a run past the cap both refuse",
		_why(short_run) == "A promo runs at least 1 day."
		and _why(long_run) == "Promos run up to 30 days.", _why(long_run))
	var radio: CampaignData = GuiPromoTests._campaign(&"radio", CampaignData.MODE_PROMO, 5)
	radio.locations.assign([0])
	var far: CampaignData = GuiPromoTests._campaign(&"flyers", CampaignData.MODE_PROMO, 5)
	far.locations.assign([1])
	TestFixtures.check(res, "a town with no mast and a town with no permit both refuse",
		_why(radio) == "Radio cannot reach Buern."
		and _why(far) == "No Operations Permit in Aerdis.", _why(far))
	var sponsor: CampaignData = GuiPromoTests._campaign(&"sponsor", CampaignData.MODE_PROMO, 5)
	TestFixtures.check(res, "a sponsorship asks for its sponsor first",
		_why(sponsor) == "Choose who to sponsor.", _why(sponsor))
	sponsor.sponsor_target = TraitFilterDefs.name_at("Company", 0)
	sponsor.locations.assign([0, 2])
	TestFixtures.check(res, "and then takes one place only",
		_why(sponsor) == "Sponsorship takes one location.", _why(sponsor))
	var band: CampaignData = GuiPromoTests._campaign(&"flyers", CampaignData.MODE_PROMO, 5)
	band.difficulty_lo = 2.5
	var types: CampaignData = GuiPromoTests._campaign(&"flyers", CampaignData.MODE_PROMO, 5)
	types.contract_types.assign([ContractLibrary.contract_type_names()[0]])
	TestFixtures.check(res, "a Guild Promo field the plan has not bought has to stay put",
		_why(band) == "Minimum Difficulty is locked."
		and _why(types) == "Contract Type is locked.", _why(band))
	var crew: CampaignData = GuiPromoTests._campaign(&"wom", CampaignData.MODE_JOB, 5)
	crew.pay_per = 25
	var packed: CampaignData = GuiPromoTests._campaign(&"wom", CampaignData.MODE_JOB, 5)
	packed.pay_per = 25
	packed.crew.assign([1, 2, 3])
	TestFixtures.check(res, "a crew campaign needs a crew and cannot oversell its seats",
		_why(crew) == "Add at least one merc."
		and _why(packed) == "Odd Jobs holds 2 mercs.", _why(packed))
	var bank: int = GameState.bank_notes
	GameState.bank_notes = 0
	TestFixtures.check(res, "an empty bank is the last reason a fixed run refuses",
		_why(GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 5)) == "Not enough notes.",
		_why(GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 5)))
	GameState.bank_notes = bank
	TestFixtures.check(res, "a campaign the plan carries gives no reason at all",
		_why(GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 5)) == ""
		and bool(PromotionsManager.can_launch(
			GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 5))["ok"]), "the launch is clear")
	_fresh(_ent_with({"maxPromoDays": 0}))
	TestFixtures.check(res, "with no duration at all the whole promo is locked",
		_why(GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 5)) == "Promos are locked.",
		_why(GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 5)))
	_fresh(_ent_with({"maxPromoDays": 5}))
	var weekly: CampaignData = GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 7)
	weekly.unit_key = CampaignTypeDefs.UNIT_WEEKS
	TestFixtures.check(res, "a unit the cap has not reached names itself in the reason",
		_why(weekly) == "Weeks promos are locked.", _why(weekly))
	_fresh(_ent_with({"jobPostings": false}))
	TestFixtures.check(res, "a tab the guild has not bought refuses its own campaigns",
		_why(GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 5)) == "Job Postings are locked.",
		_why(GuiPromoTests._campaign(&"flyers", CampaignData.MODE_JOB, 5)))
	_fresh(_ent_with({"guildPromo": false}))
	TestFixtures.check(res, "and so does the Guild Promo side",
		_why(GuiPromoTests._campaign(&"flyers", CampaignData.MODE_PROMO, 5)) == "Guild Promotion is locked.",
		_why(GuiPromoTests._campaign(&"flyers", CampaignData.MODE_PROMO, 5)))
	_fresh(_ent_with({"oddJobs": 0}))
	var shut: CampaignData = GuiPromoTests._campaign(&"wom", CampaignData.MODE_JOB, 5)
	shut.crew.assign([1])
	shut.pay_per = 25
	TestFixtures.check(res, "a method the guild has not bought names itself first",
		_why(shut) == "Word of Mouth is locked.", _why(shut))


#Case 14: launching from the builder adds the card, takes the notes and says so.
static func _case_launch(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	var sink := Sink.new()
	viewer.campaign_launched.connect(sink.on_launched)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	builder.press_launch()
	TestFixtures.check(res, "launching closes the builder and takes the price out of the bank",
		not builder.is_open() and GameState.bank_notes == BANK - 25,
		"bank %d" % [GameState.bank_notes])
	TestFixtures.check(res, "the new campaign takes the next number and stands on the panel",
		viewer.card_count() == 1 and viewer.card_names().has(FIRST_NEW_NAME)
		and viewer.shown_text() == "1 of 1 shown", viewer.shown_text())
	TestFixtures.check(res, "the screen says the campaign went out",
		viewer.notice_shown() and viewer.notice_text() == "%s launched." % FIRST_NEW_NAME,
		viewer.notice_text())
	TestFixtures.check(res, "the screen reports the launch to whoever is listening",
		sink.ids == [FIRST_NEW_ID], "%s" % [sink.ids])
	var made: CampaignData = PromotionsManager.campaign_of(FIRST_NEW_ID)
	TestFixtures.check(res, "the stored campaign carries its price, its run and today",
		made != null and made.total_cost == 25 and made.days == 5
		and made.day_started == GameState.day() and made.mode == CampaignData.MODE_JOB
		and made.is_launched(), "%s" % [made.name if made != null else "nothing"])
	viewer.press_new()
	builder.set_campaign_name("Spring Push")
	builder.press_launch()
	TestFixtures.check(res, "a named campaign keeps its name on the card and in the notice",
		viewer.card_names().has("Spring Push") and viewer.card_count() == 2
		and viewer.notice_text() == "Spring Push launched."
		and GameState.bank_notes == BANK - 50, viewer.notice_text())
	TestFixtures.check(res, "both launches reported once each",
		sink.ids.size() == 2 and sink.ids[1] == FIRST_NEW_ID + 1, "%s" % [sink.ids])
	viewer.campaign_launched.disconnect(sink.on_launched)
	_fresh(_infinite_ent())
	viewer.press_new()
	builder.pick_type(&"radio")
	builder.pick_unit(CampaignTypeDefs.UNIT_INFINITE)
	builder.press_launch()
	var forever: CampaignData = PromotionsManager.campaign_of(FIRST_NEW_ID)
	TestFixtures.check(res, "an Infinite launch pays the days to its first bill and waits on that bill",
		forever != null and forever.infinite and GameState.bank_notes == BANK - 3120
		and forever.next_bill_day == 161 and forever.bill_day == FinanceManager.bill_day_from(GameState.day())
		and forever.next_bill_day == TrynnCalendar.next_day_on(GameState.day(), forever.bill_day),
		"bank %d, bill day %d" % [GameState.bank_notes, forever.next_bill_day if forever != null else -1])



#Case 15: the icons of the window, read off the sheet in the three tones the screen draws.
static func _case_glyphs(res: Dictionary, viewer: PromotionsViewer) -> void:
	Icons.clear_cache()
	var off: String = ""
	var ids: Array[String] = []
	for key: StringName in CampaignTypeDefs.keys():
		var id: String = PromoGlyphs.type_id(key)
		ids.append(id)
		if not Icons.has(id):
			off += String(key) + " "
	TestFixtures.check(res, "every method icon is the art file its table row names",
		off == "" and ids == ["wom", "flyers", "direct_sale", "radio", "sponsorship"],
		"off the sheet: %s, ids %s" % [off, ids])
	TestFixtures.check(res, "a resting tab icon is the art file of that tab",
		PromoGlyphs.tab_id(PromotionsViewer.JOB_KEY) == "job_ads"
		and PromoGlyphs.tab_id(PromotionsViewer.PROMO_KEY) == "guild_ads"
		and Icons.has(PromoGlyphs.tab_id(PromotionsViewer.JOB_KEY))
		and Icons.has(PromoGlyphs.tab_id(PromotionsViewer.PROMO_KEY)),
		"%s and %s" % [PromoGlyphs.tab_id(PromotionsViewer.JOB_KEY),
			PromoGlyphs.tab_id(PromotionsViewer.PROMO_KEY)])
	var big: Texture2D = PromoGlyphs.type_icon(&"radio", 4)
	TestFixtures.check(res, "a scaled icon grows by whole pixels",
		big != null and big.get_width() == PromoGlyphs.ICON_SIDE * 4
		and big.get_height() == PromoGlyphs.ICON_SIDE * 4,
		"%d by %d, want 64" % [big.get_width(), big.get_height()])
	var dim: Image = PromoGlyphs.type_icon(&"wom", 1, true).get_image()
	var grey: bool = true
	var lit: int = 0
	for y: int in dim.get_height():
		for x: int in dim.get_width():
			var px: Color = dim.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			lit += 1
			grey = grey and is_equal_approx(px.r, px.g) and is_equal_approx(px.g, px.b)
	TestFixtures.check(res, "a concluded card draws its icon in grey alone",
		grey and lit > 0 and PromoGlyphs.dim_modulate(true) == Color(0.6, 0.6, 0.6, 1.0)
		and PromoGlyphs.dim_modulate(false) == Color.WHITE,
		"%d lit pixels, dim %s" % [lit, PromoGlyphs.dim_modulate(true)])
	var on: Image = Icons.baked("guild_ads", 1, Icons.MODE_TWO_TONE).get_image()
	var ink: int = 0
	var rest: int = 0
	var stray: int = 0
	for y: int in on.get_height():
		for x: int in on.get_width():
			var px: Color = on.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			if _tone_is(px, Icons.TAB_ON_INK):
				ink += 1
			elif _tone_is(px, Icons.TAB_ON_LIGHT) or _tone_is(px, Icons.TAB_ON_MID):
				rest += 1
			else:
				stray += 1
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	var job_tab: TabButton = viewer.tab_button(PromotionsViewer.JOB_KEY)
	var guild_tab: TabButton = viewer.tab_button(PromotionsViewer.PROMO_KEY)
	var guild_two: bool = guild_tab.icon_rect.mode == Icons.MODE_TWO_TONE
	var guild_on: bool = guild_two and job_tab.icon_rect.mode == Icons.MODE_PLAIN
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	var job_two: bool = job_tab.icon_rect.mode == Icons.MODE_TWO_TONE
	var job_on: bool = job_two and guild_tab.icon_rect.mode == Icons.MODE_PLAIN
	TestFixtures.check(res, "an active tab draws in the two dark tones and nothing else",
		stray == 0 and ink > 0 and rest > 0 and guild_on and job_on,
		"%d ink, %d rest, %d stray, guild %s, job %s" % [ink, rest, stray, guild_on, job_on])
	TestFixtures.check(res, "an icon asked for twice is built once",
		PromoGlyphs.type_icon(&"wom") == PromoGlyphs.type_icon(&"wom")
		and Icons.baked("job_ads", 2, Icons.MODE_TWO_TONE)
		== Icons.baked("job_ads", 2, Icons.MODE_TWO_TONE),
		"the cache hands one texture back")


#The colour of one pixel, alpha aside, read against one tone of the palette.
static func _tone_is(px: Color, want: Color) -> bool:
	return absf(px.r - want.r) <= TONE_SLACK and absf(px.g - want.g) <= TONE_SLACK \
			and absf(px.b - want.b) <= TONE_SLACK


static func _why(campaign: CampaignData) -> String:
	return GuiPromoTests._reason(PromotionsManager.can_launch(campaign))


#Catches the launches the screen reports.
class Sink extends RefCounted:
	var ids: Array[int] = []

	func on_launched(campaign: CampaignData) -> void:
		ids.append(campaign.id)


#The New, View Applicants and Launch buttons of the window are all BevelButton and shade
#with the tab and the state they are in.
static func _case_bevel_sweep(res: Dictionary, viewer: PromotionsViewer) -> void:
	_fresh(_full_ent())
	lay_board()
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	var new_bevel: BevelButton = viewer.campaign_list().new_button
	TestFixtures.check(res, "the New Hiring Campaign button is an orange BevelButton",
		new_bevel != null and new_bevel.kind == &"orange"
		and new_bevel.text == CampaignList.NEW_JOB, "%s: %s" % [new_bevel, new_bevel.text])
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	TestFixtures.check(res, "the same button keeps its orange shade on the Guild Promo tab",
		new_bevel.kind == &"orange" and new_bevel.text == CampaignList.NEW_PROMO,
		new_bevel.text)
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	var card: CampaignCard = viewer.campaign_list().card_for(FIXED_ID)
	var view_bevel: BevelButton = card.view_button
	TestFixtures.check(res, "a job card's View Applicants button is a blue BevelButton",
		view_bevel != null and view_bevel.kind == &"blue"
		and view_bevel.text == CampaignCard.VIEW_TEXT, "%s: %s" % [view_bevel, view_bevel.text])
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	var launch_bevel: BevelButton = builder.launch_button
	TestFixtures.check(res, "the builder's Launch button is a go BevelButton, enabled by default",
		launch_bevel != null and launch_bevel.kind == &"go"
		and launch_bevel.text == CampaignBuilder.LAUNCH_TEXT and not launch_bevel.disabled,
		"%s disabled %s" % [launch_bevel, launch_bevel.disabled])
	builder.pick_type(&"wom")
	TestFixtures.check(res, "a blocked reason disables the Launch button and dims its own shade",
		launch_bevel.disabled and not builder.launch_enabled(),
		"reason: %s" % [builder.reason_text()])
	builder.press_close()


#The window rect of a HUD viewer and the close X inside its top right corner.
const CANVAS: Rect2 = Rect2(0.0, 0.0, 1280.0, 644.0)
const X_RECT: Rect2 = Rect2(1280.0 - 10.0 - 36.0, 10.0, 36.0, 36.0)


#Lays a viewer on the HUD band the way a SubWindow does: top left, 1280 x 644.
static func fit_band(viewer: Control) -> void:
	viewer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	viewer.position = Vector2.ZERO
	viewer.size = CANVAS.size


#Every shown control under root whose rect leaves the canvas. A ScrollContainer or a clipping
#control hides what it holds past its rect, and a CanvasLayer is a dialog layer, so the walk stops.
static func out_of_canvas(root: Node) -> Array[String]:
	var out: Array[String] = []
	_walk_out(root, out)
	return out


static func _walk_out(node: Node, out: Array[String]) -> void:
	if node is CanvasLayer:
		return
	var control: Control = node as Control
	if control != null:
		if not control.is_visible_in_tree():
			return
		if not CANVAS.grow(0.5).encloses(control.get_global_rect()):
			out.append("%s %s" % [control.name, control.get_global_rect()])
			return
		if control is ScrollContainer or control.clip_contents:
			return
	for child: Node in node.get_children():
		_walk_out(child, out)


#The root and each direct control child of it asks for no more than the canvas.
static func min_fits(root: Control) -> bool:
	if not _min_ok(root.get_combined_minimum_size()):
		return false
	for child: Node in root.get_children():
		var control: Control = child as Control
		if control != null and control.visible and not _min_ok(control.get_combined_minimum_size()):
			return false
	return true


static func _min_ok(value: Vector2) -> bool:
	return value.x <= CANVAS.size.x + 0.5 and value.y <= CANVAS.size.y + 0.5


#The shown children of a top row whose rect meets the close X.
static func x_hits(row: Control) -> Array[String]:
	var out: Array[String] = []
	for child: Node in row.get_children():
		var control: Control = child as Control
		if control == null or control.name == &"CloseReserve":
			continue
		if control.is_visible_in_tree() and control.get_global_rect().intersects(X_RECT):
			out.append(String(control.name))
	return out


#One tab of a viewer on the band: the minimum fits, nothing leaves the canvas, the page root is
#no ScrollContainer and no top row control meets the close X.
static func check_fit(res: Dictionary, label: String, viewer: Control, page: Node, rows: Array) -> void:
	var mins: Array[String] = []
	for child: Node in viewer.get_children():
		var control: Control = child as Control
		if control != null and control.visible:
			mins.append("%s %s" % [control.name, control.get_combined_minimum_size()])
	var fits: bool = min_fits(viewer)
	TestFixtures.check(res, "%s asks for no more than 1280 x 644" % label, fits, ", ".join(mins))
	var out: Array[String] = out_of_canvas(viewer)
	TestFixtures.check(res, "%s keeps every control on the canvas" % label, out.is_empty(), str(out))
	TestFixtures.check(res, "%s has no ScrollContainer as its page root" % label,
		page != null and not (page is ScrollContainer), str(page))
	var hits: Array[String] = []
	for row: Control in rows:
		hits.append_array(x_hits(row))
	TestFixtures.check(res, "%s keeps the top row clear of the close X" % label, hits.is_empty(), str(hits))


static func _case_fit(res: Dictionary, viewer: PromotionsViewer, host: Node) -> void:
	_fresh(_full_ent())
	lay_board()

	fit_band(viewer)
	var body: Control = viewer.get_node("Body") as Control
	var tabs: Control = viewer.get_node("Body/Rows/Tabs") as Control
	var rows: Array = [tabs, viewer.get_node("Body/Rows/Head")]
	for key: StringName in [PromotionsViewer.JOB_KEY, PromotionsViewer.PROMO_KEY]:
		viewer.open_tab(key)
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		check_fit(res, "Promotions %s" % key, viewer, body, rows)
		_check_strip(res, "Promotions %s" % key, viewer, tabs, key)


#The tab strip owns the free width of its row, so the live tab can widen to hold its icon and label.
static func _check_strip(res: Dictionary, label: String, viewer: PromotionsViewer, tabs: Control,
		key: StringName) -> void:
	var strip: TabStrip = viewer.tab_strip
	var reserve: Control = tabs.get_node("CloseReserve") as Control
	var tab: TabButton = viewer.tab_button(key)
	var inner: Control = tab.get_node("Row") as Control
	TestFixtures.check(res, "%s tab strip expands and stands as tall as the live tab" % label,
		strip.size_flags_horizontal == Control.SIZE_EXPAND_FILL
		and is_equal_approx(strip.custom_minimum_size.y, float(TabButton.ACTIVE_HEIGHT)),
		"flags %d min %s" % [strip.size_flags_horizontal, strip.custom_minimum_size])
	var need: float = inner.get_combined_minimum_size().x
	TestFixtures.check(res, "%s live tab is as wide as its icon and label" % label,
		tab.size.x + EDGE_SLACK >= need and tab.size.x > TabButton.IDLE_SIZE.x,
		"tab %s needs %s" % [tab.size.x, need])
	var strip_end: float = strip.get_global_rect().end.x
	TestFixtures.check(res, "%s tab strip ends left of the close reserve" % label,
		strip_end <= reserve.get_global_rect().position.x
		and tab.get_global_rect().end.x <= strip_end + EDGE_SLACK,
		"strip ends %s, reserve starts %s" % [strip_end, reserve.get_global_rect().position.x])


#Case 16: the builder with its layout settled; each type row holds its text and the footer sits right.
static func _case_builder_fit(res: Dictionary, viewer: PromotionsViewer, host: Node) -> void:
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var tall: Array[String] = []
	var spill: Array[String] = []
	for row: TypeRow in builder.type_rows():
		var need: float = row.texts.get_combined_minimum_size().y + row.body.offset_top \
			- row.body.offset_bottom
		if need > row.size.y:
			tall.append("%s needs %s of %s" % [row.key(), need, row.size.y])
		var inside: Rect2 = row.get_global_rect().grow_individual(0.0, -row.body.offset_top, 0.0,
			row.body.offset_bottom)
		if not inside.encloses(row.stars.get_global_rect()):
			spill.append("%s stars %s in %s" % [row.key(), row.stars.get_global_rect(), inside])
	TestFixtures.check(res, "every type row is tall enough for its name, line and stars",
		builder.type_rows().size() == CampaignTypeDefs.TYPES.size() and tall.is_empty(), str(tall))
	TestFixtures.check(res, "the quality stars of every type row stay inside the row",
		spill.is_empty(), str(spill))
	var footer: Control = builder.launch_button.get_parent() as Control
	TestFixtures.check(res, "the Launch button ends on the right edge of the footer",
		absf(builder.launch_button.get_global_rect().end.x - footer.get_global_rect().end.x) <= EDGE_SLACK,
		"launch %s footer %s" % [builder.launch_button.get_global_rect(), footer.get_global_rect()])
	builder.press_close()


#Case 17: the Guild Promo builder with its layout settled; the frame, the guild columns and the tiles fit.
static func _case_guild_builder_fit(res: Dictionary, viewer: PromotionsViewer, host: Node) -> void:
	_fresh(_full_ent())
	viewer.open_tab(PromotionsViewer.PROMO_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	var guild: GuildTargeting = builder.guild_panel()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var frame_rect: Rect2 = builder.frame.get_global_rect()
	TestFixtures.check(res, "the guild builder fits the window",
		frame_rect.end.x <= CANVAS.end.x + EDGE_SLACK,
		"frame %s, widest %s" % [frame_rect, GuiAcceptTests.widest_chain(builder.frame, true)])
	#The pane grows with the columns it holds, so the room is read at the frame's designed width.
	var grown: float = maxf(0.0, builder.frame.size.x - CampaignBuilder.MODAL_SIZE.x)
	var room: float = guild.size.x - grown
	var need: float = guild.columns.get_combined_minimum_size().x
	TestFixtures.check(res, "the guild columns fit the pane that holds them",
		need <= room + EDGE_SLACK,
		"columns need %s of %s, widest %s" % [need, room, GuiAcceptTests.widest_chain(guild.columns, true)])
	var tile: ModuleTile = guild.tile_for(GuildTargeting.LOC_KEY, 0)
	TestFixtures.check(res, "a guild module tile keeps its square",
		tile != null and tile.size == Vector2(ModuleTile.TILE_SIDE, ModuleTile.TILE_SIDE),
		"size %s" % (str(tile.size) if tile != null else "missing"))
	builder.press_close()


#The z a node draws at: its own z_index plus each relative ancestor's, up to the first top level node.
static func canvas_z(node: CanvasItem) -> int:
	var total: int = 0
	var cur: CanvasItem = node
	while cur != null:
		total += cur.z_index
		if cur.top_level or not cur.z_as_relative:
			break
		cur = cur.get_parent() as CanvasItem
	return total
