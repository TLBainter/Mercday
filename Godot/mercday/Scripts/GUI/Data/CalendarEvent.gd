class_name CalendarEvent extends RefCounted

#One calendar row. Its icon, colour and type label are read off source, never copied here; ref is
#the record it was made from (OrderData, LoanData, ActiveRun, ContractResultData, FineData, a bill row).

var source: CalendarSource = null
var day: int = 0
var title: String = ""
var sub: String = ""
var past: bool = false
var ref: Variant = null
