class_name GuiStockTests
extends RefCounted

#StockMarket: the deterministic price history, holdings, trades, dividends, alerts and the
#Run headless with the --gui-stock-tests flag after the harness argument separator.

#Companies without a seeded holding, used as scratch for the trade and alert cases.
const FREE_K: int = 1
const OTHER_FREE_K: int = 7
const DAY_A: int = 5080
const YEAR_B: int = 316
#StockMarket is an autoload with no class_name, so its statics are read off the script itself.
const MARKET_SCRIPT := preload("res://Scripts/GUI/Autoloads/StockMarket.gd")
#How many labels each range draws on the two build days of _case_ranges: the 10th of Erta, a
#40 day month, and the 10th of Kusarra, a 30 day one. YTD counts one month more on the second.
const TICKS_40: Dictionary = {"5Y": 5, "1Y": 4, "YTD": 5, "6M": 6, "3M": 3, "1M": 3,
	"MTD": 10, "1W": 10}
const TICKS_30: Dictionary = {"5Y": 5, "1Y": 4, "YTD": 6, "6M": 6, "3M": 3, "1M": 3,
	"MTD": 10, "1W": 10}


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	await host.get_tree().process_frame
	_case_rng(res)
	_case_band(res)
	_case_companies(res)
	_case_company_defs_tsv(res)
	_case_history(res)
	_case_determinism(res)
	_case_events(res)
	_case_holdings_seed(res)
	_case_buy(res)
	_case_sell(res)
	_case_check_notify(res)
	_case_mark_viewed(res)
	_case_advance_day(res)
	_case_dividend_day(res)
	_case_tick(res)
	_case_contract_result(res)
	_case_issuer(res)
	_case_stats_and_accepted(res)
	_case_ranges(res)
	_case_invest_readers(res)
	_case_f5f_constants(res)
	_reset()
	return TestFixtures.summarize(res, "GUI STOCK")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	CampaignClock.reset()
	NotificationCenter.reset()
	StockMarket.reset()


static func _reset() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.reset()
	NotificationCenter.reset()
	CampaignClock.reset()
	StockMarket.reset()
	TestFixtures.reset_campaign()


#StockRng

static func _case_rng(res: Dictionary) -> void:
	var expect_17: Array[float] = [0.6771502960, 0.1926569212, 0.5313839065, 0.1654723147, 0.0877851779]
	var expect_7936: Array[float] = [0.0563838845, 0.9311983488, 0.0858476860, 0.0649862350, 0.1103599225]
	var r17 := StockRng.new(17)
	for i: int in 5:
		var v: float = r17.next()
		TestFixtures.check(res, "rng17[%d]" % i, is_equal_approx(v, expect_17[i]),
			"%.10f vs %.10f" % [v, expect_17[i]])
	var r7936 := StockRng.new(7936)
	for i: int in 5:
		var v: float = r7936.next()
		TestFixtures.check(res, "rng7936[%d]" % i, is_equal_approx(v, expect_7936[i]),
			"%.10f vs %.10f" % [v, expect_7936[i]])


static func _case_band(res: Dictionary) -> void:
	var cases: Array = [[-11.0, -2], [-5.0, -1], [-4.9, 0], [0.0, 0], [4.9, 0], [5.0, 1], [11.0, 2]]
	for row: Array in cases:
		var pct: float = row[0]
		var expect: int = row[1]
		var got: int = MARKET_SCRIPT._band(pct)
		TestFixtures.check(res, "band(%s)" % pct, got == expect, "%d vs %d" % [got, expect])


#Companies and history

static func _case_companies(res: Dictionary) -> void:
	TestFixtures.check(res, "company_count", StockMarket.company_count() == 9,
		"%d" % StockMarket.company_count())
	for k: int in 9:
		var c: Dictionary = StockMarket.company(k)
		var def: Dictionary = StockMarket.company_defs[k]
		var ok: bool = c.get("id") == k and c.get("name") == def["name"] and \
			c.get("type") == def["type"] and c.get("lender") == "Lender %d" % (k + 1) and \
			is_equal_approx(float(c.get("yld")), float(def["yld"])) and float(c.get("price")) >= 0.5
		TestFixtures.check(res, "company(%d) fields" % k, ok, str(c))


