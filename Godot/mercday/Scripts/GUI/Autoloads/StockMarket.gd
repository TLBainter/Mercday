extends Node

#Nine companies with a deterministic price history, holdings, buy and sell, quarterly dividends,
#the price reaction to contract results and the stockMove notifications. No screen is built here;
#the Invest tab of wave 3 (GX3G) renders this data.
#PLACEHOLDER: the whole market model is the data and formulas of the Finance Viewer prototype.

signal changed

const TRADE_FEE: int = 5
const HISTORY_DAYS: int = 1800
const RANGES: Array[String] = ["5Y", "1Y", "YTD", "6M", "3M", "1M", "MTD", "1W"]
const RANGE_DAYS: Dictionary = {"1W": 10, "1M": 33, "3M": 99, "6M": 198, "1Y": 330, "5Y": 1650}
const SEASON_START_MONTHS: Array[int] = [0, 3, 5, 8]
const REASON_STOCK: String = "stock"
const REASON_DIVIDEND: String = "dividend"

#Dividend day rule (PROTO isDivDay): day DIV_DAY_OFFSET of every DIV_PERIOD_DAYS day quarter.
const DIV_PERIOD_DAYS: int = 90
const DIV_DAY_OFFSET: int = 45
#Dividend payout and its price drop: this share of the annual yield, paid each dividend day.
const DIV_SHARE_OF_YIELD: float = 0.25
#Price jump from a contract result: a base plus a term scaled by the difficulty.
const WIN_JUMP_BASE: float = 0.015
const WIN_JUMP_PER_DIFF: float = 0.02
const LOSS_JUMP_BASE: float = 0.02
const LOSS_JUMP_PER_DIFF: float = 0.025
#Share of a price jump the fair (mean reversion target) value keeps.
const FAIR_JUMP_SHARE: float = 0.6
#Rival contract cadence: first event FIRST_MIN to FIRST_MIN + FIRST_SPAN days in, then every
#GAP_MIN to GAP_MIN + GAP_SPAN days, none within TAIL_DAYS of today; difficulty DIFF_MIN to
#DIFF_MIN + DIFF_SPAN.
const RIVAL_FIRST_MIN_DAYS: int = 20
const RIVAL_FIRST_SPAN_DAYS: int = 40
const RIVAL_GAP_MIN_DAYS: int = 30
const RIVAL_GAP_SPAN_DAYS: int = 55
const RIVAL_TAIL_DAYS: int = 8
const RIVAL_DIFF_MIN: float = 0.5
const RIVAL_DIFF_SPAN: float = 1.5
#The first day's price starts at p0 times a factor between START_PRICE_MIN and that plus SPAN.
const START_PRICE_MIN: float = 0.55
const START_PRICE_SPAN: float = 0.3
#Daily pull of the log price back toward the fair value.
const MEAN_REVERT: float = 0.01
#No price ever prints below this floor.
const PRICE_FLOOR: float = 0.5
#Per company StockRng seed: the company index times the step plus the base.
const RNG_SEED_STEP: int = 7919
const RNG_SEED_BASE: int = 17

#Company defs are authored in TSVs/Companies.tsv; company k belongs to lender k + 1 ("Lender N").
const COMPANIES_TSV: String = "res://TSVs/Companies.tsv"

#PLACEHOLDER: the PROTO companyStats table (Finance Viewer.dc.html:1401), [taken, failed] by k.
const COMPANY_STATS: Array[Array] = [
	[0, 0], [0, 0], [6, 1], [5, 1], [4, 0], [7, 2], [0, 0], [0, 0], [0, 0],
]

