class_name ContractIssuer extends RefCounted

#The issuer seats and the legacy entry id rule. Seat ids run through KINDS in order: orgs 0..8, people
#9..16, places 17..24. The id rule names a kind and, within that kind, an index. Only orgs map onto a
#StockMarket company.

const KINDS: Array[StringName] = [&"orgs", &"people", &"places"]
#One org seat per Companies.tsv row.
const ORGS: int = 9
const PEOPLE: int = 8
const PLACES: int = 8
const SEATS: Array[int] = [ORGS, PEOPLE, PLACES]


static func kind_of(entry_id: int) -> StringName:
	return KINDS[posmod(entry_id, 3)]


static func index_of(entry_id: int, count: int) -> int:
	if count < 1:
		return 0
	return posmod(floori(entry_id / 3.0), count)


static func company_of(entry_id: int, company_count: int) -> int:
	if kind_of(entry_id) != &"orgs" or company_count < 1:
		return -1
	return index_of(entry_id, company_count)


#Seats in one kind; 0 for an unknown kind.
static func group_size(kind: String) -> int:
	var k: int = KINDS.find(StringName(kind))
	if k < 0:
		return 0
	return SEATS[k]


#The seat of the index-th issuer of a kind; -1 when the kind or the index is off the layout.
static func seat_id(kind: String, index: int) -> int:
	if index < 0 or index >= group_size(kind):
		return -1
	return _first_seat(kind) + index


#"orgs", "people" or "places"; "" for a seat off the layout.
static func kind_of_seat(seat: int) -> String:
	var first: int = 0
	for k: int in range(KINDS.size()):
		if seat >= first and seat < first + SEATS[k]:
			return String(KINDS[k])
		first += SEATS[k]
	return ""


#A seat's index within its kind; -1 for a seat off the layout.
static func index_of_seat(seat: int) -> int:
	var kind: String = kind_of_seat(seat)
	if kind.is_empty():
		return -1
	return seat - _first_seat(kind)


static func _first_seat(kind: String) -> int:
	var k: int = KINDS.find(StringName(kind))
	var first: int = 0
	for i: int in range(maxi(k, 0)):
		first += SEATS[i]
	return first