#StockMarket.company_defs is loaded from TSVs/Companies.tsv; a bad path yields an empty array.
static func _case_company_defs_tsv(res: Dictionary) -> void:
	var defs: Array[Dictionary] = StockMarket.company_defs
	TestFixtures.check(res, "company_defs loads nine rows", defs.size() == 9, "%d" % defs.size())
	var row0: Dictionary = defs[0]
	TestFixtures.check(res, "company_defs row 0 name", String(row0.get("name")) == "Company 1 Name",
		String(row0.get("name")))
	TestFixtures.check(res, "company_defs row 0 p0", is_equal_approx(float(row0.get("p0")), 38.0),
		"%.4f" % float(row0.get("p0")))
	TestFixtures.check(res, "company_defs row 0 win", is_equal_approx(float(row0.get("win")), 0.62),
		"%.4f" % float(row0.get("win")))
	TestFixtures.check(res, "company_defs row 0 lender", String(row0.get("lender")) == "Lender 1",
		String(row0.get("lender")))
	var missing: Array[Dictionary] = MARKET_SCRIPT.load_company_defs(
		"res://TSVs/No Such Companies File.tsv")
	TestFixtures.check(res, "load_company_defs on a missing path returns empty", missing.is_empty(),
		"%d rows" % missing.size())


static func _case_history(res: Dictionary) -> void:
	var floor_ok: bool = true
	for k: int in 9:
		var h: PackedFloat32Array = StockMarket.history(k)
		TestFixtures.check(res, "history(%d) size" % k, h.size() == StockMarket.HISTORY_DAYS,
			"%d vs %d" % [h.size(), StockMarket.HISTORY_DAYS])
		for v: float in h:
			if v < 0.5:
				floor_ok = false
	TestFixtures.check(res, "history floor 0.5", floor_ok, "all values >= 0.5")


static func _case_determinism(res: Dictionary) -> void:
	StockMarket.build(DAY_A)
	var h1: PackedFloat32Array = StockMarket.history(0)
	var e1: Array[Dictionary] = StockMarket.events(0)
	StockMarket.build(DAY_A)
	var h2: PackedFloat32Array = StockMarket.history(0)
	var e2: Array[Dictionary] = StockMarket.events(0)
	TestFixtures.check(res, "determinism history", h1 == h2, "same day rebuild differs")
	var labels_equal: bool = e1.size() == e2.size()
	if labels_equal:
		for i: int in e1.size():
			if e1[i]["day"] != e2[i]["day"] or e1[i]["label"] != e2[i]["label"]:
				labels_equal = false
				break
	TestFixtures.check(res, "determinism events", labels_equal, "same day rebuild event rows differ")
	StockMarket.reset()


static func _case_events(res: Dictionary) -> void:
	StockMarket.build(DAY_A)
	var contract_seen: bool = false
	var div_seen: bool = false
	for e: Dictionary in StockMarket.events(2):
		if String(e.get("kind")) == "contract":
			contract_seen = true
		if String(e.get("kind")) == "div":
			div_seen = true
	TestFixtures.check(res, "events has contract row", contract_seen, "company 2 events")
	TestFixtures.check(res, "events has div row", div_seen, "company 2 events")
	for e: Dictionary in StockMarket.events(0):
		TestFixtures.check(res, "event row keys", e.has("day") and e.has("kind") and
			e.has("win") and e.has("label") and e.has("pct"), str(e))
		break
	StockMarket.reset()


#Holdings

static func _case_holdings_seed(res: Dictionary) -> void:
	for row: Array in StockMarket.SEED_HOLDINGS:
		var k: int = int(row[0])
		var shares: int = int(row[1])
		var pct: float = float(row[2])
		var div: int = int(row[3])
		var h: Dictionary = StockMarket.holding(k)
		TestFixtures.check(res, "seed holding(%d) present" % k, not h.is_empty(), "%s" % h)
		if h.is_empty():
			continue
		var px: float = StockMarket.price(k)
		var expect_seen: float = px / (1.0 + pct / 100.0)
		var factor: float = 0.08 if k == 3 else -0.04
		var expect_avg: float = expect_seen / (1.0 + factor)
		TestFixtures.check(res, "seed holding(%d) shares" % k, int(h["shares"]) == shares,
			"%d vs %d" % [h["shares"], shares])
		TestFixtures.check(res, "seed holding(%d) seen" % k, is_equal_approx(float(h["seen"]), expect_seen),
			"%.4f vs %.4f" % [h["seen"], expect_seen])
		TestFixtures.check(res, "seed holding(%d) avg" % k, is_equal_approx(float(h["avg"]), expect_avg),
			"%.4f vs %.4f" % [h["avg"], expect_avg])
		TestFixtures.check(res, "seed holding(%d) dividends" % k, int(h["dividends"]) == div,
			"%d vs %d" % [h["dividends"], div])
		TestFixtures.check(res, "seed holding(%d) band" % k, int(h["band"]) == MARKET_SCRIPT._band(pct),
			"%d vs %d" % [h["band"], MARKET_SCRIPT._band(pct)])
		TestFixtures.check(res, "seed holding(%d) since_day stamped" % k,
			h.has("since_day") and int(h["since_day"]) == StockMarket._today,
			"%s vs %d" % [h.get("since_day"), StockMarket._today])
	TestFixtures.check(res, "unseeded holding empty", StockMarket.holding(FREE_K).is_empty(), "holding(1)")


