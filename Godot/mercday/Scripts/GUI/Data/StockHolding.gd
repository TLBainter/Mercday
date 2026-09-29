class_name StockHolding extends RefCounted

#One held position. StockMarket owns every field; holding(k) reads it into a Dictionary.

var company_id: int = -1
var shares: int = 0
var avg: float = 0.0
#The price last viewed (or last bought); check() compares the live price against this baseline.
var seen: float = 0.0
#The 5% step band since seen; 0 means no unread stockMove alert is owed.
var band: int = 0
var dividends: int = 0
#The campaign day of the first buy that opened this holding; stamped once and never moved.
var since_day: int = 0
