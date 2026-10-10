class_name LoanSource extends CalendarSource

#One event per payment row of every open and closed loan: sent rows read Paid, scheduled ones
#"Payment k of n".


func events_between(d0: int, d1: int) -> Array[CalendarEvent]:
	var out: Array[CalendarEvent] = []
	var books: Array[LoanData] = []
	books.append_array(FinanceManager.loans)
	books.append_array(FinanceManager.closed_loans)
	for loan: LoanData in books:
		var rows: Array[Dictionary] = FinanceManager.payment_rows(loan.id)
		for k: int in rows.size():
			var row: Dictionary = rows[k]
			var day: int = TrynnCalendar.day_index(int(row["minute"]))
			if not within(day, d0, d1):
				continue
			var state: String = "Payment %d of %d" % [k + 1, loan.months] if bool(row["future"]) else "Paid"
			out.append(make_event(day, "Loan Payment - %s" % loan.lender,
				"%s notes - %s" % [TransactionData.grouped(int(row["amount"])), state], loan))
	return out


func change_signals() -> Array[Signal]:
	return [FinanceManager.loans_changed]