#Trades

static func _case_buy(res: Dictionary) -> void:
	GameState.bank_notes = 100000
	var bank0: int = GameState.bank_notes
	var px: float = StockMarket.price(FREE_K)
	var expect_cost: int = int(ceil(3.0 * px + float(StockMarket.TRADE_FEE)))
	TestFixtures.check(res, "buy_cost", StockMarket.buy_cost(FREE_K, 3) == expect_cost,
		"%d vs %d" % [StockMarket.buy_cost(FREE_K, 3), expect_cost])
	var moved: Array = []
	var cb := func(delta: int, reason: String) -> void: moved.append([delta, reason])
	GameState.money_moved.connect(cb)
	var ok1: bool = StockMarket.buy(FREE_K, 3)
	TestFixtures.check(res, "buy first ok", ok1, "buy(1,3)")
	TestFixtures.check(res, "buy bank debited", GameState.bank_notes == bank0 - expect_cost,
		"%d vs %d" % [GameState.bank_notes, bank0 - expect_cost])
	TestFixtures.check(res, "buy money row", moved.size() == 1 and moved[0][0] == -expect_cost and
		moved[0][1] == "stock", str(moved))
	GameState.money_moved.disconnect(cb)
	var h1: Dictionary = StockMarket.holding(FREE_K)
	TestFixtures.check(res, "buy avg == price (first buy)", is_equal_approx(float(h1["avg"]), px),
		"%.4f vs %.4f" % [h1["avg"], px])
	TestFixtures.check(res, "buy stamps since_day on the first buy",
		h1.has("since_day") and int(h1["since_day"]) == StockMarket._today,
		"%s vs %d" % [h1.get("since_day"), StockMarket._today])
	var cost2: int = StockMarket.buy_cost(FREE_K, 2)
	StockMarket.buy(FREE_K, 2)
	var h2: Dictionary = StockMarket.holding(FREE_K)
	var expect_avg: float = (px * 3.0 + px * 2.0) / 5.0
	TestFixtures.check(res, "buy avg over two buys", is_equal_approx(float(h2["avg"]), expect_avg),
		"%.4f vs %.4f" % [h2["avg"], expect_avg])
	TestFixtures.check(res, "buy shares total", int(h2["shares"]) == 5, "%d" % h2["shares"])
	TestFixtures.check(res, "since_day is unchanged on a second buy",
		int(h2["since_day"]) == int(h1["since_day"]), "%d vs %d" % [h2["since_day"], h1["since_day"]])
	GameState.bank_notes = 0
	TestFixtures.check(res, "buy refused when short", not StockMarket.buy(OTHER_FREE_K, 1000000),
		"buy with empty bank")
	GameState.bank_notes = bank0 - expect_cost - cost2


static func _case_sell(res: Dictionary) -> void:
	var h: Dictionary = StockMarket.holding(FREE_K)
	var shares: int = int(h["shares"])
	var px: float = StockMarket.price(FREE_K)
	var bank0: int = GameState.bank_notes
	var expect_value: int = maxi(0, int(floor(2.0 * px - float(StockMarket.TRADE_FEE))))
	TestFixtures.check(res, "sell_value", StockMarket.sell_value(FREE_K, 2) == expect_value,
		"%d vs %d" % [StockMarket.sell_value(FREE_K, 2), expect_value])
	var ok1: bool = StockMarket.sell(FREE_K, 2)
	TestFixtures.check(res, "sell ok", ok1, "sell(1,2)")
	TestFixtures.check(res, "sell credits bank", GameState.bank_notes == bank0 + expect_value,
		"%d vs %d" % [GameState.bank_notes, bank0 + expect_value])
	TestFixtures.check(res, "sell refused above shares", not StockMarket.sell(FREE_K, 10000),
		"sell too many")
	var left: int = shares - 2
	var ok2: bool = StockMarket.sell(FREE_K, left)
	TestFixtures.check(res, "sell to zero ok", ok2, "sell remaining")
	TestFixtures.check(res, "sell removes holding at 0", StockMarket.holding(FREE_K).is_empty(),
		"%s" % StockMarket.holding(FREE_K))


