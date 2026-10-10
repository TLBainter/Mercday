class_name IssuerOpinion

#Each issuer seat's satisfaction with the guild, read as a -5..5 face, and one GuildRecord per issuer group.

const SAT_WIN: int = 10
const SAT_FAIL: int = 15
const SAT_REJECT_FACTOR: float = 0.75
const SAT_MIN: int = 0
const SAT_MAX: int = 100
#What a seat the store does not hold reads: face 0.
const SAT_UNKNOWN: int = 50
const SAT_PER_FACE: int = 10
#satisfaction = (face + FACE_OFFSET) x SAT_PER_FACE.
const FACE_OFFSET: int = 5
const ORG_SEATS: int = ContractIssuer.ORGS
const PEOPLE_SEATS: int = ContractIssuer.PEOPLE
const PLACE_SEATS: int = ContractIssuer.PLACES
const ORG_GROUP: String = "orgs"

#Seat id -> {"name", "group", "satisfaction"}.
static var seats: Dictionary = {}
#Group (a ContractIssuer.KINDS entry) -> GuildRecord.
static var group_records: Dictionary = {}


#Seeds every seat from the relationship ClientRegistry gives it today and gives every group an empty record.
static func reset(companies: Array, lender_rel: Dictionary) -> void:
	seats.clear()
	group_records.clear()
	for kind: StringName in ContractIssuer.KINDS:
		var group: String = String(kind)
		group_records[group] = GuildRecord.new()
		for index: int in range(ContractIssuer.group_size(group)):
			var seeded: int = ClientRegistry.seed_relationship(group, index, companies, lender_rel)
			seats[ContractIssuer.seat_id(group, index)] = {
				"name": ClientRegistry.seat_name(group, index, companies),
				"group": group,
				"satisfaction": clampi((seeded + FACE_OFFSET) * SAT_PER_FACE, SAT_MIN, SAT_MAX),
			}


static func seat_count() -> int:
	return seats.size()


static func has_seat(id: int) -> bool:
	return seats.has(id)


#Every seat id, ascending.
static func ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in seats.keys():
		out.append(id)
	out.sort()
	return out


static func ids_in_group(group: String) -> Array[int]:
	var out: Array[int] = []
	for id: int in ids():
		if group_of(id) == group:
			out.append(id)
	return out


static func group_of(id: int) -> String:
	return String(_seat(id).get("group", ""))


static func name_of(id: int) -> String:
	return String(_seat(id).get("name", ""))


static func satisfaction(id: int) -> int:
	return int(_seat(id).get("satisfaction", SAT_UNKNOWN))


static func face(id: int) -> int:
	var steps: int = roundi(satisfaction(id) / float(SAT_PER_FACE))
	return clampi(steps - FACE_OFFSET, ClientRegistry.REL_MIN, ClientRegistry.REL_MAX)


#The StockMarket company index of an org seat; -1 for any other seat.
static func company_index(id: int) -> int:
	if ContractIssuer.kind_of_seat(id) != ORG_GROUP:
		return -1
	return ContractIssuer.index_of_seat(id)


#The seat the legacy entry id rule names: the id's kind, at its index within that kind's seats.
static func seat_for_entry(entry_id: int) -> int:
	var group: String = String(ContractIssuer.kind_of(entry_id))
	return ContractIssuer.seat_id(group, ContractIssuer.index_of(entry_id, ContractIssuer.group_size(group)))


#A contract this seat issued succeeded. A guild in the red earns no satisfaction but the group still counts it.
static func on_success(id: int, minute: int, in_red: bool) -> void:
	if not seats.has(id):
		return
	if not in_red:
		_set_satisfaction(id, satisfaction(id) + SAT_WIN)
	group_record(group_of(id)).record(true, minute)


static func on_fail(id: int, minute: int) -> void:
	if not seats.has(id):
		return
	_set_satisfaction(id, satisfaction(id) - SAT_FAIL)
	group_record(group_of(id)).record(false, minute)


#The guild turned down this seat's posting; no group record entry.
static func on_reject(id: int) -> void:
	if not seats.has(id):
		return
	_set_satisfaction(id, roundi(satisfaction(id) * SAT_REJECT_FACTOR))


#Moves this seat's satisfaction by whole faces (SAT_PER_FACE each); no group record entry.
static func adjust(id: int, faces: int) -> void:
	if not seats.has(id):
		return
	_set_satisfaction(id, satisfaction(id) + faces * SAT_PER_FACE)


#The group's record; a group the store does not hold reads a fresh empty record that is not kept.
static func group_record(group: String) -> GuildRecord:
	var record: GuildRecord = group_records.get(group, null)
	if record == null:
		return GuildRecord.new()
	return record


static func group_blended(group: String, now_minute: int) -> float:
	return group_record(group).blended(now_minute)


static func _seat(id: int) -> Dictionary:
	return seats.get(id, {})


static func _set_satisfaction(id: int, value: int) -> void:
	seats[id]["satisfaction"] = clampi(value, SAT_MIN, SAT_MAX)
