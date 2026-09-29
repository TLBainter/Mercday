class_name GuiInvestTests
extends RefCounted

#The Invest page: the roster column and its hover card, the header, the range row, the price
#chart, the portfolio and position widgets, the trade panel and the trade confirmation.
#Run headless with the gui invest tests flag after the harness argument separator.

const PAGE_SCENE: String = "res://Scenes/GUI/Finance/Invest/InvestTab.tscn"
const PAGE_SIZE: Vector2 = Vector2(1400.0, 820.0)
const LIST_WIDTH: float = 272.0
const RIGHT_WIDTH: float = 290.0
const COLUMN_GAP: float = 16.0
#Company 0 carries a seeded holding of 25 shares; 1 and 7 carry none.
const HELD_K: int = 0
const FREE_K: int = 1
const OTHER_FREE_K: int = 7
#Entry 12 belongs to company 4, which ContractIssuer maps it to.
const ENTRY_COMPANY: int = 4
const ENTRY_ID: int = 12
const MONEY: int = 10000


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	InvestChart.instant_reveal = true
	_fresh()
	await host.get_tree().process_frame
	await _case_layout(res, host)
	await _case_mount_size(res, host)
	await _case_list(res, host)
	await _case_viewed(res, host)
	await _case_select(res, host)
	await _case_header(res, host)
	await _case_ranges(res, host)
	await _case_chart(res, host)
	await _case_hover(res, host)
	await _case_reveal(res, host)
	await _case_widgets(res, host)
	await _case_switch(res, host)
	await _case_captions(res, host)
	await _case_quantity(res, host)
	await _case_rows(res, host)
	await _case_confirm(res, host)
	await _case_sell_all(res, host)
	await _case_tooltip(res, host)
	await _case_contract(res, host)
	await _case_modal_host(res, host)
	await _case_hidden(res, host)
	await _case_fee_floor(res, host)
	await _case_glyphs(res, host)
	InvestChart.instant_reveal = false
	_reset()
	return TestFixtures.summarize(res, "GUI INVEST")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	CampaignClock.reset()
	NotificationCenter.reset()
	StockMarket.reset()
	GameState.bank_notes = MONEY


static func _reset() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	NotificationCenter.reset()
	CampaignClock.reset()
	StockMarket.reset()
	TestFixtures.reset_campaign()


static func _mount(host: Node) -> InvestTab:
	var page: InvestTab = (load(PAGE_SCENE) as PackedScene).instantiate() as InvestTab
	host.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.size = PAGE_SIZE
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return page


static func _drop(host: Node, page: Node) -> void:
	page.queue_free()
	await host.get_tree().process_frame


static func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.5


#A scene colour is stored with six decimals, so a channel is compared with a tolerance.
static func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


#The change of the last history day, forced so a case can read a rising, falling or flat row.
static func _force_change(k: int, from_price: float, to_price: float) -> void:
	var c: StockCompany = StockMarket.companies[k]
	var h: PackedFloat32Array = c.history
	h[h.size() - 2] = from_price
	h[h.size() - 1] = to_price
	c.history = h


#Layout

static func _case_layout(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var w: PackedFloat32Array = page.column_widths()
	TestFixtures.check(res, "roster column is 272 wide", _near(w[0], LIST_WIDTH), "%.1f" % w[0])
	TestFixtures.check(res, "right column is 290 wide", _near(w[2], RIGHT_WIDTH), "%.1f" % w[2])
	TestFixtures.check(res, "centre column takes the rest",
		_near(w[1], PAGE_SIZE.x - LIST_WIDTH - RIGHT_WIDTH - COLUMN_GAP * 2.0), "%.1f" % w[1])
	TestFixtures.check(res, "roster shows by default", page.roster_shown(), "visible")
	TestFixtures.check(res, "page builds its parts",
		page.chart_node() != null and page.list_node() != null and page.panel_node() != null
			and page.portfolio_node() != null and page.tooltip_node() != null, "five parts")
	TestFixtures.check(res, "no confirm dialog until a trade", page.confirm_node() == null,
		"%s" % page.confirm_node())
	page.hide_roster = true
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "hide_roster hides the roster", not page.roster_shown(), "hidden")
	var wide: PackedFloat32Array = page.column_widths()
	TestFixtures.check(res, "hidden roster widens the centre",
		_near(wide[1], PAGE_SIZE.x - RIGHT_WIDTH - COLUMN_GAP), "%.1f" % wide[1])
	page.hide_roster = false
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "hide_roster false shows it again", page.roster_shown(), "visible")
	TestFixtures.check(res, "default company is the first", page.company_id == 0,
		"%d" % page.company_id)
	TestFixtures.check(res, "default range is 1Y", page.range_key == "1Y", page.range_key)
	var pos: InvestPosition = page.position_widget()
	TestFixtures.check(res, "a held company shows a position widget",
		pos != null and pos.shares() == 25, "%s" % pos)
	page.select_company(FREE_K)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unheld company drops the position widget",
		page.position_widget() == null, "%s" % page.position_widget())
	var scrolls: Array[Node] = []
	_scrolls(page, scrolls)
	TestFixtures.check(res, "the page holds one scroll", scrolls.size() == 1,
		"%d" % scrolls.size())
	TestFixtures.check(res, "the scroll belongs to the roster",
		scrolls.size() == 1 and page.company_list.is_ancestor_of(scrolls[0]), "roster")
	await _drop(host, page)


#GX4F-13: the page mounts to its full size with no anchor warning.
static func _case_mount_size(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	TestFixtures.check(res, "the page mounts at its full size", page.size == PAGE_SIZE,
		"%s" % [page.size])
	await _drop(host, page)


#The company roster

static func _case_list(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var list: InvestCompanyList = page.list_node()
	TestFixtures.check(res, "list holds every company",
		list.item_count() == StockMarket.company_count(), "%d rows" % list.item_count())
	TestFixtures.check(res, "list counts its rows",
		list.count_text() == "%d listed" % StockMarket.company_count(), list.count_text())
	var order_ok: bool = true
	var price_ok: bool = true
	for k: int in StockMarket.company_count():
		var row: InvestCompanyItem = list.item(k)
		if row == null:
			order_ok = false
			continue
		if row.name_text() != String(StockMarket.company(k).get("name", "")):
			order_ok = false
		if row.price_text() != InvestText.price_text(StockMarket.price(k)):
			price_ok = false
	TestFixtures.check(res, "rows keep the market order", order_ok,
		"%d rows" % list.item_count())
	TestFixtures.check(res, "rows print the live price", price_ok, "%d rows" % list.item_count())
	TestFixtures.check(res, "a held row prints its shares",
		list.item(HELD_K).owned_text() == "25 shares", list.item(HELD_K).owned_text())
	TestFixtures.check(res, "an unheld row prints Not owned",
		list.item(FREE_K).owned_text() == "Not owned", list.item(FREE_K).owned_text())
	TestFixtures.check(res, "the selected row is marked",
		list.item(0).is_selected() and not list.item(1).is_selected(), "row 0 selected")
	list.press_item(2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a press picks its company", page.company_id == 2,
		"%d" % page.company_id)
	TestFixtures.check(res, "the press moves the mark",
		list.item(2).is_selected() and not list.item(0).is_selected(), "row 2 selected")
	list.press_item(99)
	TestFixtures.check(res, "a press on no row changes nothing", page.company_id == 2,
		"%d" % page.company_id)
	_colour_rows(res, page, list)
	await _dot_rows(res, host, page, list)
	await _drop(host, page)


#The three change colours of a roster row, on a company no other case trades.
static func _colour_rows(res: Dictionary, page: InvestTab, list: InvestCompanyList) -> void:
	var saved: PackedFloat32Array = StockMarket.companies[OTHER_FREE_K].history
	var row7: InvestCompanyItem = list.item(OTHER_FREE_K)
	_force_change(OTHER_FREE_K, 100.0, 110.0)
	page.refresh()
	TestFixtures.check(res, "a rising row reads +10.0%", row7.change_text() == "+10.0%",
		row7.change_text())
	TestFixtures.check(res, "a rising row is green", row7.change_color() == InvestText.GREEN,
		"%s" % row7.change_color())
	_force_change(OTHER_FREE_K, 100.0, 90.0)
	page.refresh()
	TestFixtures.check(res, "a falling row reads -10.0%", row7.change_text() == "-10.0%",
		row7.change_text())
	TestFixtures.check(res, "a falling row is red", row7.change_color() == InvestText.RED,
		"%s" % row7.change_color())
	_force_change(OTHER_FREE_K, 100.0, 100.0)
	page.refresh()
	TestFixtures.check(res, "a flat row reads +0.0%", row7.change_text() == "+0.0%",
		row7.change_text())
	TestFixtures.check(res, "a flat row is cream", row7.change_color() == InvestText.CREAM,
		"%s" % row7.change_color())
	StockMarket.companies[OTHER_FREE_K].history = saved
	page.refresh()


#The unread dot of a roster row and the pick that clears it.
static func _dot_rows(res: Dictionary, host: Node, page: InvestTab,
		list: InvestCompanyList) -> void:
	var row7: InvestCompanyItem = list.item(OTHER_FREE_K)
	TestFixtures.check(res, "no unread row leaves the dot off", not row7.has_dot(), "dot off")
	NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, OTHER_FREE_K,
		{"company_id": OTHER_FREE_K, "company": "Company", "pct": 5.0, "band": 1})
	page.refresh()
	TestFixtures.check(res, "an unread row lights the dot", row7.has_dot(), "dot on")
	page.select_company(OTHER_FREE_K)
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking the company clears its dot",
		not row7.has_dot() and not StockMarket.has_unread(OTHER_FREE_K), "dot off")