#Alerts

static func _unread_count(k: int) -> int:
	var unread: int = 0
	for row: NotificationData in NotificationCenter.rows_of(NotificationData.TYPE_STOCK_MOVE, k):
		if not row.read:
			unread += 1
	return unread


static func _case_check_notify(res: Dictionary) -> void:
	StockMarket.buy(OTHER_FREE_K, 10)
	var h: StockHolding = StockMarket._holdings[OTHER_FREE_K] as StockHolding
	var c: StockCompany = StockMarket.companies[OTHER_FREE_K]
	StockMarket.mark_viewed(OTHER_FREE_K)
	h.seen = 100.0
	h.band = 0
	c.history[c.history.size() - 1] = 112.0
	StockMarket.check(OTHER_FREE_K)
	TestFixtures.check(res, "check pushes one row", _unread_count(OTHER_FREE_K) == 1,
		"%d unread" % _unread_count(OTHER_FREE_K))
	StockMarket.mark_viewed(OTHER_FREE_K)
	h.seen = 100.0
	h.band = 2
	c.history[c.history.size() - 1] = 102.0
	StockMarket.check(OTHER_FREE_K)
	TestFixtures.check(res, "check at band 0 pushes nothing new", _unread_count(OTHER_FREE_K) == 0,
		"%d unread" % _unread_count(OTHER_FREE_K))
	StockMarket.mark_viewed(OTHER_FREE_K)
	h.seen = 100.0
	h.band = 0
	c.history[c.history.size() - 1] = 130.0
	StockMarket.check(OTHER_FREE_K)
	c.history[c.history.size() - 1] = 145.0
	StockMarket.check(OTHER_FREE_K)
	TestFixtures.check(res, "check replaces older unread row", _unread_count(OTHER_FREE_K) == 1,
		"%d unread" % _unread_count(OTHER_FREE_K))


static func _case_mark_viewed(res: Dictionary) -> void:
	var h: StockHolding = StockMarket._holdings[OTHER_FREE_K] as StockHolding
	var px: float = StockMarket.price(OTHER_FREE_K)
	StockMarket.mark_viewed(OTHER_FREE_K)
	TestFixtures.check(res, "mark_viewed resets seen", is_equal_approx(h.seen, px), "%.4f" % h.seen)
	TestFixtures.check(res, "mark_viewed resets band", h.band == 0, "%d" % h.band)
	var unread: int = 0
	for row: NotificationData in NotificationCenter.rows_of(NotificationData.TYPE_STOCK_MOVE, OTHER_FREE_K):
		if not row.read:
			unread += 1
	TestFixtures.check(res, "mark_viewed resolves rows", unread == 0, "%d unread" % unread)
	StockMarket.sell(OTHER_FREE_K, h.shares)


#Days

static func _case_advance_day(res: Dictionary) -> void:
	StockMarket.build(DAY_A)
	var before: PackedFloat32Array = StockMarket.history(0)
	var last_before: float = before[before.size() - 1]
	StockMarket.advance_day()
	var after: PackedFloat32Array = StockMarket.history(0)
	TestFixtures.check(res, "advance_day keeps size", after.size() == StockMarket.HISTORY_DAYS,
		"%d" % after.size())
	TestFixtures.check(res, "advance_day changes last value", not is_equal_approx(after[after.size() - 1], last_before) or
		after[after.size() - 1] != last_before, "%.5f -> %.5f" % [last_before, after[after.size() - 1]])
	StockMarket.reset()


