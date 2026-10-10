class_name GuiPromoTests

#PromotionsManager, CampaignTypeDefs and TraitFilterDefs: the campaign table and its gates, the
#effect and duration rules, the filter rows and their locks, an empty reset, the card
#stats, the campaign list, the Hiring filters and sorts, launching, monthly billing, ending with
#a refund, the ledger row of every charge, the permit gate, the away rows of both crews, hiring,
#counter-offers and what a new day brings. Campaigns go out through the real launch and days pass
#through TestFixtures.pass_days, so every bill, arrival and answer lands on the real day tick.


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	_case_types(res)
	_case_effect(res)
	_case_fit_locations(res)
	_case_duration(res)
	_case_merc_defs(res)
	_case_contract_defs(res)
	_case_arrivals(res)
	_case_card_stats(res)
	_case_list(res)
	_case_filters(res)
	_case_launch(res)
	_case_launch_rules(res)
	_case_end_refund(res)
	_case_infinite_billing(res)
	_case_finance(res)
	_case_view_applicants(res)
	_case_hire(res)
	_case_counter(res)
	_case_day_tick(res)
	_case_ledger(res)
	_case_permit_gate(res)
	_case_away_rows(res)
	_case_hired_merc(res)
	_case_counter_hire(res)
	_case_restore_holds(res)
	_case_tick_restore(res)
	_case_busy_crew(res)
	await _case_view_contracts(res)
	await _case_promo_contracts(res)
	await _case_reopen_promotions(res, host)
	await _case_reopen_applicants(res, host)
	await _case_builder_time_hold(res, host)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.max_out()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI PROMO")


#Where the salary range is cut: the ask of the applicant this many places up from the cheapest.
const CHEAP_RANK := 2
const ROUND_SEED := 9
const AGE_LOW := 16
const AGE_HIGH := 30
#The prefix the old placeholder names carried; no rolled merc name may start with it.
const PLACEHOLDER_NAME := "FirstName"
#The merc filter rows the campaign builder offers, in order, and the six only applicant review adds.
const BUILDER_ROWS: Array[String] = ["salary", "tradition", "ancestry", "vigor", "speed", "dexterity",
	"cognition", "wile"]
const REVIEW_ONLY_ROWS: Array[String] = ["bloodline", "heritage", "criminality", "age", "knowledges",
	"tools"]
#The place whose operations and tele permits _fresh grants beside the starting one.
const SECOND_PERMIT := 2
const PROMOTIONS_VIEWER := "res://Scenes/GUI/Promotions/PromotionsViewer.tscn"


#Every case starts bare: Enterprise with no upgrade tier and no override, plus the starting permit,
#a second permit at SECOND_PERMIT and an empty campaign board.
static func _fresh(ent: Dictionary = {}) -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	TestFixtures.fix_applicant_seed()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	if not ent.is_empty():
		SubscriptionManager.set_entitlements(ent)
	LegalManager.reset()
	LegalManager.permits[SECOND_PERMIT] = {"ops": true, "tele": true}
	LegalManager.permits_changed.emit()
	PromotionsManager.reset()


#The New Campaign builder holds campaign time while it is open: paused on open, the old speed back on close and on free.
static func _case_builder_time_hold(res: Dictionary, host: Node) -> void:
	_fresh(_launch_ent())
	var viewer: PromotionsViewer = (load(PROMOTIONS_VIEWER) as PackedScene).instantiate() as PromotionsViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	var ticking: bool = GameState.clock.is_processing()
	GameState.clock.set_process(false)
	GameState.set_speed(ClockRunner.Speed.PLAY)
	TestFixtures.check(res, "the closed campaign builder holds no time",
		not GameState.is_time_held() and GameState.clock.speed == ClockRunner.Speed.PLAY,
		"held %s speed %d" % [GameState.is_time_held(), GameState.clock.speed])
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	TestFixtures.check(res, "the open campaign builder pauses time",
		builder.is_open() and GameState.is_time_held() and GameState.clock.speed == ClockRunner.Speed.PAUSE,
		"open %s held %s speed %d" % [builder.is_open(), GameState.is_time_held(), GameState.clock.speed])
	builder.close()
	TestFixtures.check(res, "closing the campaign builder brings back the old speed",
		not builder.is_open() and not GameState.is_time_held() and GameState.clock.speed == ClockRunner.Speed.PLAY,
		"held %s speed %d" % [GameState.is_time_held(), GameState.clock.speed])
	viewer.press_new()
	var reopened: bool = GameState.is_time_held()
	viewer.queue_free()
	await host.get_tree().process_frame
	TestFixtures.check(res, "freeing the viewer with the builder open brings back the old speed",
		reopened and not GameState.is_time_held() and GameState.clock.speed == ClockRunner.Speed.PLAY,
		"reopened %s held %s speed %d" % [reopened, GameState.is_time_held(), GameState.clock.speed])
	GuiFrameStack.clear()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.clock.set_process(ticking)


#Whole days through GameState.process_until so the 8:00 contract round runs, then the day tick pass_days sends.
static func _round_days(count: int) -> void:
	for _i: int in count:
		var next: int = GameState.day() + 1
		await GameState.process_until(next * TrynnCalendar.MINUTES_PER_DAY + 8 * TrynnCalendar.MINUTES_PER_HOUR)
		GameState.day_changed.emit(next)


#A bare start plus one thirty day Flyers job ad that has pulled in applicants 20, 21 and 22.
static func _fresh_priced(ent: Dictionary = {}) -> void:
	_fresh(ent)
	_arrivals(3)


#Launches ads thirty day Flyers job ads and passes rounds arrival steps, so rounds x ads applicants
#land, the ads taking turns in launch order.
static func _arrivals(rounds: int, ads: int = 1) -> Array[CampaignData]:
	var cap: int = maxi(30, int(SubscriptionManager.entitlements().get("maxPromoDays", 0)))
	SubscriptionManager.set_entitlements({"promotions": true, "jobPostings": true, "maxPromoDays": cap})
	GameState.bank_notes = maxi(GameState.bank_notes, 1000)
	var out: Array[CampaignData] = []
	for _i: int in ads:
		var launched: CampaignData = TestFixtures.launch_campaign({"type": &"flyers", "days": 30})
		if launched != null:
			out.append(launched)
	TestFixtures.pass_days(rounds * 3)
	for _round: int in rounds:
		for ad: CampaignData in out:
			PromotionsManager.land_applicant(ad)
	return out


#The board the card, list, refund and finance cases read: six campaigns launched in two waves, then
#five more days. On day 134 it holds c1 Flyers job 30d, c2 Word of Mouth promo 14d, c3 Radio job
#Infinite, c4 Flyers job 5d (ran out), all from day 122, and c5 Sponsorship job Infinite and c6 Flyers
#job 20d from day 129.
static func _board(res: Dictionary) -> Array[CampaignData]:
	var ent: Dictionary = _launch_ent()
	ent.merge({"adRadio": true, "maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE}, true)
	_fresh(ent)
	GameState.bank_notes = 100000
	var crew: Array[int] = _free_uids(res, 2, "two free mercs for the board crew")
	var out: Array[CampaignData] = []
	out.append(TestFixtures.launch_campaign({"type": &"flyers", "days": 30}))
	out.append(TestFixtures.launch_campaign({"type": &"wom", "mode": CampaignData.MODE_PROMO,
		"days": 14, "crew": crew}))
	out.append(TestFixtures.launch_campaign({"type": &"radio", "infinite": true}))
	out.append(TestFixtures.launch_campaign({"type": &"flyers", "days": 5}))
	TestFixtures.pass_days(7)
	_land(out, [0, 2, 3, 0, 2])
	out.append(TestFixtures.launch_campaign({"type": &"sponsor", "infinite": true, "target": 0}))
	out.append(TestFixtures.launch_campaign({"type": &"flyers", "days": 20}))
	TestFixtures.pass_days(5)
	_land(out, [0, 2, 4, 5, 0, 2])
	var missing: Array[int] = []
	for i: int in out.size():
		if out[i] == null or out[i].id != i + 1:
			missing.append(i + 1)
	TestFixtures.check(res, "the board launches its six campaigns and reaches day 134",
		missing.is_empty() and GameState.day() == 134, "missing %s, day %d" % [missing, GameState.day()])
	return out


#Lands one job applicant per listed board index, in order, the way the old three day arrivals fell.
static func _land(board: Array[CampaignData], picks: Array[int]) -> void:
	for i: int in picks:
		if i < board.size() and board[i] != null:
			PromotionsManager.land_applicant(board[i])


#The My Promotions window the way the HUD opens it, on the Job Postings tab.
static func _open_promotions(host: Node, hud: GameHUD) -> PromotionsViewer:
	var promo: PromotionsViewer = hud.open_viewer(&"promotions") as PromotionsViewer
	await host.get_tree().process_frame
	if promo != null:
		promo.open_tab(PromotionsViewer.JOB_KEY)
	await host.get_tree().process_frame
	return promo


#The four picks of the My Promotions toolbar, as the viewer and its toolbar both hold them.
static func _promo_picks(promo: PromotionsViewer) -> Dictionary:
	var bar: AdsToolbar = promo.toolbar()
	return {"concluded": promo.show_concluded, "infinite": promo.show_infinite, "key": promo.sort_key,
		"ascending": promo.ascending, "bar_concluded": bar.show_concluded(),
		"bar_infinite": bar.show_infinite(), "bar_key": bar.sort_key(), "bar_ascending": bar.ascending(),
		"sort_index": bar.sort_button.selected, "dir_descending": bar.dir_toggle.descending}


#Designer rule 2026-10-04: the picks reset once the My Promotions window is fully closed.
static func _case_reopen_promotions(res: Dictionary, host: Node) -> void:
	GuiClickJBTests._fresh(true)
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var promo: PromotionsViewer = await _open_promotions(host, hud)
	TestFixtures.check(res, "the HUD opens My Promotions with the job ads of the board",
		promo != null and promo.card_count() > 1, "cards %d" % (promo.card_count() if promo != null else -1))
	if promo == null:
		await GuiClickJBTests._close(host, hud)
		_fresh()
		return
	var first: Dictionary = _promo_picks(promo)
	var first_ids: Array[int] = GuiClickJBTests._shown_ids(promo)
	var first_rows: int = promo.card_count()
	promo.toolbar().press_row(true)
	promo.toolbar().press_row(false)
	promo.pick_sort(&"cost")
	promo.toggle_direction()
	await host.get_tree().process_frame
	var moved: Dictionary = _promo_picks(promo)
	var moved_ids: Array[int] = GuiClickJBTests._shown_ids(promo)
	var all_moved: bool = true
	for key: String in first.keys():
		if moved[key] == first[key]:
			all_moved = false
	TestFixtures.check(res, "the My Promotions picks under test moved",
		all_moved and moved_ids != first_ids, "picks %s ids %s of %s" % [str(moved), str(moved_ids),
		str(first_ids)])
	hud.popup().close()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing My Promotions frees its content", not is_instance_valid(promo),
		"valid %s" % is_instance_valid(promo))
	var again: PromotionsViewer = await _open_promotions(host, hud)
	var picks: Dictionary = {} if again == null else _promo_picks(again)
	TestFixtures.check(res, "a fully closed My Promotions opens again with its filter and sort reset",
		again != null and picks == first and not bool(first["concluded"]) and bool(first["infinite"])
		and first["key"] == PromotionsManager.CAMPAIGN_SORT_DEFAULT,
		"picks %s" % str(picks))
	TestFixtures.check(res, "a fully closed My Promotions opens again with its first list",
		again != null and again.card_count() == first_rows and GuiClickJBTests._shown_ids(again) == first_ids,
		"cards %d of %d" % [again.card_count() if again != null else -1, first_rows])
	await GuiClickJBTests._close(host, hud)
	_fresh()


#Designer rule 2026-10-04: the picks reset once the View Applicants window is fully closed.
static func _case_reopen_applicants(res: Dictionary, host: Node) -> void:
	GuiClickJBTests._fresh(true)
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var promo: PromotionsViewer = await _open_promotions(host, hud)
	if promo == null:
		TestFixtures.check(res, "the HUD opens My Promotions for the View Applicants case", false, "null")
		await GuiClickJBTests._close(host, hud)
		_fresh()
		return
	promo.toolbar().press_row(true)
	promo.pick_sort(&"cost")
	promo.toggle_direction()
	await host.get_tree().process_frame
	var held: Dictionary = _promo_picks(promo)
	var hiring: HiringTab = await _open_applicants(host, promo)
	TestFixtures.check(res, "View Applicants opens its nested window over My Promotions",
		hiring != null and hiring.card_ids().size() > 1,
		"cards %d" % (hiring.card_ids().size() if hiring != null else -1))
	if hiring == null:
		await GuiClickJBTests._close(host, hud)
		_fresh()
		return
	var first_key: StringName = hiring.sort_key()
	var first_descending: bool = hiring.descending()
	var first_ids: Array[int] = hiring.card_ids()
	hiring.sort_dropdown().select(&"level", true)
	hiring.sort_toggle().toggle()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the View Applicants picks under test moved",
		hiring.sort_key() != first_key and hiring.descending() != first_descending
		and hiring.sort_dropdown().selected != first_key and hiring.card_ids() != first_ids,
		"key %s descending %s ids %s of %s" % [hiring.sort_key(), hiring.descending(),
		str(hiring.card_ids()), str(first_ids)])
	var window: ViewerPopup = promo.popup()
	window.close()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing View Applicants frees its page while My Promotions stays open",
		not is_instance_valid(hiring) and promo.popup() == null and hud.popup().current() == promo,
		"page valid %s current %s" % [is_instance_valid(hiring), str(hud.popup().current())])
	var again: HiringTab = await _open_applicants(host, promo)
	TestFixtures.check(res, "a fully closed View Applicants opens again with its sort reset",
		again != null and again.sort_key() == first_key and again.descending() == first_descending
		and first_key == &"fit" and first_descending and again.sort_dropdown().selected == first_key
		and again.sort_toggle().descending and again.card_ids() == first_ids,
		"key %s descending %s ids %s of %s" % [again.sort_key() if again != null else &"",
		again != null and again.descending(), str(again.card_ids() if again != null else []), str(first_ids)])
	TestFixtures.check(res, "the My Promotions picks hold while View Applicants closes and opens again",
		_promo_picks(promo) == held, "picks %s of %s" % [str(_promo_picks(promo)), str(held)])
	await GuiClickJBTests._close(host, hud)
	_fresh()


#Presses View Applicants on the board's two applicant ad and hands back the Hiring page it opens.
static func _open_applicants(host: Node, promo: PromotionsViewer) -> HiringTab:
	promo.press_view(GuiClickJBTests.VIA_ID)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var window: ViewerPopup = promo.popup()
	var finance: FinanceViewer = null if window == null else window.current() as FinanceViewer
	if finance == null:
		return null
	await host.get_tree().process_frame
	return finance.page(FinanceViewer.HIRING_KEY) as HiringTab


#True when the applicant carries a rolled merc and takes its name from it.
static func _named_for_merc(a: ApplicantData) -> bool:
	var merc: MercenaryData = PromotionsManager.merc_of(a)
	return merc != null and a.name != "" and a.name == merc.merc_name \
		and not a.name.begins_with(PLACEHOLDER_NAME)


#True when the level is the merc's, inside the draw band, and the ask is what the salary system asks.
static func _priced_by_merc(a: ApplicantData) -> bool:
	var merc: MercenaryData = PromotionsManager.merc_of(a)
	return merc != null and a.level == ExperienceSystem.current_level(merc) \
		and a.level >= 1 and a.level <= GenConstants.LEVEL_CAP \
		and a.ask == SalarySystem.asking_salary(merc, GameState.mercs)


#True when the applicant carries its rolled merc's dominant ancestry, a name the data sheet lists.
static func _ancestry_of_merc(a: ApplicantData) -> bool:
	var merc: MercenaryData = PromotionsManager.merc_of(a)
	if merc == null or merc.ancestry == null or a.ancestry == "":
		return false
	return a.ancestry == merc.ancestry.ancestry_name and TraitFilterDefs.ancestry_names().has(a.ancestry)


#The sorted ids of the applicants who carry one of the picked ancestries.
static func _ids_with_ancestry(picks: Array[String]) -> Array[int]:
	var out: Array[int] = []
	for row: ApplicantData in PromotionsManager.applicants:
		if picks.has(row.ancestry):
			out.append(row.id)
	out.sort()
	return out


#The first real ancestry no applicant carries, or an empty string when every one is carried.
static func _uncarried_ancestry() -> String:
	var carried: Dictionary = {}
	for row: ApplicantData in PromotionsManager.applicants:
		carried[row.ancestry] = true
	for ancestry_name: String in TraitFilterDefs.ancestry_names():
		if not carried.has(ancestry_name):
			return ancestry_name
	return ""


#The ask of the applicant at that rank from the cheapest.
static func _ask_at_rank(rank: int) -> int:
	var asks: Array[int] = []
	for row: ApplicantData in PromotionsManager.applicants:
		asks.append(row.ask)
	asks.sort()
	return asks[mini(rank, asks.size() - 1)]


#The sorted ids asking at most max_ask notes and aged inside the range.
static func _ids_within(max_ask: int, age_low: int, age_high: int) -> Array[int]:
	var out: Array[int] = []
	for row: ApplicantData in PromotionsManager.applicants:
		if row.ask <= max_ask and row.age >= age_low and row.age <= age_high:
			out.append(row.id)
	out.sort()
	return out


#The sorted ids of the applicants the test passes.
static func _ids_matching(test: Callable) -> Array[int]:
	var out: Array[int] = []
	for row: ApplicantData in PromotionsManager.applicants:
		if bool(test.call(row)):
			out.append(row.id)
	out.sort()
	return out


