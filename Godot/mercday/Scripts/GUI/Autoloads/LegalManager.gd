extends Node

#Legal: the permits the guild holds, the fines it owes, the mercs sitting in custody and the odd
#jobs sent to fix either. Permits, counsel and Odd Job crew size all read
#SubscriptionManager.entitlements(); nothing here branches on a plan name.

signal permits_changed
signal fines_changed
signal captures_changed
signal odd_jobs_changed
signal odd_job_resolved(target: Dictionary, success: bool)

#scope is the permit tier a location needs: 1 most nations, 2 restricted, 3 another domain.
#The place name is not held here: CampaignTypeDefs.LOCATIONS is the one source of the nine.
const LOCATIONS: Array[Dictionary] = [
	{"id": 0, "nation": "Nation 1", "scope": 1, "ops_cost": 0,
		"tele_cost": 300, "avg_difficulty": 1.5, "relationship": 2},
	{"id": 1, "nation": "Nation 1", "scope": 1, "ops_cost": 400,
		"tele_cost": 250, "avg_difficulty": 2.0, "relationship": 1},
	{"id": 2, "nation": "Nation 2", "scope": 1, "ops_cost": 650,
		"tele_cost": 400, "avg_difficulty": 2.5, "relationship": 3},
	{"id": 3, "nation": "Nation 2", "scope": 1, "ops_cost": 900,
		"tele_cost": 550, "avg_difficulty": 3.0, "relationship": -1},
	{"id": 4, "nation": "Nation 3", "scope": 1, "ops_cost": 1200,
		"tele_cost": 700, "avg_difficulty": 3.0, "relationship": 0},
	{"id": 5, "nation": "Nation 4, Restricted", "scope": 2,
		"ops_cost": 1500, "tele_cost": 900, "avg_difficulty": 3.5, "relationship": -3},
	{"id": 6, "nation": "Nation 5, Restricted", "scope": 2,
		"ops_cost": 2000, "tele_cost": 1200, "avg_difficulty": 4.0, "relationship": 1},
	{"id": 7, "nation": "Domain 2, Nation 6", "scope": 3,
		"ops_cost": 2600, "tele_cost": 1600, "avg_difficulty": 4.5, "relationship": 0},
	{"id": 8, "nation": "Domain 2, Nation 7", "scope": 3,
		"ops_cost": 3400, "tele_cost": 2000, "avg_difficulty": 5.0, "relationship": -1},
]
const LOCATION_RULES: Array[String] = ["Rule 1", "Rule 2", "Rule 3"]
const PERMIT_OPS := &"ops"
const PERMIT_TELE := &"tele"
const PERMIT_KINDS: Array[StringName] = [PERMIT_OPS, PERMIT_TELE]
const TARGET_FINE := &"fine"
const TARGET_CAPTURE := &"capture"
const JOB_RENEGOTIATE := &"renegotiate"
const JOB_BREAKOUT := &"breakout"
#The three states permit_state reports: not held, held and usable, held while the plan no
#longer reaches the location.
const STATE_NONE: int = 0
const STATE_ACTIVE: int = 1
const STATE_INACTIVE: int = 2
#The guild sits at location 0, so its operating permit can never fall out of reach.
const HOME_LOCATION: int = 0
#The separator every ledger label of this manager uses.
const LABEL_JOIN: String = " - "