static func _case_dividend_day(res: Dictionary) -> void:
	var div_day: int = 45
	while div_day < 100000 and not MARKET_SCRIPT._is_div_day(div_day + 1):
		div_day += 1
	StockMarket.build(div_day)
	StockMarket._holdings.clear()
	StockMarket.buy(FREE_K, 50)
	var h: StockHolding = StockMarket._holdings[FREE_K] as StockHolding
	var px: float = StockMarket.price(FREE_K)
	var yld: float = StockMarket.companies[FREE_K].yld
	var expect_amount: int = int(floor(float(h.shares) * px * yld / 4.0))
	var bank0: int = GameState.bank_notes
	var div0: int = h.dividends
	StockMarket.advance_day()
	TestFixtures.check(res, "dividend credits holder", GameState.bank_notes == bank0 + expect_amount,
		"%d vs %d" % [GameState.bank_notes, bank0 + expect_amount])
	TestFixtures.check(res, "dividend adds to holding total", h.dividends == div0 + expect_amount,
		"%d vs %d" % [h.dividends, div0 + expect_amount])
	var new_px: float = StockMarket.price(FREE_K)
	TestFixtures.check(res, "dividend drops price", new_px < px, "%.4f -> %.4f" % [px, new_px])
	var div_event: bool = false
	for e: Dictionary in StockMarket.events(FREE_K):
		if String(e.get("kind")) == "div" and int(e.get("day")) == div_day + 1:
			div_event = true
	TestFixtures.check(res, "dividend adds event row", div_event, "no div event on day %d" % (div_day + 1))
	StockMarket.reset()


static func _case_tick(res: Dictionary) -> void:
	StockMarket.build(DAY_A)
	CampaignClock.reset()
	CampaignClock.advance_to(DAY_A * CampaignClock.MINUTES_PER_DAY)
	StockMarket.tick(CampaignClock.now())
	var size0: int = StockMarket.history(0).size()
	var last0: float = StockMarket.price(0)
	StockMarket.tick(CampaignClock.now())
	TestFixtures.check(res, "tick twice same day advances once", is_equal_approx(StockMarket.price(0), last0),
		"%.5f -> %.5f" % [last0, StockMarket.price(0)])
	CampaignClock.advance_to(CampaignClock.now() + CampaignClock.MINUTES_PER_DAY * 12)
	var today_before: int = StockMarket._today
	StockMarket.tick(CampaignClock.now())
	TestFixtures.check(res, "tick 12 day jump advances 12", StockMarket._today == today_before + 12,
		"%d vs %d" % [StockMarket._today, today_before + 12])
	TestFixtures.check(res, "tick keeps size", size0 == StockMarket.history(0).size(),
		"%d vs %d" % [size0, StockMarket.history(0).size()])
	CampaignClock.reset()
	StockMarket.reset()


#Contract results

static func _case_contract_result(res: Dictionary) -> void:
	StockMarket.build(DAY_A)
	var k: int = 4
	var entry_id: int = 3 * k
	TestFixtures.check(res, "the entry id used here maps onto company k under ContractIssuer",
		ContractIssuer.company_of(entry_id, StockMarket.company_count()) == k,
		"%d" % ContractIssuer.company_of(entry_id, StockMarket.company_count()))
	var before: float = StockMarket.price(k)
	StockMarket.contract_result(entry_id, true, 1.0)
	var after_win: float = StockMarket.price(k)
	TestFixtures.check(res, "contract_result win raises price", after_win > before,
		"%.4f -> %.4f" % [before, after_win])
	var win_event: bool = false
	for e: Dictionary in StockMarket.events(k):
		if String(e.get("kind")) == "contract" and bool(e.get("win")) == true and float(e.get("pct")) > 0.0:
			win_event = true
	TestFixtures.check(res, "contract_result win adds event", win_event, "no win event")
	var before2: float = StockMarket.price(k)
	StockMarket.contract_result(entry_id, false, 1.0)
	var after_fail: float = StockMarket.price(k)
	TestFixtures.check(res, "contract_result fail lowers price", after_fail < before2,
		"%.4f -> %.4f" % [before2, after_fail])
	var fail_event: bool = false
	for e: Dictionary in StockMarket.events(k):
		if String(e.get("kind")) == "contract" and bool(e.get("win")) == false and float(e.get("pct")) < 0.0:
			fail_event = true
	TestFixtures.check(res, "contract_result fail adds event", fail_event, "no fail event")
	var people_id: int = 3 * k + 1
	var places_id: int = 3 * k + 2
	var before_people: float = StockMarket.price(k)
	var events_before: int = StockMarket.events(k).size()
	StockMarket.contract_result(people_id, true, 1.0)
	StockMarket.contract_result(places_id, false, 1.0)
	TestFixtures.check(res, "a people id never moves the company price",
		is_equal_approx(StockMarket.price(k), before_people),
		"%.4f -> %.4f" % [before_people, StockMarket.price(k)])
	TestFixtures.check(res, "a places id never adds a company event",
		StockMarket.events(k).size() == events_before,
		"%d vs %d" % [StockMarket.events(k).size(), events_before])
	var seen: Dictionary = {"n": 0}
	var counter: Callable = func() -> void:
		seen["n"] = int(seen["n"]) + 1
	StockMarket.changed.connect(counter)
	StockMarket.contract_result(entry_id, true, 1.0)
	TestFixtures.check(res, "contract_result tells the screens once", int(seen["n"]) == 1,
		str(seen["n"]))
	StockMarket.changed.disconnect(counter)
	StockMarket.reset()