#The id a Hiring sort should open on: the highest or lowest value, a tie going to the lower id.
static func _lead_id(value: Callable, descending: bool) -> int:
	var best: ApplicantData = null
	for row: ApplicantData in PromotionsManager.applicants:
		if best == null:
			best = row
			continue
		var have: float = float(value.call(row))
		var top: float = float(value.call(best))
		var better: bool = have > top if descending else have < top
		if better or (have == top and row.id < best.id):
			best = row
	return -1 if best == null else best.id


#True when the whole list under that sort never steps the wrong way on level or ask.
static func _ordered(sort: StringName, descending: bool) -> bool:
	var empty: Array[int] = []
	var rows: Array[ApplicantData] = PromotionsManager.applicants_filtered({}, empty, sort, descending)
	for i: int in range(1, rows.size()):
		var before: int = rows[i - 1].level if sort == &"level" else rows[i - 1].ask
		var after: int = rows[i].level if sort == &"level" else rows[i].ask
		if (descending and after > before) or (not descending and after < before):
			return false
	return rows.size() == PromotionsManager.applicants.size()


#The entitlements a launch case needs: the cheap types, two Odd Job slots, a thirty day cap and
#both tabs open.
static func _launch_ent() -> Dictionary:
	return {"promotions": true, "oddJobs": 2, "adDirect": true, "adSponsor": true,
		"maxPromoDays": 30, "jobPostings": true, "guildPromo": true}


static func _campaign(type_key: StringName, mode: String, days: int) -> CampaignData:
	var out := CampaignData.new()
	out.type_key = type_key
	out.mode = mode
	out.days = days
	return out


static func _forever(type_key: StringName, mode: String) -> CampaignData:
	var out: CampaignData = _campaign(type_key, mode, 0)
	out.infinite = true
	out.unit_key = CampaignTypeDefs.UNIT_INFINITE
	return out


static func _reason(verdict: Dictionary) -> String:
	return String(verdict["reason"])


#Reads the launch reason of the campaign once and checks it against the wanted text.
static func _expect_reason(res: Dictionary, label: String, campaign: CampaignData,
		want: String) -> void:
	var reason: String = _reason(PromotionsManager.can_launch(campaign))
	TestFixtures.check(res, label, reason == want, reason)


#The first uids of the roster the guild can still send somewhere. A case that has to launch or
#counter picks its crew here, since earlier crews and the Legal seed may already hold mercs of
#a fresh roster. A roster with too few free mercs fails the case that asked.
static func _free_uids(res: Dictionary, count: int, label: String) -> Array[int]:
	var out: Array[int] = []
	var busy: Array[int] = GameState.busy_uids()
	for merc: MercenaryData in GameState.mercs:
		if out.size() >= count:
			break
		if merc != null and not busy.has(merc.merc_uid):
			out.append(merc.merc_uid)
	if out.size() < count:
		TestFixtures.check(res, label, false, "%d free of %d wanted" % [out.size(), count])
		for merc: MercenaryData in GameState.mercs:
			if out.size() >= count:
				break
			if merc != null and not out.has(merc.merc_uid):
				out.append(merc.merc_uid)
	return out


static func _ids(rows: Array[ApplicantData]) -> Array[int]:
	var out: Array[int] = []
	for row: ApplicantData in rows:
		out.append(row.id)
	return out


#The filtered ids in plain id order, so a membership case does not depend on the sort.
static func _sorted_ids(rows: Array[ApplicantData]) -> Array[int]:
	var out: Array[int] = _ids(rows)
	out.sort()
	return out


static func _cids(rows: Array[CampaignData]) -> Array[int]:
	var out: Array[int] = []
	for row: CampaignData in rows:
		out.append(row.id)
	return out


#One campaign list sorted one way, as plain ids.
static func _order(mode: String, key: StringName, ascending: bool, today: int,
		concluded: bool = false, infinite: bool = true) -> Array[int]:
	var list: Array[CampaignData] = PromotionsManager.campaigns_filtered(mode, concluded,
		infinite, today)
	return _cids(PromotionsManager.campaigns_sorted(list, key, ascending, today))


#The entries of want, in the order they appear in have.
static func _kept(have: Array[int], want: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for id: int in have:
		if want.has(id):
			out.append(id)
	return out


#Case 1: the five campaign types, their gates and what each one costs up front.
static func _case_types(res: Dictionary) -> void:
	var keys: Array[String] = []
	var stars: Array[int] = []
	for row: Dictionary in CampaignTypeDefs.TYPES:
		keys.append(String(row["key"]))
		stars.append(int(row["stars"]))
	TestFixtures.check(res, "the campaign table holds the five design prototype types in order",
		keys == ["wom", "flyers", "direct", "radio", "sponsor"], "keys %s" % [keys])
	TestFixtures.check(res, "campaign quality runs one star to five",
		stars == [1, 2, 3, 4, 5], "stars %s" % [stars])
	TestFixtures.check(res, "an unknown type key finds nothing",
		CampaignTypeDefs.find(&"nope").is_empty(), "row %s" % [CampaignTypeDefs.find(&"nope")])
	TestFixtures.check(res, "Word of Mouth needs one Odd Job slot, Flyers the Promotions key",
		not CampaignTypeDefs.unlocked(&"wom", {"oddJobs": 0})
		and CampaignTypeDefs.unlocked(&"wom", {"oddJobs": 1})
		and not CampaignTypeDefs.unlocked(&"flyers", {})
		and CampaignTypeDefs.unlocked(&"flyers", {"promotions": true}),
		"wom on oddJobs, flyers on promotions")
	TestFixtures.check(res, "an unheld ad key keeps Direct Sale, Radio and Sponsorship locked",
		not CampaignTypeDefs.unlocked(&"direct", {})
		and not CampaignTypeDefs.unlocked(&"radio", {})
		and not CampaignTypeDefs.unlocked(&"sponsor", {"adSponsor": false}),
		"adDirect, adRadio and adSponsor all start false")
	TestFixtures.check(res, "a daily type costs its price over its days",
		CampaignTypeDefs.cost(&"flyers", 30) == 150 and CampaignTypeDefs.cost(&"direct", 1) == 40
		and CampaignTypeDefs.cost(&"radio", 7) == 560
		and CampaignTypeDefs.cost(&"sponsor", 2) == 500,
		"flyers 150, direct 40, radio 560, sponsor 500")
	TestFixtures.check(res, "Word of Mouth costs its crew's Odd Job pay and ignores the days",
		CampaignTypeDefs.cost(&"wom", 30, 3, 25) == 75
		and CampaignTypeDefs.cost(&"wom", 1, 3, 25) == 75
		and CampaignTypeDefs.cost(&"wom", 30, 0, 25) == 0,
		"3 mercs at 25 is 75")
	TestFixtures.check(res, "a month of an Infinite campaign is thirty days of its price",
		CampaignTypeDefs.BILL_DAYS == 30 and CampaignTypeDefs.monthly_cost(&"radio") == 2400
		and CampaignTypeDefs.monthly_cost(&"sponsor") == 7500
		and CampaignTypeDefs.monthly_cost(&"wom") == 0,
		"radio 2400, sponsor 7500, wom nothing")
	TestFixtures.check(res, "only Word of Mouth is paid as a crew",
		CampaignTypeDefs.is_crew_paid(&"wom") and not CampaignTypeDefs.is_crew_paid(&"flyers")
		and not CampaignTypeDefs.is_crew_paid(&"sponsor"), "per_day 0 marks the crew types")
	TestFixtures.check(res, "every type but Word of Mouth hands notes back when it ends",
		not bool(CampaignTypeDefs.find(&"wom")["refund"])
		and bool(CampaignTypeDefs.find(&"flyers")["refund"])
		and bool(CampaignTypeDefs.find(&"radio")["refund"]), "the crew was already paid")
	TestFixtures.check(res, "Direct Sale is the only guild-only type and the picks match",
		bool(CampaignTypeDefs.find(&"direct")["guild_only"])
		and not bool(CampaignTypeDefs.find(&"sponsor")["guild_only"])
		and String(CampaignTypeDefs.find(&"direct")["picks"]) == CampaignTypeDefs.PICK_COMPANY
		and String(CampaignTypeDefs.find(&"sponsor")["picks"])
			== CampaignTypeDefs.PICK_COMPANY_OR_EVENT
		and String(CampaignTypeDefs.find(&"flyers")["picks"]) == "",
		"direct picks a company, sponsor a company or event")
	TestFixtures.check(res, "each type names the upgrade tier that unlocks it",
		String(CampaignTypeDefs.find(&"wom")["upgrade_id"]) == "oddjobs"
		and String(CampaignTypeDefs.find(&"flyers")["upgrade_id"]) == "promotions"
		and String(CampaignTypeDefs.find(&"radio")["upgrade_id"]) == "promomethods"
		and int(CampaignTypeDefs.find(&"radio")["upgrade_tier"]) == 2
		and int(CampaignTypeDefs.find(&"sponsor")["upgrade_tier"]) == 3
		and UpgradeDefs.display_tiers(String(CampaignTypeDefs.find(&"sponsor")["upgrade_id"])) == 3,
		"radio is tier 2 of Promo Methods")
	TestFixtures.check(res, "a fixed campaign runs from one day to thirty",
		CampaignTypeDefs.MIN_DAYS == 1 and CampaignTypeDefs.MAX_DAYS == 30,
		"%d to %d" % [CampaignTypeDefs.MIN_DAYS, CampaignTypeDefs.MAX_DAYS])


#Case 2: how effective each type reads, with and without the Marketing Agency boost.
static func _case_effect(res: Dictionary) -> void:
	var plain: Dictionary = {}
	TestFixtures.check(res, "Word of Mouth varies with the crew and carries no percentage",
		CampaignTypeDefs.effect_text(&"wom", plain) == "Varies"
		and is_equal_approx(CampaignTypeDefs.effect_value(&"wom", plain),
			CampaignTypeDefs.VARIES), "%s" % [CampaignTypeDefs.effect_text(&"wom", plain)])
	TestFixtures.check(res, "an unboosted type reads its own effect as a whole percentage",
		CampaignTypeDefs.effect_text(&"flyers", plain) == "2%"
		and CampaignTypeDefs.effect_text(&"direct", plain) == "9%"
		and CampaignTypeDefs.effect_text(&"radio", plain) == "12%"
		and CampaignTypeDefs.effect_text(&"sponsor", plain) == "15%",
		"2, 9, 12 and 15 per cent")
	var boost: Dictionary = {"adBoost": 25}
	TestFixtures.check(res, "a quarter of Marketing Agency boost lifts every percentage",
		CampaignTypeDefs.effect_text(&"flyers", boost) == "2.5%"
		and CampaignTypeDefs.effect_text(&"direct", boost) == "11.3%"
		and CampaignTypeDefs.effect_text(&"radio", boost) == "15%"
		and CampaignTypeDefs.effect_text(&"sponsor", boost) == "18.8%",
		"9 x 1.25 reads %s" % [CampaignTypeDefs.effect_text(&"direct", boost)])
	TestFixtures.check(res, "the boost rounds to one decimal and Word of Mouth stays Varies",
		CampaignTypeDefs.effect_text(&"flyers", {"adBoost": 7}) == "2.1%"
		and CampaignTypeDefs.effect_text(&"wom", boost) == "Varies",
		"%s" % [CampaignTypeDefs.effect_text(&"flyers", {"adBoost": 7})])
	TestFixtures.check(res, "an unknown type has no effect to read",
		CampaignTypeDefs.effect_text(&"nope", plain) == "Varies", "unknown reads as Varies")


#Case 3: the places each type can reach.
static func _case_fit_locations(res: Dictionary) -> void:
	TestFixtures.check(res, "the nine design prototype locations are named, not numbered",
		CampaignTypeDefs.locations().size() == 9
		and CampaignTypeDefs.location_name(0) == "Buern"
		and CampaignTypeDefs.location_name(4) == "Rossade"
		and CampaignTypeDefs.location_name(8) == "Cyfrolaef"
		and CampaignTypeDefs.location_name(9) == "", "%s" % [CampaignTypeDefs.locations()])
	var wide: Array[int] = [0, 1, 4, 7, 8]
	TestFixtures.check(res, "Radio cannot reach three of the nine locations",
		CampaignTypeDefs.fit_locations(&"radio", wide) == [1, 8]
		and not CampaignTypeDefs.location_allowed(&"radio", 0)
		and not CampaignTypeDefs.location_allowed(&"radio", 4)
		and not CampaignTypeDefs.location_allowed(&"radio", 7)
		and CampaignTypeDefs.location_allowed(&"radio", 1),
		"%s" % [CampaignTypeDefs.fit_locations(&"radio", wide)])
	var two: Array[int] = [3, 5]
	TestFixtures.check(res, "Sponsorship keeps the first location and drops the rest",
		CampaignTypeDefs.fit_locations(&"sponsor", two) == [3]
		and bool(CampaignTypeDefs.find(&"sponsor")["one_loc"])
		and not bool(CampaignTypeDefs.find(&"flyers")["one_loc"]),
		"%s" % [CampaignTypeDefs.fit_locations(&"sponsor", two)])
	TestFixtures.check(res, "Flyers reach everywhere and an off-list index is refused",
		CampaignTypeDefs.fit_locations(&"flyers", wide) == wide
		and not CampaignTypeDefs.location_allowed(&"flyers", -1)
		and not CampaignTypeDefs.location_allowed(&"flyers", 9),
		"%s" % [CampaignTypeDefs.fit_locations(&"flyers", wide)])
	TestFixtures.check(res, "the picker shows the place names the Legal autoload holds",
		TraitFilterDefs.location_names() == CampaignTypeDefs.locations()
		and LegalManager.location(0).name == CampaignTypeDefs.locations()[0],
		"%s" % [TraitFilterDefs.location_names()])


#Case 4: the duration units, the cap that opens each one and what a unit adds up to.
static func _case_duration(res: Dictionary) -> void:
	TestFixtures.check(res, "the four duration units run days, weeks, months and Infinite",
		CampaignTypeDefs.unit_keys() == [CampaignTypeDefs.UNIT_DAYS,
		CampaignTypeDefs.UNIT_WEEKS, CampaignTypeDefs.UNIT_MONTHS,
		CampaignTypeDefs.UNIT_INFINITE], "%s" % [CampaignTypeDefs.unit_keys()])
	TestFixtures.check(res, "the Infinite cap is the one SubscriptionManager hands out",
		CampaignTypeDefs.INFINITE_CAP == SubscriptionManager.PROMO_DAYS_INFINITE,
		"%d against %d" % [CampaignTypeDefs.INFINITE_CAP,
		SubscriptionManager.PROMO_DAYS_INFINITE])
	var caps: Array[int] = [5, 10, 17, 25, 30, CampaignTypeDefs.INFINITE_CAP]
	var weeks: Array[int] = []
	var months: Array[int] = []
	for cap: int in caps:
		weeks.append(CampaignTypeDefs.unit_qty_max(CampaignTypeDefs.UNIT_WEEKS,
			{"maxPromoDays": cap}))
		months.append(CampaignTypeDefs.unit_qty_max(CampaignTypeDefs.UNIT_MONTHS,
			{"maxPromoDays": cap}))
	TestFixtures.check(res, "the weeks a cap allows never pass the thirty day ceiling",
		weeks == [0, 1, 2, 3, 4, 4], "weeks %s" % [weeks])
	TestFixtures.check(res, "a month only fits once the cap reaches thirty days",
		months == [0, 0, 0, 0, 1, 1], "months %s" % [months])
	TestFixtures.check(res, "no duration at all is offered without the Long Promos cap",
		not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_DAYS, {})
		and not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_DAYS,
			{"maxPromoDays": 0})
		and CampaignTypeDefs.unit_qty_max(CampaignTypeDefs.UNIT_DAYS, {}) == 0,
		"cap 0 allows nothing")
	TestFixtures.check(res, "each unit opens at its own cap",
		CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_DAYS, {"maxPromoDays": 5})
		and not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_WEEKS,
			{"maxPromoDays": 5})
		and CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_WEEKS, {"maxPromoDays": 10})
		and not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_MONTHS,
			{"maxPromoDays": 25})
		and CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_MONTHS, {"maxPromoDays": 30}),
		"weeks at 10, months at 30")
	TestFixtures.check(res, "Infinite waits on the top tier of Long Promos",
		not CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_INFINITE,
			{"maxPromoDays": 30})
		and CampaignTypeDefs.unit_unlocked(CampaignTypeDefs.UNIT_INFINITE,
			{"maxPromoDays": CampaignTypeDefs.INFINITE_CAP}), "only the sentinel cap opens it")
	TestFixtures.check(res, "a unit and a quantity add up to plain days",
		CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_WEEKS, 2) == 14
		and CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_DAYS, 5) == 5
		and CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_MONTHS, 1) == 30
		and CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_INFINITE, 3) == 0
		and CampaignTypeDefs.days_of(&"nope", 3) == 0,
		"2 weeks is %d days" % [CampaignTypeDefs.days_of(CampaignTypeDefs.UNIT_WEEKS, 2)])


