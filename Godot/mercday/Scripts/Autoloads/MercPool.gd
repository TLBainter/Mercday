extends Node

#Mercs that left the party and may be hired again.
#Memory only; nothing is written to disk.

var _pool: Array[MercenaryData] = []
#Mercs held by kidnappers: {"merc", "contract_type", "location", "stamp", "crew", "crew_source", "kind"}.
var _captives: Array[Dictionary] = []


func add(merc: MercenaryData) -> void:
	if merc == null or _pool.has(merc):
		return
	_pool.append(merc)


func list() -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	out.assign(_pool)
	return out


func count() -> int:
	return _pool.size()


#Removes and returns the pooled merc with this uid; null when none is pooled.
func take(merc_uid: int) -> MercenaryData:
	var at := -1
	for i: int in range(_pool.size()):
		if _pool[i].merc_uid == merc_uid:
			at = i
			break
	if at < 0:
		return null
	var merc := _pool[at]
	_pool.remove_at(at)
	return merc


#crew holds the captors kept for a later rescue; crew_source is the Enemy cell they were built from.
func add_captive(merc: MercenaryData, contract_type: String, location: String, stamp: String,
		crew: Array = [], crew_source: String = "") -> void:
	if merc == null:
		return
	for entry: Dictionary in _captives:
		if entry["merc"] == merc:
			return
		if merc.merc_uid > 0 and (entry["merc"] as MercenaryData).merc_uid == merc.merc_uid:
			return
	var held: Array[MercenaryData] = []
	for member: Variant in crew:
		if member is MercenaryData and member != merc and not held.has(member):
			held.append(member)
	_captives.append({
		"merc": merc,
		"contract_type": contract_type,
		"location": location,
		"stamp": stamp,
		"crew": held,
		"crew_source": crew_source,
		"kind": "kidnapped",
	})


func captives() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_captives)
	return out


#The held record for this uid; {} when nobody with that uid is held.
func captive_record(merc_uid: int) -> Dictionary:
	for entry: Dictionary in _captives:
		if (entry["merc"] as MercenaryData).merc_uid == merc_uid:
			return entry
	return {}


#Removes and returns the captive with this uid; null when none is held.
func take_captive(merc_uid: int) -> MercenaryData:
	var at := -1
	for i: int in range(_captives.size()):
		if (_captives[i]["merc"] as MercenaryData).merc_uid == merc_uid:
			at = i
			break
	if at < 0:
		return null
	var merc: MercenaryData = _captives[at]["merc"]
	_captives.remove_at(at)
	return merc


func clear() -> void:
	_pool.clear()
	_captives.clear()