#page_shown marks the open company viewed; _ready does not

static func _case_viewed(res: Dictionary, host: Node) -> void:
	NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, 0,
		{"company_id": 0, "company": "Company", "pct": 5.0, "band": 1})
	var page: InvestTab = await _mount(host)
	TestFixtures.check(res, "_ready leaves the alert unread", StockMarket.has_unread(0),
		"still unread")
	TestFixtures.check(res, "_ready leaves the dot on", page.list_node().item(0).has_dot(),
		"dot on")
	page.page_shown()
	await host.get_tree().process_frame
	TestFixtures.check(res, "page_shown marks the company viewed", not StockMarket.has_unread(0),
		"read")
	TestFixtures.check(res, "page_shown clears the dot", not page.list_node().item(0).has_dot(),
		"dot off")
	TestFixtures.check(res, "page_shown leaves the chart drawn",
		page.chart_node().reveal_ratio() >= 1.0, "%.2f" % page.chart_node().reveal_ratio())
	await _drop(host, page)


#select_company and open_stock

static func _case_select(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	page.select_company(3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "select_company takes a known company", page.company_id == 3,
		"%d" % page.company_id)
	TestFixtures.check(res, "select_company moves the header",
		page.header_name() == String(StockMarket.company(3).get("name", "")), page.header_name())
	TestFixtures.check(res, "select_company sets the quantity back to 1", page.quantity() == 1,
		"%d" % page.quantity())
	page.set_quantity(4)
	page.select_company(5)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a second pick resets the quantity too", page.quantity() == 1,
		"%d" % page.quantity())
	page.select_company(-1)
	TestFixtures.check(res, "select_company ignores a negative id", page.company_id == 5,
		"%d" % page.company_id)
	page.select_company(StockMarket.company_count())
	TestFixtures.check(res, "select_company ignores an id past the end", page.company_id == 5,
		"%d" % page.company_id)
	page.open_stock(2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "open_stock opens a known company", page.company_id == 2,
		"%d" % page.company_id)
	TestFixtures.check(res, "open_stock feeds the chart", page.chart_node().company_id == 2,
		"%d" % page.chart_node().company_id)
	page.open_stock(42)
	TestFixtures.check(res, "open_stock ignores an unknown company", page.company_id == 2,
		"%d" % page.company_id)
	await _drop(host, page)


#The header, with and without a hovered chart sample

static func _case_header(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var chart: InvestChart = page.chart_node()
	TestFixtures.check(res, "header names the company",
		page.header_name() == String(StockMarket.company(0).get("name", "")), page.header_name())
	TestFixtures.check(res, "header prints the yield",
		page.header_yield() == "Dividend Yield 5.2% - paid quarterly", page.header_yield())
	TestFixtures.check(res, "header captions the price", page.header_small() == "Price / Share",
		page.header_small())
	TestFixtures.check(res, "header prints the live price",
		page.header_price() == InvestText.price_text(StockMarket.price(0)), page.header_price())
	var first: float = StockMarket.first_price(0, "1Y")
	var px: float = StockMarket.price(0)
	var delta: float = px - first
	var pct: float = (px / first - 1.0) * 100.0 if first > 0.0 else 0.0
	TestFixtures.check(res, "header prints the range move",
		page.header_change() == "%s - 1Y" % InvestText.move_text(delta, pct),
		page.header_change())
	TestFixtures.check(res, "header tints the range move",
		page.header_change_color() == InvestText.gain_color(delta),
		"%s" % page.header_change_color())
	chart.hover_at(0.0)
	var texts: Dictionary = chart.hover_texts()
	TestFixtures.check(res, "a hover captions the date",
		page.header_small() == String(texts.get("date", "")), page.header_small())
	TestFixtures.check(res, "a hover prints the sample price",
		page.header_price() == InvestText.price_text(chart.hover_price()), page.header_price())
	chart.clear_hover()
	TestFixtures.check(res, "clearing the hover restores the caption",
		page.header_small() == "Price / Share", page.header_small())
	TestFixtures.check(res, "clearing the hover restores the price",
		page.header_price() == InvestText.price_text(StockMarket.price(0)), page.header_price())
	page.select_company(4)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the yield follows the company",
		page.header_yield() == "Dividend Yield 0.5% - paid quarterly", page.header_yield())
	await _drop(host, page)


#The eight range buttons