#PLACEHOLDER: every figure below, and the seeded permits, fines and captures, stand in until the
#real legal data exists. Replace the block whole.
const MANAGER_SEED := 7
const COUNSEL_PCT: Array[int] = [0, 5, 7, 9, 13, 15]
const JOB_DAYS := 12
const LATE_PCT := 2
const CUSTODY_FEE := 5
const ODDS_BASE := 30
const ODDS_PER_MERC := 20
const ODDS_CAP := 95
const RENEGOTIATE_WIN := 0.5
const RENEGOTIATE_LOSS := 1.25
const BREAKOUT_LOSS := 1.5
const SEED_TODAY := 540
const SEED_PERMITS: Array[Dictionary] = [
	{"loc": 0, "ops": true, "tele": false},
	{"loc": 2, "ops": true, "tele": true},
]
const SEED_FINES: Array[Dictionary] = [
	{"id": 1, "loc": 2, "crime": "Crime 1", "mercs": [3, 6], "contract": 11, "issued": 530,
		"due": 548, "amount": 180, "unread": true},
	{"id": 2, "loc": 0, "crime": "Crime 2", "mercs": [1], "contract": 12, "issued": 520,
		"due": 535, "amount": 450, "unread": false},
	{"id": 3, "loc": 3, "crime": "Crime 3", "mercs": [2, 7, 8], "contract": 13, "issued": 538,
		"due": 561, "amount": 900, "unread": true},
	{"id": 4, "loc": 0, "crime": "Crime 4", "mercs": [5], "contract": 11, "issued": 500,
		"due": 520, "amount": 60, "paid": 60, "paid_day": 517, "unread": false},
]
const SEED_CAPTURES: Array[Dictionary] = [
	{"id": 1, "merc": 4, "loc": 3, "crime": "Crime 5", "contract": 13, "since": 536,
		"sentence": 30, "bail": 350, "unread": true},
	{"id": 2, "merc": 9, "loc": 2, "crime": "Crime 6", "contract": 11, "since": 530,
		"sentence": 20, "bail": 220, "unread": false},
]

var permits: Dictionary = {}
var fines: Array[FineData] = []
var captured: Array[CaptureData] = []
var odd_jobs: Array[OddJobData] = []
var next_fine_id: int = 1
var next_capture_id: int = 1
var next_job_id: int = 1

var _locations: Array[LegalLocationData] = []
var _rng := RandomNumberGenerator.new()
var _seeded: bool = false
var _resetting: bool = false
var _restoring: bool = false
var _away_uids: Dictionary = {}


func _ready() -> void:
	_build_locations()
	GameState.roster_changed.connect(_on_roster_changed)
	GameState.day_changed.connect(_on_day_changed)
	reset()


#Rebuilds the seeded permits, fines and captures around today and drops every odd job.
func reset() -> void:
	if _locations.is_empty():
		_build_locations()
	_resetting = true
	_clear_away_rows()
	_rng = RandomNumberGenerator.new()
	_rng.seed = MANAGER_SEED
	var today: int = GameState.day()
	permits.clear()
	for row: Dictionary in SEED_PERMITS:
		permits[int(row["loc"])] = {"ops": bool(row["ops"]), "tele": bool(row["tele"])}
	fines.clear()
	next_fine_id = 1
	for row: Dictionary in SEED_FINES:
		fines.append(_fine_from_seed(row, today))
		next_fine_id = maxi(next_fine_id, int(row["id"]) + 1)
	captured.clear()
	next_capture_id = 1
	for row: Dictionary in SEED_CAPTURES:
		captured.append(_capture_from_seed(row, today))
		next_capture_id = maxi(next_capture_id, int(row["id"]) + 1)
	odd_jobs.clear()
	next_job_id = 1
	_seeded = GameState.started
	for row: CaptureData in captured:
		_hold_merc(row.merc_uid, GuiTypes.MercStatus.CAPTURED, -1)
	_resetting = false
	permits_changed.emit()
	fines_changed.emit()
	captures_changed.emit()
	odd_jobs_changed.emit()


func _build_locations() -> void:
	_locations.clear()
	for row: Dictionary in LOCATIONS:
		var made := LegalLocationData.new()
		made.id = int(row["id"])
		made.name = CampaignTypeDefs.location_name(made.id)
		made.nation = str(row["nation"])
		made.scope = int(row["scope"])
		made.ops_cost = int(row["ops_cost"])
		made.tele_cost = int(row["tele_cost"])
		made.avg_difficulty = float(row["avg_difficulty"])
		made.relationship = int(row["relationship"])
		made.rules.assign(LOCATION_RULES)
		_locations.append(made)