#PLACEHOLDER: the PROTO own-contract events and the forced event of company 5 (ensureMarket's
#`own` and `forced` maps), kept as an offset from today so they always land near the end of the
#history however far `today` has moved. own: cid 11/12/13 are companies (cid - 9); forced: cid 5.
const SAMPLE_EVENTS: Array[Dictionary] = [
	{"company": 2, "offset": 0, "win": true, "label": "Contract 12 Name - Success (your guild)", "diff": 1.6},
	{"company": 3, "offset": -2, "win": true, "label": "Contract 13 Name - Success (your guild)", "diff": 1.6},
	{"company": 4, "offset": -6, "win": true, "label": "Contract 14 Name - Success (your guild)", "diff": 1.6},
	{"company": 5, "offset": -3, "win": false, "label": "Contract 6 Name - Failed (rival guild)", "diff": 1.4},
]

#PLACEHOLDER: the three sample seeded holdings (ensureMarket's tail forEach), [company, shares,
#pct since seen, dividends already received].
const SEED_HOLDINGS: Array[Array] = [
	[0, 25, 2.1, 38], [3, 40, 6.4, 71], [5, 120, -5.3, 164],
]

var companies: Array[StockCompany] = []
var company_defs: Array[Dictionary] = []

var _holdings: Dictionary = {}
var _today: int = 0
var _last_tick_day: int = -1
var _seeded: bool = false


func _ready() -> void:
	GameState.results_recorded.connect(_on_results_recorded)
	GameState.roster_changed.connect(_on_roster_changed)
	reset()


#Reads the company table from a TSV (Name, Type, Lender, Price, Yield, Volatility, Drift, Win).
#A row with an empty Name is skipped. A missing file yields an empty array and one warning.
static func load_company_defs(path: String = COMPANIES_TSV) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_warning("StockMarket: cannot find %s" % path)
		return out
	for row: Dictionary in TsvReader.load_header_rows(path):
		var company_name: String = String(row.get("Name", ""))
		if company_name == "":
			continue
		out.append({
			"name": company_name, "type": String(row.get("Type", "")),
			"lender": String(row.get("Lender", "")),
			"p0": float(row.get("Price", "0")), "yld": float(row.get("Yield", "0")),
			"vol": float(row.get("Volatility", "0")), "drift": float(row.get("Drift", "0")),
			"win": float(row.get("Win", "0")),
		})
	return out


#Builds the market for the current day, seeds the holdings and forgets the last tick day. Runs
#on _ready and on a new game. MetricsHistory has no self triggered new game detection on this
#copy (verified: no _ready, reset, roster_changed or started reference anywhere in it); this
#follows the BazaarManager and LegalManager _seeded/roster_changed/GameState.started idiom
#instead, the one working "new game" pattern actually present in the codebase.
#company_defs loads once, from disk; a test may point it at a fixture first, by writing to
#company_defs before calling reset() or by assigning the result of load_company_defs(path) to it.
func reset() -> void:
	if company_defs.is_empty():
		company_defs = load_company_defs()
	build(GameState.day())
	_seed_holdings()
	_last_tick_day = -1
	_seeded = GameState.started
	changed.emit()


#Creates for every company the history that ends `today`, exactly as ensureMarket does. The same
#day and the same seed always give the same history: build() touches nothing but `companies`.
func build(today: int) -> void:
	_today = today
	companies.clear()
	for k: int in range(company_defs.size()):
		companies.append(_build_company(k, today))


func company_count() -> int:
	return company_defs.size()


func company(k: int) -> Dictionary:
	if k < 0 or k >= companies.size():
		return {}
	var c: StockCompany = companies[k]
	var h: PackedFloat32Array = c.history
	var cur: float = h[h.size() - 1]
	var prev: float = h[h.size() - 2] if h.size() >= 2 else cur
	var change: float = (cur / prev - 1.0) * 100.0 if prev > 0.0 else 0.0
	return {
		"id": c.id, "name": c.name, "type": c.type, "lender": c.lender,
		"yld": c.yld, "price": cur, "change_pct": change,
	}


func price(k: int) -> float:
	if k < 0 or k >= companies.size():
		return 0.0
	var h: PackedFloat32Array = companies[k].history
	return h[h.size() - 1] if h.size() > 0 else 0.0


