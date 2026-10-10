class_name ContractPool
extends RefCounted
#Generated contracts held off the board until the roster has room; unbounded (proposal 5.16).

var entries: Array[BoardEntry] = []


func add(entry: BoardEntry, now: int) -> void:
	if entry == null or entries.has(entry):
		return
	entry.status = BoardEntry.STATUS_POOLED
	entry.pooled_minute = now
	entries.append(entry)


func remove(entry: BoardEntry) -> void:
	entries.erase(entry)


func issuer_ids() -> Array[int]:
	var out: Array[int] = []
	for entry: BoardEntry in entries:
		out.append(entry.issuer_id)
	return out


func types() -> Array[String]:
	var out: Array[String] = []
	for entry: BoardEntry in entries:
		out.append(entry.contract_type())
	return out


#Removes and returns every non-story entry the board auto-reject rule would drop at now, as GameState._sweep_reach.
func sweep(now: int, bank: int, tele_fn: Callable) -> Array[BoardEntry]:
	var gone: Array[BoardEntry] = []
	var kept: Array[BoardEntry] = []
	for entry: BoardEntry in entries:
		if entry.story or not _out_of_reach(entry, now, bank, bool(tele_fn.call(entry))):
			kept.append(entry)
		else:
			gone.append(entry)
	entries = kept
	return gone


static func reject_bonus(face: int) -> float:
	return GenConstants.REJECT_VALUE_STEP * float(maxi(0, absi(face) - 1)) / 100.0


#A rejected roster posting comes back as a new pooled entry with its value raised by the face read before the reject.
func return_rejected(posting: BoardEntry, face_before: int, now: int) -> BoardEntry:
	var entry := BoardEntry.new()
	if posting.contract != null:
		entry.contract = posting.contract.duplicate() as ContractData
	entry.posted_minute = posting.posted_minute
	entry.expires_minute = posting.expires_minute
	entry.distance_km = posting.distance_km
	entry.completion_hours = posting.completion_hours
	entry.issuer = posting.issuer
	entry.issuer_type = posting.issuer_type
	entry.merc_min = posting.merc_min
	entry.image = posting.image
	entry.campaign_id = posting.campaign_id
	entry.issuer_id = posting.issuer_id
	entry.deadline_minute = posting.deadline_minute
	entry.quality = posting.quality
	entry.match_pct = posting.match_pct
	entry.best_mode = posting.best_mode
	entry.story = posting.story
	entry.id = 0
	entry.reach_warned = false
	entry.reject_count = posting.reject_count + 1
	entry.value = roundi(float(posting.value) * (1.0 + reject_bonus(face_before)))
	if entry.contract != null:
		entry.contract.reward_notes = entry.value
	add(entry, now)
	return entry


static func _out_of_reach(entry: BoardEntry, now: int, bank: int, tele_permit: bool) -> bool:
	if entry.deadline_minute <= 0:
		return false
	var best: String = Reachability.best_mode(entry, now, bank, tele_permit, maxi(1, entry.merc_min))
	if best == "":
		return true
	var modes: Array[String] = [best]
	return Reachability.auto_reject_minute(entry, modes, now) <= now
