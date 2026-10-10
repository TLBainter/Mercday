class_name DividendSource extends CalendarSource

#The quarter dividend days of StockMarket. The sub line is the guild's estimated payout while it
#holds shares, else the line every shareholder reads.

const TITLE: String = "Quarterly Dividends"
const MARKET_SCRIPT := preload("res://Scripts/GUI/Autoloads/StockMarket.gd")


func events_between(d0: int, d1: int) -> Array[CalendarEvent]:
	var out: Array[CalendarEvent] = []
	for day: int in range(d0, d1 + 1):
		if MARKET_SCRIPT.is_div_day(day):
			out.append(make_event(day, TITLE, sub_line(), null))
	return out


func sub_line() -> String:
	if StockMarket.holdings().is_empty():
		return "All %d companies pay shareholders" % StockMarket.company_count()
	return "Estimated %s notes" % TransactionData.grouped(StockMarket.dividend_estimate())


func change_signals() -> Array[Signal]:
	return [StockMarket.changed]