#Case 5: the merc filter rows, their groups, their locks and what counts as narrowing.
static func _case_merc_defs(res: Dictionary) -> void:
	_fresh(_launch_ent())
	var defs: Array[Dictionary] = TraitFilterDefs.merc_defs()
	var hiring: Array[Dictionary] = PromotionsManager.hiring_defs()
	var builder_keys: Array[String] = GuiFinanceDataTests._keys_of(defs)
	TestFixtures.check(res, "the builder has the eight design rows and Hiring adds the review rows and Applied Via",
		builder_keys == BUILDER_ROWS
		and hiring.size() == BUILDER_ROWS.size() + REVIEW_ONLY_ROWS.size() + 1
		and TraitFilterDefs.find(defs, &"from").is_empty(),
		"builder %s, hiring %d" % [builder_keys, hiring.size()])
	var leaked: Array[String] = []
	var dropped: Array[String] = []
	for key: String in REVIEW_ONLY_ROWS:
		if not TraitFilterDefs.find(defs, StringName(key)).is_empty():
			leaked.append(key)
		if TraitFilterDefs.find(hiring, StringName(key)).is_empty():
			dropped.append(key)
	TestFixtures.check(res, "bloodline, heritage, criminality, age, knowledges and tools are review only",
		leaked.is_empty() and dropped.is_empty(),
		"the builder carries %s, Hiring lacks %s" % [leaked, dropped])
	TestFixtures.check(res, "the builder fills its four groups with the rows the design lists",
		GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(defs, "Value")) == ["salary"]
		and GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(defs, "Identity"))
		== ["tradition", "ancestry"]
		and GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(defs, "Physical"))
		== ["vigor", "speed", "dexterity"]
		and GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(defs, "Mental"))
		== ["cognition", "wile"], "%s" % [builder_keys])
	GameState.bank_notes = 1000
	var launched: bool = TestFixtures.launch_campaign({"type": &"flyers", "days": 5}) != null \
		and TestFixtures.launch_campaign({"type": &"flyers", "mode": CampaignData.MODE_PROMO,
			"days": 5}) != null \
		and TestFixtures.launch_campaign({"type": &"flyers", "days": 5}) != null
	var from: Dictionary = TraitFilterDefs.find(PromotionsManager.hiring_defs(), &"from")
	var options: Array = from.get("options", [])
	var values: Array = from.get("values", [])
	TestFixtures.check(res, "Applied Via lists the job campaigns, skips the promo and ends with Walk-In",
		launched and options == ["Campaign 1", "Campaign 3", "Walk-In"]
		and values == [1, 3, TraitFilterDefs.WALK_IN], "options %s values %s" % [options, values])
	var bad_group: Array[String] = []
	for def: Dictionary in hiring:
		if not TraitFilterDefs.GROUPS.has(String(def["group"])):
			bad_group.append(String(def["key"]))
	TestFixtures.check(res, "every merc filter sits in one of the four groups",
		bad_group.is_empty(), "off-group rows %s" % [bad_group])
	TestFixtures.check(res, "the Identity group holds tradition and the four trait rows",
		GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(hiring, "Identity"))
		== ["tradition", "ancestry", "bloodline", "heritage", "criminality"],
		"%s" % [GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(hiring, "Identity"))])
	TestFixtures.check(res, "the Mental group holds the two stats, knowledges and tools",
		GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(hiring, "Mental"))
		== ["cognition", "wile", "knowledges", "tools"],
		"%s" % [GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(hiring, "Mental"))])
	TestFixtures.check(res, "the Physical group holds age and the three stats",
		GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(hiring, "Physical"))
		== ["age", "vigor", "speed", "dexterity"],
		"%s" % [GuiFinanceDataTests._keys_of(TraitFilterDefs.in_group(hiring, "Physical"))])
	var ancestry: Dictionary = TraitFilterDefs.find(hiring, &"ancestry")
	TestFixtures.check(res, "Ancestry is locked until Hiring Discrimination is held",
		TraitFilterDefs.locked(ancestry, {})
		and TraitFilterDefs.locked(ancestry, {"hiringDiscrim": false})
		and not TraitFilterDefs.locked(ancestry, {"hiringDiscrim": true}),
		"lock key %s" % [ancestry.get("lock", "")])
	var real_names: Array[String] = TraitFilterDefs.ancestry_names()
	var builder_ancestry: Dictionary = TraitFilterDefs.find(defs, &"ancestry")
	TestFixtures.check(res, "the builder and Hiring both list the real ancestries the data sheet holds",
		not real_names.is_empty() and real_names == DataManager.ancestries.keys()
		and builder_ancestry.get("options", []) == real_names
		and builder_ancestry.get("values", []) == real_names
		and ancestry.get("options", []) == real_names and ancestry.get("values", []) == real_names,
		"names %s" % [real_names])
	TestFixtures.check(res, "Bloodline and Age lock on the same key as Ancestry",
		TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"bloodline"), {})
		and TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"age"), {})
		and not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"age"),
			{"hiringDiscrim": true}), "both name hiringDiscrim")
	TestFixtures.check(res, "Heritage waits on a Background Check, Criminality on a Criminal one",
		TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"heritage"), {"background": 0})
		and not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"heritage"),
			{"background": 1})
		and TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"criminality"), {})
		and not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"criminality"),
			{"criminal": true}), "background tier 1 and criminal")
	var speed: Dictionary = TraitFilterDefs.find(hiring, &"speed")
	TestFixtures.check(res, "Min Speed opens at Mercday Pro and stays open above it",
		TraitFilterDefs.locked(speed, {"plan": "free"})
		and not TraitFilterDefs.locked(speed, {"plan": "pro"})
		and not TraitFilterDefs.locked(speed, {"plan": "enterprise"}),
		"plan tier %d on free" % [TraitFilterDefs.tier_of({"plan": "free"}, "plan")])
	TestFixtures.check(res, "Salary Request, Applied Via and Tradition are never locked",
		not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"salary"), {})
		and not TraitFilterDefs.locked(from, {})
		and not TraitFilterDefs.locked(TraitFilterDefs.find(hiring, &"tradition"), {}),
		"no lock key on the three open rows")
	var salary: Dictionary = TraitFilterDefs.find(hiring, &"salary")
	TestFixtures.check(res, "Salary Request is a two-handled slider over the asking rate",
		String(salary["kind"]) == TraitFilterDefs.KIND_SLIDER2
		and String(salary["field"]) == "ask" and float(salary["min"]) == 1.0
		and float(salary["max"]) == 999.0 and float(salary["step"]) == 1.0,
		"kind %s field %s" % [salary["kind"], salary["field"]])
	TestFixtures.check(res, "a stat row reads the applicant's stats dictionary",
		String(TraitFilterDefs.find(hiring, &"vigor")["field"]) == "stats/vigor"
		and String(TraitFilterDefs.find(hiring, &"vigor")["kind"]) == TraitFilterDefs.KIND_MIN,
		"field %s" % [TraitFilterDefs.find(hiring, &"vigor")["field"]])
	TestFixtures.check(res, "a row only narrows once it leaves its own bounds",
		not TraitFilterDefs.active(salary, null)
		and not TraitFilterDefs.active(salary, [1.0, 999.0])
		and TraitFilterDefs.active(salary, [50.0, 999.0])
		and TraitFilterDefs.active(salary, [1.0, 950.0])
		and not TraitFilterDefs.active(TraitFilterDefs.find(hiring, &"vigor"), 0)
		and TraitFilterDefs.active(TraitFilterDefs.find(hiring, &"vigor"), 1)
		and not TraitFilterDefs.active(ancestry, [])
		and TraitFilterDefs.active(ancestry, [real_names[0]]), "bounds mean no filter")
	var picked: Dictionary = {&"ancestry": [real_names[0]], &"tradition": ["Brave"]}
	TestFixtures.check(res, "a group's active count skips the rows the guild cannot read",
		TraitFilterDefs.active_count(hiring, "Identity", picked, {}) == 1
		and TraitFilterDefs.active_count(hiring, "Identity", picked,
			{"hiringDiscrim": true}) == 2,
		"1 without Hiring Discrimination, 2 with it")


#Case 6: the contract filters a Guild Promo campaign targets, and their tier locks.
static func _case_contract_defs(res: Dictionary) -> void:
	_fresh()
	var flyers: Array[Dictionary] = TraitFilterDefs.contract_defs(&"flyers")
	var direct: Array[Dictionary] = TraitFilterDefs.contract_defs(&"direct")
	var sponsor: Array[Dictionary] = TraitFilterDefs.contract_defs(&"sponsor")
	TestFixtures.check(res, "a guild campaign targets difficulty, contract type and location",
		GuiFinanceDataTests._keys_of(flyers) == ["diff", "ctype", "loc"], "%s" % [GuiFinanceDataTests._keys_of(flyers)])
	TestFixtures.check(res, "only a type that names a sponsor leads with the pick",
		GuiFinanceDataTests._keys_of(direct) == ["target", "diff", "ctype", "loc"]
		and GuiFinanceDataTests._keys_of(sponsor) == ["target", "diff", "ctype", "loc"],
		"direct %s" % [GuiFinanceDataTests._keys_of(direct)])
	var target: Dictionary = TraitFilterDefs.find(direct, &"target")
	TestFixtures.check(res, "Direct Sale advertises to any number of the six companies",
		(target["options"] as Array).size() == 6 and String(target["short"]) == "Advertise To"
		and String(target["label"]) == "Advertise To"
		and String(target["kind"]) == TraitFilterDefs.KIND_CHIPS
		and (target["values"] as Array) == (target["options"] as Array)
		and bool(target["full_row"]),
		"kind %s, options %s" % [target["kind"], target["options"]])
	var sponsor_target: Dictionary = TraitFilterDefs.find(sponsor, &"target")
	var sponsor_options: Array = sponsor_target["options"]
	TestFixtures.check(res, "Sponsorship picks one company or one event",
		sponsor_options.size() == 9 and String(sponsor_options[5]) == "Company 6"
		and String(sponsor_options[6]) == "Event 1"
		and String(sponsor_target["label"]) == "Sponsor (Company or Event)"
		and String(sponsor_target["kind"]) == TraitFilterDefs.KIND_ONE,
		"options %s" % [sponsor_options])
	var diff: Dictionary = TraitFilterDefs.find(flyers, &"diff")
	TestFixtures.check(res, "the difficulty range only narrows inside half a star to five",
		not TraitFilterDefs.active(diff, [0.5, 5.0])
		and TraitFilterDefs.active(diff, [1.5, 5.0])
		and TraitFilterDefs.active(diff, [0.5, 4.0]), "stars2 bounds")
	var rows: Array = diff["row_locks"]
	var low: Dictionary = rows[0]
	var high: Dictionary = rows[1]
	TestFixtures.check(res, "the two difficulty handles are separate Guild Promo tiers",
		rows.size() == 2 and String(low["label"]) == "Min"
		and String(low["lock"]) == "gpMinDifficulty" and int(low["upgrade_tier"]) == 2
		and String(high["lock"]) == "gpMaxDifficulty" and int(high["upgrade_tier"]) == 3
		and UpgradeDefs.display_tiers(String(high["upgrade_id"])) == 4,
		"row locks %s" % [rows])
	TestFixtures.check(res, "a difficulty handle stays locked until its own tier is paid for",
		TraitFilterDefs.locked(low, {}) and not TraitFilterDefs.locked(low,
			{"gpMinDifficulty": true}) and TraitFilterDefs.locked(high,
			{"gpMinDifficulty": true}), "the Min tier does not open the Max handle")
	var ctype: Dictionary = TraitFilterDefs.find(flyers, &"ctype")
	TestFixtures.check(res, "the Contract Type section is the fourth Guild Promo tier",
		String(ctype["lock"]) == "gpContractType" and int(ctype["upgrade_tier"]) == 4
		and String(ctype["upgrade_id"]) == TraitFilterDefs.GUILD_PROMO_ID
		and TraitFilterDefs.locked(ctype, {})
		and not TraitFilterDefs.locked(ctype, {"gpContractType": true}),
		"lock %s tier %s" % [ctype["lock"], ctype["upgrade_tier"]])
	var ctype_mods: Array = ctype["mods"]
	var hist: Array[int] = TraitFilterDefs.history(0, TraitFilterDefs.CTYPE_HIST_SEED)
	TestFixtures.check(res, "each contract type module carries its placeholder history",
		ctype_mods.size() == TraitFilterDefs.contract_type_count()
		and int((ctype_mods[0] as Dictionary)["received"]) == hist[0]
		and int((ctype_mods[0] as Dictionary)["completed"]) == hist[1]
		and int((ctype_mods[0] as Dictionary)["failed"]) == hist[2],
		"mod 0 %s against %s" % [ctype_mods[0], hist])
	TestFixtures.check(res, "a contract type module hides the relationship row",
		not bool((ctype_mods[0] as Dictionary)["has_relationship"]),
		"has_relationship %s" % [(ctype_mods[0] as Dictionary)["has_relationship"]])
	var loc: Dictionary = TraitFilterDefs.find(flyers, &"loc")
	var loc_mods: Array = loc["mods"]
	TestFixtures.check(res, "the nine locations show a relationship and gate on a permit",
		loc_mods.size() == 9 and bool((loc_mods[0] as Dictionary)["has_relationship"])
		and int((loc_mods[3] as Dictionary)["relationship"]) == -1
		and String(loc["gate"]) == "opsPermits" and String(loc["short"]) == "Locations",
		"relationship 3 %s" % [(loc_mods[3] as Dictionary)["relationship"]])
	var open_at: int = -1
	var shut_at: int = -1
	for i: int in range(loc_mods.size()):
		if LegalManager.has_permit(i, LegalManager.PERMIT_OPS) and open_at < 0:
			open_at = i
		elif not LegalManager.has_permit(i, LegalManager.PERMIT_OPS) and shut_at < 0:
			shut_at = i
	TestFixtures.check(res, "a location with no operating permit is disabled with the permit note",
		open_at >= 0 and shut_at >= 0
		and not bool((loc_mods[open_at] as Dictionary)["disabled"])
		and bool((loc_mods[shut_at] as Dictionary)["disabled"])
		and String((loc_mods[shut_at] as Dictionary)["disabled_reason"])
			== TraitFilterDefs.NO_PERMIT_NOTE
		and String((loc_mods[8] as Dictionary)["name"]) == "Cyfrolaef",
		"open %d, shut %d" % [open_at, shut_at])


#Case 7: a reset lays nothing down, and the applicants two job ads pull in read off their rolled mercs.
static func _case_arrivals(res: Dictionary) -> void:
	_fresh()
	var today: int = GameState.day()
	TestFixtures.check(res, "a fresh guild opens on the first day of play",
		today == TrynnCalendar.day_index(TrynnCalendar.START_MINUTE) and today == 122, "day %d" % today)
	PromotionsManager.reset()
	TestFixtures.check(res, "a reset runs no campaign and lists no applicant",
		PromotionsManager.campaigns.is_empty() and PromotionsManager.applicants.is_empty()
		and PromotionsManager.next_campaign_id == 1
		and PromotionsManager.next_applicant_id == PromotionsManager.FIRST_APPLICANT_ID
		and PromotionsManager.next_campaign_name() == "Campaign 1" and not PromotionsManager.has_unseen(),
		"%d campaigns, %d applicants" % [PromotionsManager.campaigns.size(),
		PromotionsManager.applicants.size()])
	var ads: Array[CampaignData] = _arrivals(4, 2)
	var rows: Array[ApplicantData] = PromotionsManager.applicants
	var c1_ids: Array[int] = _ids_matching(func(a: ApplicantData) -> bool: return a.campaign_id == 1)
	var c2_ids: Array[int] = _ids_matching(func(a: ApplicantData) -> bool: return a.campaign_id == 2)
	TestFixtures.check(res, "two job ads take turns, each pulling one applicant every three days",
		ads.size() == 2 and c1_ids == [20, 22, 24, 26] and c2_ids == [21, 23, 25, 27],
		"%s and %s" % [c1_ids, c2_ids])
	var bad: Array[String] = []
	for row: ApplicantData in rows:
		if row.name == "" or row.tradition == "" or row.ancestry == "" or row.bloodline == "":
			bad.append("%d names" % row.id)
		if row.heritage == "" or row.criminality == "" or row.age <= 0:
			bad.append("%d traits" % row.id)
		if row.stats.size() != ApplicantData.STAT_KEYS.size() or row.tools.size() != 1:
			bad.append("%d stats" % row.id)
		if row.knowledges.size() != 1 or not ApplicantData.RARITIES.has(row.rarity):
			bad.append("%d rarity" % row.id)
		if not row.is_open():
			bad.append("%d status" % row.id)
	TestFixtures.check(res, "every arrival has every field filled",
		rows.size() == 8 and bad.is_empty(), TestFixtures.detail(bad, rows.size(), "applicants"))
	var unpriced: Array[int] = []
	var misnamed: Array[int] = []
	var foreign: Array[int] = []
	for row: ApplicantData in rows:
		if not _priced_by_merc(row):
			unpriced.append(row.id)
		if not _named_for_merc(row):
			misnamed.append(row.id)
		if not _ancestry_of_merc(row):
			foreign.append(row.id)
	TestFixtures.check(res, "each applicant's level and rate are its rolled merc's",
		unpriced.is_empty(), "off %s" % [unpriced])
	TestFixtures.check(res, "every applicant is named for its rolled merc",
		misnamed.is_empty(), "%s and %s, off %s" % [rows[0].name, rows[7].name, misnamed])
	TestFixtures.check(res, "every applicant carries its rolled merc's real ancestry",
		foreign.is_empty(), "%s and %s, off %s" % [rows[0].ancestry, rows[7].ancestry, foreign])
	TestFixtures.check(res, "the next campaign is named after the id it will take",
		PromotionsManager.next_campaign_name() == "Campaign 3"
		and PromotionsManager.next_campaign_id == 3,
		"%s" % [PromotionsManager.next_campaign_name()])
	TestFixtures.check(res, "a campaign name answers by id, and a walk-in names itself",
		PromotionsManager.campaign_name(1) == "Campaign 1"
		and PromotionsManager.campaign_name(2) == "Campaign 2"
		and PromotionsManager.campaign_name(ApplicantData.WALK_IN) == "Walk-In"
		and PromotionsManager.campaign_name(99) == "",
		"%s" % [PromotionsManager.campaign_name(2)])
	var dotted: Array[int] = _ids_matching(func(a: ApplicantData) -> bool: return a.unseen)
	TestFixtures.check(res, "every arrival is unseen until the player looks",
		PromotionsManager.has_unseen() and dotted.size() == rows.size(), "%s carry the dot" % [dotted])
	PromotionsManager.mark_seen()
	TestFixtures.check(res, "marking the page seen clears every dot",
		not PromotionsManager.has_unseen() and not PromotionsManager.applicant_of(23).unseen
		and _ids_matching(func(a: ApplicantData) -> bool: return a.unseen).is_empty(),
		"has_unseen %s" % [PromotionsManager.has_unseen()])
	TestFixtures.check(res, "an unknown id finds no campaign and no applicant",
		PromotionsManager.campaign_of(99) == null and PromotionsManager.applicant_of(99) == null,
		"both come back null")