#The seeds are written against a fixed prototype day; each one keeps its age around today.
func _fine_from_seed(row: Dictionary, today: int) -> FineData:
	var made := FineData.new()
	made.id = int(row["id"])
	made.location_id = int(row["loc"])
	made.crime = str(row["crime"])
	made.mercs.assign(row["mercs"] as Array)
	made.contract_id = int(row["contract"])
	made.day_issued = today - (SEED_TODAY - int(row["issued"]))
	made.day_due = made.day_issued + (int(row["due"]) - int(row["issued"]))
	made.amount = int(row["amount"])
	made.paid = int(row.get("paid", 0))
	made.day_paid = -1
	if row.has("paid_day"):
		made.day_paid = today - (SEED_TODAY - int(row["paid_day"]))
	made.unread = bool(row.get("unread", false))
	return made


func _capture_from_seed(row: Dictionary, today: int) -> CaptureData:
	var made := CaptureData.new()
	made.id = int(row["id"])
	made.merc_uid = int(row["merc"])
	made.location_id = int(row["loc"])
	made.crime = str(row["crime"])
	made.contract_id = int(row["contract"])
	made.day_captured = today - (SEED_TODAY - int(row["since"]))
	made.sentence_days = int(row["sentence"])
	made.bail = int(row["bail"])
	made.unread = bool(row.get("unread", false))
	return made


func _on_roster_changed() -> void:
	if _seed_if_started():
		return
	_restore_holds()


func _on_day_changed(_day_index: int) -> void:
	if _seed_if_started():
		return
	_resolve_due_jobs()
	_restore_holds()


#Reseeds once, on the first signal after a campaign starts; true when this call did it.
func _seed_if_started() -> bool:
	if _resetting or _seeded or not GameState.started:
		return false
	reset()
	return true


func _ent() -> Dictionary:
	return SubscriptionManager.entitlements()


func locations() -> Array[LegalLocationData]:
	return _locations.duplicate()


func location(id: int) -> LegalLocationData:
	for row: LegalLocationData in _locations:
		if row.id == id:
			return row
	return null


func has_permit(loc_id: int, kind: StringName) -> bool:
	var held: Dictionary = permits.get(loc_id, {}) as Dictionary
	return bool(held.get(String(kind), false))


func permit_cost(loc_id: int, kind: StringName) -> int:
	var place: LegalLocationData = location(loc_id)
	if place == null:
		return 0
	return place.tele_cost if kind == PERMIT_TELE else place.ops_cost


#The permit tier the plan grants for this kind of permit.
func permit_tier(kind: StringName) -> int:
	var key: String = "teleport" if kind == PERMIT_TELE else "opsPermits"
	return int(_ent().get(key, 0))


#Whether the permit may be bought right now, and the line the button prints when it may not.
func can_request(loc_id: int, kind: StringName) -> Dictionary:
	var place: LegalLocationData = location(loc_id)
	if place == null or not PERMIT_KINDS.has(kind):
		return {"ok": false, "reason": "No such permit."}
	if has_permit(loc_id, kind):
		return {"ok": false, "reason": "You already hold this permit."}
	if permit_tier(kind) < place.scope:
		return {"ok": false, "reason": "Your plan does not reach this location."}
	if kind == PERMIT_TELE and not has_permit(loc_id, PERMIT_OPS):
		return {"ok": false, "reason": "An operating permit comes first."}
	var cost: int = permit_cost(loc_id, kind)
	if not GameState.can_afford(cost):
		return {"ok": false, "reason": "Not enough notes. You need %d more."
			% (cost - GameState.bank_notes)}
	return {"ok": true, "reason": ""}


func request_permit(loc_id: int, kind: StringName) -> bool:
	if not bool(can_request(loc_id, kind)["ok"]):
		return false
	var tail: String = "Teleportation Permit" if kind == PERMIT_TELE else "Operations Permit"
	if not _pay(permit_cost(loc_id, kind), "permit", _ledger_label(loc_id, tail)):
		return false
	var held: Dictionary = permits.get(loc_id, {"ops": false, "tele": false}) as Dictionary
	held[String(kind)] = true
	permits[loc_id] = held
	permits_changed.emit()
	return true


#The percentage whoKnows takes off every new fine and bail; the highest owned tier applies.
func money_reduction() -> int:
	var tier: int = int(_ent().get("whoKnows", 0))
	if tier >= 5:
		return 25
	if tier >= 3:
		return 20
	if tier >= 1:
		return 5
	return 0