func history(k: int) -> PackedFloat32Array:
	if k < 0 or k >= companies.size():
		return PackedFloat32Array()
	return companies[k].history.duplicate()


func events(k: int) -> Array[Dictionary]:
	if k < 0 or k >= companies.size():
		return []
	return companies[k].events.duplicate(true)


func company_stats(k: int) -> Dictionary:
	if k < 0 or k >= COMPANY_STATS.size():
		return {"taken": 0, "failed": 0, "succeeded": 0}
	var row: Array = COMPANY_STATS[k]
	var taken: int = int(row[0])
	var failed: int = int(row[1])
	return {"taken": taken, "failed": failed, "succeeded": taken - failed}


#The last accepted contract by this issuer: company k issues the contracts ContractIssuer names
#as its own. Active ranks newest; a posting still Available or Rejected is never picked.
func last_accepted(k: int) -> Dictionary:
	var best: ContractView = null
	var best_active: bool = false
	var best_status: String = ""
	for view: ContractView in GameState.contracts:
		if ContractIssuer.company_of(view.entry_id, company_count()) != k:
			continue
		var st: String = _accepted_status(view)
		if st == "":
			continue
		var is_active: bool = st == "Active"
		if best == null or (is_active and not best_active) or \
				(is_active == best_active and view.entry_id > best.entry_id):
			best = view
			best_active = is_active
			best_status = st
	if best == null:
		return {}
	var best_name: String = best.name if best.name != "" else "Contract %d Name" % \
		(best.entry_id + 1)
	return {"name": best_name, "status": best_status,
		"color": _accepted_color(best_status), "entry_id": best.entry_id}


func _accepted_status(view: ContractView) -> String:
	match view.status:
		GuiTypes.ContractStatus.ACTIVE:
			return "Active"
		GuiTypes.ContractStatus.COMPLETED:
			return "Failed" if view.outcome == "Failed" else "Completed"
		GuiTypes.ContractStatus.EXPIRED:
			return "Expired"
	return ""


func _accepted_color(status_text: String) -> String:
	match status_text:
		"Active":
			return "#5aa6e8"
		"Completed":
			return "#6cc36a"
		"Failed":
			return "#e8583f"
	return "#9aa0a8"


#Holdings

func holding(k: int) -> Dictionary:
	if not _holdings.has(k):
		return {}
	return _holding_row(_holdings[k] as StockHolding)


func holdings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var keys: Array = _holdings.keys()
	keys.sort()
	for k: Variant in keys:
		out.append(_holding_row(_holdings[k] as StockHolding))
	return out


func portfolio_value() -> float:
	var total: float = 0.0
	for k: Variant in _holdings.keys():
		var h: StockHolding = _holdings[k] as StockHolding
		total += price(h.company_id) * float(h.shares)
	return total


func _holding_row(h: StockHolding) -> Dictionary:
	var px: float = price(h.company_id)
	var value: float = px * float(h.shares)
	var cost: float = h.avg * float(h.shares)
	var gain_pct: float = (px / h.avg - 1.0) * 100.0 if h.avg > 0.0 else 0.0
	return {
		"company_id": h.company_id, "company": companies[h.company_id].name,
		"shares": h.shares, "avg": h.avg, "seen": h.seen, "band": h.band,
		"dividends": h.dividends, "price": px, "value": value,
		"gain": value - cost, "gain_pct": gain_pct, "since_day": h.since_day,
	}


#PLACEHOLDER: the PROTO sample holdings (ensureMarket's tail forEach). Seed rows never move the
#bank: avg and seen are back solved from the seeded pct so the row shows the same pct at once.
func _seed_holdings() -> void:
	_holdings.clear()
	for row: Array in SEED_HOLDINGS:
		var k: int = int(row[0])
		if k < 0 or k >= companies.size():
			continue
		var shares: int = int(row[1])
		var pct: float = float(row[2])
		var div: int = int(row[3])
		var px: float = price(k)
		var seen: float = px / (1.0 + pct / 100.0)
		var factor: float = 0.08 if k == 3 else -0.04
		var h := StockHolding.new()
		h.company_id = k
		h.shares = shares
		h.seen = seen
		h.avg = seen / (1.0 + factor)
		h.band = _band(pct)
		h.dividends = div
		h.since_day = _today
		_holdings[k] = h