#Case 8: the numbers one campaign card reads off itself.
static func _case_card_stats(res: Dictionary) -> void:
	_board(res)
	var t: int = GameState.day()
	var one: CampaignData = PromotionsManager.campaign_of(1)
	TestFixtures.check(res, "a fixed ad paid in full at launch spends by the day and holds the rest",
		one.used(t) == 12 and one.run_days(t) == 12 and one.spent_so_far(t) == 60
		and one.unused_days(t) == 18 and one.budget_remaining(t) == 90
		and one.total_committed(t) == 150 and one.total_cost == 150 and one.next_bill_day == -1
		and is_equal_approx(one.progress(t), 0.4),
		"spent %d, left %d" % [one.spent_so_far(t), one.budget_remaining(t)])
	var radio: CampaignData = PromotionsManager.campaign_of(3)
	TestFixtures.check(res, "an Infinite ad spends every day it has run and holds the days to its first bill",
		radio.used(t) == 12 and radio.spent_so_far(t) == 960 and radio.next_bill_day == 161
		and radio.total_cost == 3120 and radio.unused_days(t) == 27 and radio.budget_remaining(t) == 2160
		and radio.total_committed(t) == 3120
		and is_equal_approx(radio.progress(t), 1.0) and not radio.is_concluded(t),
		"spent %d, left %d" % [radio.spent_so_far(t), radio.budget_remaining(t)])
	var over: CampaignData = PromotionsManager.campaign_of(4)
	TestFixtures.check(res, "an ad that ran out spent its whole budget and no more",
		over.used(t) == 12 and over.run_days(t) == 5 and over.spent_so_far(t) == 25
		and over.total_cost == 25 and over.budget_remaining(t) == 0 and over.is_concluded(t),
		"spent %d over %d days" % [over.spent_so_far(t), over.run_days(t)])
	var crew: CampaignData = PromotionsManager.campaign_of(2)
	TestFixtures.check(res, "a Word of Mouth ad spent its crew pay and holds nothing back",
		crew.spent_so_far(t) == 50 and crew.budget_remaining(t) == 0 and crew.unused_days(t) == 0
		and crew.next_bill_day == -1 and crew.bill_day == -1,
		"crew %d, left %d" % [crew.spent_so_far(t), crew.budget_remaining(t)])
	var forever: CampaignData = PromotionsManager.campaign_of(5)
	TestFixtures.check(res, "a Sponsorship launched on the 10th paid 32 days and has spent five",
		forever.total_cost == 8000 and forever.spent_so_far(t) == 1250
		and forever.budget_remaining(t) == 6750 and forever.total_committed(t) == 8000
		and forever.next_bill_day == 161,
		"spent %d, left %d" % [forever.spent_so_far(t), forever.budget_remaining(t)])
	var late: CampaignData = PromotionsManager.campaign_of(6)
	TestFixtures.check(res, "a later fixed ad counts its own days left",
		late.days_left(t) == 15 and late.total_committed(t) == 100 and late.spent_so_far(t) == 25,
		"%d days left" % [late.days_left(t)])
	TestFixtures.check(res, "the results count every applicant the ad has pulled in",
		PromotionsManager.results_of(one) == 4 and PromotionsManager.results_of(radio) == 4
		and PromotionsManager.results_of(over) == 1 and PromotionsManager.results_of(forever) == 1,
		"%d, %d, %d, %d" % [PromotionsManager.results_of(one), PromotionsManager.results_of(radio),
		PromotionsManager.results_of(over), PromotionsManager.results_of(forever)])
	TestFixtures.check(res, "the success rate is the results a week so far",
		is_equal_approx(PromotionsManager.success_rate(one, t), 4.0 / 12.0 * 7.0)
		and is_equal_approx(PromotionsManager.success_rate(forever, t), 1.4)
		and is_equal_approx(PromotionsManager.success_rate(over, t), 1.4),
		"campaign 1 at %.2f a week" % [PromotionsManager.success_rate(one, t)])
	TestFixtures.check(res, "no campaign has no stats to read",
		PromotionsManager.results_of(null) == 0
		and is_equal_approx(PromotionsManager.success_rate(null, t), 0.0), "both read nothing")


#Case 9: the My Promotions list: what the two toggles hide and how the five sorts order it.
static func _case_list(res: Dictionary) -> void:
	_board(res)
	var t: int = GameState.day()
	var job: String = CampaignData.MODE_JOB
	TestFixtures.check(res, "the tab count is every campaign of the tab",
		PromotionsManager.campaign_count(job) == 5
		and PromotionsManager.campaign_count(CampaignData.MODE_PROMO) == 1
		and PromotionsManager.campaigns_in(job).size() == 5,
		"%d job ads" % [PromotionsManager.campaign_count(job)])
	TestFixtures.check(res, "the list opens on the running ads and hides the one that ran out",
		_cids(PromotionsManager.campaigns_filtered(job, false, true, t)) == [1, 3, 5, 6],
		"%s" % [_cids(PromotionsManager.campaigns_filtered(job, false, true, t))])
	TestFixtures.check(res, "Show Concluded brings the finished ad back",
		PromotionsManager.campaigns_filtered(job, true, true, t).size() == 5
		and _cids(PromotionsManager.campaigns_filtered(job, true, true, t)).has(4),
		"%d rows" % [PromotionsManager.campaigns_filtered(job, true, true, t).size()])
	TestFixtures.check(res, "dropping the Infinite ads takes two more rows out",
		PromotionsManager.campaigns_filtered(job, false, false, t).size() == 2
		and PromotionsManager.campaigns_filtered(job, true, false, t).size() == 3,
		"%d and %d rows" % [PromotionsManager.campaigns_filtered(job, false, false, t).size(),
		PromotionsManager.campaigns_filtered(job, true, false, t).size()])
	TestFixtures.check(res, "Start Date reads newest first and turns right around",
		_order(job, &"start", false, t) == [6, 5, 3, 1] and _order(job, &"start", true, t)[0] == 3
		and PromotionsManager.CAMPAIGN_SORT_DEFAULT == &"start"
		and not PromotionsManager.CAMPAIGN_ASCENDING_DEFAULT,
		"%s" % [_order(job, &"start", false, t)])
	var left: Array[int] = _order(job, &"left", true, t)
	TestFixtures.check(res, "Time Remaining leads with the ad closest to its end",
		left == [6, 1, 5, 3], "%s" % [left])
	var method: Array[int] = _order(job, &"method", true, t)
	TestFixtures.check(res, "Campaign Method leads with the best method the guild bought",
		method == [5, 3, 6, 1] and PromotionsManager.campaign_of(method[0]).type_key == &"sponsor",
		"%s" % [method])
	var cost: Array[int] = _order(job, &"cost", true, t)
	TestFixtures.check(res, "Cost sorts on the notes the ad has committed",
		cost == [6, 1, 3, 5] and _order(job, &"cost", false, t)[0] == 5, "%s" % [cost])
	var best: Array[int] = _order(job, &"success", false, t)
	TestFixtures.check(res, "Success Rate leads with the ad pulling the most a week",
		best == [3, 1, 6, 5] and _order(job, &"success", true, t)[0] == 6, "%s" % [best])
	var tied: Array[int] = [1, 3]
	TestFixtures.check(res, "campaigns on the same rate hold the newest first, either way",
		_kept(best, tied) == [3, 1]
		and _kept(_order(job, &"success", true, t), tied) == [3, 1],
		"%s" % [_kept(best, tied)])
	TestFixtures.check(res, "the sort dropdown reads its five labels off the table",
		PromotionsManager.CAMPAIGN_SORTS.size() == 5
		and PromotionsManager.campaign_sort_label(&"start") == "Start Date"
		and PromotionsManager.campaign_sort_label(&"left") == "Time Remaining"
		and PromotionsManager.campaign_sort_label(&"success") == "Success Rate"
		and PromotionsManager.campaign_sort_label(&"method") == "Campaign Method"
		and PromotionsManager.campaign_sort_label(&"cost") == "Cost"
		and PromotionsManager.campaign_sort_label(&"nope") == "", "five sorts, no sixth")


#Case 10: the Hiring filters, the Applied Via chips and the four sorts.
static func _case_filters(res: Dictionary) -> void:
	_fresh()
	_arrivals(4, 2)
	TestFixtures.check(res, "an untouched filter set leaves every applicant standing",
		PromotionsManager.applicants_filtered().size() == 8,
		"%d rows" % [PromotionsManager.applicants_filtered().size()])
	var cut: int = _ask_at_rank(CHEAP_RANK)
	var cheap: Dictionary = {&"salary": [0.0, float(cut)]}
	var cheap_ids: Array[int] = _ids_within(cut, int(TraitFilterDefs.AGE_MIN), int(TraitFilterDefs.AGE_MAX))
	TestFixtures.check(res, "the salary slider keeps the applicants inside its range",
		_sorted_ids(PromotionsManager.applicants_filtered(cheap)) == cheap_ids
		and cheap_ids.size() > CHEAP_RANK,
		"%s against %s" % [_sorted_ids(PromotionsManager.applicants_filtered(cheap)), cheap_ids])
	var strong: Dictionary = {&"vigor": 5}
	TestFixtures.check(res, "a locked stat row filters nothing until its test is held",
		PromotionsManager.applicants_filtered(strong).size() == 8,
		"%d rows" % [PromotionsManager.applicants_filtered(strong).size()])
	SubscriptionManager.set_entitlements({"brawn": true})
	var vigorous: Array[int] = _ids_matching(func(a: ApplicantData) -> bool: return a.stat("vigor") >= 5)
	TestFixtures.check(res, "Min Vigor keeps the applicants at or above it once unlocked",
		_sorted_ids(PromotionsManager.applicants_filtered(strong)) == vigorous,
		"%s against %s" % [_sorted_ids(PromotionsManager.applicants_filtered(strong)), vigorous])
	var picked_tradition: String = PromotionsManager.applicant_of(20).tradition
	var one_tradition: Dictionary = {&"tradition": [picked_tradition]}
	var same_tradition: Array[int] = _ids_matching(func(a: ApplicantData) -> bool:
		return a.tradition == picked_tradition)
	TestFixtures.check(res, "a tradition chip keeps that tradition alone",
		same_tradition.has(20)
		and _sorted_ids(PromotionsManager.applicants_filtered(one_tradition)) == same_tradition,
		"%s keeps %s" % [picked_tradition,
		_sorted_ids(PromotionsManager.applicants_filtered(one_tradition))])
	var seeded: Array[ApplicantData] = PromotionsManager.applicants
	var carried: Array[String] = [seeded[0].ancestry]
	var either: Array[String] = [seeded[0].ancestry, seeded[seeded.size() - 1].ancestry]
	var carriers: Array[int] = _ids_with_ancestry(carried)
	var ancestry: Dictionary = {&"ancestry": carried}
	TestFixtures.check(res, "an Ancestry chip needs Hiring Discrimination before it bites",
		PromotionsManager.applicants_filtered(ancestry).size() == 8, "still eight rows")
	SubscriptionManager.set_entitlements({"hiringDiscrim": true})
	TestFixtures.check(res, "the Ancestry chip then keeps exactly the applicants who carry it",
		not carriers.is_empty()
		and _sorted_ids(PromotionsManager.applicants_filtered(ancestry)) == carriers,
		"%s against %s" % [_sorted_ids(PromotionsManager.applicants_filtered(ancestry)), carriers])
	var uncarried: Array[String] = [_uncarried_ancestry()]
	TestFixtures.check(res, "a real ancestry no applicant carries keeps nobody",
		uncarried[0] != "" and PromotionsManager.applicants_filtered({&"ancestry": uncarried}).is_empty(),
		"%s keeps %d" % [uncarried, PromotionsManager.applicants_filtered({&"ancestry": uncarried}).size()])
	TestFixtures.check(res, "two Ancestry chips keep the applicants who carry either one",
		_sorted_ids(PromotionsManager.applicants_filtered({&"ancestry": either}))
		== _ids_with_ancestry(either),
		"%s against %s" % [_sorted_ids(PromotionsManager.applicants_filtered({&"ancestry": either})),
		_ids_with_ancestry(either)])
	var young: Dictionary = {&"age": [float(AGE_LOW), float(AGE_HIGH)]}
	var young_ids: Array[int] = _ids_matching(func(a: ApplicantData) -> bool:
		return a.age >= AGE_LOW and a.age <= AGE_HIGH)
	TestFixtures.check(res, "the age range keeps the applicants inside it",
		_sorted_ids(PromotionsManager.applicants_filtered(young)) == young_ids,
		"%s against %s" % [_sorted_ids(PromotionsManager.applicants_filtered(young)), young_ids])
	var picked_tool: String = ""
	for row: ApplicantData in PromotionsManager.applicants:
		if picked_tool == "" and not row.tools.is_empty():
			picked_tool = row.tools[0]
	var tools: Dictionary = {&"tools": [picked_tool]}
	var tool_ids: Array[int] = _ids_matching(func(a: ApplicantData) -> bool:
		return a.tools.has(picked_tool))
	SubscriptionManager.set_entitlements({"skilltest": true})
	TestFixtures.check(res, "a tools chip matches an applicant's own list",
		not tool_ids.is_empty() and _sorted_ids(PromotionsManager.applicants_filtered(tools)) == tool_ids,
		"%s keeps %s" % [picked_tool, _sorted_ids(PromotionsManager.applicants_filtered(tools))])
	var two: Dictionary = {&"salary": [0.0, float(cut)], &"age": [float(AGE_LOW), float(AGE_HIGH)]}
	var both_ids: Array[int] = _ids_within(cut, AGE_LOW, AGE_HIGH)
	TestFixtures.check(res, "two filters narrow together",
		_sorted_ids(PromotionsManager.applicants_filtered(two)) == both_ids,
		"%s against %s" % [_sorted_ids(PromotionsManager.applicants_filtered(two)), both_ids])
	var walk: Array[int] = [ApplicantData.WALK_IN]
	var via_one: Array[int] = [1]
	var both: Array[int] = [1, ApplicantData.WALK_IN]
	TestFixtures.check(res, "the Applied Via chips read the campaign an applicant came through",
		PromotionsManager.applicants_filtered({}, walk).is_empty()
		and _sorted_ids(PromotionsManager.applicants_filtered({}, via_one)) == [20, 22, 24, 26]
		and PromotionsManager.applicants_filtered({}, both).size() == 4,
		"campaign 1 %s" % [_sorted_ids(PromotionsManager.applicants_filtered({}, via_one))])
	var empty: Array[int] = []
	var fit_of: Callable = func(a: ApplicantData) -> float: return a.fit
	TestFixtures.check(res, "Fit descending is the list's opening order",
		_ids(PromotionsManager.applicants_filtered())[0] == _lead_id(fit_of, true)
		and _ids(PromotionsManager.applicants_filtered({}, empty, &"fit", false))[0]
			== _lead_id(fit_of, false),
		"%s" % [_ids(PromotionsManager.applicants_filtered())])
	TestFixtures.check(res, "Level sorts both ways",
		_ordered(&"level", true) and _ordered(&"level", false),
		"%s" % [_ids(PromotionsManager.applicants_filtered({}, empty, &"level", true))])
	TestFixtures.check(res, "Salary sorts both ways",
		_ordered(&"salary", true) and _ordered(&"salary", false),
		"%s" % [_ids(PromotionsManager.applicants_filtered({}, empty, &"salary", false))])
	var uniq_of: Callable = func(a: ApplicantData) -> float:
		return a.uniq * 10.0 + float(a.rarity_rank())
	TestFixtures.check(res, "Uniqueness sorts on the rarity behind it and ties on the id",
		_ids(PromotionsManager.applicants_filtered({}, empty, &"uniqueness", true))[0]
			== _lead_id(uniq_of, true)
		and _ids(PromotionsManager.applicants_filtered({}, empty, &"uniqueness", false))[0]
			== _lead_id(uniq_of, false),
		"%s" % [_ids(PromotionsManager.applicants_filtered({}, empty, &"uniqueness", true))])
	TestFixtures.check(res, "the sort dropdown reads its four labels off the table",
		PromotionsManager.sort_label(&"uniqueness") == "Uniqueness"
		and PromotionsManager.sort_label(&"fit") == "Fit"
		and PromotionsManager.sort_label(&"level") == "Level"
		and PromotionsManager.sort_label(&"salary") == "Salary"
		and PromotionsManager.sort_label(&"nope") == "", "four sorts, no fifth")