#The percentage whoKnows takes off a sentence. No prison time model exists yet, so nothing
#reads this: CaptureData.sentence_days is set by whoever files the capture.
func prison_reduction() -> int:
	var tier: int = int(_ent().get("whoKnows", 0))
	if tier >= 6:
		return 20
	if tier >= 4:
		return 15
	if tier >= 2:
		return 5
	return 0


#The percentage whoKnows takes off the late fee: tier 7 halves it, tier 8 drops it.
func fee_reduction() -> int:
	var tier: int = int(_ent().get("whoKnows", 0))
	if tier >= 8:
		return 100
	if tier >= 7:
		return 50
	return 0


func _less(amount: int, reduction_pct: int) -> int:
	return int(round(float(amount) * float(100 - reduction_pct) / 100.0))


#Files a new fine. whoKnows cuts new fines, so the reduction lands here, not on the seeds.
func add_fine(loc_id: int, crime: String, mercs: Array[int], contract_id: int, amount: int,
		days_until_due: int) -> FineData:
	var made := FineData.new()
	made.id = next_fine_id
	next_fine_id += 1
	made.location_id = loc_id
	made.crime = crime
	made.mercs.assign(mercs)
	made.contract_id = contract_id
	made.day_issued = GameState.day()
	made.day_due = made.day_issued + maxi(0, days_until_due)
	made.amount = _less(amount, money_reduction())
	if made.amount != amount:
		made.previous_amount = amount
		made.note = "Reduced by who you know."
	made.unread = true
	fines.append(made)
	fines_changed.emit()
	return made


#Files a new capture. whoKnows cuts new bail the same way it cuts a new fine.
func add_capture(merc_uid: int, loc_id: int, crime: String, contract_id: int, sentence_days: int,
		bail: int) -> CaptureData:
	var made := CaptureData.new()
	made.id = next_capture_id
	next_capture_id += 1
	made.merc_uid = merc_uid
	made.location_id = loc_id
	made.crime = crime
	made.contract_id = contract_id
	made.day_captured = GameState.day()
	made.sentence_days = _less(sentence_days, prison_reduction())
	made.bail = _less(bail, money_reduction())
	if made.bail != bail:
		made.previous_bail = bail
		made.note = "Reduced by who you know."
	made.unread = true
	captured.append(made)
	_hold_merc(made.merc_uid, GuiTypes.MercStatus.CAPTURED, -1)
	captures_changed.emit()
	return made


func fine(id: int) -> FineData:
	for row: FineData in fines:
		if row.id == id:
			return row
	return null


func capture(id: int) -> CaptureData:
	for row: CaptureData in captured:
		if row.id == id:
			return row
	return null


#The fee for running late, charged per overdue day and frozen on the day the fine was paid.
func late_fee(f: FineData) -> int:
	if f == null:
		return 0
	var upto: int = f.day_paid if f.is_paid() and f.day_paid >= 0 else GameState.day()
	var late_days: int = maxi(0, upto - f.day_due)
	var per_day: int = int(ceil(float(f.amount * LATE_PCT) / 100.0))
	return _less(late_days * per_day, fee_reduction())


func fine_due(f: FineData) -> int:
	if f == null:
		return 0
	if f.is_paid():
		return f.paid
	return f.amount + late_fee(f)


func custody_fee(c: CaptureData) -> int:
	if c == null:
		return 0
	return maxi(0, GameState.day() - c.day_captured) * CUSTODY_FEE


func bail_due(c: CaptureData) -> int:
	if c == null:
		return 0
	return c.bail + custody_fee(c)


func unpaid_fines(loc_id: int = -1) -> Array[FineData]:
	var out: Array[FineData] = []
	for row: FineData in fines:
		if row.is_paid() or (loc_id >= 0 and row.location_id != loc_id):
			continue
		out.append(row)
	return out


func captures_at(loc_id: int) -> Array[CaptureData]:
	var out: Array[CaptureData] = []
	for row: CaptureData in captured:
		if row.location_id == loc_id:
			out.append(row)
	return out