#Trades

func can_buy(k: int, qty: int) -> bool:
	if k < 0 or k >= companies.size() or qty < 1:
		return false
	return GameState.bank_notes >= buy_cost(k, qty)


func buy_cost(k: int, qty: int) -> int:
	if k < 0 or k >= companies.size() or qty < 1:
		return 0
	return int(ceil(float(qty) * price(k) + float(TRADE_FEE)))


func sell_value(k: int, qty: int) -> int:
	if k < 0 or k >= companies.size() or qty < 1:
		return 0
	return maxi(0, int(floor(float(qty) * price(k) - float(TRADE_FEE))))


func buy(k: int, qty: int) -> bool:
	if not can_buy(k, qty):
		return false
	var cost: int = buy_cost(k, qty)
	var px: float = price(k)
	var label: String = "%s - Bought %d shares" % [companies[k].name, qty]
	if not _pay(cost, REASON_STOCK, label):
		return false
	var h: StockHolding = _holdings.get(k) as StockHolding
	if h == null:
		h = StockHolding.new()
		h.company_id = k
		h.since_day = _today
		_holdings[k] = h
	h.avg = (h.avg * float(h.shares) + px * float(qty)) / float(h.shares + qty)
	h.shares += qty
	h.seen = px
	h.band = 0
	changed.emit()
	return true


func sell(k: int, qty: int) -> bool:
	if k < 0 or k >= companies.size():
		return false
	var h: StockHolding = _holdings.get(k) as StockHolding
	if h == null or qty < 1 or qty > h.shares:
		return false
	var value: int = sell_value(k, qty)
	var label: String = "%s - Sold %d shares" % [companies[k].name, qty]
	_credit(value, REASON_STOCK, label)
	h.shares -= qty
	if h.shares <= 0:
		_holdings.erase(k)
	changed.emit()
	return true


#Alerts

static func _band(pct: float) -> int:
	if pct >= 0.0:
		return int(floor(pct / 5.0))
	return -int(floor(-pct / 5.0))


#Runs for a held company: fires a stockMove alert every time price crosses another 5% step from
#the price at h.seen, replacing that company's older unread alert.
func check(k: int) -> void:
	var h: StockHolding = _holdings.get(k) as StockHolding
	if h == null or h.seen <= 0.0:
		return
	var pct: float = (price(k) / h.seen - 1.0) * 100.0
	var b: int = _band(pct)
	if b == h.band:
		return
	h.band = b
	if b == 0:
		return
	var center: Node = _notice_center()
	if center == null:
		return
	if center.has_method("resolve"):
		center.call("resolve", NotificationData.TYPE_STOCK_MOVE, k)
	if center.has_method("push"):
		center.call("push", NotificationData.TYPE_STOCK_MOVE, k,
			{"company_id": k, "company": companies[k].name, "pct": snappedf(pct, 0.1), "band": b},
			NotificationData.Urgency.INFORMATIONAL)


#Viewing a stock's page: resets its alert baseline (when held) and resolves its unread rows.
func mark_viewed(k: int) -> void:
	if k < 0 or k >= companies.size():
		return
	var h: StockHolding = _holdings.get(k) as StockHolding
	if h != null:
		h.seen = price(k)
		h.band = 0
	var center: Node = _notice_center()
	if center != null and center.has_method("resolve"):
		center.call("resolve", NotificationData.TYPE_STOCK_MOVE, k)


func _notice_center() -> Node:
	return get_node_or_null("/root/NotificationCenter")


#Days