#Case 11: what stops a campaign going out, and what launching one costs.
static func _case_launch(res: Dictionary) -> void:
	_fresh(_launch_ent())
	var today: int = GameState.day()
	PromotionsManager.mark_seen()
	GameState.bank_notes = 1000
	_expect_reason(res, "no campaign refuses with its own reason", null, "No campaign.")
	var radio: CampaignData = _campaign(&"radio", CampaignData.MODE_JOB, 30)
	_expect_reason(res, "a type whose key is not held names itself as locked", radio, "Radio is locked.")
	var direct_job: CampaignData = _campaign(&"direct", CampaignData.MODE_JOB, 30)
	_expect_reason(res, "Direct Sale refuses the Job Ads tab",
		direct_job, "Direct Sale is for Guild Promo only.")
	var direct: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	_expect_reason(res, "Direct Sale asks who it advertises to", direct, "Choose who to advertise to.")
	var sponsor: CampaignData = _campaign(&"sponsor", CampaignData.MODE_PROMO, 30)
	_expect_reason(res, "Sponsorship asks who it sponsors", sponsor, "Choose who to sponsor.")
	direct.sponsor_target = "Company 2"
	TestFixtures.check(res, "naming the company clears that reason",
		bool(PromotionsManager.can_launch(direct)["ok"]),
		_reason(PromotionsManager.can_launch(direct)))
	var three: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	var trio: Array[int] = [0, 2, 4]
	three.advertise_targets = trio
	TestFixtures.check(res, "three advertised companies clear the reason on the indices alone",
		bool(PromotionsManager.can_launch(three)["ok"]) and three.sponsor_target == "",
		_reason(PromotionsManager.can_launch(three)))
	var one_pick: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	var only: Array[int] = [3]
	one_pick.advertise_targets = only
	var no_pick: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	TestFixtures.check(res, "one company is enough and an empty pick list still refuses",
		bool(PromotionsManager.can_launch(one_pick)["ok"])
		and _reason(PromotionsManager.can_launch(no_pick)) == "Choose who to advertise to.",
		_reason(PromotionsManager.can_launch(one_pick)))
	var sponsor_pick: CampaignData = _campaign(&"sponsor", CampaignData.MODE_PROMO, 3)
	sponsor_pick.sponsor_index = 6
	TestFixtures.check(res, "a sponsored event index clears the sponsor reason",
		bool(PromotionsManager.can_launch(sponsor_pick)["ok"]),
		_reason(PromotionsManager.can_launch(sponsor_pick)))
	var short_run: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 0)
	var long_run: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 31)
	TestFixtures.check(res, "a run shorter than a day or longer than thirty refuses",
		_reason(PromotionsManager.can_launch(short_run)) == "A promo runs at least 1 day."
		and _reason(PromotionsManager.can_launch(long_run)) == "Promos run up to 30 days.",
		_reason(PromotionsManager.can_launch(short_run)))
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 14)
	_expect_reason(res, "Word of Mouth needs a crew to send", wom, "Add at least one merc.")
	var crowd: Array[int] = [1, 2, 3]
	wom.crew = crowd
	_expect_reason(res, "the crew cannot outrun the Odd Job slots the guild holds",
		wom, "Odd Jobs holds 2 mercs.")
	var pair: Array[int] = _free_uids(res, 2, "two free mercs for the Word of Mouth crew")
	wom.crew = pair
	TestFixtures.check(res, "Word of Mouth costs its crew's pay and nothing by the day",
		PromotionsManager.launch_cost(wom) == 50 and PromotionsManager.pay_per_of(wom) == 25,
		"cost %d" % [PromotionsManager.launch_cost(wom)])
	GameState.bank_notes = 100
	var pricey: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 30)
	_expect_reason(res, "a campaign the bank cannot cover refuses", pricey, "Not enough notes.")
	GameState.bank_notes = 1000
	var flyers: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 30)
	TestFixtures.check(res, "a launch takes the whole price up front",
		PromotionsManager.launch(flyers) and GameState.bank_notes == 850,
		"bank %d" % GameState.bank_notes)
	TestFixtures.check(res, "the launched campaign is stamped and named after its id",
		flyers.id == 1 and flyers.name == "Campaign 1" and flyers.day_started == today
		and flyers.per_day == 5 and flyers.total_cost == 150 and flyers.next_bill_day == -1 and flyers.bill_day == 2
		and flyers.next_arrival_day == -1,
		"id %d, started %d" % [flyers.id, flyers.day_started])
	TestFixtures.check(res, "the new name is on the roll and the next id moves on",
		PromotionsManager.campaign_name(1) == "Campaign 1"
		and PromotionsManager.next_campaign_name() == "Campaign 2",
		PromotionsManager.next_campaign_name())
	TestFixtures.check(res, "a job campaign joins the Job Ads tab",
		PromotionsManager.campaign_count(CampaignData.MODE_JOB) == 1
		and _cids(PromotionsManager.campaigns_in(CampaignData.MODE_JOB)) == [1],
		"%d job campaigns" % [PromotionsManager.campaign_count(CampaignData.MODE_JOB)])
	TestFixtures.check(res, "ending a campaign that never ran hands the whole price back",
		PromotionsManager.end(1) and GameState.bank_notes == 1000
		and PromotionsManager.campaign_of(1) == null
		and PromotionsManager.campaign_count(CampaignData.MODE_JOB) == 0,
		"bank %d" % [GameState.bank_notes])
	TestFixtures.check(res, "a campaign cannot be ended twice and an unknown id does nothing",
		not PromotionsManager.end(1) and not PromotionsManager.end(99), "both refuse")
	TestFixtures.check(res, "a Word of Mouth promo launches on its crew pay alone",
		PromotionsManager.launch(wom) and GameState.bank_notes == 950 and wom.id == 2
		and wom.total_cost == 50 and wom.per_day == 0
		and wom.next_arrival_day == today + PromotionsManager.ARRIVAL_DAYS,
		"bank %d, cost %d" % [GameState.bank_notes, wom.total_cost])
	TestFixtures.check(res, "the guild promo tab holds the promo",
		PromotionsManager.campaign_count(CampaignData.MODE_PROMO) == 1
		and _cids(PromotionsManager.campaigns_in(CampaignData.MODE_PROMO)) == [2],
		"%s" % [_cids(PromotionsManager.campaigns_in(CampaignData.MODE_PROMO))])
	var far: CampaignData = _campaign(&"sponsor", CampaignData.MODE_JOB, 5)
	far.sponsor_target = "Company 1"
	var one_place: Array[int] = [2]
	far.locations = one_place
	GameState.bank_notes = 5000
	TestFixtures.check(res, "a sponsored job ad goes out on the one location it holds",
		PromotionsManager.launch(far) and far.locations == [2] and far.id == 3
		and far.total_cost == 1250, "%s at %d" % [far.locations, far.total_cost])
	var wide: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	var places: Array[int] = [0, 2]
	wide.locations = places
	wide.filters[&"loc"] = []
	TestFixtures.check(res, "a launch keeps every location the type reaches and syncs the filter",
		PromotionsManager.launch(wide) and wide.locations == places
		and (wide.filters[&"loc"] as Array) == places and wide.id == 4,
		"%s against %s" % [wide.locations, wide.filters[&"loc"]])
	var many: CampaignData = _campaign(&"direct", CampaignData.MODE_PROMO, 5)
	many.advertise_targets = trio
	many.sponsor_index = 0
	many.sponsor_target = "Company 1, Company 3, Company 5"
	many.advertise_to = CampaignData.TO_COMPANY
	var back: CampaignData = CampaignData.from_dict(many.to_dict())
	TestFixtures.check(res, "a campaign that advertises to three companies survives the save",
		back.advertise_targets == trio and back.sponsor_index == 0
		and back.sponsor_target == many.sponsor_target
		and back.advertise_to == CampaignData.TO_COMPANY,
		"%s" % [back.advertise_targets])
	var older: CampaignData = CampaignData.from_dict({"type_key": "direct", "days": 5,
		"mode": CampaignData.MODE_PROMO, "sponsor_index": 3, "sponsor_target": "Company 4"})
	TestFixtures.check(res, "a campaign saved before the multi pick loads and still launches",
		older.advertise_targets.is_empty() and older.sponsor_index == 3
		and bool(PromotionsManager.can_launch(older)["ok"]),
		_reason(PromotionsManager.can_launch(older)))
	var known: Array[String] = ContractLibrary.contract_type_names()
	var by_index: CampaignData = CampaignData.from_dict({"type_key": "direct", "days": 5,
		"mode": CampaignData.MODE_PROMO, "contract_types": [1, 4.0, 99, -1, 2.5, "", known[1]]})
	var mapped: Array[String] = [known[1], known[4]]
	TestFixtures.check(res, "a campaign saved with type indices loads them as type names, once each",
		by_index.contract_types == mapped, "%s" % [by_index.contract_types])
	var by_name: CampaignData = CampaignData.from_dict({"type_key": "direct", "days": 5,
		"mode": CampaignData.MODE_PROMO, "contract_types": ["Escort", "TEST Gone"]})
	var kept: Array[String] = ["Escort", "TEST Gone"]
	TestFixtures.check(res, "a campaign saved with type names keeps them, and none loads as none",
		by_name.contract_types == kept and CampaignData.from_dict({}).contract_types.is_empty(),
		"%s" % [by_name.contract_types])
	var saved: CampaignData = _campaign(&"flyers", CampaignData.MODE_PROMO, 5)
	saved.contract_types.assign([known[3]])
	var one_type: Array[String] = [known[3]]
	var reloaded: CampaignData = CampaignData.from_dict(saved.to_dict())
	TestFixtures.check(res, "type names survive the save",
		reloaded.contract_types == one_type, "%s" % [reloaded.contract_types])