#ContractIssuer

static func _case_issuer(res: Dictionary) -> void:
	var kinds: Array[StringName] = [&"orgs", &"people", &"places", &"orgs", &"people", &"places"]
	var kinds_ok: bool = true
	for i: int in kinds.size():
		if ContractIssuer.kind_of(i) != kinds[i]:
			kinds_ok = false
	TestFixtures.check(res, "kind_of cycles orgs, people, places for ids 0 to 5", kinds_ok,
		"%s" % str(kinds))
	TestFixtures.check(res, "kind_of wraps a negative id back around",
		ContractIssuer.kind_of(-1) == &"places", "%s" % ContractIssuer.kind_of(-1))
	TestFixtures.check(res, "index_of counts by threes within a kind",
		ContractIssuer.index_of(0, 9) == 0 and ContractIssuer.index_of(3, 9) == 1
			and ContractIssuer.index_of(27, 9) == 0,
		"%d, %d, %d" % [ContractIssuer.index_of(0, 9), ContractIssuer.index_of(3, 9),
			ContractIssuer.index_of(27, 9)])
	TestFixtures.check(res, "index_of with no companies is always 0",
		ContractIssuer.index_of(12, 0) == 0, "%d" % ContractIssuer.index_of(12, 0))
	TestFixtures.check(res, "company_of only resolves an orgs id",
		ContractIssuer.company_of(0, 9) == 0 and ContractIssuer.company_of(1, 9) == -1
			and ContractIssuer.company_of(2, 9) == -1,
		"%d, %d, %d" % [ContractIssuer.company_of(0, 9), ContractIssuer.company_of(1, 9),
			ContractIssuer.company_of(2, 9)])
	TestFixtures.check(res, "company_of with no companies is -1",
		ContractIssuer.company_of(0, 0) == -1, "%d" % ContractIssuer.company_of(0, 0))


static func _case_stats_and_accepted(res: Dictionary) -> void:
	var stats: Dictionary = StockMarket.company_stats(2)
	TestFixtures.check(res, "company_stats succeeded", int(stats["succeeded"]) ==
		int(stats["taken"]) - int(stats["failed"]), "%s" % stats)
	var accepted: Dictionary = StockMarket.last_accepted(0)
	TestFixtures.check(res, "last_accepted empty on empty board", accepted.is_empty(),
		"%s" % accepted)
	var saved: Array[ContractView] = GameState.contracts
	var k: int = 3
	var org_view := ContractView.new()
	org_view.entry_id = 3 * k
	org_view.name = "Org Contract"
	org_view.status = GuiTypes.ContractStatus.ACTIVE
	var people_view := ContractView.new()
	people_view.entry_id = 3 * k + 1
	people_view.name = "People Contract"
	people_view.status = GuiTypes.ContractStatus.ACTIVE
	GameState.contracts = [org_view, people_view]
	var org_accepted: Dictionary = StockMarket.last_accepted(k)
	TestFixtures.check(res, "last_accepted finds an orgs id issued to its company",
		String(org_accepted.get("status", "")) == "Active" and
			String(org_accepted.get("name", "")) == "Org Contract",
		"%s" % org_accepted)
	var people_missed: bool = true
	for other_k: int in StockMarket.company_count():
		var found: Dictionary = StockMarket.last_accepted(other_k)
		if String(found.get("name", "")) == "People Contract":
			people_missed = false
	TestFixtures.check(res, "last_accepted never returns a people id for any company",
		people_missed, str(people_missed))
	GameState.contracts = saved


#Ranges