#One market day for every company; the history keeps its last HISTORY_DAYS values. Emits
#nothing on its own: tick() coalesces every day it steps into one changed signal.
func advance_day() -> void:
	_today += 1
	var is_div: bool = _is_div_day(_today)
	for c: StockCompany in companies:
		var last_price: float = c.history[c.history.size() - 1]
		var lp: float = log(last_price)
		var jump: float = 0.0
		if is_div:
			_pay_dividend(c)
			jump -= c.yld * DIV_SHARE_OF_YIELD
			c.lf -= c.yld * DIV_SHARE_OF_YIELD
			c.events.append({
				"day": _today, "kind": "div", "win": false,
				"label": "Dividend paid (%.2f%% of price)" % (c.yld * DIV_SHARE_OF_YIELD * 100.0),
				"pct": -(c.yld * DIV_SHARE_OF_YIELD * 100.0),
			})
		var g: float = c.rng.gauss()
		c.lf += c.drift
		lp += c.drift + c.vol * g - MEAN_REVERT * (lp - c.lf) + jump
		c.history.append(maxf(PRICE_FLOOR, exp(lp)))
		if c.history.size() > HISTORY_DAYS:
			c.history.remove_at(0)
	for k: Variant in _holdings.keys():
		check(int(k))


func _pay_dividend(c: StockCompany) -> void:
	var h: StockHolding = _holdings.get(c.id) as StockHolding
	if h == null:
		return
	var amount: int = int(floor(float(h.shares) * price(c.id) * c.yld * DIV_SHARE_OF_YIELD))
	_credit(amount, REASON_DIVIDEND, "%s - Dividend" % c.name)
	h.dividends += amount


#Idempotent: one advance_day per calendar day passed since the last tick. The first call after
#reset() only records the day. `now` is a CampaignClock minute.
func tick(now: int) -> void:
	var d: int = TrynnCalendar.day_index(now)
	if _last_tick_day < 0:
		_last_tick_day = d
		return
	var advanced: bool = false
	while _last_tick_day < d:
		_last_tick_day += 1
		advance_day()
		advanced = true
	if advanced:
		changed.emit()


#Contract results

func contract_result(entry_id: int, win: bool, difficulty: float) -> void:
	var count: int = company_count()
	var k: int = ContractIssuer.company_of(entry_id, count)
	if k < 0 or k >= companies.size():
		return
	var j: float = _jump_of(win, difficulty)
	var c: StockCompany = companies[k]
	var last: int = c.history.size() - 1
	c.history[last] = c.history[last] * exp(j)
	c.lf += j * FAIR_JUMP_SHARE
	var result: ContractResultData = GameState.result_of(entry_id)
	var title: String = "Contract %d Name" % (entry_id + 1)
	if result != null and result.name != "":
		title = result.name
	c.events.append({
		"day": _today, "kind": "contract", "win": win,
		"label": "%s - %s (your guild)" % [title, "Success" if win else "Failed"],
		"pct": j * 100.0,
	})
	check(k)
	changed.emit()


func _on_results_recorded(entry_id: int) -> void:
	var result: ContractResultData = GameState.result_of(entry_id)
	if result == null:
		return
	contract_result(entry_id, not result.failed, result.difficulty)


func _on_roster_changed() -> void:
	_seed_if_started()


func _seed_if_started() -> bool:
	if _seeded or not GameState.started:
		return false
	reset()
	return true


#Ranges

func range_start(range_key: String) -> int:
	if range_key == "MTD":
		return _index_of_day(_month_start_day(_today))
	if range_key == "YTD":
		return _index_of_day(_year_start_day(_today))
	var n: int = int(RANGE_DAYS.get(range_key, 10))
	return maxi(0, HISTORY_DAYS - n)


