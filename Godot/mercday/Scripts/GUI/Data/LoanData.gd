class_name LoanData extends RefCounted

#One loan the guild took: what it owes, how much of it is paid and how it ended.
#FinanceManager keeps the active ones in loans and the finished ones in closed_loans.

var id: int = 0
var lender: String = ""
var principal: int = 0
var rate: float = 0.0
var months: int = 0
#Payments made so far; months - paid is what is left.
var paid: int = 0
#Months from the month the loan was taken to the month of the first payment.
var first_due: int = 0
var start_minute: int = 0
#The day of the month every payment lands on, picked when the loan is taken.
var bill_day: int = 15
#"" while the loan runs, then "Paid in Full" or "Paid Off Early".
var closed_as: String = ""
#The notes the loan cost in the end; written when it closes.
var paid_total: int = 0
#The minute the loan closed; 0 while it runs.
var closed_minute: int = 0


func is_closed() -> bool:
	return closed_as != ""


func months_left() -> int:
	return maxi(0, months - paid)


func to_row() -> Dictionary:
	return {"id": id, "lender": lender, "principal": principal, "rate": rate, "months": months,
		"paid": paid, "first_due": first_due, "start_minute": start_minute, "bill_day": bill_day,
		"closed_as": closed_as, "paid_total": paid_total, "closed_minute": closed_minute,
		"months_left": months_left()}
