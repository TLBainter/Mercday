class_name MailEffects

#The Mail.tsv fx grammar: money:N, pay, vac:approve, vac:deny, vac:shift:N, opinion:MERC:N, rel:SENDER:N.
#There is no delete token. MailCatalog validates every Fx cell here at load.

const VAC_WORDS: Array[String] = ["approve", "deny"]
const SIZES: Dictionary = {"money": 2, "opinion": 3, "rel": 3}
const GIFT_LABEL: String = "Gifts"
const CHARGE_LABEL: String = "Mail"
const BILL_LABEL: String = "Mail bill"


#Applies an option's tokens; false, with nothing applied, when a vac token meets a request no longer PENDING.
#A vac token on a mail with no request applies nothing by itself.
static func apply(mail: MailInstance, tokens: PackedStringArray) -> bool:
	if mail == null:
		return false
	var req: VacationRequest = mail.request
	for token: String in tokens:
		if token.begins_with("vac:") and req != null and req.state != VacationRequest.State.PENDING:
			return false
	for token: String in tokens:
		_apply_one(mail, token.split(":"))
	return true


#-1 for a charge, a pay or a deny, +1 for a credit, an approve or a shift, else 0; rel is hidden and never counts.
static func tone(tokens: PackedStringArray) -> int:
	var out: int = 0
	for token: String in tokens:
		var parts: PackedStringArray = token.split(":")
		if (parts[0] == "money" and int(parts[1]) < 0) or token == Bill.PAY_TOKEN or token == "vac:deny":
			return -1
		if (parts[0] == "money" and int(parts[1]) > 0) or token == "vac:approve" or token.begins_with("vac:shift:"):
			out = 1
	return out


#The signed notes the option moves: money:N as N, pay as minus the bill amount; rel and the rest move none.
static func cost(mail: MailInstance, tokens: PackedStringArray) -> int:
	var total: int = 0
	for token: String in tokens:
		var parts: PackedStringArray = token.split(":")
		if parts[0] == "money" and parts.size() == 2:
			total += int(parts[1])
		elif token == Bill.PAY_TOKEN and mail != null and mail.bill != null:
			total -= mail.bill.amount
	return total


static func _apply_one(mail: MailInstance, parts: PackedStringArray) -> void:
	var book: VacationBook = BenefitsManager.book
	match parts[0]:
		"money":
			var notes: int = int(parts[1])
			if notes > 0:
				GameState.refund(notes, GameState.REASON_MAIL, GIFT_LABEL)
			else:
				GameState.charge(-notes, GameState.REASON_MAIL, CHARGE_LABEL)
		"pay":
			if mail.bill != null and mail.bill.status == Bill.Status.UNPAID:
				mail.bill.status = Bill.Status.PAID
				GameState.charge(mail.bill.amount, GameState.REASON_MAIL, BILL_LABEL)
		"vac":
			if parts[1] == "approve":
				book.approve(mail.request)
			elif parts[1] == "deny":
				book.deny(mail.request)
			else:
				book.shift(mail.request, int(parts[2]))
		"opinion":
			var merc: MercenaryData = GameState.merc_by_uid(_opinion_uid(mail, parts[1]))
			SalarySystem.adjust_opinion(merc, int(parts[2]))
			if merc != null:
				GameState.refresh_views()
		"rel":
			IssuerOpinion.adjust(MailSenders.seat_of(parts[1]), int(parts[2]))


#opinion:K:N names mercK: the mail's own merc when it is the sender, else mercK on the roster now; -1 for none.
static func _opinion_uid(mail: MailInstance, index: String) -> int:
	var id: String = MailSenders.MERC_PREFIX + index
	if mail.sender_id == id and mail.merc_uid >= 0:
		return mail.merc_uid
	return MailSenders.merc_uid_for(id)


#Why a token is invalid; "" when it is fine. pay needs a row with a Bill Id and an Amount (bill_ready).
static func problem(token: String, bill_ready: bool) -> String:
	var parts: PackedStringArray = token.split(":")
	var tail: String = parts[parts.size() - 1]
	match parts[0]:
		"money", "opinion", "rel":
			if parts.size() != int(SIZES[parts[0]]) or not tail.is_valid_int():
				return "malformed"
			if parts[0] == "opinion" and not parts[1].is_valid_int():
				return "merc index is not a number"
			if parts[0] == "rel" and MailSenders.seat_of(parts[1]) < 0:
				return "no issuer seat"
			return ""
		"vac":
			var word: bool = parts.size() == 2 and VAC_WORDS.has(tail)
			var shift: bool = parts.size() == 3 and parts[1] == "shift" and tail.is_valid_int()
			return "" if word or shift else "unknown vac action"
		"pay":
			return "" if parts.size() == 1 and bill_ready else "pay needs a Bill Id and an Amount"
		"delete":
			return "no delete token; mail leaves a folder only through Archive"
	return "unknown fx token"