#Case 12: the tier gates a launch has to clear.
static func _case_launch_rules(res: Dictionary) -> void:
	_fresh({"promotions": true, "adRadio": true, "adDirect": true, "adSponsor": true,
		"maxPromoDays": 25, "jobPostings": true, "guildPromo": true})
	GameState.bank_notes = 100000
	var month: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 30)
	_expect_reason(res, "a run past the duration cap names the cap", month, "Promos run up to 25 days.")
	var forever: CampaignData = _forever(&"flyers", CampaignData.MODE_JOB)
	_expect_reason(res, "an Infinite run waits on the top tier of Long Promos",
		forever, "Infinite promos are locked.")
	SubscriptionManager.set_entitlements(
		{"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE})
	TestFixtures.check(res, "the sentinel cap opens both the Infinite run and the thirty day one",
		bool(PromotionsManager.can_launch(forever)["ok"])
		and bool(PromotionsManager.can_launch(month)["ok"]),
		_reason(PromotionsManager.can_launch(forever)))
	var radio: CampaignData = _campaign(&"radio", CampaignData.MODE_JOB, 10)
	var far: Array[int] = [4]
	radio.locations = far
	_expect_reason(res, "a type refuses a location it cannot reach, by name",
		radio, "Radio cannot reach Rossade.")
	var sponsor: CampaignData = _campaign(&"sponsor", CampaignData.MODE_JOB, 10)
	sponsor.sponsor_target = "Company 1"
	var two: Array[int] = [0, 2]
	sponsor.locations = two
	_expect_reason(res, "Sponsorship refuses a second location", sponsor, "Sponsorship takes one location.")
	var promo: CampaignData = _campaign(&"flyers", CampaignData.MODE_PROMO, 10)
	promo.difficulty_lo = 1.5
	_expect_reason(res, "a Guild Promo field the guild has not paid for has to stay put",
		promo, "Minimum Difficulty is locked.")
	promo.difficulty_lo = 0.5
	promo.difficulty_hi = 4.0
	_expect_reason(res, "the Max Difficulty handle is its own tier", promo, "Maximum Difficulty is locked.")
	promo.difficulty_hi = 5.0
	var types: Array[String] = [ContractLibrary.contract_type_names()[2]]
	promo.contract_types = types
	_expect_reason(res, "the Contract Type section is its own tier too", promo, "Contract Type is locked.")
	var open_types: Array[String] = []
	promo.contract_types = open_types
	SubscriptionManager.set_entitlements({"guildPromo": false})
	TestFixtures.check(res, "the Guild Ads tab itself is locked until Guild Promo is held",
		_reason(PromotionsManager.can_launch(promo)) == "Guild Promotion is locked."
		and not PromotionsManager.mode_unlocked(CampaignData.MODE_PROMO,
			SubscriptionManager.entitlements()),
		_reason(PromotionsManager.can_launch(promo)))
	SubscriptionManager.set_entitlements({"guildPromo": true, "jobPostings": false})
	var job: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 10)
	TestFixtures.check(res, "the Job Ads tab is locked until Job Postings are held",
		_reason(PromotionsManager.can_launch(job)) == "Job Postings are locked."
		and bool(PromotionsManager.can_launch(promo)["ok"]),
		_reason(PromotionsManager.can_launch(job)))
	var lock: Dictionary = PromotionsManager.mode_lock(CampaignData.MODE_PROMO)
	TestFixtures.check(res, "a locked tab names the upgrade tier behind it",
		String(lock["upgrade_id"]) == "guildpromo" and int(lock["tier"]) == 1
		and int(lock["tiers"]) == 4 and String(lock["name"]) == "Guild Promo"
		and String(PromotionsManager.mode_lock(CampaignData.MODE_JOB)["upgrade_id"])
			== "promotions" and PromotionsManager.mode_lock("nope").is_empty(),
		"%s" % [lock])
	_fresh({"promotions": true, "jobPostings": true})
	GameState.bank_notes = 100000
	TestFixtures.check(res, "without the Long Promos cap no campaign goes out at all",
		_reason(PromotionsManager.can_launch(_campaign(&"flyers", CampaignData.MODE_JOB, 5)))
		== "Promos are locked.",
		_reason(PromotionsManager.can_launch(_campaign(&"flyers", CampaignData.MODE_JOB, 5))))


#Case 13: ending a campaign early and what it hands back.
static func _case_end_refund(res: Dictionary) -> void:
	_board(res)
	var t: int = GameState.day()
	GameState.bank_notes = 1000
	var preview: Dictionary = PromotionsManager.end_preview(1)
	TestFixtures.check(res, "the confirm dialog reads the unused days and the notes back",
		bool(preview["ok"]) and int(preview["refund"]) == 90 and int(preview["unused"]) == 18
		and not bool(preview["infinite"]) and not bool(preview["crew_paid"]),
		"%s" % [preview])
	TestFixtures.check(res, "ending a fixed ad hands back the days it never used",
		PromotionsManager.end(1) and GameState.bank_notes == 1090
		and PromotionsManager.campaign_of(1) == null
		and PromotionsManager.campaign_count(CampaignData.MODE_JOB) == 4,
		"bank %d" % [GameState.bank_notes])
	TestFixtures.check(res, "an ended ad still answers to its name for the applicants it sent",
		PromotionsManager.campaign_name(1) == "Campaign 1"
		and PromotionsManager.applicant_of(20).campaign_id == 1,
		"%s" % [PromotionsManager.campaign_name(1)])
	var crew: Dictionary = PromotionsManager.end_preview(2)
	TestFixtures.check(res, "a Word of Mouth crew was already paid, so nothing comes back",
		bool(crew["ok"]) and int(crew["refund"]) == 0 and bool(crew["crew_paid"])
		and PromotionsManager.end(2) and GameState.bank_notes == 1090,
		"%s" % [crew])
	var forever: Dictionary = PromotionsManager.end_preview(3)
	TestFixtures.check(res, "ending an Infinite ad hands back the days to its next bill",
		bool(forever["infinite"]) and int(forever["refund"]) == 2160
		and int(forever["unused"]) == 27 and PromotionsManager.end(3)
		and GameState.bank_notes == 3250, "%s" % [forever])
	var over: Dictionary = PromotionsManager.end_preview(4)
	TestFixtures.check(res, "an ad that already ran out cannot be ended and gives nothing",
		not bool(over["ok"]) and int(over["refund"]) == 0 and not PromotionsManager.end(4)
		and PromotionsManager.campaign_of(4) != null, "%s" % [over])
	TestFixtures.check(res, "an unknown id previews nothing",
		not bool(PromotionsManager.end_preview(99)["ok"])
		and int(PromotionsManager.end_preview(99)["refund"]) == 0, "no such campaign")
	TestFixtures.check(res, "the day the ad ran out is still the day it was told to end",
		PromotionsManager.campaign_of(4).is_concluded(t), "concluded before today")


#Case 14: the monthly charge an Infinite campaign brings on its calendar day, and what a short bank does to it.
static func _case_infinite_billing(res: Dictionary) -> void:
	var ent: Dictionary = {"promotions": true, "adRadio": true, "jobPostings": true,
		"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE}
	_fresh(ent)
	var today: int = GameState.day()
	TestFixtures.check(res, "the first period runs to the first bill date, capped at a fixed run's length",
		PromotionsManager.first_bill_days(122) == 39 and PromotionsManager.first_bill_days(122, 30) == 30
		and PromotionsManager.first_bill_days(122, 50) == 39 and PromotionsManager.first_bill_days(150) == 24
		and PromotionsManager.first_charge(&"flyers", 122, 30) == 150
		and PromotionsManager.first_charge(&"flyers", 122, 5) == 25,
		"%d days from the 3rd of Erta" % [PromotionsManager.first_bill_days(122)])
	GameState.bank_notes = 10000
	var radio: CampaignData = _forever(&"radio", CampaignData.MODE_JOB)
	var charge: int = PromotionsManager.launch_cost(radio)
	var went: bool = PromotionsManager.launch(radio)
	var after: int = GameState.bank_notes
	TestFixtures.check(res, "an Infinite launch on the 3rd of Erta pays 39 days of its month up front",
		charge == 3120 and charge == PromotionsManager.first_charge(&"radio", today) and went
		and GameState.bank_notes == 10000 - 3120 and radio.days == 0 and radio.total_cost == 3120,
		"charge %d bank %d" % [charge, GameState.bank_notes])
	var first: Dictionary = TrynnCalendar.date_of(radio.next_bill_day * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "a launch on the 3rd of Erta bills on the 2nd, first on the 2nd of Kusarra",
		today == 122 and radio.bill_day == 2 and radio.next_bill_day == 161
		and int(first["day"]) == 2 and String(first["month_name"]) == "Kusarra",
		"bill day %d, next bill %d" % [radio.bill_day, radio.next_bill_day])
	TestFixtures.check(res, "the first period of an Infinite ad counts its unused days to the first bill",
		radio.unused_days(today) == 39 and radio.budget_remaining(today) == 3120
		and radio.unused_days(150) == 11 and radio.unused_days(161) == 0,
		"%d days" % [radio.unused_days(today)])
	var paid: Array[int] = []
	var watcher: Callable = func(id: int, amount: int) -> void:
		if id == radio.id:
			paid.append(amount)
	PromotionsManager.campaign_billed.connect(watcher)
	TestFixtures.pass_days(160 - GameState.day())
	TestFixtures.check(res, "nothing more is charged before the bill day",
		went and paid.is_empty() and GameState.bank_notes == after, "%s, bank %d" % [paid, GameState.bank_notes])
	TestFixtures.pass_days(1)
	PromotionsManager.campaign_billed.disconnect(watcher)
	var second: Dictionary = TrynnCalendar.date_of(radio.next_bill_day * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "the bill day charges another month and moves the bill to the 2nd of Urbai",
		GameState.day() == 161 and paid == [2400] and GameState.bank_notes == after - 2400
		and radio.next_bill_day == 191 and int(second["day"]) == 2 and String(second["month_name"]) == "Urbai"
		and radio.next_bill_after(191) == 221,
		"bank %d, %s, next %d" % [GameState.bank_notes, paid, radio.next_bill_day])
	var failed: Array[Dictionary] = []
	var loss: Callable = func(id: int, name: String) -> void:
		failed.append({"id": id, "name": name})
	PromotionsManager.campaign_bill_failed.connect(loss)
	GameState.bank_notes = 100
	TestFixtures.pass_days(191 - GameState.day())
	PromotionsManager.campaign_bill_failed.disconnect(loss)
	TestFixtures.check(res, "a bill the bank cannot cover takes the campaign down",
		failed.size() == 1 and int(failed[0]["id"]) == radio.id
		and PromotionsManager.campaign_of(radio.id) == null and GameState.bank_notes <= 100,
		"%s" % [failed])
	var rows: Array[Dictionary] = PromotionsManager.billing_failures
	TestFixtures.check(res, "the missed charge is written down for the player to read",
		rows.size() == 1 and int(rows[0]["amount"]) == 2400 and int(rows[0]["day"]) == 191
		and String(rows[0]["name"]) == "Campaign 1", "%s" % [rows])
	_fresh(ent)
	TestFixtures.pass_days(150 - GameState.day())
	GameState.bank_notes = 100000
	var late: CampaignData = _forever(&"radio", CampaignData.MODE_JOB)
	var launched: bool = PromotionsManager.launch(late)
	var due: Array[int] = []
	for row: Dictionary in PromotionsManager.ad_bill_days(150, 90):
		if int(row["campaign_id"]) == late.id:
			due.append(int(row["day"]))
	TestFixtures.check(res, "a launch on the 31st of Erta bills on the 15th, then monthly on the 15th",
		launched and late.day_started == 150 and late.bill_day == 15 and late.next_bill_day == 174
		and due == [174, 204, 234] and late.unused_days(150) == 24,
		"bill day %d, due %s" % [late.bill_day, due])
	var fixed: CampaignData = TestFixtures.launch_campaign({"type": &"flyers", "days": 30})
	var fixed_rows: Array[Dictionary] = []
	if fixed != null:
		for row: Dictionary in PromotionsManager.ad_bill_days(150, 30):
			if int(row["campaign_id"]) == fixed.id:
				fixed_rows.append(row)
	TestFixtures.check(res, "a fixed run past the first bill date pays to it now and is billed the rest later",
		fixed != null and fixed.total_cost == 120 and fixed.next_bill_day == 174
		and PromotionsManager.next_bill_amount(fixed) == 30 and fixed_rows.size() == 1
		and int(fixed_rows[0]["day"]) == 174 and int(fixed_rows[0]["amount"]) == 30
		and PromotionsManager.monthly_ad_bill() == 2400 + 30 and PromotionsManager.billed_count() == 2,
		"%s, monthly %d" % [fixed_rows, PromotionsManager.monthly_ad_bill()])
	var billed: Array[int] = []
	var tally: Callable = func(id: int, amount: int) -> void:
		if fixed != null and id == fixed.id:
			billed.append(amount)
	PromotionsManager.campaign_billed.connect(tally)
	TestFixtures.pass_days(174 - GameState.day())
	PromotionsManager.campaign_billed.disconnect(tally)
	TestFixtures.check(res, "the fixed run's last bill pays through its end and stops billing",
		fixed != null and billed == [30] and fixed.next_bill_day == -1
		and PromotionsManager.next_bill_amount(fixed) == 0,
		"%s" % [billed])
	TestFixtures.pass_days(2)
	var tail: Dictionary = PromotionsManager.end_preview(fixed.id if fixed != null else -1)
	TestFixtures.check(res, "ending it after the last bill hands back the days left to its end",
		bool(tail["ok"]) and int(tail["refund"]) == 20 and int(tail["unused"]) == 4,
		"%s" % [tail])
	CampaignClock.reset()
	CampaignClock.advance_to(TrynnCalendar.START_MINUTE)


#Case 15: what the Infinite campaigns add to the Finance screen.
static func _case_finance(res: Dictionary) -> void:
	_board(res)
	var t: int = GameState.day()
	TestFixtures.check(res, "the monthly ad bill is the sum of every campaign's next bill",
		PromotionsManager.monthly_ad_bill() == 9900
		and PromotionsManager.infinite_count() == 2 and PromotionsManager.billed_count() == 2,
		"%d notes a month" % [PromotionsManager.monthly_ad_bill()])
	var rows: Array[Dictionary] = PromotionsManager.ad_bill_days(t, 30)
	TestFixtures.check(res, "the next month of charges holds one row per billed campaign",
		rows.size() == 2 and int(rows[0]["day"]) == 161 and int(rows[0]["amount"]) == 2400
		and int(rows[0]["campaign_id"]) == 3 and int(rows[1]["day"]) == 161
		and int(rows[1]["amount"]) == 7500 and int(rows[1]["campaign_id"]) == 5,
		"%s" % [rows])
	TestFixtures.check(res, "a window that ends before the charge is empty",
		PromotionsManager.ad_bill_days(t, 27).is_empty()
		and PromotionsManager.ad_bill_days(t, 0).is_empty(),
		"%s" % [PromotionsManager.ad_bill_days(t, 27)])
	TestFixtures.check(res, "a longer window holds the charges that follow, a month on the same day",
		PromotionsManager.ad_bill_days(t, 60).size() == 4
		and int(PromotionsManager.ad_bill_days(t, 60)[3]["day"]) == 191,
		"%d rows" % [PromotionsManager.ad_bill_days(t, 60).size()])
	PromotionsManager.end(3)
	TestFixtures.check(res, "taking an Infinite ad down takes its charge off the calendar",
		PromotionsManager.monthly_ad_bill() == 7500
		and PromotionsManager.infinite_count() == 1
		and PromotionsManager.ad_bill_days(t, 30).size() == 1,
		"%d notes a month" % [PromotionsManager.monthly_ad_bill()])


#Case 16: the View Applicants button of a job ad card.
static func _case_view_applicants(res: Dictionary) -> void:
	_fresh()
	_arrivals(1, 2)
	var seen: Array[int] = []
	var watcher: Callable = func(id: int) -> void:
		seen.append(id)
	GameState.open_hiring_requested.connect(watcher)
	PromotionsManager.view_applicants(2)
	GameState.open_hiring_requested.disconnect(watcher)
	var want: Array = [2]
	TestFixtures.check(res, "View Applicants opens Hiring filtered to that campaign",
		seen == [2] and GameState.hire_filter.size() == 1
		and (GameState.hire_filter.get("from", []) as Array) == want,
		"%s" % [GameState.hire_filter])
	var taken: Dictionary = GameState.take_hire_filter()
	TestFixtures.check(res, "the screen takes the filter once and leaves nothing behind",
		(taken.get("from", []) as Array) == want and GameState.hire_filter.is_empty(),
		"%s then %s" % [taken, GameState.hire_filter])
	var via: Array[int] = [2]
	TestFixtures.check(res, "that filter names the one applicant the campaign sent",
		_sorted_ids(PromotionsManager.applicants_filtered({}, via)) == [21],
		"%s" % [_sorted_ids(PromotionsManager.applicants_filtered({}, via))])


#Case 17: the Guild Opinion a hire carries and the two reasons hiring refuses.
static func _case_hire(res: Dictionary) -> void:
	_fresh_priced()
	GameState.bank_notes = 10000
	TestFixtures.check(res, "the asking rate is worth one step of Guild Opinion",
		PromotionsManager.opinion_delta(320, 320) == 1
		and PromotionsManager.opinion_delta(320, 300) == 0, "asking +1, under it nothing")
	TestFixtures.check(res, "each margin over the asking rate is worth another step",
		PromotionsManager.opinion_delta(320, 352) == 2
		and PromotionsManager.opinion_delta(320, 400) == 3
		and PromotionsManager.opinion_delta(320, 480) == 4
		and PromotionsManager.opinion_delta(320, 640) == 5,
		"+10 gives 2, +25 gives 3, +50 gives 4, +100 gives 5")
	TestFixtures.check(res, "the steps hold for any asking rate",
		PromotionsManager.opinion_delta(260, 286) == 2
		and PromotionsManager.opinion_delta(960, 1200) == 3
		and PromotionsManager.opinion_delta(0, 500) == 0, "260, 960 and a rate of nothing")
	var seen: Array[Dictionary] = []
	var watcher: Callable = func(a: ApplicantData, salary: int, delta: int) -> void:
		seen.append({"id": a.id, "salary": salary, "delta": delta})
	PromotionsManager.applicant_hired.connect(watcher)
	var before: int = GameState.bank_notes
	var counted: int = PromotionsManager.results_of(PromotionsManager.campaign_of(1))
	var doubled: int = PromotionsManager.applicant_of(20).ask * 2
	var first_pay: int = PromotionsManager.hire_charge_for(doubled)
	TestFixtures.check(res, "a hire reports the applicant, the salary and the opinion it earns",
		counted == 3 and PromotionsManager.hire(20, doubled) and seen.size() == 1
		and int(seen[0]["id"]) == 20 and int(seen[0]["salary"]) == doubled and int(seen[0]["delta"]) == 5,
		"%s" % [seen])
	PromotionsManager.applicant_hired.disconnect(watcher)
	TestFixtures.check(res, "hiring takes the pro-rated first pay and drops the applicant off the list",
		first_pay > 0 and GameState.bank_notes == before - first_pay and PromotionsManager.applicant_of(20) == null
		and PromotionsManager.applicants_filtered().size() == 2,
		"bank %d of %d less %d, %d rows" % [GameState.bank_notes, before, first_pay,
		PromotionsManager.applicants_filtered().size()])
	TestFixtures.check(res, "the campaign still counts the merc it brought in",
		PromotionsManager.results_of(PromotionsManager.campaign_of(1)) == counted,
		"%d results" % [PromotionsManager.results_of(PromotionsManager.campaign_of(1))])
	TestFixtures.check(res, "rejecting an applicant drops them too",
		PromotionsManager.reject(21) and PromotionsManager.applicant_of(21) == null
		and PromotionsManager.applicants_filtered().size() == 1
		and not PromotionsManager.reject(21),
		"%d rows left" % [PromotionsManager.applicants_filtered().size()])
	TestFixtures.check(res, "an applicant who is gone cannot be hired",
		_reason(PromotionsManager.can_hire(20, 320)) == "No such applicant.",
		_reason(PromotionsManager.can_hire(20, 320)))
	TestFixtures.check(res, "the plan roster cap sets how many mercs may still be signed",
		PromotionsManager.max_mercs() == UpgradeDefs.ENTERPRISE_MERCS
		and PromotionsManager.free_slots()
			== UpgradeDefs.ENTERPRISE_MERCS - GameState.mercs.size(),
		"cap %d, %d free" % [PromotionsManager.max_mercs(), PromotionsManager.free_slots()])
	var seat_tier: bool = SubscriptionManager.set_tier("seats", 1)
	TestFixtures.check(res, "a Seats tier adds its mercs to the roster cap",
		seat_tier and PromotionsManager.max_mercs()
			== UpgradeDefs.ENTERPRISE_MERCS + UpgradeDefs.MERCS_PER_SEAT
		and PromotionsManager.free_slots() == UpgradeDefs.ENTERPRISE_MERCS
			+ UpgradeDefs.MERCS_PER_SEAT - GameState.mercs.size(),
		"set_tier %s, cap %d" % [seat_tier, PromotionsManager.max_mercs()])
	TestFixtures.add_mercs(maxi(0, UpgradeDefs.FREE_MERCS - GameState.mercs.size()))
	SubscriptionManager.set_plan(SubscriptionManager.Plan.FREE)
	TestFixtures.check(res, "a full roster refuses the hire",
		PromotionsManager.max_mercs() == UpgradeDefs.FREE_MERCS
		and PromotionsManager.free_slots() == 0
		and _reason(PromotionsManager.can_hire(22, 260)) == "No free merc slots.",
		"cap %d, %s" % [PromotionsManager.max_mercs(),
		_reason(PromotionsManager.can_hire(22, 260))])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	GameState.bank_notes = 10
	TestFixtures.check(res, "a bank that cannot cover the first month refuses the hire",
		_reason(PromotionsManager.can_hire(22, 260))
		== "Not enough notes for their first month." and not PromotionsManager.hire(22, 260),
		_reason(PromotionsManager.can_hire(22, 260)))


#Case 18: counter-offer odds, what the offer costs and the answer on the third day.
static func _case_counter(res: Dictionary) -> void:
	_fresh_priced({"oddJobs": 3})
	var today: int = GameState.day()
	GameState.bank_notes = 1000
	var uid: int = _free_uids(res, 1, "one free merc for the counter-offer crew")[0]
	var fit: float = PromotionsManager.merc_fit(uid)
	var team: Array[int] = [uid]
	var ask: int = PromotionsManager.applicant_of(20).ask
	var low: int = roundi(float(ask) * 0.75)
	var base: float = 100.0 - (1.0 - float(low) / float(ask)) * 200.0
	TestFixtures.check(res, "a merc's Odd Job fit is the placeholder draw off their id",
		is_equal_approx(fit, clampf(float(absi(uid * PromotionsManager.FIT_STEP
		+ PromotionsManager.FIT_SEED) % 10) / 2.0 + 0.5, 0.5, 5.0))
		and fit >= 0.5 and fit <= 5.0, "uid %d fit %.1f" % [uid, fit])
	TestFixtures.check(res, "the odds clamp at ninety-five and at five",
		ask > 0 and PromotionsManager.counter_odds(20, ask) == 95
		and PromotionsManager.counter_odds(20, ask * 2) == 95
		and PromotionsManager.counter_odds(20, int(float(ask) * 0.5)) == 5
		and PromotionsManager.counter_odds(20, 0) == 5,
		"at the asking rate %d" % [PromotionsManager.counter_odds(20, ask)])
	TestFixtures.check(res, "a quarter under the asking rate halves the odds",
		PromotionsManager.counter_odds(20, low) == roundi(clampf(base, 5.0, 95.0))
		and absf(float(PromotionsManager.counter_odds(20, low)) - 50.0) <= 1.0 + 100.0 / float(ask),
		"%d at %d of %d" % [PromotionsManager.counter_odds(20, low), low, ask])
	TestFixtures.check(res, "every merc sent lifts the odds by three per fit star",
		PromotionsManager.counter_odds(20, low, team)
		== roundi(clampf(base + fit * PromotionsManager.ODDS_PER_FIT, 5.0, 95.0)),
		"%d with one merc" % [PromotionsManager.counter_odds(20, low, team)])
	TestFixtures.check(res, "an unknown applicant has no odds at all",
		PromotionsManager.counter_odds(99, 100) == 0, "no applicant, no odds")
	TestFixtures.check(res, "an offer at or over the asking rate is no counter-offer",
		_reason(PromotionsManager.can_counter(20, ask)) == "That is their asking rate or better.",
		_reason(PromotionsManager.can_counter(20, ask)))
	var crowd: Array[int] = [1, 2, 3, 4]
	TestFixtures.check(res, "the Odd Job crew cannot outrun the slots the guild holds",
		_reason(PromotionsManager.can_counter(20, low, crowd)) == "Odd Jobs holds 3 mercs.",
		_reason(PromotionsManager.can_counter(20, low, crowd)))
	GameState.bank_notes = 10
	TestFixtures.check(res, "the Odd Job pay has to be there before the offer goes out",
		_reason(PromotionsManager.can_counter(20, low, team, 25))
		== "Not enough notes for Odd Job pay.",
		_reason(PromotionsManager.can_counter(20, low, team, 25)))
	GameState.bank_notes = 1000
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	TestFixtures.check(res, "sending the offer pays the crew and marks the applicant countered",
		PromotionsManager.counter(20, low, team, 25) and GameState.bank_notes == 975
		and applicant.status == ApplicantData.STATUS_COUNTERED
		and applicant.counter_offer == low and applicant.counter_day == today
		and applicant.counter_odds > 0, "bank %d, odds %d" % [GameState.bank_notes,
		applicant.counter_odds])
	TestFixtures.check(res, "an applicant waiting on an answer cannot be hired or rejected",
		_reason(PromotionsManager.can_hire(20, low)) == "Waiting for their answer."
		and not PromotionsManager.reject(20)
		and _reason(PromotionsManager.can_counter(20, low)) == "Waiting for their answer.",
		_reason(PromotionsManager.can_hire(20, low)))
	TestFixtures.pass_days(PromotionsManager.COUNTER_DAYS - 1)
	TestFixtures.check(res, "the answer does not come early",
		applicant.status == ApplicantData.STATUS_COUNTERED, "status %s" % [applicant.status])
	var seen: Array[Dictionary] = []
	var watcher: Callable = func(id: int, accepted: bool) -> void:
		seen.append({"id": id, "accepted": accepted})
	PromotionsManager.counter_resolved.connect(watcher)
	TestFixtures.pass_days(1)
	PromotionsManager.counter_resolved.disconnect(watcher)
	var signed_on: bool = applicant.status == ApplicantData.STATUS_HIRED
	TestFixtures.check(res, "the answer lands three days out and settles the applicant",
		seen.size() == 1 and int(seen[0]["id"]) == 20 and (applicant.is_open() or signed_on)
		and applicant.accepted_counter != applicant.refused_counter,
		"%s, hired %s" % [seen, signed_on])
	TestFixtures.check(res, "an accepted offer becomes their rate and a refusal leaves it alone",
		applicant.ask == (low if applicant.accepted_counter else ask)
		and signed_on == applicant.accepted_counter,
		"accepted %s, rate %d" % [applicant.accepted_counter, applicant.ask])


#Case 19: arrivals, a campaign running out and the dots a new day leaves behind.
static func _case_day_tick(res: Dictionary) -> void:
	_fresh(_launch_ent())
	GameState.bank_notes = 200000
	var job: CampaignData = TestFixtures.launch_campaign({"type": &"flyers", "days": 30})
	var promo: CampaignData = TestFixtures.launch_campaign({"type": &"flyers",
		"mode": CampaignData.MODE_PROMO, "days": 30})
	var short_run: CampaignData = TestFixtures.launch_campaign({"type": &"flyers", "days": 4})
	var today: int = GameState.day()
	TestFixtures.check(res, "a new job ad arms no arrival day; the 8:00 hire round rolls it",
		job != null and promo != null and short_run != null
		and job.next_arrival_day == -1,
		"due %d, today %d" % [job.next_arrival_day if job != null else -1, today])
	if job == null or promo == null or short_run == null:
		return
	var seen: Array[int] = []
	var watcher: Callable = func(a: ApplicantData) -> void:
		seen.append(a.id)
	PromotionsManager.applicant_arrived.connect(watcher)
	TestFixtures.pass_days(PromotionsManager.ARRIVAL_DAYS - 1)
	TestFixtures.check(res, "no applicant arrives before the ads are due",
		PromotionsManager.applicants.is_empty() and seen.is_empty(), "%s" % [seen])
	TestFixtures.pass_days(1)
	TestFixtures.check(res, "a day tick lands no job applicant", seen.is_empty(), "%s" % [seen])
	PromotionsManager.land_applicant(job)
	PromotionsManager.land_applicant(short_run)
	TestFixtures.check(res, "the two job ads due today each bring one merc in",
		seen == [20, 21] and PromotionsManager.applicants.size() == 2
		and PromotionsManager.applicant_of(21).campaign_id == short_run.id,
		"%s" % [seen])
	var fresh_one: ApplicantData = PromotionsManager.applicant_of(20)
	TestFixtures.check(res, "an arrival comes in filled out, unseen and credited to its ad",
		fresh_one != null and fresh_one.campaign_id == job.id
		and _named_for_merc(fresh_one) and _priced_by_merc(fresh_one) and fresh_one.tradition != ""
		and fresh_one.stats.size() == ApplicantData.STAT_KEYS.size()
		and fresh_one.tools.size() == 1 and fresh_one.knowledges.size() == 1
		and fresh_one.ask >= 1
		and fresh_one.fit >= 0.0 and fresh_one.fit <= 5.0
		and ApplicantData.RARITIES.has(fresh_one.rarity) and fresh_one.unseen
		and PromotionsManager.has_unseen(),
		"%s asking %d" % [fresh_one.name, fresh_one.ask])
	TestFixtures.check(res, "an arrival carries its rolled merc's real ancestry",
		_ancestry_of_merc(fresh_one), "ancestry %s" % [fresh_one.ancestry])
	TestFixtures.check(res, "the campaign counts the arrival among its results",
		PromotionsManager.results_of(job) == 1, "%d results" % [PromotionsManager.results_of(job)])
	TestFixtures.check(res, "clearing one card's dot leaves the rest of the page alone",
		PromotionsManager.mark_applicant_seen(20) and not fresh_one.unseen
		and not PromotionsManager.mark_applicant_seen(20)
		and PromotionsManager.has_unseen(), "one dot of two cleared")
	var via_promo: int = 0
	for row: ApplicantData in PromotionsManager.applicants:
		if row.campaign_id == promo.id:
			via_promo += 1
	TestFixtures.check(res, "a guild promo brings no applicants in and its arrival day posts no contract",
		promo.next_arrival_day == today + 2 * PromotionsManager.ARRIVAL_DAYS
		and PromotionsManager.results_of(promo) == 0 and via_promo == 0,
		"due %d, %d results, %d applicants" % [promo.next_arrival_day,
		PromotionsManager.results_of(promo), via_promo])
	TestFixtures.pass_days(1)
	TestFixtures.check(res, "the ad that ran out stops pulling",
		short_run.is_concluded(GameState.day()) and short_run.next_arrival_day == -1,
		"due %d" % [short_run.next_arrival_day])
	TestFixtures.pass_days(8)
	var via: Array[int] = [job.id]
	var ticked: int = PromotionsManager.applicants_filtered({}, via).size()
	var seen_ticked: int = seen.size()
	for day: int in range(today + 1, GameState.day() + 1):
		PromotionsManager.hire_round(day * TrynnCalendar.MINUTES_PER_DAY + 8 * TrynnCalendar.MINUTES_PER_HOUR)
	PromotionsManager.applicant_arrived.disconnect(watcher)
	var via_job: Array[int] = _sorted_ids(PromotionsManager.applicants_filtered({}, via))
	var walk_ins: int = 0
	for row: ApplicantData in PromotionsManager.applicants:
		if row.pool:
			walk_ins += 1
	TestFixtures.check(res, "day ticks land nothing; the seeded hire rounds land only from the ad still running",
		ticked == 1 and seen_ticked == 2 and seen.size() - seen_ticked == via_job.size() - 1 + walk_ins,
		"%s, seen %s, walk-ins %d" % [via_job, seen, walk_ins])
	TestFixtures.check(res, "an ad that had already run out brings nothing in",
		PromotionsManager.results_of(short_run) == 1,
		"%d results" % [PromotionsManager.results_of(short_run)])
	TestFixtures.check(res, "the guild promo's arrival days posted no contract; the 8:00 round posts them",
		PromotionsManager.results_of(promo) == 0 and GameState.campaign_contracts(promo.id).size() == 0,
		"%d results, %d posted" % [PromotionsManager.results_of(promo),
		GameState.campaign_contracts(promo.id).size()])
	TestFixtures.check(res, "a fixed ad that reaches its last day stays on the list",
		PromotionsManager.campaign_of(short_run.id) != null and short_run.is_concluded(GameState.day()),
		"campaign %d is concluded, not gone" % [short_run.id])


#Case 20: the ledger row every campaign charge and refund leaves behind.
static func _case_ledger(res: Dictionary) -> void:
	_fresh_priced(_launch_ent())
	GameState.bank_notes = 200000
	var ledger: MoneyLog = MoneyLog.new()
	GameState.money_logged.connect(ledger.on_money)
	var flyers: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	PromotionsManager.launch(flyers)
	TestFixtures.check(res, "a launch charge names the campaign and the method it bought",
		_row_is(ledger, "Campaign 2 - Flyers", -25, "ads"), "%s" % [ledger.rows])
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 7)
	wom.crew.assign(_free_uids(res, 2, "two free mercs for the ledger crew"))
	PromotionsManager.launch(wom)
	TestFixtures.check(res, "Word of Mouth pay rides the Odd Job reason, not the ads one",
		_row_is(ledger, "Campaign 3 - Word of Mouth", -50, GameState.REASON_ODD_JOB),
		"%s" % [_row(ledger, "Campaign 3 - Word of Mouth")])
	PromotionsManager.end(flyers.id)
	TestFixtures.check(res, "the refund of an ended ad reaches the ledger as a refund",
		_row_is(ledger, "Campaign 2 - Refund", 25, PromotionsManager.REASON_ADS),
		"%s" % [_row(ledger, "Campaign 2 - Refund")])
	SubscriptionManager.set_entitlements(
		{"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE})
	var forever: CampaignData = _forever(&"flyers", CampaignData.MODE_JOB)
	PromotionsManager.launch(forever)
	TestFixtures.check(res, "an Infinite launch pays its first period under the ad's name",
		_row_is(ledger, "Campaign 4 - Flyers", -150, PromotionsManager.REASON_ADS),
		"%s" % [_row(ledger, "Campaign 4 - Flyers")])
	TestFixtures.pass_days(maxi(0, forever.next_bill_day - GameState.day()))
	TestFixtures.check(res, "the monthly bill of an Infinite ad says which ad it is for",
		_row_is(ledger, "Campaign 4 - Monthly bill", -150, PromotionsManager.REASON_ADS),
		"%s" % [_row(ledger, "Campaign 4 - Monthly bill")])
	var team: Array[int] = _free_uids(res, 1, "one free merc for the counter-offer ledger row")
	var counter_row: String = "%s - Counter-offer" % PromotionsManager.applicant_of(20).name
	PromotionsManager.counter(20, roundi(float(PromotionsManager.applicant_of(20).ask) * 0.75), team, 25)
	TestFixtures.check(res, "the crew sent with a counter-offer is paid under the applicant's name",
		_row_is(ledger, counter_row, -25, GameState.REASON_ODD_JOB), "%s" % [_row(ledger, counter_row)])
	var bare: int = 0
	for row: Dictionary in ledger.rows:
		if String(row["reason"]) == "" or String(row["label"]) == "":
			bare += 1
	GameState.money_logged.disconnect(ledger.on_money)
	TestFixtures.check(res, "no campaign charge reaches the ledger without a reason and a label",
		bare == 0 and ledger.rows.size() >= 5, "%d bare of %d rows" % [bare, ledger.rows.size()])


#Case 21: the operations permit a picked location needs before an ad goes out.
static func _case_permit_gate(res: Dictionary) -> void:
	_fresh(_launch_ent())
	GameState.bank_notes = 100000
	var closed: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	var one: Array[int] = [1]
	closed.locations = one
	_expect_reason(res, "a place the guild holds no operations permit for refuses by name",
		closed, "No Operations Permit in Aerdis.")
	var seeded: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	var pair: Array[int] = [0, 2]
	seeded.locations = pair
	TestFixtures.check(res, "the two held permits let an ad go out in both their places",
		bool(PromotionsManager.can_launch(seeded)["ok"]),
		_reason(PromotionsManager.can_launch(seeded)))
	SubscriptionManager.set_entitlements({"opsPermits": 1})
	var bought: bool = LegalManager.request_permit(1, LegalManager.PERMIT_OPS)
	TestFixtures.check(res, "buying the permit opens that place to the same ad",
		bought and bool(PromotionsManager.can_launch(closed)["ok"]),
		"bought %s, %s" % [bought, _reason(PromotionsManager.can_launch(closed))])
	var bare: CampaignData = _campaign(&"flyers", CampaignData.MODE_JOB, 5)
	TestFixtures.check(res, "an ad that picked no place at all needs no permit",
		bool(PromotionsManager.can_launch(bare)["ok"]),
		_reason(PromotionsManager.can_launch(bare)))
	SubscriptionManager.set_entitlements({"adRadio": true})
	var radio: CampaignData = _campaign(&"radio", CampaignData.MODE_JOB, 5)
	var buern: Array[int] = [0]
	radio.locations = buern
	_expect_reason(res, "a place the type cannot reach is refused before the permit is read",
		radio, "Radio cannot reach Buern.")


#Case 22: the away rows a Word of Mouth crew and a counter-offer crew leave in GameState.
static func _case_away_rows(res: Dictionary) -> void:
	_fresh_priced(_launch_ent())
	var today: int = GameState.day()
	GameState.bank_notes = 200000
	var pair: Array[int] = _free_uids(res, 2, "two free mercs for the away row crews")
	var one: int = pair[0]
	var two: int = pair[1]
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	wom.crew.assign([one, two])
	var day: int = CampaignClock.MINUTES_PER_DAY
	TestFixtures.check(res, "a Word of Mouth crew goes out on the Odd Job status until it ends",
		PromotionsManager.launch(wom) and GameState.is_away(one) and GameState.is_away(two)
		and GameState.away_status(one) == GuiTypes.MercStatus.ODD_JOB
		and GameState.away_until(one) == wom.end_day() * day
		and GameState.away_until(two) == wom.end_day() * day,
		"status %d until %d" % [GameState.away_status(one), GameState.away_until(one)])
	TestFixtures.check(res, "ending the campaign brings that crew home",
		PromotionsManager.end(wom.id) and not GameState.is_away(one)
		and not GameState.is_away(two), "%s and %s" % [GameState.is_away(one),
		GameState.is_away(two)])
	var short_run: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 2)
	short_run.crew.assign([one])
	PromotionsManager.launch(short_run)
	TestFixtures.pass_days(2)
	TestFixtures.check(res, "a crew comes home on its own when the campaign runs out",
		GameState.day() == today + 2 and short_run.is_concluded(GameState.day()) and not GameState.is_away(one),
		"concluded %s, away %s" % [short_run.is_concluded(GameState.day()), GameState.is_away(one)])
	var team: Array[int] = [one]
	PromotionsManager.counter(20, roundi(float(PromotionsManager.applicant_of(20).ask) * 0.75), team, 25)
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	TestFixtures.check(res, "the crew of a counter-offer is away until the answer day",
		GameState.is_away(one) and applicant.counter_team == team
		and GameState.away_until(one) == (applicant.counter_day
			+ PromotionsManager.COUNTER_DAYS) * day,
		"until %d" % [GameState.away_until(one)])
	applicant.counter_odds = 0
	TestFixtures.pass_days(PromotionsManager.COUNTER_DAYS)
	TestFixtures.check(res, "the answer brings that crew home and clears the row",
		not GameState.is_away(one) and applicant.counter_team.is_empty()
		and applicant.refused_counter, "away %s" % [GameState.is_away(one)])
	SubscriptionManager.set_entitlements(
		{"maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE})
	var forever: CampaignData = _forever(&"wom", CampaignData.MODE_PROMO)
	forever.crew.assign([two])
	TestFixtures.check(res, "an Infinite Word of Mouth crew has no return day at all",
		PromotionsManager.launch(forever) and GameState.is_away(two)
		and GameState.away_until(two) == -1, "until %d" % [GameState.away_until(two)])
	PromotionsManager.end(forever.id)
	var ghost: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 3)
	var nobody: int = 99999
	ghost.crew.assign([nobody])
	TestFixtures.check(res, "a crew uid the roster does not hold never reaches the registry",
		PromotionsManager.launch(ghost) and not GameState.is_away(nobody)
		and GameState.merc_by_uid(nobody) == null, "away %s" % [GameState.is_away(nobody)])
	var last: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 3)
	last.crew.assign([one, two])
	PromotionsManager.launch(last)
	var both_out: bool = GameState.is_away(one) and GameState.is_away(two)
	PromotionsManager.reset()
	TestFixtures.check(res, "a reset takes back every away row this manager put up",
		both_out and not GameState.is_away(one) and not GameState.is_away(two),
		"out %s, back %s" % [both_out, not GameState.is_away(one)])


#Case 23: the merc a hire signs on.
static func _case_hired_merc(res: Dictionary) -> void:
	_fresh_priced()
	GameState.bank_notes = 10000
	var before: int = GameState.mercs.size()
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	var want_name: String = applicant.name
	var want_level: int = applicant.level
	var want_tradition: String = applicant.tradition
	var salary: int = applicant.ask * 2
	var delta: int = PromotionsManager.opinion_delta(applicant.ask, salary)
	var beats: Array[int] = []
	var beat_watcher: Callable = func() -> void:
		beats.append(1)
	GameState.roster_changed.connect(beat_watcher)
	TestFixtures.check(res, "a hire signs one merc on and says which uid it was",
		PromotionsManager.hire(20, salary) and GameState.mercs.size() == before + 1
		and PromotionsManager.last_hired_uid > 0
		and GameState.merc_by_uid(PromotionsManager.last_hired_uid) != null,
		"roster %d, uid %d" % [GameState.mercs.size(), PromotionsManager.last_hired_uid])
	GameState.roster_changed.disconnect(beat_watcher)
	TestFixtures.check(res, "the hire says the roster changed again once the wage was written",
		beats.size() >= 2, "%d roster signals" % [beats.size()])
	var merc: MercenaryData = GameState.merc_by_uid(PromotionsManager.last_hired_uid)
	TestFixtures.check(res, "the new merc carries the applicant's name and level",
		merc.merc_name == want_name and int(merc.stats.get("level", 0)) == want_level,
		"%s at level %d" % [merc.merc_name, int(merc.stats.get("level", 0))])
	TestFixtures.check(res, "the new merc keeps the tradition the applicant applied with",
		merc.tradition != null and merc.tradition.tradition_name == want_tradition,
		"%s wanted %s" % [merc.tradition.tradition_name if merc.tradition != null else "none",
		want_tradition])
	TestFixtures.check(res, "the agreed salary is the wage the merc signs on at",
		merc.monthly_salary == salary and delta == 5,
		"%d notes, delta %d" % [merc.monthly_salary, delta])
	var wile: int = roundi(float(merc.stats.get("wile", 0.0)))
	TestFixtures.check(res, "the opinion the hire earned sits on top of their opening opinion",
		merc.guild_opinion == clampi(SalarySystem.OPINION_BASE + wile + delta,
			SalarySystem.OPINION_MIN, SalarySystem.OPINION_MAX),
		"opinion %d, wile %d" % [merc.guild_opinion, wile])
	var view: MercView = null
	for row: MercView in GameState.roster:
		if row.uid == PromotionsManager.last_hired_uid:
			view = row
	TestFixtures.check(res, "the roster view of the new merc holds the agreed wage and opinion",
		view != null and delta != 0 and view.monthly_salary == salary
		and view.guild_opinion == merc.guild_opinion,
		"none" if view == null else "%d notes, opinion %d against %d" % [view.monthly_salary,
		view.guild_opinion, merc.guild_opinion])
	TestFixtures.check(res, "hiring takes the pro-rated first pay and leaves the applicant list shorter",
		GameState.bank_notes == 10000 - PromotionsManager.hire_charge_for(salary)
		and PromotionsManager.applicant_of(20) == null,
		"bank %d, charge %d" % [GameState.bank_notes, PromotionsManager.hire_charge_for(salary)])


#Case 24: what an accepted counter-offer does, with a free merc slot and without one.
static func _case_counter_hire(res: Dictionary) -> void:
	_fresh_priced({"oddJobs": 2})
	GameState.bank_notes = 200000
	var hires: Array[Dictionary] = []
	var hire_watcher: Callable = func(a: ApplicantData, salary: int, delta: int) -> void:
		hires.append({"id": a.id, "salary": salary, "delta": delta})
	var answers: Array[Dictionary] = []
	var answer_watcher: Callable = func(id: int, accepted: bool) -> void:
		answers.append({"id": id, "accepted": accepted})
	PromotionsManager.applicant_hired.connect(hire_watcher)
	PromotionsManager.counter_resolved.connect(answer_watcher)
	var first: ApplicantData = PromotionsManager.applicant_of(20)
	var first_offer: int = roundi(float(first.ask) * 0.75)
	PromotionsManager.counter(20, first_offer)
	first.counter_odds = 100
	var before: int = GameState.mercs.size()
	TestFixtures.pass_days(PromotionsManager.COUNTER_DAYS)
	TestFixtures.check(res, "an accepted counter-offer signs the merc on at the offer",
		answers.size() == 1 and bool(answers[0]["accepted"]) and hires.size() == 1
		and int(hires[0]["salary"]) == first_offer and GameState.mercs.size() == before + 1,
		"%s and %s" % [answers, hires])
	TestFixtures.check(res, "a counter-offer hire earns no step of Guild Opinion",
		int(hires[0]["delta"]) == 0
		and GameState.merc_by_uid(PromotionsManager.last_hired_uid).monthly_salary == first_offer,
		"delta %d" % [int(hires[0]["delta"])])
	TestFixtures.check(res, "the applicant who accepted is hired and off the list",
		first.status == ApplicantData.STATUS_HIRED and first.accepted_counter
		and PromotionsManager.applicant_of(20) == null, "status %s" % [first.status])
	var second: ApplicantData = PromotionsManager.applicant_of(21)
	var third: ApplicantData = PromotionsManager.applicant_of(22)
	var second_offer: int = roundi(float(second.ask) * 0.75)
	var third_ask: int = third.ask
	PromotionsManager.counter(21, second_offer)
	PromotionsManager.counter(22, roundi(float(third_ask) * 0.6))
	second.counter_odds = 100
	third.counter_odds = 0
	TestFixtures.add_mercs(maxi(0, UpgradeDefs.FREE_MERCS - GameState.mercs.size()))
	SubscriptionManager.set_plan(SubscriptionManager.Plan.FREE)
	var roster: int = GameState.mercs.size()
	TestFixtures.pass_days(PromotionsManager.COUNTER_DAYS)
	PromotionsManager.applicant_hired.disconnect(hire_watcher)
	PromotionsManager.counter_resolved.disconnect(answer_watcher)
	TestFixtures.check(res, "an accepted offer with no free slot leaves them open at the offer",
		second.is_open() and second.accepted_counter and second.ask == second_offer
		and PromotionsManager.free_slots() == 0 and GameState.mercs.size() == roster
		and hires.size() == 1, "status %s at %d" % [second.status, second.ask])
	TestFixtures.check(res, "a refused offer leaves their asking rate where it was",
		third.is_open() and third.refused_counter and not third.accepted_counter
		and third.ask == third_ask
		and PromotionsManager.applicant_of(22) != null, "rate %d" % [third.ask])
	TestFixtures.check(res, "each answer was reported once, accepted or refused",
		answers.size() == 3 and int(answers[1]["id"]) == 21 and bool(answers[1]["accepted"])
		and int(answers[2]["id"]) == 22 and not bool(answers[2]["accepted"]),
		"%s" % [answers])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})