static func _case_ranges(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var keys: PackedStringArray = page.range_keys()
	TestFixtures.check(res, "the row holds eight ranges", keys.size() == 8, "%d" % keys.size())
	var order_ok: bool = keys.size() == StockMarket.RANGES.size()
	for i: int in mini(keys.size(), StockMarket.RANGES.size()):
		if keys[i] != StockMarket.RANGES[i]:
			order_ok = false
	TestFixtures.check(res, "the row keeps the market range order", order_ok, "%s" % keys)
	TestFixtures.check(res, "1Y opens active", page.range_button("1Y").is_active(), "active")
	TestFixtures.check(res, "5Y opens idle", not page.range_button("5Y").is_active(), "idle")
	var every_range_ok: bool = true
	var samples_ok: bool = true
	var counts: PackedInt32Array = PackedInt32Array()
	for key: String in StockMarket.RANGES:
		page.set_range(key)
		var lit: int = 0
		for other: String in StockMarket.RANGES:
			if page.range_button(other).is_active():
				lit += 1
		if lit != 1 or not page.range_button(key).is_active():
			every_range_ok = false
		if page.range_key != key or page.chart_node().range_key != key:
			every_range_ok = false
		var n: int = page.chart_node().sample_count()
		counts.append(n)
		if n < 1 or n > int(InvestChart.MAX_SAMPLES) + 2:
			samples_ok = false
		if not page.header_change().ends_with("- %s" % key):
			every_range_ok = false
	TestFixtures.check(res, "every range lights only its own button", every_range_ok,
		"%d ranges" % keys.size())
	TestFixtures.check(res, "every range stays inside the sample cap", samples_ok,
		"%s" % counts)
	page.set_range("1Y")
	page.set_range("nope")
	TestFixtures.check(res, "an unknown range is ignored", page.range_key == "1Y",
		page.range_key)
	await _drop(host, page)


#The price chart: samples, bounds, rows, grid, ticks and the cost line

static func _case_chart(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var chart: InvestChart = page.chart_node()
	var hist: PackedFloat32Array = StockMarket.history(0)
	var i0: int = StockMarket.range_start("1Y")
	var last: int = hist.size() - 1
	var n: int = chart.sample_count()
	TestFixtures.check(res, "the chart opens on the range start", chart.sample_index(0) == i0,
		"%d vs %d" % [chart.sample_index(0), i0])
	TestFixtures.check(res, "the chart ends on the build day",
		chart.sample_index(n - 1) == last, "%d vs %d" % [chart.sample_index(n - 1), last])
	TestFixtures.check(res, "a sample index off the ends is -1",
		chart.sample_index(-1) == -1 and chart.sample_index(n) == -1, "-1")
	var lo: float = hist[i0]
	var hi: float = hist[i0]
	for j: int in n:
		var v: float = hist[chart.sample_index(j)]
		lo = minf(lo, v)
		hi = maxf(hi, v)
	TestFixtures.check(res, "the bounds pad under the lowest sample", chart.low() < lo,
		"%.2f under %.2f" % [chart.low(), lo])
	TestFixtures.check(res, "the bounds pad over the highest sample", chart.high() > hi,
		"%.2f over %.2f" % [chart.high(), hi])
	TestFixtures.check(res, "the high bound sits on the top row", chart.row_of(chart.high()) == 0,
		"%d" % chart.row_of(chart.high()))
	TestFixtures.check(res, "the low bound sits on the bottom row",
		chart.row_of(chart.low()) == InvestChart.ROWS - 1, "%d" % chart.row_of(chart.low()))
	var mid: float = (chart.low() + chart.high()) / 2.0
	TestFixtures.check(res, "the middle price sits on a middle row",
		chart.row_of(mid) == 34 or chart.row_of(mid) == 35, "%d" % chart.row_of(mid))
	var rows: PackedInt32Array = chart.column_rows()
	TestFixtures.check(res, "the chart holds 120 columns", rows.size() == InvestChart.COLS,
		"%d" % rows.size())
	var rows_ok: bool = true
	for r: int in rows:
		if r < 0 or r >= InvestChart.ROWS:
			rows_ok = false
	TestFixtures.check(res, "every column row stays on the grid", rows_ok,
		"%d columns" % rows.size())
	var rising: bool = hist[last] >= hist[i0]
	TestFixtures.check(res, "the line takes the range colour",
		chart.line_color() == (InvestText.GREEN if rising else InvestText.RED),
		"%s" % chart.line_color())
	var labels: PackedStringArray = chart.grid_labels()
	TestFixtures.check(res, "the grid carries five labels",
		labels.size() == InvestChart.GRID_LINES, "%d" % labels.size())
	var climbs: bool = labels.size() > 1
	for g: int in labels.size() - 1:
		if labels[g].to_float() >= labels[g + 1].to_float():
			climbs = false
	TestFixtures.check(res, "the grid labels climb", climbs, "%s" % labels)
	TestFixtures.check(res, "the ticks come from the market",
		chart.tick_rows().size() == StockMarket.tick_labels("1Y").size(),
		"%d rows" % chart.tick_rows().size())
	var avg: float = float(StockMarket.holding(0).get("avg", 0.0))
	TestFixtures.check(res, "a held company draws a cost line", chart.has_cost_line(),
		"%.2f avg" % avg)
	TestFixtures.check(res, "the cost line sits on the row of the average",
		chart.cost_row() == chart.row_of(avg), "%d" % chart.cost_row())
	TestFixtures.check(res, "the cost line is labelled",
		chart.cost_text() == "Your avg cost %s" % InvestText.price_text(avg), chart.cost_text())
	page.select_company(FREE_K)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unheld company draws no cost line",
		not page.chart_node().has_cost_line(), "no line")
	await _drop(host, page)


#The chart hover card and its event rows

static func _case_hover(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var chart: InvestChart = page.chart_node()
	var n: int = chart.sample_count()
	var hits: Array[int] = [0]
	var counter: Callable = func(_sample: int) -> void:
		hits[0] += 1
	chart.hover_changed.connect(counter)
	chart.hover_at(0.0)
	TestFixtures.check(res, "a hover at the left edge takes the first sample",
		chart.hovered() == 0, "%d" % chart.hovered())
	TestFixtures.check(res, "the hover reports itself", hits[0] == 1, "%d hits" % hits[0])
	chart.hover_at(0.0)
	TestFixtures.check(res, "the same hover reports nothing new", hits[0] == 1,
		"%d hits" % hits[0])
	chart.hover_at(0.5)
	TestFixtures.check(res, "a hover halfway takes the middle sample",
		chart.hovered() == int(round(0.5 * float(n - 1))), "%d" % chart.hovered())
	TestFixtures.check(res, "a hover halfway sits on the right side",
		not bool(chart.hover_texts().get("left_side", true)), "right side")
	chart.hover_at(1.0)
	TestFixtures.check(res, "a hover at the right edge takes the last sample",
		chart.hovered() == n - 1, "%d" % chart.hovered())
	TestFixtures.check(res, "a hover past the flip sits on the left side",
		bool(chart.hover_texts().get("left_side", false)), "left side")
	var texts: Dictionary = chart.hover_texts()
	var px: float = chart.hover_price()
	TestFixtures.check(res, "the card prints the sample price",
		String(texts.get("price", "")) == "%s per share" % InvestText.price_text(px),
		String(texts.get("price", "")))
	TestFixtures.check(res, "the card dates the sample",
		String(texts.get("date", "")) == GuiDates.short_text(
			StockMarket.day_of_index(chart.sample_index(chart.hovered()))),
		String(texts.get("date", "")))
	var first: float = StockMarket.history(page.company_id)[chart.sample_index(0)]
	var pct: float = (px / first - 1.0) * 100.0 if first > 0.0 else 0.0
	TestFixtures.check(res, "the card counts the move since the range start",
		String(texts.get("change", "")).begins_with(InvestText.change_text(pct)),
		String(texts.get("change", "")))
	TestFixtures.check(res, "the card names the range start day",
		String(texts.get("change", "")).ends_with(GuiDates.short_text(
			StockMarket.day_of_index(chart.sample_index(0)))), String(texts.get("change", "")))
	var move_tint: Color = texts.get("change_color", Color.BLACK) as Color
	TestFixtures.check(res, "the card tints the move",
		move_tint == InvestText.gain_color(pct), "%s" % move_tint)
	TestFixtures.check(res, "the hover price is the live price at the last sample",
		is_equal_approx(px, StockMarket.price(page.company_id)), "%.2f" % px)
	var before: int = hits[0]
	chart.clear_hover()
	TestFixtures.check(res, "clear_hover drops the sample", chart.hovered() == -1,
		"%d" % chart.hovered())
	TestFixtures.check(res, "clear_hover empties the card", chart.hover_texts().is_empty(),
		"%s" % chart.hover_texts())
	TestFixtures.check(res, "clear_hover reports itself", hits[0] == before + 1,
		"%d hits" % hits[0])
	chart.hover_changed.disconnect(counter)
	_event_rows(res, page)
	await _drop(host, page)


#Company events land on the sample whose step holds their day.
static func _event_rows(res: Dictionary, page: InvestTab) -> void:
	page.select_company(2)
	page.set_range("1W")
	var chart: InvestChart = page.chart_node()
	chart.hover_at(1.0)
	var rows: Array = chart.hover_texts().get("events", []) as Array
	var win_found: bool = false
	for row: Variant in rows:
		var event: Dictionary = row as Dictionary
		var tint: Color = event.get("color", Color.BLACK) as Color
		if tint == InvestText.GREEN and String(event.get("label",
				"")).begins_with("Contract 12 Name"):
			win_found = true
	TestFixtures.check(res, "a won contract event lands on its sample", win_found,
		"%d rows" % rows.size())
	page.set_range("5Y")
	chart = page.chart_node()
	var n: int = chart.sample_count()
	var div_found: bool = false
	var loss_found: bool = false
	for j: int in n:
		chart.hover_at(float(j) / float(n - 1))
		for row: Variant in chart.hover_texts().get("events", []) as Array:
			var event: Dictionary = row as Dictionary
			var tint: Color = event.get("color", Color.BLACK) as Color
			if tint == InvestText.YELLOW:
				div_found = true
			if tint == InvestText.RED:
				loss_found = true
	TestFixtures.check(res, "a dividend event is yellow", div_found, "%d samples" % n)
	TestFixtures.check(res, "a lost contract event is red", loss_found, "%d samples" % n)
	chart.clear_hover()
	page.set_range("1Y")
	page.select_company(0)


#The reveal sweep

static func _case_reveal(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var chart: InvestChart = page.chart_node()
	TestFixtures.check(res, "instant_reveal fills the line at once",
		chart.reveal_ratio() >= 1.0, "%.2f" % chart.reveal_ratio())
	InvestChart.instant_reveal = false
	chart.play_reveal()
	TestFixtures.check(res, "a played reveal starts empty", is_zero_approx(chart.reveal_ratio()),
		"%.2f" % chart.reveal_ratio())
	chart.step_reveal(InvestChart.REVEAL_SECONDS / 2.0)
	var mid: float = chart.reveal_ratio()
	var step: float = 1.0 / float(InvestChart.REVEAL_STEPS)
	TestFixtures.check(res, "the reveal moves in 48 steps",
		is_equal_approx(snappedf(mid, step), mid) and mid > 0.0 and mid < 1.0
			and absf(mid - 0.5) <= step, "%.4f" % mid)
	chart.finish_reveal()
	TestFixtures.check(res, "finish_reveal fills the line", chart.reveal_ratio() >= 1.0,
		"%.2f" % chart.reveal_ratio())
	chart.step_reveal(InvestChart.REVEAL_SECONDS)
	TestFixtures.check(res, "a step with no reveal running changes nothing",
		chart.reveal_ratio() >= 1.0, "%.2f" % chart.reveal_ratio())
	InvestChart.instant_reveal = true
	chart.play_reveal()
	TestFixtures.check(res, "instant_reveal skips the sweep", chart.reveal_ratio() >= 1.0,
		"%.2f" % chart.reveal_ratio())
	await _drop(host, page)


#The portfolio and position widgets

static func _case_widgets(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var folio: InvestPortfolio = page.portfolio_node()
	var cost: float = 0.0
	for row: Dictionary in StockMarket.holdings():
		cost += float(row.get("avg", 0.0)) * float(int(row.get("shares", 0)))
	var value: float = StockMarket.portfolio_value()
	var gain: float = value - cost
	TestFixtures.check(res, "the portfolio prints its value",
		folio.value_text() == InvestText.value_text(value), folio.value_text())
	TestFixtures.check(res, "the portfolio prints its all time move",
		folio.gain_text() == "%s all time" % InvestText.move_text(gain, gain / cost * 100.0),
		folio.gain_text())
	TestFixtures.check(res, "the portfolio tints its move",
		folio.gain_color() == InvestText.gain_color(gain), "%s" % folio.gain_color())
	TestFixtures.check(res, "the portfolio counts its dividends",
		folio.dividends_text() == "273 notes earned in dividends", folio.dividends_text())
	var pos: InvestPosition = page.position_widget()
	var held: Dictionary = StockMarket.holding(0)
	TestFixtures.check(res, "the position names its company",
		pos.title_text() == "%s Position" % String(StockMarket.company(0).get("name", "")),
		pos.title_text())
	TestFixtures.check(res, "the position prints its value",
		pos.value_text() == InvestText.value_text(float(held.get("value", 0.0))),
		pos.value_text())
	TestFixtures.check(res, "the position prints its shares and its move",
		pos.gain_text() == " (%s, %s)" % [InvestText.shares_text(int(held.get("shares", 0))),
			InvestText.change_text(float(held.get("gain_pct", 0.0)))],
		pos.gain_text())
	TestFixtures.check(res, "the worth suffix runs small and trims before widening the column",
		pos.value_notes.suffix_label.get_theme_font_size("font_size") == InvestPosition.SUFFIX_SIZE
			and pos.value_notes.suffix_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
			and pos.value_notes.suffix_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		str(pos.value_notes.suffix_label.get_theme_font_size("font_size")))
	TestFixtures.check(res, "a positive share count carries no minus sign",
		not pos.gain_text().contains(" - ") and
			not pos.gain_text().contains("-%d share" % int(held.get("shares", 0))),
		pos.gain_text())
	TestFixtures.check(res, "the position counts its dividends since the buy day",
		pos.dividends_text() == "%s notes earned in dividends since %s" % [
			InvestText.notes_text(int(held.get("dividends", 0))),
			InvestText.since_text(int(held.get("since_day", 0)))],
		pos.dividends_text())
	page.select_company(3)
	await host.get_tree().process_frame
	var other: InvestPosition = page.position_widget()
	TestFixtures.check(res, "the position follows the pick",
		other != null and other.shares() == 40, "%s" % other)
	TestFixtures.check(res, "the position renames itself",
		other.title_text() == "%s Position" % String(StockMarket.company(3).get("name", "")),
		other.title_text())
	await _drop(host, page)


#The Buy and Sell switch

static func _case_switch(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	page.select_company(HELD_K)
	await host.get_tree().process_frame
	var panel: InvestTradePanel = page.panel_node()
	var sides: Array[int] = [0]
	var watcher: Callable = func(_new_side: StringName) -> void:
		sides[0] += 1
	panel.side_changed.connect(watcher)
	TestFixtures.check(res, "the switch opens on Buy", panel.side() == InvestTradePanel.SIDE_BUY,
		"%s" % panel.side())
	TestFixtures.check(res, "Buy tops out at what the bank can buy",
		panel.max_quantity() == StockMarket.max_buy(HELD_K), "%d" % panel.max_quantity())
	TestFixtures.check(res, "Buy labels one share", panel.confirm_label() == "Buy 1 Share",
		panel.confirm_label())
	panel.press_side(InvestTradePanel.SIDE_SELL)
	TestFixtures.check(res, "pressing Sell flips the switch",
		panel.side() == InvestTradePanel.SIDE_SELL, "%s" % panel.side())
	TestFixtures.check(res, "the flip reports itself once", sides[0] == 1, "%d" % sides[0])
	TestFixtures.check(res, "Sell tops out at the shares held", panel.max_quantity() == 25,
		"%d" % panel.max_quantity())
	TestFixtures.check(res, "Sell labels one share", panel.confirm_label() == "Sell 1 Share",
		panel.confirm_label())
	panel.press_side(InvestTradePanel.SIDE_SELL)
	TestFixtures.check(res, "pressing the live side reports nothing", sides[0] == 1,
		"%d" % sides[0])
	panel.press_swap()
	TestFixtures.check(res, "the swap button goes back to Buy",
		panel.side() == InvestTradePanel.SIDE_BUY and sides[0] == 2, "%s" % panel.side())
	panel.press_swap()
	TestFixtures.check(res, "the swap button goes to Sell again",
		panel.side() == InvestTradePanel.SIDE_SELL, "%s" % panel.side())
	page.set_side(InvestTradePanel.SIDE_BUY)
	TestFixtures.check(res, "the page passes the side through",
		page.side() == InvestTradePanel.SIDE_BUY, "%s" % page.side())
	panel.side_changed.disconnect(watcher)
	page.select_company(FREE_K)
	page.set_side(InvestTradePanel.SIDE_SELL)
	await host.get_tree().process_frame
	TestFixtures.check(res, "Sell on nothing held tops out at 0", page.max_quantity() == 0,
		"%d" % page.max_quantity())
	TestFixtures.check(res, "Sell on nothing held is invalid", not page.trade_valid(),
		"invalid")
	page.press_confirm()
	TestFixtures.check(res, "a confirm press on an invalid trade opens nothing",
		page.confirm_node() == null, "%s" % page.confirm_node())
	await _drop(host, page)


#The captions of the painted buttons: the bevel fill covers built-in text, so each caption rides
#in a child Label

static func _case_captions(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	page.select_company(HELD_K)
	page.set_side(InvestTradePanel.SIDE_BUY)
	page.set_quantity(1)
	await host.get_tree().process_frame
	var panel: InvestTradePanel = page.panel_node()
	var field: InvestQuantityField = panel.quantity_field
	_caption_row(res, panel.confirm_button, "Buy 1 Share", InvestText.INK, "the confirm button")
	TestFixtures.check(res, "the confirm button carries no outline override",
		not panel.confirm_button.has_theme_color_override("font_outline_color")
			and not panel.confirm_button.has_theme_constant_override("outline_size"), "outline set")
	_caption_row(res, field.minus_button, "-", InvestText.CREAM, "the minus button")
	_caption_row(res, field.plus_button, "+", InvestText.CREAM, "the plus button")
	_caption_row(res, field.max_button, "Max", InvestText.CREAM, "the Max button")
	page.set_side(InvestTradePanel.SIDE_SELL)
	page.set_quantity(3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the confirm caption follows the side and the quantity",
		panel.confirm_button.caption_text() == "Sell 3 Shares"
			and panel.confirm_button.caption_text() == panel.confirm_label(),
		panel.confirm_button.caption_text())
	page.press_confirm()
	var box: InvestTradeConfirm = page.confirm_node()
	TestFixtures.check(res, "the confirmation opens for its caption check", box != null,
		"%s" % box)
	_caption_row(res, box.cancel_button, "Cancel", InvestText.CREAM, "the dialog Cancel")
	_caption_row(res, box.ok_button, "Confirm", InvestText.INK, "the dialog Confirm")
	page.press_confirm_cancel()
	_range_captions(res, page)
	await _drop(host, page)


#One painted button: no built-in text, the caption in a visible child Label of the scene colour.
static func _caption_row(res: Dictionary, button: InvestBevelButton, caption: String,
		wanted: Color, tag: String) -> void:
	var cap: Label = button.caption_node()
	TestFixtures.check(res, "%s draws no built-in text" % tag, button.text == "",
		"'%s'" % button.text)
	TestFixtures.check(res, "%s captions its child Label" % tag,
		cap != null and cap.text == caption and button.caption_text() == caption,
		"'%s'" % ("" if cap == null else cap.text))
	TestFixtures.check(res, "%s hangs the caption under itself" % tag,
		cap != null and cap.get_parent() == button and cap.visible
			and cap.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s" % cap)
	var tint: Color = Color.BLACK if cap == null else cap.get_theme_color("font_color")
	TestFixtures.check(res, "%s paints the caption in the scene colour" % tag,
		cap != null and _same_color(tint, wanted)
			and tint == button.get_theme_color("font_color"), tint.to_html(false))


#The range row: the key in the child Label, ink while active and cream while idle.
static func _range_captions(res: Dictionary, page: InvestTab) -> void:
	var text_ok: bool = true
	var caption_ok: bool = true
	var colour_ok: bool = true
	for key: String in StockMarket.RANGES:
		var button: InvestRangeButton = page.range_button(key)
		var cap: Label = button.caption_node()
		if button.text != "":
			text_ok = false
		if cap == null or cap.text != key or button.caption_text() != key:
			caption_ok = false
			continue
		if cap.get_parent() != button or not cap.visible:
			caption_ok = false
		var wanted: Color = InvestText.INK if button.is_active() else InvestText.CREAM
		if cap.get_theme_color("font_color") != wanted:
			colour_ok = false
	TestFixtures.check(res, "no range button draws built-in text", text_ok, "empty")
	TestFixtures.check(res, "every range button captions its child Label", caption_ok,
		"%d ranges" % StockMarket.RANGES.size())
	TestFixtures.check(res, "every range caption takes its state colour", colour_ok,
		"ink and cream")
	var idle: InvestRangeButton = page.range_button("5Y")
	idle.set_active(true)
	TestFixtures.check(res, "an activated range repaints its caption ink",
		idle.caption_node().get_theme_color("font_color") == InvestText.INK, "ink")
	idle.set_active(false)
	TestFixtures.check(res, "a deactivated range repaints its caption cream",
		idle.caption_node().get_theme_color("font_color") == InvestText.CREAM, "cream")


#The quantity field

static func _case_quantity(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	page.select_company(FREE_K)
	page.set_side(InvestTradePanel.SIDE_BUY)
	await host.get_tree().process_frame
	var field: InvestQuantityField = page.panel_node().quantity_field
	var top: int = page.max_quantity()
	var half: int = maxi(2, int(floor(float(top) / 2.0)))
	TestFixtures.check(res, "the field ceiling is the trade ceiling", field.ceiling() == top,
		"%d vs %d" % [field.ceiling(), top])
	TestFixtures.check(res, "the field opens at one share", field.value == 1,
		"%d" % field.value)
	TestFixtures.check(res, "the field prints its value", field.field.text == "1",
		field.field.text)
	field.press_minus()
	TestFixtures.check(res, "minus at one share holds", field.value == 1, "%d" % field.value)
	TestFixtures.check(res, "minus at one share tints the field", field.is_rejecting(),
		"rejecting")
	field.end_reject()
	TestFixtures.check(res, "the reject ends", not field.is_rejecting(), "settled")
	field.press_plus()
	TestFixtures.check(res, "plus adds one share", field.value == 2, "%d" % field.value)
	field.press_max()
	TestFixtures.check(res, "Max takes the ceiling", field.value == top, "%d" % field.value)
	TestFixtures.check(res, "Max does not reject", not field.is_rejecting(), "settled")
	field.press_plus()
	TestFixtures.check(res, "plus at the ceiling holds", field.value == top, "%d" % field.value)
	TestFixtures.check(res, "plus at the ceiling tints the field", field.is_rejecting(),
		"rejecting")
	field.end_reject()
	field.type_text(str(half))
	TestFixtures.check(res, "a typed number is taken", field.value == half, "%d" % field.value)
	field.type_text("%dx" % half)
	TestFixtures.check(res, "typed letters are dropped", field.value == half, "%d" % field.value)
	field.type_text("abc")
	TestFixtures.check(res, "a field of letters keeps the value", field.value == half,
		"%d" % field.value)
	TestFixtures.check(res, "a field of letters does not reject", not field.is_rejecting(),
		"settled")
	field.type_text("0")
	TestFixtures.check(res, "a typed zero clamps to one", field.value == 1, "%d" % field.value)
	TestFixtures.check(res, "a typed zero tints the field", field.is_rejecting(), "rejecting")
	field.end_reject()
	field.type_text(str(top + 5))
	TestFixtures.check(res, "a typed number over the ceiling clamps", field.value == top,
		"%d" % field.value)
	TestFixtures.check(res, "a typed number over the ceiling tints the field",
		field.is_rejecting(), "rejecting")
	field.end_reject()
	_hold_steps(res, field)
	_shake_base_holds(res, field)
	await _drop(host, page)


#A held minus or plus button: nothing before the delay, one step as it is crossed, then a step
#every tick, and a stop as soon as a bound rejects.
static func _hold_steps(res: Dictionary, field: InvestQuantityField) -> void:
	field.set_value_silent(1)
	field.hold_start(1)
	field.step_hold(0.2)
	TestFixtures.check(res, "a hold under the delay adds nothing", field.value == 1,
		"%d" % field.value)
	field.step_hold(0.2)
	TestFixtures.check(res, "the hold steps once as it crosses the delay", field.value == 2,
		"%d" % field.value)
	field.step_hold(0.08)
	TestFixtures.check(res, "the hold steps again on the next tick", field.value == 3,
		"%d" % field.value)
	field.step_hold(0.04)
	TestFixtures.check(res, "a part tick adds nothing", field.value == 3, "%d" % field.value)
	field.hold_stop()
	field.step_hold(1.0)
	TestFixtures.check(res, "a stopped hold adds nothing", field.value == 3, "%d" % field.value)
	field.set_value_silent(1)
	field.hold_start(-1)
	field.step_hold(0.4)
	TestFixtures.check(res, "a hold into a bound holds the value", field.value == 1,
		"%d" % field.value)
	TestFixtures.check(res, "a hold into a bound tints the field", field.is_rejecting(),
		"rejecting")
	field.step_hold(1.0)
	TestFixtures.check(res, "the bound stops the hold", field.value == 1, "%d" % field.value)
	field.end_reject()
	var hits: Array[int] = [0]
	var watcher: Callable = func(_n: int) -> void:
		hits[0] += 1
	field.value_changed.connect(watcher)
	field.press_plus()
	TestFixtures.check(res, "a change reports itself once", hits[0] == 1, "%d" % hits[0])
	field.set_value_silent(field.ceiling())
	field.press_plus()
	TestFixtures.check(res, "a rejected press reports nothing", hits[0] == 1, "%d" % hits[0])
	field.value_changed.disconnect(watcher)
	field.end_reject()
	field.set_value_silent(1)


#A reject that meets a live shake keeps the rest x: the base is never read from a displaced field.
static func _shake_base_holds(res: Dictionary, field: InvestQuantityField) -> void:
	field.set_value_silent(field.ceiling())
	var base: float = field.field.position.x
	field.press_plus()
	TestFixtures.check(res, "a bound press starts the shake", field.is_rejecting(), "rejecting")
	field.step_reject(InvestQuantityField.REJECT_TIME / 8.0)
	var shaken: float = field.field.position.x
	TestFixtures.check(res, "the shake displaces the field", absf(shaken - base) > 0.5,
		"%.2f" % (shaken - base))
	field.press_plus()
	field.end_reject()
	TestFixtures.check(res, "a second reject keeps the shake base",
		absf(field.field.position.x - base) < 0.01, "%.2f" % (field.field.position.x - base))
	field.set_value_silent(1)


#The three rows and the two cells of the trade panel

static func _case_rows(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	page.select_company(FREE_K)
	page.set_side(InvestTradePanel.SIDE_BUY)
	page.set_quantity(3)
	await host.get_tree().process_frame
	var panel: InvestTradePanel = page.panel_node()
	var px: float = StockMarket.price(FREE_K)
	var rows: PackedStringArray = panel.row_texts()
	TestFixtures.check(res, "the price row reads the share price",
		rows[0] == InvestText.price_text(px), rows[0])
	TestFixtures.check(res, "the fee row reads the platform fee",
		rows[1] == "-%d" % StockMarket.TRADE_FEE, rows[1])
	TestFixtures.check(res, "the total row reads the buy cost",
		rows[2] == "-%s" % InvestText.notes_text(StockMarket.buy_cost(FREE_K, 3)), rows[2])
	TestFixtures.check(res, "the total row is named for a buy",
		_row_name(panel.total_row) == "Total Cost", _row_name(panel.total_row))
	var cells: PackedStringArray = panel.cell_texts()
	var held: int = panel.shares_held()
	TestFixtures.check(res, "the share cell counts the shares after the buy",
		cells[0] == InvestText.notes_text(held + 3), cells[0])
	TestFixtures.check(res, "the value cell prices the position after the buy",
		cells[1] == InvestText.value_text(float(held + 3) * px), cells[1])
	TestFixtures.check(res, "the cells are named",
		_cell_name(panel.share_cell) == "New Share Count"
			and _cell_name(panel.value_cell) == "New Position Value",
		_cell_name(panel.share_cell))
	TestFixtures.check(res, "a valid trade keeps the confirm button lit",
		not panel.confirm_button.disabled
			and is_equal_approx(panel.confirm_button.modulate.a, 1.0),
		"%.2f" % panel.confirm_button.modulate.a)
	page.select_company(HELD_K)
	page.set_side(InvestTradePanel.SIDE_SELL)
	page.set_quantity(4)
	await host.get_tree().process_frame
	var sell_rows: PackedStringArray = panel.row_texts()
	var sell_px: float = StockMarket.price(HELD_K)
	TestFixtures.check(res, "the total row reads what a sale pays",
		sell_rows[2] == "+%s" % InvestText.notes_text(StockMarket.sell_value(HELD_K, 4)),
		sell_rows[2])
	TestFixtures.check(res, "the total row is named for a sale",
		_row_name(panel.total_row) == "Total Received", _row_name(panel.total_row))
	var sell_cells: PackedStringArray = panel.cell_texts()
	TestFixtures.check(res, "the share cell counts the shares after the sale",
		sell_cells[0] == InvestText.notes_text(panel.shares_held() - 4), sell_cells[0])
	TestFixtures.check(res, "the value cell prices the position after the sale",
		sell_cells[1] == InvestText.value_text(float(panel.shares_held() - 4) * sell_px),
		sell_cells[1])
	TestFixtures.check(res, "a sale labels its shares",
		panel.confirm_label() == "Sell 4 Shares", panel.confirm_label())
	panel.quantity_field.max_value = 2000
	panel.quantity_field.set_value_silent(1200)
	TestFixtures.check(res, "a large trade groups its shares",
		panel.confirm_label() == "Sell 1,200 Shares", panel.confirm_label())
	page.set_quantity(1)
	page.select_company(OTHER_FREE_K)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an invalid trade dims the confirm button",
		panel.confirm_button.disabled and is_equal_approx(panel.confirm_button.modulate.a,
			InvestTradePanel.INVALID_ALPHA), "%.2f" % panel.confirm_button.modulate.a)
	var presses: Array[int] = [0]
	var watcher: Callable = func() -> void:
		presses[0] += 1
	panel.confirm_pressed.connect(watcher)
	panel.press_confirm()
	TestFixtures.check(res, "an invalid trade reports no press", presses[0] == 0,
		"%d" % presses[0])
	page.set_side(InvestTradePanel.SIDE_BUY)
	await host.get_tree().process_frame
	panel.press_confirm()
	TestFixtures.check(res, "a valid trade reports its press", presses[0] == 1,
		"%d" % presses[0])
	panel.confirm_pressed.disconnect(watcher)
	await _drop(host, page)


static func _row_name(row: PanelContainer) -> String:
	return (row.get_node("Row/NameLabel") as Label).text


static func _cell_name(cell: PanelContainer) -> String:
	return (cell.get_node("Col/NameLabel") as Label).text


#The trade confirmation, both sides

static func _case_confirm(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	page.select_company(FREE_K)
	page.set_side(InvestTradePanel.SIDE_BUY)
	page.set_quantity(2)
	await host.get_tree().process_frame
	var bank_before: int = GameState.bank_notes
	var cost: int = StockMarket.buy_cost(FREE_K, 2)
	page.press_confirm()
	var box: InvestTradeConfirm = page.confirm_node()
	TestFixtures.check(res, "a valid press opens the confirmation",
		box != null and page.confirm_open(), "%s" % box)
	TestFixtures.check(res, "the confirmation sits in the modal host",
		box.get_parent() == page.modal_host(), "%s" % box.get_parent())
	TestFixtures.check(res, "a buy is kickered Buy Shares", box.kicker_text() == "Buy Shares",
		box.kicker_text())
	TestFixtures.check(res, "the confirmation names the company",
		box.title_text() == String(StockMarket.company(FREE_K).get("name", "")),
		box.title_text())
	TestFixtures.check(res, "a buy is tinted green", box.title_color() == InvestText.GREEN,
		"%s" % box.title_color())
	TestFixtures.check(res, "the confirmation carries the trade",
		box.quantity() == 2 and box.side() == InvestTradePanel.SIDE_BUY, "%d" % box.quantity())
	TestFixtures.check(res, "the confirmation totals the buy", box.total_notes() == cost,
		"%d" % box.total_notes())
	var rows: PackedStringArray = box.row_texts()
	TestFixtures.check(res, "the confirmation rows read the trade",
		rows.size() == 4 and rows[0] == "2"
			and rows[1] == InvestText.price_text(StockMarket.price(FREE_K))
			and rows[2] == "-%d" % StockMarket.TRADE_FEE
			and rows[3] == "-%s notes" % InvestText.notes_text(cost), "%s" % rows)
	page.press_confirm_cancel()
	TestFixtures.check(res, "Cancel closes the confirmation", not page.confirm_open(), "closed")
	TestFixtures.check(res, "Cancel spends nothing", GameState.bank_notes == bank_before,
		"%d" % GameState.bank_notes)
	TestFixtures.check(res, "Cancel buys nothing", StockMarket.holding(FREE_K).is_empty(),
		"%s" % StockMarket.holding(FREE_K))
	page.press_confirm()
	page.press_confirm_ok()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Confirm closes the confirmation", not page.confirm_open(), "closed")
	TestFixtures.check(res, "Confirm reports the trade taken", box.last_result(), "traded")
	TestFixtures.check(res, "Confirm pays the cost once",
		GameState.bank_notes == bank_before - cost, "%d" % GameState.bank_notes)
	TestFixtures.check(res, "Confirm adds the shares once",
		int(StockMarket.holding(FREE_K).get("shares", 0)) == 2,
		"%s" % StockMarket.holding(FREE_K))
	TestFixtures.check(res, "a taken trade sets the quantity back to 1", page.quantity() == 1,
		"%d" % page.quantity())
	await _confirm_sell(res, host, page, box)
	await _drop(host, page)


#The sell side of the confirmation, and a buy the bank cannot cover any more.
static func _confirm_sell(res: Dictionary, host: Node, page: InvestTab,
		box: InvestTradeConfirm) -> void:
	page.select_company(HELD_K)
	page.set_side(InvestTradePanel.SIDE_SELL)
	page.set_quantity(5)
	await host.get_tree().process_frame
	var pay: int = StockMarket.sell_value(HELD_K, 5)
	var bank_before: int = GameState.bank_notes
	page.press_confirm()
	TestFixtures.check(res, "a sale is kickered Sell Shares", box.kicker_text() == "Sell Shares",
		box.kicker_text())
	TestFixtures.check(res, "a sale is tinted red", box.title_color() == InvestText.RED,
		"%s" % box.title_color())
	TestFixtures.check(res, "a sale reads what it pays",
		box.row_texts()[3] == "+%s notes" % InvestText.notes_text(pay), "%s" % box.row_texts())
	page.press_confirm_ok()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a sale takes the shares once",
		int(StockMarket.holding(HELD_K).get("shares", 0)) == 20,
		"%s" % StockMarket.holding(HELD_K))
	TestFixtures.check(res, "a sale credits the bank once",
		GameState.bank_notes == bank_before + pay, "%d" % GameState.bank_notes)
	page.select_company(OTHER_FREE_K)
	page.set_side(InvestTradePanel.SIDE_BUY)
	page.set_quantity(2)
	await host.get_tree().process_frame
	var saved_bank: int = GameState.bank_notes
	page.press_confirm()
	GameState.bank_notes = 0
	page.press_confirm_ok()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a buy the bank cannot cover closes", not page.confirm_open(),
		"closed")
	TestFixtures.check(res, "a buy the bank cannot cover reports no trade", not box.last_result(),
		"no trade")
	TestFixtures.check(res, "a buy the bank cannot cover adds no shares",
		StockMarket.holding(OTHER_FREE_K).is_empty(), "%s" % StockMarket.holding(OTHER_FREE_K))
	GameState.bank_notes = saved_bank


#Selling out drops the position widget

static func _case_sell_all(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	page.select_company(HELD_K)
	page.set_side(InvestTradePanel.SIDE_SELL)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the held company opens with its position widget",
		page.position_widget() != null, "%s" % page.position_widget())
	page.set_quantity(page.max_quantity())
	page.press_confirm()
	page.press_confirm_ok()
	await host.get_tree().process_frame
	TestFixtures.check(res, "selling out clears the holding",
		StockMarket.holding(HELD_K).is_empty(), "%s" % StockMarket.holding(HELD_K))
	TestFixtures.check(res, "selling out drops the position widget",
		page.position_widget() == null, "%s" % page.position_widget())
	TestFixtures.check(res, "selling out drops the cost line",
		not page.chart_node().has_cost_line(), "no line")
	TestFixtures.check(res, "selling out marks the row Not owned",
		page.list_node().item(HELD_K).owned_text() == "Not owned",
		page.list_node().item(HELD_K).owned_text())
	await _drop(host, page)


#The hover card of a roster row

static func _case_tooltip(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var list: InvestCompanyList = page.list_node()
	var tip: InvestCompanyTooltip = page.tooltip_node()
	tip.hide_delay = 0.02
	list.company_hovered.emit(3, list.item(3))
	TestFixtures.check(res, "a hovered row opens the card", tip.is_shown(), "shown")
	TestFixtures.check(res, "the card names the type and the lender",
		tip.type_text() == "Issuer Type 4 - Lender 4", tip.type_text())
	TestFixtures.check(res, "the card names the company",
		tip.name_text() == String(StockMarket.company(3).get("name", "")), tip.name_text())
	var stats: PackedStringArray = tip.stat_texts()
	var row: Dictionary = StockMarket.company_stats(3)
	TestFixtures.check(res, "the card carries three stats", stats.size() == 3, "%s" % stats)
	TestFixtures.check(res, "the stats read taken, succeeded and failed",
		stats[0] == str(int(row["taken"])) and stats[1] == str(int(row["succeeded"]))
			and stats[2] == str(int(row["failed"])), "%s" % stats)
	TestFixtures.check(res, "the card shows a face", tip.face() != null, "%s" % tip.face())
	TestFixtures.check(res, "the face takes the lender relationship",
		tip.face() != null and tip.face().opinion == tip.relationship(),
		"%d" % tip.relationship())
	TestFixtures.check(res, "the lender relationship comes from the manager",
		tip.relationship() == 3, "%d" % tip.relationship())
	TestFixtures.check(res, "an empty board shows the empty box",
		tip.empty_shown() and not tip.contract_shown(), "empty")
	TestFixtures.check(res, "an empty board carries no contract", tip.entry_id() == -1,
		"%d" % tip.entry_id())
	var hovered: Control = list.item(3)
	var row_right: float = hovered.global_position.x - page.global_position.x + hovered.size.x
	TestFixtures.check(res, "the card sits right of its row",
		tip.position.x >= row_right + InvestCompanyTooltip.ITEM_GAP - 0.5,
		"%.1f" % tip.position.x)
	var clamped: bool = true
	for k: int in StockMarket.company_count():
		tip.show_for(k, list.item(k))
		if tip.position.y < 0.0 or tip.position.y + InvestCompanyTooltip.CARD_RESERVE\
				> PAGE_SIZE.y:
			clamped = false
	TestFixtures.check(res, "every card stays inside the page", clamped,
		"%.1f" % tip.position.y)
	tip.show_for(-1, list.item(0))
	TestFixtures.check(res, "an unknown company has no relationship", tip.relationship() == 0,
		"%d" % tip.relationship())
	await _tooltip_contract(res, host, page, list, tip)
	await _drop(host, page)


#The contract row of the card, its press and the two ways the card hides.
static func _tooltip_contract(res: Dictionary, host: Node, page: InvestTab,
		list: InvestCompanyList, tip: InvestCompanyTooltip) -> void:
	var saved: Array[ContractView] = GameState.contracts
	GameState.contracts = [_board_contract()]
	tip.show_for(ENTRY_COMPANY, list.item(ENTRY_COMPANY))
	TestFixtures.check(res, "a company with a contract shows its row",
		tip.contract_shown() and not tip.empty_shown(), "row shown")
	TestFixtures.check(res, "the row names the contract", tip.contract_text() == "Board Contract",
		tip.contract_text())
	TestFixtures.check(res, "the row prints the status", tip.status_text() == "Active",
		tip.status_text())
	var accepted: Dictionary = StockMarket.last_accepted(ENTRY_COMPANY)
	TestFixtures.check(res, "the row tints the status",
		tip.status_color() == Color(String(accepted.get("color", "#f3ead7"))),
		"%s" % tip.status_color())
	TestFixtures.check(res, "the row carries the entry id", tip.entry_id() == ENTRY_ID,
		"%d" % tip.entry_id())
	var opened: Array[int] = [-1]
	var watcher: Callable = func(id: int) -> void:
		opened[0] = id
	tip.open_contract.connect(watcher)
	tip.press_contract()
	TestFixtures.check(res, "the row reports the contract to open", opened[0] == ENTRY_ID,
		"%d" % opened[0])
	tip.open_contract.disconnect(watcher)
	tip.show_for(ENTRY_COMPANY, list.item(ENTRY_COMPANY))
	list.company_unhovered.emit(ENTRY_COMPANY)
	TestFixtures.check(res, "leaving the row starts the hide timer", tip.hide_pending(),
		"pending")
	tip.cancel_hide()
	TestFixtures.check(res, "coming back stops the hide timer",
		not tip.hide_pending() and tip.is_shown(), "held open")
	tip.begin_hide()
	await host.get_tree().create_timer(0.05).timeout
	TestFixtures.check(res, "the timer hides the card", not tip.is_shown(), "hidden")
	tip.show_for(2, list.item(2))
	page.select_company(2)
	TestFixtures.check(res, "picking a company hides the card", not tip.is_shown(), "hidden")
	GameState.contracts = saved


static func _board_contract() -> ContractView:
	var view := ContractView.new()
	view.entry_id = ENTRY_ID
	view.name = "Board Contract"
	view.status = GuiTypes.ContractStatus.ACTIVE
	return view


#View Contract opens a contract viewer in the modal host

static func _case_contract(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var saved: Array[ContractView] = GameState.contracts
	GameState.contracts = [_board_contract()]
	var tip: InvestCompanyTooltip = page.tooltip_node()
	tip.show_for(ENTRY_COMPANY, page.list_node().item(ENTRY_COMPANY))
	var before: int = _popup_count(page.modal_host())
	tip.press_contract()
	await host.get_tree().process_frame
	TestFixtures.check(res, "View Contract opens one viewer",
		_popup_count(page.modal_host()) == before + 1,
		"%d popups" % _popup_count(page.modal_host()))
	TestFixtures.check(res, "View Contract hides the card", not tip.is_shown(), "hidden")
	GameState.contracts = saved
	await _drop(host, page)


static func _popup_count(at: Node) -> int:
	var n: int = 0
	for child: Node in at.get_children():
		if child is ViewerPopup:
			n += 1
	return n


#The modal host, with and without a ModalLayer ancestor

static func _case_modal_host(res: Dictionary, host: Node) -> void:
	var shell := Control.new()
	shell.name = "Shell"
	shell.size = PAGE_SIZE
	host.add_child(shell)
	var layer := Control.new()
	layer.name = InvestTab.MODAL_NAME
	shell.add_child(layer)
	var page: InvestTab = (load(PAGE_SCENE) as PackedScene).instantiate() as InvestTab
	shell.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.size = PAGE_SIZE
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a layer outside the group is not the host",
		page.modal_host() == page, "%s" % page.modal_host())
	layer.add_to_group(InvestTab.MODAL_GROUP)
	TestFixtures.check(res, "a grouped layer is the host", page.modal_host() == layer,
		"%s" % page.modal_host())
	layer.remove_from_group(InvestTab.MODAL_GROUP)
	shell.add_to_group(InvestTab.MODAL_GROUP)
	TestFixtures.check(res, "a grouped ancestor gives its layer", page.modal_host() == layer,
		"%s" % page.modal_host())
	page.select_company(FREE_K)
	page.set_side(InvestTradePanel.SIDE_BUY)
	page.set_quantity(1)
	await host.get_tree().process_frame
	page.press_confirm()
	TestFixtures.check(res, "the confirmation opens inside the layer",
		page.confirm_node() != null and page.confirm_node().get_parent() == layer,
		"%s" % page.confirm_node())
	page.press_confirm_cancel()
	shell.queue_free()
	await host.get_tree().process_frame


#A refresh while the page is hidden is held until it shows again

static func _case_hidden(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	TestFixtures.check(res, "a shown page is clean", not page.is_dirty(), "clean")
	page.visible = false
	await host.get_tree().process_frame
	page.refresh()
	TestFixtures.check(res, "a refresh while hidden is held", page.is_dirty(), "dirty")
	page.visible = true
	await host.get_tree().process_frame
	page.page_shown()
	TestFixtures.check(res, "page_shown clears the held refresh", not page.is_dirty(), "clean")
	page.visible = false
	await host.get_tree().process_frame
	StockMarket.changed.emit()
	TestFixtures.check(res, "a market change while hidden is held", page.is_dirty(), "dirty")
	page.visible = true
	await host.get_tree().process_frame
	page.refresh()
	TestFixtures.check(res, "a refresh while shown runs at once", not page.is_dirty(), "clean")
	await _drop(host, page)


#A sale whose proceeds after the fee are 0 is not a valid trade

static func _case_fee_floor(res: Dictionary, host: Node) -> void:
	_fresh()
	StockMarket.buy(OTHER_FREE_K, 1)
	_force_change(OTHER_FREE_K, 3.0, 3.0)
	var page: InvestTab = await _mount(host)
	page.select_company(OTHER_FREE_K)
	page.set_side(InvestTradePanel.SIDE_SELL)
	await host.get_tree().process_frame
	var panel: InvestTradePanel = page.panel_node()
	TestFixtures.check(res, "the one share under the fee is the sell ceiling",
		page.max_quantity() == 1, "%d" % page.max_quantity())
	TestFixtures.check(res, "a sale under the fee pays nothing",
		StockMarket.sell_value(OTHER_FREE_K, 1) == 0,
		"%d" % StockMarket.sell_value(OTHER_FREE_K, 1))
	TestFixtures.check(res, "a sale under the fee is not valid", not page.trade_valid(),
		"invalid")
	TestFixtures.check(res, "a sale under the fee still labels its share",
		panel.confirm_label() == "Sell 1 Share", panel.confirm_label())
	TestFixtures.check(res, "a sale under the fee dims the confirm button",
		panel.confirm_button.disabled and is_equal_approx(panel.confirm_button.modulate.a,
			InvestTradePanel.INVALID_ALPHA), "%.2f" % panel.confirm_button.modulate.a)
	var before: int = GameState.bank_notes
	page.press_confirm()
	TestFixtures.check(res, "a sale under the fee opens no confirmation",
		not page.confirm_open(), "closed")
	TestFixtures.check(res, "a sale under the fee moves no notes",
		GameState.bank_notes == before, "%d" % GameState.bank_notes)
	await _drop(host, page)


#The runtime glyphs, the range colours and the side switch

static func _case_glyphs(res: Dictionary, host: Node) -> void:
	var page: InvestTab = await _mount(host)
	var big: ImageTexture = InvestGlyphs.hatch(InvestGlyphs.LOGO_LARGE)
	TestFixtures.check(res, "the hatch takes the size it is asked for",
		big.get_size() == Vector2(40.0, 48.0), "%s" % big.get_size())
	TestFixtures.check(res, "the hatch is cached by size",
		InvestGlyphs.hatch(InvestGlyphs.LOGO_LARGE) == big, "cached")
	var green_arrow: ImageTexture = InvestGlyphs.arrow(InvestText.GREEN,
		InvestTradePanel.ARROW_SCALE)
	TestFixtures.check(res, "the arrow is seven cells wide",
		green_arrow.get_size() == Vector2(21.0, 21.0), "%s" % green_arrow.get_size())
	TestFixtures.check(res, "the roster logo carries the hatch",
		page.list_node().item(0).hatch.texture == big, "hatch")
	TestFixtures.check(res, "the header logo carries the small hatch",
		page.logo.texture == InvestGlyphs.hatch(InvestGlyphs.LOGO_SMALL), "hatch")
	var panel: InvestTradePanel = page.panel_node()
	TestFixtures.check(res, "the Buy arrow is not mirrored", not panel.arrow.flip_h, "plain")
	TestFixtures.check(res, "the Buy arrow is green", panel.arrow.texture == green_arrow,
		"green")
	TestFixtures.check(res, "Buy lights its own label",
		panel.buy_button.get_theme_color("font_color") == InvestText.GREEN,
		panel.buy_button.get_theme_color("font_color").to_html(false))
	page.set_side(InvestTradePanel.SIDE_SELL)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Sell arrow is mirrored", panel.arrow.flip_h, "flipped")
	TestFixtures.check(res, "the Sell arrow is red",
		panel.arrow.texture == InvestGlyphs.arrow(InvestText.RED, InvestTradePanel.ARROW_SCALE),
		"red")
	TestFixtures.check(res, "Sell dims the Buy label",
		panel.buy_button.get_theme_color("font_color") == InvestText.SWITCH_OFF,
		panel.buy_button.get_theme_color("font_color").to_html(false))
	TestFixtures.check(res, "the active range is orange",
		page.range_button("1Y").body_color() == InvestText.ORANGE,
		page.range_button("1Y").body_color().to_html(false))
	TestFixtures.check(res, "an idle range is blue",
		page.range_button("5Y").body_color() == InvestText.BLUE2,
		page.range_button("5Y").body_color().to_html(false))
	TestFixtures.check(res, "the active range inks its text",
		page.range_button("1Y").text_color() == InvestText.INK, "ink")
	TestFixtures.check(res, "an idle range creams its text",
		page.range_button("5Y").text_color() == InvestText.CREAM, "cream")
	await _drop(host, page)


static func _scrolls(root: Node, out: Array[Node]) -> void:
	for child: Node in root.get_children():
		if child is ScrollContainer:
			out.append(child)
		_scrolls(child, out)