#Good standing at a location: nothing owed there and nobody of ours held there.
func good_standing(loc_id: int) -> bool:
	return unpaid_fines(loc_id).is_empty() and captures_at(loc_id).is_empty()


func total_owed() -> int:
	var total: int = 0
	for row: FineData in unpaid_fines():
		total += fine_due(row)
	for row: CaptureData in captured:
		total += bail_due(row)
	return total


func pay_fine(id: int) -> bool:
	var f: FineData = fine(id)
	if f == null or f.is_paid():
		return false
	var total: int = fine_due(f)
	if not _pay(total, "fine", _ledger_label(f.location_id, "Fine")):
		return false
	f.paid = total
	f.day_paid = GameState.day()
	f.unread = false
	fines_changed.emit()
	return true


func pay_bail(id: int) -> bool:
	var c: CaptureData = capture(id)
	if c == null:
		return false
	if not _pay(bail_due(c), "bail", _ledger_label(c.location_id, "Bail")):
		return false
	_release(c)
	return true


#Hands the merc back when MercPool is holding one. Nothing else tracks a released merc yet, so
#for a capture MercPool never took, dropping the row is the whole of the release.
func _release(c: CaptureData) -> void:
	if MercPool.has_method("take_captive"):
		MercPool.take_captive(c.merc_uid)
	_free_merc(c.merc_uid)
	captured.erase(c)
	captures_changed.emit()


func has_unread_fine() -> bool:
	for row: FineData in fines:
		if row.unread:
			return true
	return false


func has_unread_capture() -> bool:
	for row: CaptureData in captured:
		if row.unread:
			return true
	return false


#Emits once when a row really turned read, so a listening screen or dot clears on the signal
#and a second call from that same handler ends the chain.
func mark_fines_seen() -> void:
	var touched: bool = false
	for row: FineData in fines:
		if row.unread:
			row.unread = false
			touched = true
	if touched:
		fines_changed.emit()


func mark_captures_seen() -> void:
	var touched: bool = false
	for row: CaptureData in captured:
		if row.unread:
			row.unread = false
			touched = true
	if touched:
		captures_changed.emit()


#The percentage counsel adds per merc on a Renegotiate. The entitlement carries the percentage
#itself; COUNSEL_PCT is the tier table it comes from.
func counsel_pct() -> int:
	return maxi(0, int(_ent().get("counselPct", 0)))


func has_counsel() -> bool:
	return bool(_ent().get("counsel", false)) or counsel_pct() > 0


#How many mercs the plan lets an odd job carry.
func odd_job_slots() -> int:
	return maxi(0, int(_ent().get("oddJobs", 0)))


func odd_job_odds(team_size: int, kind: StringName) -> int:
	if team_size <= 0:
		return 0
	var odds: int = ODDS_BASE + ODDS_PER_MERC * team_size
	if kind == JOB_RENEGOTIATE:
		odds += counsel_pct() * team_size
	return mini(ODDS_CAP, odds)


func active_odd_job(target_kind: StringName, target_id: int) -> OddJobData:
	for job: OddJobData in odd_jobs:
		if job.target_kind == target_kind and job.target_id == target_id:
			return job
	return null


func odd_job_days_left(job: OddJobData) -> int:
	if job == null:
		return 0
	return job.day_started + job.days - GameState.day()


#Whether a crew can be sent at this target right now, and the line the dialog prints otherwise.
func can_start_odd_job(target_kind: StringName, target_id: int, team: Array[int],
		pay_per: int) -> Dictionary:
	if not _target_exists(target_kind, target_id):
		return {"ok": false, "reason": "No such case."}
	var slots: int = odd_job_slots()
	if slots <= 0:
		return {"ok": false, "reason": "Odd Jobs are not part of your plan."}
	if team.is_empty():
		return {"ok": false, "reason": "Pick at least one merc."}
	if team.size() > slots:
		var word: String = "merc" if slots == 1 else "mercs"
		return {"ok": false, "reason": "Your plan allows %d %s." % [slots, word]}
	#The case comes before the crew: a job already on this case is the plainer answer, and its own
	#crew counts as busy the moment it leaves.
	if active_odd_job(target_kind, target_id) != null:
		return {"ok": false, "reason": "A job is already running on this case."}
	var seen: Dictionary = {}
	var busy: Array[int] = GameState.busy_uids()
	for uid: int in team:
		if seen.has(uid):
			return {"ok": false, "reason": "That merc is already on the crew."}
		seen[uid] = true
		if busy.has(uid):
			return {"ok": false, "reason": "One of those mercs is already busy."}
	if pay_per < 0:
		return {"ok": false, "reason": "Pay cannot be negative."}
	var cost: int = pay_per * team.size()
	if not GameState.can_afford(cost):
		return {"ok": false, "reason": "Not enough notes. You need %d more."
			% (cost - GameState.bank_notes)}
	return {"ok": true, "reason": ""}