func tick_labels(range_key: String) -> Array[Dictionary]:
	var i0: int = range_start(range_key)
	var last: int = HISTORY_DAYS - 1
	var span: float = float(maxi(1, last - i0))
	var out: Array[Dictionary] = []
	var week_n: int = 0
	for i: int in range(i0, last + 1):
		var day: int = _today - (HISTORY_DAYS - 1 - i)
		var date: Dictionary = TrynnCalendar.date_of(day * CampaignClock.MINUTES_PER_DAY)
		var label: String = ""
		match range_key:
			"1W", "MTD":
				label = GuiDates.short_text(day)
			"1M":
				if int(date["weekday"]) == 0:
					week_n += 1
					label = "Wk %d" % week_n
			"3M", "6M", "YTD":
				if int(date["day"]) == 1:
					label = str(date["month_name"]).substr(0, 3)
			"1Y":
				if int(date["day"]) == 1 and SEASON_START_MONTHS.has(int(date["month"])):
					label = "%s %d" % [_season_cap(str(date["season"])), int(date["year"])]
			_:
				if int(date["day"]) == 1 and int(date["month"]) == 0:
					label = str(date["year"])
		if label == "":
			continue
		var x: float = float(i - i0) / span
		var align: String = "start" if x < 0.04 else ("end" if x > 0.96 else "center")
		out.append({"index": i, "label": label, "x": x, "align": align})
	return out


func _month_start_day(day: int) -> int:
	var date: Dictionary = TrynnCalendar.date_of(day * CampaignClock.MINUTES_PER_DAY)
	var minute: int = TrynnCalendar.month_start_minute(int(date["year"]), int(date["month"]))
	return TrynnCalendar.day_index(minute)


func _year_start_day(day: int) -> int:
	var date: Dictionary = TrynnCalendar.date_of(day * CampaignClock.MINUTES_PER_DAY)
	var minute: int = TrynnCalendar.month_start_minute(int(date["year"]), 0)
	return TrynnCalendar.day_index(minute)


func _index_of_day(day: int) -> int:
	return maxi(0, mini(HISTORY_DAYS - 1, day - _today + HISTORY_DAYS - 1))


static func _season_cap(season: String) -> String:
	if season == "":
		return season
	return season.substr(0, 1).to_upper() + season.substr(1)


#History build

static func _jump_of(win: bool, diff: float) -> float:
	if win:
		return WIN_JUMP_BASE + WIN_JUMP_PER_DIFF * diff
	return -(LOSS_JUMP_BASE + LOSS_JUMP_PER_DIFF * diff)


#Dividend day rule (PROTO isDivDay): day DIV_DAY_OFFSET of every DIV_PERIOD_DAYS day quarter, on
#the day index. posmod folds a negative day the same way ((d % 90) + 90) % 90 does.
static func _is_div_day(day: int) -> bool:
	return posmod(day, DIV_PERIOD_DAYS) == DIV_DAY_OFFSET