#The build days are the 10th of Erta and the 10th of Kusarra, so MTD starts nine days back on
#both while YTD reaches one month further on the second.
static func _case_ranges(res: Dictionary) -> void:
	var year_start: int = TrynnCalendar.day_index(TrynnCalendar.month_start_minute(YEAR_B, 0))
	var days: Array[Dictionary] = [
		{"month": 4, "ticks": TICKS_40},
		{"month": 5, "ticks": TICKS_30},
	]
	for row: Dictionary in days:
		var month_start: int = TrynnCalendar.day_index(
			TrynnCalendar.month_start_minute(YEAR_B, int(row["month"])))
		var day: int = month_start + 9
		var counts: Dictionary = row["ticks"]
		StockMarket.build(day)
		for range_key: String in StockMarket.RANGES:
			var start: int = StockMarket.range_start(range_key)
			TestFixtures.check(res, "range_start(%s,%d) bounds" % [range_key, day],
				start >= 0 and start <= StockMarket.HISTORY_DAYS - 1, "%d" % start)
			if StockMarket.RANGE_DAYS.has(range_key):
				var expect: int = maxi(0, StockMarket.HISTORY_DAYS - int(StockMarket.RANGE_DAYS[range_key]))
				TestFixtures.check(res, "range_start(%s,%d) value" % [range_key, day], start == expect,
					"%d vs %d" % [start, expect])
			if range_key == "MTD":
				var mtd: int = StockMarket.HISTORY_DAYS - 1 - (day - month_start)
				TestFixtures.check(res, "range_start(MTD,%d) opens on the 1st of the month" % day,
					start == mtd, "%d vs %d" % [start, mtd])
			if range_key == "YTD":
				var ytd: int = StockMarket.HISTORY_DAYS - 1 - (day - year_start)
				TestFixtures.check(res, "range_start(YTD,%d) opens on the 1st of the year" % day,
					start == ytd, "%d vs %d" % [start, ytd])
			var ticks: Array[Dictionary] = StockMarket.tick_labels(range_key)
			var want: int = int(counts[range_key])
			TestFixtures.check(res, "tick_labels(%s,%d) label count" % [range_key, day],
				ticks.size() == want, "%d vs %d" % [ticks.size(), want])
			var rows_ok: bool = true
			for t: Dictionary in ticks:
				var idx: int = int(t["index"])
				var x: float = float(t["x"])
				var align: String = String(t["align"])
				if idx < start or idx > StockMarket.HISTORY_DAYS - 1 or x < 0.0 or x > 1.0 or \
						String(t["label"]) == "" or not (align == "start" or align == "end" or align == "center"):
					rows_ok = false
			TestFixtures.check(res, "tick_labels(%s,%d) rows well formed" % [range_key, day], rows_ok,
				"%d rows" % ticks.size())
			if range_key == "1W" and ticks.size() > 0:
				var last: String = String(ticks[ticks.size() - 1]["label"])
				TestFixtures.check(res, "the last 1W label dates the build day %d" % day,
					last == GuiDates.short_text(day), last)
			if range_key == "5Y":
				var years_ok: bool = ticks.size() == 5
				for i: int in ticks.size():
					if String(ticks[i]["label"]) != str(YEAR_B - 4 + i):
						years_ok = false
				TestFixtures.check(res, "the 5Y labels name five years up to the build year",
					years_ok, str(ticks))
	StockMarket.reset()
#Readers the Invest page (GX3G) added to StockMarket.