func _target_exists(target_kind: StringName, target_id: int) -> bool:
	if target_kind == TARGET_FINE:
		var f: FineData = fine(target_id)
		return f != null and not f.is_paid()
	if target_kind == TARGET_CAPTURE:
		return capture(target_id) != null
	return false


#Pays the crew up front and files the job; null when it cannot be sent.
func start_odd_job(target_kind: StringName, target_id: int, kind: StringName, team: Array[int],
		pay_per: int) -> OddJobData:
	if not bool(can_start_odd_job(target_kind, target_id, team, pay_per)["ok"]):
		return null
	var tail: String = "Renegotiate" if kind == JOB_RENEGOTIATE else "Break Out"
	var loc_id: int = _target_location(target_kind, target_id)
	if not _pay(pay_per * team.size(), "odd_job", _ledger_label(loc_id, tail)):
		return null
	var job := OddJobData.new()
	job.id = next_job_id
	next_job_id += 1
	job.target_kind = target_kind
	job.target_id = target_id
	job.kind = kind
	job.team.assign(team)
	job.pay_per = pay_per
	job.day_started = GameState.day()
	job.days = JOB_DAYS
	job.odds = odd_job_odds(team.size(), kind)
	odd_jobs.append(job)
	for uid: int in job.team:
		_hold_merc(uid, GuiTypes.MercStatus.ODD_JOB, _job_end_minute(job))
	odd_jobs_changed.emit()
	return job


func _resolve_due_jobs() -> void:
	var due: Array[OddJobData] = []
	for job: OddJobData in odd_jobs:
		if odd_job_days_left(job) <= 0:
			due.append(job)
	if due.is_empty():
		return
	for job: OddJobData in due:
		for uid: int in job.team:
			_free_merc(uid)
		var success: bool = _rng.randi_range(1, 100) <= job.odds
		_apply_odd_job(job, success)
		odd_jobs.erase(job)
		odd_job_resolved.emit({"kind": job.target_kind, "id": job.target_id}, success)
	odd_jobs_changed.emit()


#A won Renegotiate halves the fine and a lost one raises it; a won Break Out frees the merc with
#no bail and a lost one raises the bail.
func _apply_odd_job(job: OddJobData, success: bool) -> void:
	if job.target_kind == TARGET_FINE:
		var f: FineData = fine(job.target_id)
		if f == null or f.is_paid():
			return
		f.previous_amount = f.amount
		f.amount = maxi(1, int(round(float(f.amount)
			* (RENEGOTIATE_WIN if success else RENEGOTIATE_LOSS))))
		f.note = "Renegotiated." if success else "Renegotiation failed."
		f.unread = true
		fines_changed.emit()
		return
	var c: CaptureData = capture(job.target_id)
	if c == null:
		return
	if success:
		_release(c)
		return
	c.previous_bail = c.bail
	c.bail = maxi(1, int(round(float(c.bail) * BREAKOUT_LOSS)))
	c.note = "Break out failed."
	c.unread = true
	captures_changed.emit()


#Every notes movement of this manager goes through here, so no screen spends for it and every
#ledger row carries a reason and a short label.
func _pay(amount: int, reason: String, label: String) -> bool:
	return GameState.spend(amount, reason, label)