#Case 25: the Odd Job rows this manager owns go back up when something else clears them, and stay
#down once the campaign that wrote them is over.
static func _case_restore_holds(res: Dictionary) -> void:
	_fresh_priced(_launch_ent())
	var today: int = GameState.day()
	GameState.bank_notes = 200000
	var pair: Array[int] = _free_uids(res, 2, "two free mercs for the restored rows")
	var one: int = pair[0]
	var two: int = pair[1]
	var day: int = CampaignClock.MINUTES_PER_DAY
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	wom.crew.assign([one])
	var sent: bool = PromotionsManager.launch(wom)
	GameState.clear_away(one)
	TestFixtures.check(res, "a cleared row of a running campaign crew goes back up",
		sent and GameState.away_status(one) == GuiTypes.MercStatus.ODD_JOB
		and GameState.busy_uids().has(one)
		and GameState.away_until(one) == wom.end_day() * day,
		"status %d until %d" % [GameState.away_status(one), GameState.away_until(one)])
	var team: Array[int] = [two]
	var offered: bool = PromotionsManager.counter(20, roundi(float(PromotionsManager.applicant_of(20).ask) * 0.75), team, 25)
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	GameState.clear_away(two)
	TestFixtures.check(res, "a cleared row of a counter-offer crew goes back up to the answer day",
		offered and GameState.away_status(two) == GuiTypes.MercStatus.ODD_JOB
		and GameState.away_until(two) == (applicant.counter_day
			+ PromotionsManager.COUNTER_DAYS) * day,
		"status %d until %d" % [GameState.away_status(two), GameState.away_until(two)])
	var moved: Array[int] = []
	var watcher: Callable = func(who: int) -> void:
		moved.append(who)
	GameState.away_changed.connect(watcher)
	GameState.roster_changed.emit()
	GameState.away_changed.disconnect(watcher)
	TestFixtures.check(res, "a roster signal with every row standing moves nothing",
		moved.is_empty(), "%s" % [moved])
	var ended: bool = PromotionsManager.end(wom.id)
	GameState.roster_changed.emit()
	TestFixtures.check(res, "the crew of an ended campaign is never held again",
		ended and GameState.away_status(one) == -1 and not GameState.busy_uids().has(one),
		"status %d" % [GameState.away_status(one)])
	var short_run: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 2)
	short_run.crew.assign([one])
	PromotionsManager.launch(short_run)
	TestFixtures.pass_days(2)
	GameState.roster_changed.emit()
	TestFixtures.check(res, "the crew of a run that ran out is never held again",
		GameState.day() == today + 2 and short_run.is_concluded(GameState.day()) and GameState.away_status(one) == -1,
		"status %d" % [GameState.away_status(one)])


