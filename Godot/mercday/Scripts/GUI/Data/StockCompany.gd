class_name StockCompany extends RefCounted

#One company's def, its rolling price history and its event log. StockMarket owns every field.

var id: int = -1
var name: String = ""
var type: String = ""
var lender: String = ""
var p0: float = 0.0
var yld: float = 0.0
var vol: float = 0.0
var drift: float = 0.0
var win: float = 0.0

#The fair (mean reversion target) and the live log price; both carry on across advance_day().
var lf: float = 0.0
var lp: float = 0.0
#One StockRng per company, seeded once in build() and never reseeded again.
var rng: StockRng = null

var history: PackedFloat32Array = PackedFloat32Array()
#Rows {day: int, kind: String ("contract" or "div"), win: bool, label: String, pct: float}.
var events: Array[Dictionary] = []