func _ledger_label(loc_id: int, tail_text: String) -> String:
	var place: LegalLocationData = location(loc_id)
	var head: String = place.name if place != null else "Legal"
	return head + LABEL_JOIN + tail_text


func _target_location(target_kind: StringName, target_id: int) -> int:
	if target_kind == TARGET_FINE:
		var f: FineData = fine(target_id)
		return f.location_id if f != null else -1
	var c: CaptureData = capture(target_id)
	return c.location_id if c != null else -1


#The minute the crew is due back: midnight of the day the job resolves on.
func _job_end_minute(job: OddJobData) -> int:
	return (job.day_started + job.days) * CampaignClock.MINUTES_PER_DAY


#The away registry is shared, so the manager tracks only the rows it wrote itself.
func _hold_merc(uid: int, status: int, until_minute: int) -> void:
	if GameState.set_away(uid, status, until_minute):
		_away_uids[uid] = true


#A new game wipes the shared away registry while the rows here live on, so every signal the
#manager hears writes its own holds back.
func _restore_holds() -> void:
	if _resetting or _restoring:
		return
	_restoring = true
	for row: CaptureData in captured:
		_restore_one(row.merc_uid, GuiTypes.MercStatus.CAPTURED, -1)
	for job: OddJobData in odd_jobs:
		for uid: int in job.team:
			_restore_one(uid, GuiTypes.MercStatus.ODD_JOB, _job_end_minute(job))
	_restoring = false


#Only a hold this manager wrote and the registry lost is written again.
func _restore_one(uid: int, status: int, until_minute: int) -> void:
	if not _away_uids.has(uid):
		return
	if GameState.away_status(uid) != -1:
		return
	_hold_merc(uid, status, until_minute)


func _free_merc(uid: int) -> void:
	if not _away_uids.has(uid):
		return
	_away_uids.erase(uid)
	GameState.clear_away(uid)


func _clear_away_rows() -> void:
	var held: Array[int] = []
	held.assign(_away_uids.keys())
	_away_uids.clear()
	for uid: int in held:
		GameState.clear_away(uid)


#What the Permits card prints for one permit: nothing, a live permit, or one kept on file while
#the plan no longer reaches this location.
func permit_state(loc_id: int, kind: StringName) -> int:
	if not has_permit(loc_id, kind):
		return STATE_NONE
	if loc_id == HOME_LOCATION and kind == PERMIT_OPS:
		return STATE_ACTIVE
	var place: LegalLocationData = location(loc_id)
	if place == null:
		return STATE_ACTIVE
	return STATE_ACTIVE if permit_tier(kind) >= place.scope else STATE_INACTIVE


#Every open case at one location: the unpaid fines first, then the mercs held there. days counts
#the days past due on a fine and the days of sentence left on a capture.
func violations(loc_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var today: int = GameState.day()
	for row: FineData in unpaid_fines(loc_id):
		out.append({"kind": TARGET_FINE, "id": row.id, "crime": row.crime,
			"amount": fine_due(row), "days": today - row.day_due})
	for row: CaptureData in captures_at(loc_id):
		out.append({"kind": TARGET_CAPTURE, "id": row.id, "crime": row.crime,
			"amount": bail_due(row), "days": row.remaining(today)})
	return out


#One row turns read when its Review opens; the tab that lists it never clears the whole list.
func mark_fine_read(id: int) -> void:
	var f: FineData = fine(id)
	if f == null or not f.unread:
		return
	f.unread = false
	fines_changed.emit()


func mark_capture_read(id: int) -> void:
	var c: CaptureData = capture(id)
	if c == null or not c.unread:
		return
	c.unread = false
	captures_changed.emit()


func paid_fines() -> Array[FineData]:
	var out: Array[FineData] = []
	for row: FineData in fines:
		if row.is_paid():
			out.append(row)
	return out


#How many cells of a progress bar one running job has filled.
func job_cells(job: OddJobData, cells: int = 20) -> int:
	if job == null or cells <= 0:
		return 0
	var span: int = maxi(1, job.days)
	var elapsed: int = clampi(GameState.day() - job.day_started, 0, span)
	return clampi(int(floor(float(elapsed) / float(span) * float(cells))), 0, cells)