#Case 25b: a campaign that ends on the same day tick a counter-offer is accepted must not have
#its crew held again by the roster signal the hire fires from inside that same tick.
static func _case_tick_restore(res: Dictionary) -> void:
	_fresh_priced(_launch_ent())
	var today: int = GameState.day()
	GameState.bank_notes = 200000
	var pair: Array[int] = _free_uids(res, 2, "two free mercs for the tick restore case")
	var ended_uid: int = pair[0]
	var running_uid: int = pair[1]
	var ended: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO,
		PromotionsManager.COUNTER_DAYS)
	ended.crew.assign([ended_uid])
	var running: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO,
		PromotionsManager.COUNTER_DAYS * 4)
	running.crew.assign([running_uid])
	var launched_ended: bool = PromotionsManager.launch(ended)
	var launched_running: bool = PromotionsManager.launch(running)
	var offered: bool = PromotionsManager.counter(20, roundi(float(PromotionsManager.applicant_of(20).ask) * 0.75))
	var applicant: ApplicantData = PromotionsManager.applicant_of(20)
	applicant.counter_odds = 100
	var target_day: int = today + PromotionsManager.COUNTER_DAYS
	TestFixtures.check(res, "the tick restore fixture closes the campaign the day the offer lands",
		launched_ended and launched_running and offered and ended.end_day() == target_day
		and not running.is_concluded(target_day)
		and applicant.counter_day + PromotionsManager.COUNTER_DAYS == target_day,
		"end %d, target %d" % [ended.end_day(), target_day])
	var before: int = GameState.mercs.size()
	TestFixtures.pass_days(target_day - GameState.day())
	TestFixtures.check(res, "the counter-offer hire still lands from inside the day tick",
		GameState.mercs.size() == before + 1 and applicant.status == ApplicantData.STATUS_HIRED,
		"roster %d, status %s" % [GameState.mercs.size(), applicant.status])
	TestFixtures.check(res, "the crew of the campaign that ended this tick is never held again",
		GameState.away_status(ended_uid) == -1,
		"status %d" % [GameState.away_status(ended_uid)])
	TestFixtures.check(res, "the crew of the campaign still running stays held",
		GameState.away_status(running_uid) == GuiTypes.MercStatus.ODD_JOB,
		"status %d" % [GameState.away_status(running_uid)])


#Case 26: a merc the guild cannot send out is refused a crew seat, and a hold another manager
#wrote over an Odd Job row is left where it is.
static func _case_busy_crew(res: Dictionary) -> void:
	_fresh_priced(_launch_ent())
	TestFixtures.add_mercs(1)
	GameState.bank_notes = 200000
	var bank: int = GameState.bank_notes
	var free: Array[int] = _free_uids(res, 3, "three free mercs for the busy crew case")
	var held: int = free[0]
	GameState.set_away(held, GuiTypes.MercStatus.CAPTURED, -1)
	var wom: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	wom.crew.assign([held])
	TestFixtures.check(res, "a campaign crew the guild cannot send refuses the launch",
		_reason(PromotionsManager.can_launch(wom)) == PromotionsManager.CREW_BUSY_TEXT
		and not PromotionsManager.launch(wom)
		and GameState.away_status(held) == GuiTypes.MercStatus.CAPTURED
		and GameState.bank_notes == bank,
		"%s at %d" % [_reason(PromotionsManager.can_launch(wom)),
		GameState.away_status(held)])
	var team: Array[int] = [held]
	var low: int = roundi(float(PromotionsManager.applicant_of(20).ask) * 0.75)
	TestFixtures.check(res, "a counter-offer crew the guild cannot send refuses the offer",
		_reason(PromotionsManager.can_counter(20, low, team, 25))
		== PromotionsManager.CREW_BUSY_TEXT
		and not PromotionsManager.counter(20, low, team, 25)
		and GameState.bank_notes == bank,
		_reason(PromotionsManager.can_counter(20, low, team, 25)))
	GameState.clear_away(held)
	var taken: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	taken.crew.assign([free[1]])
	var sent: bool = PromotionsManager.launch(taken)
	GameState.set_away(free[1], GuiTypes.MercStatus.CAPTURED, -1)
	TestFixtures.check(res, "an Odd Job row another manager wrote over is left where it is",
		sent and PromotionsManager.end(taken.id)
		and GameState.away_status(free[1]) == GuiTypes.MercStatus.CAPTURED,
		"status %d" % [GameState.away_status(free[1])])
	GameState.clear_away(free[1])
	var merc: MercenaryData = GameState.merc_by_uid(free[2])
	merc.on_contract = true
	var busy: CampaignData = _campaign(&"wom", CampaignData.MODE_PROMO, 4)
	busy.crew.assign([free[2]])
	var refused: String = _reason(PromotionsManager.can_launch(busy))
	var no_launch: bool = not PromotionsManager.launch(busy)
	merc.on_contract = false
	TestFixtures.check(res, "a merc out on a contract is refused a crew seat the same way",
		refused == PromotionsManager.CREW_BUSY_TEXT and no_launch, refused)


#Case 27: the View Contracts button of a guild promo card and the first posting it opens on.
static func _case_view_contracts(res: Dictionary) -> void:
	var ent: Dictionary = _launch_ent()
	ent.merge({"gpContractType": true}, true)
	_fresh(ent)
	GameState.bank_notes = 5000
	var promo: CampaignData = TestFixtures.launch_campaign({"type": &"flyers",
		"mode": CampaignData.MODE_PROMO, "days": 30, "ctypes": [1], "locs": [0]})
	GameState.seed_round(ROUND_SEED)
	await _round_days(PromotionsManager.ARRIVAL_DAYS)
	var id: int = promo.id if promo != null else -1
	var posted: Array[ContractView] = GameState.campaign_contracts(id)
	var off: int = 0
	for view: ContractView in posted:
		off += 0 if view.campaign_id == id and (view.type == ContractLibrary.contract_type_names()[1] \
			or view.location == CampaignTypeDefs.location_name(0)) else 1
	TestFixtures.check(res, "the promo's results are on the board under its id, each meeting a pick",
		id > 0 and posted.size() >= 1 and posted.size() <= PromotionsManager.results_of(promo) and off == 0,
		"%d posted, %d off" % [posted.size(), off])
	var seen: Array[int] = []
	var watcher: Callable = func(seen_id: int) -> void:
		seen.append(seen_id)
	GameState.open_contracts_requested.connect(watcher)
	PromotionsManager.view_contracts(id)
	GameState.open_contracts_requested.disconnect(watcher)
	TestFixtures.check(res, "View Contracts opens the board filtered to that campaign",
		seen == [id] and GameState.contract_filter.size() == 1
		and int(GameState.contract_filter.get("campaign", 0)) == id,
		"%s" % [GameState.contract_filter])
	var taken: Dictionary = GameState.take_contract_filter()
	TestFixtures.check(res, "the board takes the contract filter once and leaves nothing behind",
		int(taken.get("campaign", 0)) == id and GameState.contract_filter.is_empty(),
		"%s then %s" % [taken, GameState.contract_filter])


#Case 28: a guild promo posts one contract from its picks every three days and stops on its last day.
static func _case_promo_contracts(res: Dictionary) -> void:
	var ent: Dictionary = _launch_ent()
	ent.merge({"gpMinDifficulty": true, "gpMaxDifficulty": true, "gpContractType": true}, true)
	_fresh(ent)
	var today: int = GameState.day()
	GameState.bank_notes = 5000
	var known: Array[String] = ContractLibrary.contract_type_names()
	var promo: CampaignData = _campaign(&"flyers", CampaignData.MODE_PROMO, 7)
	var kinds: Array[String] = [known[1], known[4]]
	var places: Array[int] = [0, 2]
	promo.contract_types = kinds
	promo.locations = places
	promo.difficulty_lo = 1.5
	promo.difficulty_hi = 3.0
	var verdict: String = _reason(PromotionsManager.can_launch(promo))
	TestFixtures.check(res, "a launched guild promo is due its first contract in three days",
		PromotionsManager.launch(promo) and promo.next_arrival_day == today + PromotionsManager.ARRIVAL_DAYS
		and PromotionsManager.results_of(promo) == 0 and GameState.campaign_contracts(promo.id).is_empty(),
		"%s, due %d" % [verdict, promo.next_arrival_day])
	GameState.seed_round(ROUND_SEED)
	await _round_days(2)
	var early: int = PromotionsManager.results_of(promo)
	TestFixtures.check(res, "the first two days post no more than they credit",
		GameState.campaign_contracts(promo.id).size() <= early,
		"%d posted, %d results" % [GameState.campaign_contracts(promo.id).size(), early])
	await _round_days(1)
	var posted: Array[ContractView] = GameState.campaign_contracts(promo.id)
	var first: ContractView = null
	if not posted.is_empty():
		first = posted[0]
	TestFixtures.check(res, "by the third day a contract is tagged with the campaign and counted",
		first != null and first.campaign_id == promo.id and PromotionsManager.results_of(promo) >= posted.size(),
		"%d posted, %d results" % [posted.size(), PromotionsManager.results_of(promo)])
	var types: Array[String] = [known[1], known[4]]
	var towns: Array[String] = [CampaignTypeDefs.location_name(0), CampaignTypeDefs.location_name(2)]
	var drawn: Array[String] = []
	for view: ContractView in posted:
		if not types.has(view.type) and not towns.has(view.location) \
				and (view.difficulty < 1.5 or view.difficulty > 3.0):
			drawn.append("%s in %s at %.1f" % [view.type, view.location, view.difficulty])
	TestFixtures.check(res, "the posting meets a picked type, a picked place or the difficulty band",
		first != null and drawn.is_empty(), "%d posted, off %s" % [posted.size(), drawn])
	var at_three: int = PromotionsManager.results_of(promo)
	await _round_days(4)
	var at_end: int = PromotionsManager.results_of(promo)
	TestFixtures.check(res, "the days to its last keep counting, never dropping a result",
		at_end >= at_three and at_three >= 1, "%d then %d results" % [at_three, at_end])
	await _round_days(5)
	TestFixtures.check(res, "a seven day promo posts nothing after its last day",
		PromotionsManager.results_of(promo) == at_end
		and promo.next_arrival_day == -1 and GameState.day() == today + 12 and promo.is_concluded(GameState.day()),
		"%d then %d results, due %d" % [at_end, PromotionsManager.results_of(promo), promo.next_arrival_day])
	GameState.bank_notes = 5000
	var odd: CampaignData = _campaign(&"flyers", CampaignData.MODE_PROMO, 7)
	var odd_types: Array[String] = [known[1], "TEST Gone"]
	odd.contract_types = odd_types
	var launched: bool = PromotionsManager.launch(odd)
	var odd_entry: Dictionary = {}
	for entry: Dictionary in PromotionsManager.contract_campaigns():
		if int(entry["id"]) == odd.id:
			odd_entry = entry
	var only_known: Array[String] = [known[1]]
	TestFixtures.check(res, "a campaign holding an unknown type name posts only known types",
		launched and not odd_entry.is_empty() and odd_entry["types"] == only_known,
		"%s, %s" % [launched, odd_entry])


#The one money row that carries this label, or an empty dictionary when none does.
static func _row(ledger: MoneyLog, label: String) -> Dictionary:
	for row: Dictionary in ledger.rows:
		if String(row["label"]) == label:
			return row
	return {}


static func _row_is(ledger: MoneyLog, label: String, delta: int, reason: String) -> bool:
	var row: Dictionary = _row(ledger, label)
	if row.is_empty():
		return false
	return int(row["delta"]) == delta and String(row["reason"]) == reason


#Catches the ledger rows GameState hands out while a case runs.
class MoneyLog extends RefCounted:
	var rows: Array[Dictionary] = []

	func on_money(delta: int, reason: String, label: String) -> void:
		rows.append({"delta": delta, "reason": reason, "label": label})
