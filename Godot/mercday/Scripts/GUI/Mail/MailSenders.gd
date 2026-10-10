class_name MailSenders

#Who a Mail.tsv Sender cell names: an issuer seat (orgN, personN, placeN), a roster merc (mercN) or a
#TSVs/Mail Senders.tsv row, which becomes one ClientData.

const SENDERS_TSV: String = "res://TSVs/Mail Senders.tsv"
const SEAT_KINDS: Dictionary = {"org": "orgs", "person": "people", "place": "places"}
const MERC_PREFIX: String = "merc"
const MAIL_KIND: StringName = &"mail"

static var _senders: Dictionary = {}


#A seat sender's ClientData, a merc sender's live MercenaryData (by the uid fixed at delivery), else the
#Mail Senders row; null when the id names none of them.
static func sender(id: String, merc_uid: int = -1) -> Object:
	var seat: int = seat_of(id)
	if seat >= 0:
		return ClientRegistry.from_game().client(StringName(ContractIssuer.kind_of_seat(seat)),
			ContractIssuer.index_of_seat(seat))
	if is_merc(id):
		return GameState.merc_by_uid(merc_uid)
	return _table().get(id, null) as ClientData


#True when the id names a seat on the layout, a merc or a Mail Senders row.
static func is_known(id: String) -> bool:
	if is_seat_like(id):
		return seat_of(id) >= 0
	return is_merc(id) or _table().has(id)


#The issuer seat of orgN, personN or placeN; -1 for anything else or a seat off the layout.
static func seat_of(id: String) -> int:
	for prefix: String in SEAT_KINDS:
		var tail: String = id.trim_prefix(prefix)
		if id.begins_with(prefix) and tail.is_valid_int():
			return ContractIssuer.seat_id(String(SEAT_KINDS[prefix]), int(tail) - 1)
	return -1


static func is_seat_like(id: String) -> bool:
	for prefix: String in SEAT_KINDS:
		if id.begins_with(prefix) and id.trim_prefix(prefix).is_valid_int():
			return true
	return false


static func is_merc(id: String) -> bool:
	var tail: String = id.trim_prefix(MERC_PREFIX)
	return id.begins_with(MERC_PREFIX) and tail.is_valid_int() and int(tail) >= 0


#mercN takes roster_uids()[N % size]; -1 for an empty roster or a non-merc sender.
static func merc_uid_for(id: String) -> int:
	var uids: Array[int] = GameState.roster_uids()
	if not is_merc(id) or uids.is_empty():
		return -1
	return uids[int(id.trim_prefix(MERC_PREFIX)) % uids.size()]


static func _table() -> Dictionary:
	if not _senders.is_empty():
		return _senders
	for cells: Dictionary in TsvReader.load_header_rows(SENDERS_TSV):
		var client := ClientData.new()
		client.kind = MAIL_KIND
		client.index = _senders.size()
		client.name = String(cells.get("Name", ""))
		client.kind_label = String(cells.get("Kind", ""))
		client.sub = String(cells.get("Sub", ""))
		client.location = String(cells.get("Location", ""))
		var km_cell: String = String(cells.get("Km", "")).strip_edges()
		#A blank Km cell is no distance at all; an authored 0 stays 0.
		client.km = int(km_cell) if km_cell != "" else -1
		client.about = String(cells.get("About", ""))
		_senders[String(cells.get("Id", "")).strip_edges()] = client
	return _senders
