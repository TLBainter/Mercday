class_name Bill extends RefCounted

#One bill thread of the mail: every mail with its Bill Id points at this row, and paying from any of
#them pays it. AUTO bills are ledger-backed notices the mail never charges; only mail-native bills are
#UNPAID and paid.

enum Status {UNPAID, PAID, AUTO}

const PAY_TOKEN: String = "pay"

var bill_id: StringName = &""
#The newest delivered mail of the thread.
var mail_id: StringName = &""
var amount: int = 0
#The day index the bill is due on; -1 when the thread names no due day.
var due_day: int = -1
var status: int = Status.AUTO


#No due day reads PAID, a pay option UNPAID, anything else AUTO.
static func status_for(due: int, has_pay: bool) -> int:
	if due < 0:
		return Status.PAID
	return Status.UNPAID if has_pay else Status.AUTO


#The bill of a thread's first row, delivered on day. A blank Amount is the ledger-backed Mercday
#notice: the subscription cost, due on the next bill day.
static func from_row(row: Dictionary, day: int, has_pay: bool) -> Bill:
	var bill := Bill.new()
	bill.bill_id = StringName(String(row["bill_id"]))
	bill.amount = int(row["amount"])
	bill.due_day = day + int(row["due"]) if int(row["due"]) >= 0 else -1
	if bill.amount < 0:
		bill.amount = SubscriptionManager.monthly_cost()
		bill.due_day = day + FinanceLedger.next_in(SubscriptionManager.BILL_DAY)
	bill.status = status_for(bill.due_day, has_pay)
	return bill


#The thread's one Bill for a delivered mail, made on its first row; null for a row with no Bill Id. A later row's
#Amount replaces the amount; the due day stays the first one.
static func for_mail(bills: Dictionary, row: Dictionary, mail: MailInstance) -> Bill:
	var key: StringName = StringName(String(row["bill_id"]))
	if key == &"":
		return null
	if not bills.has(key):
		var has_pay: bool = (row["options"] as Array).any(func(o: Dictionary) -> bool:
			return (o["fx"] as PackedStringArray).has(PAY_TOKEN))
		bills[key] = from_row(row, mail.received_day, has_pay)
	var bill: Bill = bills[key] as Bill
	bill.mail_id = mail.id
	bill.amount = int(row["amount"]) if int(row["amount"]) >= 0 else bill.amount
	return bill


func past_due(day: int) -> bool:
	return status == Status.UNPAID and due_day >= 0 and due_day < day