static func _case_invest_readers(res: Dictionary) -> void:
	GameState.bank_notes = 10000
	var n: int = StockMarket.max_buy(FREE_K)
	TestFixtures.check(res, "max_buy affords n but not n + 1",
		n >= 1 and StockMarket.can_buy(FREE_K, n) and not StockMarket.can_buy(FREE_K, n + 1),
		"n %d price %.2f" % [n, StockMarket.price(FREE_K)])
	GameState.bank_notes = StockMarket.TRADE_FEE
	TestFixtures.check(res, "max_buy is 0 with only the fee in the bank",
		StockMarket.max_buy(FREE_K) == 0, "%d" % StockMarket.max_buy(FREE_K))
	GameState.bank_notes = 0
	TestFixtures.check(res, "max_buy is 0 on an empty bank", StockMarket.max_buy(FREE_K) == 0,
		"%d" % StockMarket.max_buy(FREE_K))
	TestFixtures.check(res, "max_buy is 0 for an unknown company", StockMarket.max_buy(-1) == 0,
		"%d" % StockMarket.max_buy(-1))
	GameState.bank_notes = 10000
	TestFixtures.check(res, "has_unread is false with no row",
		not StockMarket.has_unread(OTHER_FREE_K), "no rows")
	NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, OTHER_FREE_K,
		{"company_id": OTHER_FREE_K, "company": "Company", "pct": 5.0, "band": 1})
	TestFixtures.check(res, "has_unread sees an unread stockMove row",
		StockMarket.has_unread(OTHER_FREE_K), "pushed one row")
	StockMarket.mark_viewed(OTHER_FREE_K)
	TestFixtures.check(res, "mark_viewed clears has_unread",
		not StockMarket.has_unread(OTHER_FREE_K), "resolved")
	var hist: PackedFloat32Array = StockMarket.history(FREE_K)
	var opens_ok: bool = true
	for range_key: String in StockMarket.RANGES:
		var i0: int = StockMarket.range_start(range_key)
		if not is_equal_approx(StockMarket.first_price(FREE_K, range_key), hist[i0]):
			opens_ok = false
	TestFixtures.check(res, "first_price reads the history at range_start", opens_ok,
		"%d ranges" % StockMarket.RANGES.size())
	TestFixtures.check(res, "first_price is 0 for an unknown company",
		is_equal_approx(StockMarket.first_price(-1, "1Y"), 0.0), "unknown k")
	var today: int = GameState.day()
	TestFixtures.check(res, "day_of_index ends on the build day",
		StockMarket.day_of_index(StockMarket.HISTORY_DAYS - 1) == today,
		"%d vs %d" % [StockMarket.day_of_index(StockMarket.HISTORY_DAYS - 1), today])
	TestFixtures.check(res, "day_of_index opens HISTORY_DAYS - 1 days back",
		StockMarket.day_of_index(0) == today - (StockMarket.HISTORY_DAYS - 1),
		"%d" % StockMarket.day_of_index(0))
	var ticks: Array[Dictionary] = StockMarket.tick_labels("1W")
	var ticks_ok: bool = ticks.size() > 0
	for row: Dictionary in ticks:
		if GuiDates.short_text(StockMarket.day_of_index(int(row["index"]))) != String(row["label"]):
			ticks_ok = false
	TestFixtures.check(res, "day_of_index dates every 1W tick label", ticks_ok,
		"%d rows" % ticks.size())
	var saved: Array[ContractView] = GameState.contracts
	var view := ContractView.new()
	view.entry_id = 3 * 4
	view.name = "Entry Id Contract"
	view.status = GuiTypes.ContractStatus.ACTIVE
	GameState.contracts = [view]
	var row_4: Dictionary = StockMarket.last_accepted(4)
	TestFixtures.check(res, "last_accepted carries entry_id",
		row_4.has("entry_id") and int(row_4["entry_id"]) == 12, "%s" % row_4)
	TestFixtures.check(res, "last_accepted keeps its other keys",
		row_4.has("name") and row_4.has("status") and row_4.has("color"), "%s" % row_4)
	GameState.contracts = saved


#The named market constants: the dividend day rule, the win and loss jump formulas and the
#determinism of two resets in a row. The numbers themselves are unchanged from before naming.
static func _case_f5f_constants(res: Dictionary) -> void:
	TestFixtures.check(res, "_is_div_day(45) is a dividend day", MARKET_SCRIPT._is_div_day(45), "45")
	TestFixtures.check(res, "_is_div_day(44) is not a dividend day",
		not MARKET_SCRIPT._is_div_day(44), "44")
	TestFixtures.check(res, "_is_div_day(135) is a dividend day", MARKET_SCRIPT._is_div_day(135),
		"135")
	var jump_win: float = MARKET_SCRIPT._jump_of(true, 1.0)
	var jump_loss: float = MARKET_SCRIPT._jump_of(false, 1.0)
	TestFixtures.check(res, "_jump_of(true, 1.0) is 0.035", absf(jump_win - 0.035) < 1e-9,
		"%.12f" % jump_win)
	TestFixtures.check(res, "_jump_of(false, 1.0) is -0.045", absf(jump_loss - (-0.045)) < 1e-9,
		"%.12f" % jump_loss)
	StockMarket.reset()
	var h1: PackedFloat32Array = StockMarket.history(0)
	StockMarket.reset()
	var h2: PackedFloat32Array = StockMarket.history(0)
	TestFixtures.check(res, "company 0 history is the same after two resets", h1 == h2,
		"reset determinism")