func _build_company(k: int, today: int) -> StockCompany:
	var def: Dictionary = company_defs[k]
	var c := StockCompany.new()
	c.id = k
	c.name = String(def.get("name", ""))
	c.type = String(def.get("type", ""))
	c.lender = String(def["lender"])
	c.p0 = float(def.get("p0", 0.0))
	c.yld = float(def.get("yld", 0.0))
	c.vol = float(def.get("vol", 0.0))
	c.drift = float(def.get("drift", 0.0))
	c.win = float(def.get("win", 0.0))

	var rng := StockRng.new(k * RNG_SEED_STEP + RNG_SEED_BASE)
	var t0: int = today - HISTORY_DAYS
	var jumps: Dictionary = {}

	#Rival events every RIVAL_GAP_MIN_DAYS to RIVAL_GAP_MIN_DAYS + RIVAL_GAP_SPAN_DAYS days: the
	#PROTO for-loop ported as a while, same draw order.
	var day: int = t0 + RIVAL_FIRST_MIN_DAYS + int(floor(rng.next() * RIVAL_FIRST_SPAN_DAYS))
	while day < today - RIVAL_TAIL_DAYS:
		var is_win: bool = rng.next() < c.win
		var diff: float = RIVAL_DIFF_MIN + rng.next() * RIVAL_DIFF_SPAN
		jumps[day] = {
			"win": is_win,
			"label": "Contract %s (rival guild)" % ("Success" if is_win else "Failed"),
			"diff": diff,
		}
		day += RIVAL_GAP_MIN_DAYS + int(floor(rng.next() * RIVAL_GAP_SPAN_DAYS))

	for sample: Dictionary in SAMPLE_EVENTS:
		if int(sample["company"]) != k:
			continue
		var sday: int = today + int(sample["offset"])
		jumps[sday] = {
			"win": bool(sample["win"]), "label": String(sample["label"]),
			"diff": float(sample["diff"]),
		}

	c.lp = log(c.p0 * (START_PRICE_MIN + rng.next() * START_PRICE_SPAN))
	c.lf = c.lp

	var raw: PackedFloat32Array = PackedFloat32Array()
	var built_events: Array[Dictionary] = []
	for i: int in range(HISTORY_DAYS + 1):
		var d: int = t0 + i
		var jump: float = 0.0
		if jumps.has(d):
			var e: Dictionary = jumps[d]
			var j: float = _jump_of(bool(e["win"]), float(e["diff"]))
			jump = j
			c.lf += j * FAIR_JUMP_SHARE
			built_events.append({
				"day": d, "kind": "contract", "win": bool(e["win"]),
				"label": String(e["label"]), "pct": j * 100.0,
			})
		if _is_div_day(d):
			jump -= c.yld * DIV_SHARE_OF_YIELD
			c.lf -= c.yld * DIV_SHARE_OF_YIELD
			built_events.append({
				"day": d, "kind": "div", "win": false,
				"label": "Dividend paid (%.2f%% of price)" % (c.yld * DIV_SHARE_OF_YIELD * 100.0),
				"pct": -(c.yld * DIV_SHARE_OF_YIELD * 100.0),
			})
		c.lf += c.drift
		c.lp += c.drift + c.vol * rng.gauss() - MEAN_REVERT * (c.lp - c.lf) + jump
		raw.append(maxf(PRICE_FLOOR, exp(c.lp)))

	c.history = raw.slice(1, raw.size())
	c.events = built_events
	c.rng = rng
	return c


#Money

func _pay(amount: int, reason: String, label: String) -> bool:
	if GameState.has_method("charge"):
		return bool(GameState.call("spend", amount, reason, label))
	return GameState.spend(amount, reason)


func _credit(amount: int, reason: String, label: String) -> void:
	if GameState.has_method("charge"):
		GameState.call("refund", amount, reason, label)
	else:
		GameState.refund(amount, reason)
#Readers for the Invest page (GX3G). Added members only: no formula above changes.

#The largest quantity of k the bank can still afford, 0 when even one share is out of reach.
func max_buy(k: int) -> int:
	if k < 0 or k >= companies.size():
		return 0
	var px: float = price(k)
	if px <= 0.0:
		return 0
	var budget: float = float(GameState.bank_notes - TRADE_FEE)
	if budget < 0.0:
		return 0
	var n: int = int(floor(budget / px))
	while n > 0 and not can_buy(k, n):
		n -= 1
	if n >= 0 and can_buy(k, n + 1):
		n += 1
	return maxi(0, n)


#True while NotificationCenter still holds an unread stockMove row for company k.
func has_unread(k: int) -> bool:
	var center: Node = _notice_center()
	if center == null or not center.has_method("rows_of"):
		return false
	var rows: Array = center.call("rows_of", NotificationData.TYPE_STOCK_MOVE, k)
	for row: NotificationData in rows:
		if not row.read:
			return true
	return false


#The price that opens a range: the history value at range_start(range_key).
func first_price(k: int, range_key: String) -> float:
	if k < 0 or k >= companies.size():
		return 0.0
	var h: PackedFloat32Array = companies[k].history
	if h.is_empty():
		return 0.0
	var i: int = clampi(range_start(range_key), 0, h.size() - 1)
	return h[i]


#The day a history index stands on; index HISTORY_DAYS - 1 is the build day.
func day_of_index(i: int) -> int:
	return _today - (HISTORY_DAYS - 1 - i)
