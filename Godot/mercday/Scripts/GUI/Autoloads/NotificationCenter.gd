extends Node

#The one notification store. Every system that wants the player's attention pushes a row here and
#the HUD bell, the notification panel and the escalation pass all read this list.
#The center seeds nothing on its own: GameState pushes the contract rows and the finance layer
#registers its own rule for offers and stock moves.

signal changed
signal pushed(row: NotificationData)
#One arrival cue: a fresh row not already alerted, or an urgent raise (a seeded trigger skips its first).
signal alerted(row: NotificationData)

#A deadline closer than this becomes URGENT, unless the rule sets its own "urgent_hours".
const URGENT_HOURS: float = 72.0
#An urgent row that was read re-fires after this many minutes while its trigger is still open.
const REFIRE_MINUTES: int = 480
const FILTER_ALL: String = "All"
const SORT_URGENCY := &"urgency"
const SORT_RECENCY := &"recency"

var items: Array[NotificationData] = []
var rules: Dictionary = {}

var _next_id: int = 1
#Type and trigger keys seeded without a row; the first escalation of each arrives silently.
var _seeded: Dictionary = {}
#The contract whose detail view is open; its urgency rows dismiss on arrival instead of alerting.
var open_contract_id: int = -1


#already_alerted keeps a row silent on arrival, such as one seeded at a new game.
func push(type: StringName, trigger_id: int, snap: Dictionary = {},
		urgency: int = NotificationData.Urgency.INFORMATIONAL, kind: String = "",
		already_alerted: bool = false) -> NotificationData:
	var row: NotificationData = _append(type, trigger_id, snap, urgency, kind, CampaignClock.now())
	if _suppress_on_open(type, trigger_id):
		row.alerted = true
		row.read = true
	else:
		row.alerted = already_alerted
		_announce(row)
	pushed.emit(row)
	changed.emit()
	return row


#The contract viewer reports which contract (if any) its detail view currently shows. Any of that
#contract's own unread urgency rows dismiss immediately, and new ones arrive already read.
func set_open_contract(entry_id: int) -> void:
	if open_contract_id == entry_id:
		return
	open_contract_id = entry_id
	if entry_id != -1:
		_dismiss_urgency_for(entry_id)


#A trigger seeded at a new game without a row: its first escalation arrives already alerted.
func mark_seeded(type: StringName, trigger_id: int) -> void:
	_seeded[_seed_key(type, trigger_id)] = true


#One row per day: a later posting that day raises its count in silence; the next day's row replaces the previous one.
func add_postings(day: int, count: int) -> NotificationData:
	var row: NotificationData = latest(NotificationData.TYPE_NEW_POSTINGS, day)
	if row != null:
		row.snap["count"] = int(row.snap.get("count", 0)) + count
		row.minute = CampaignClock.now()
		row.read = false
		changed.emit()
		return row
	_drop_type(NotificationData.TYPE_NEW_POSTINGS)
	return push(NotificationData.TYPE_NEW_POSTINGS, day, {"count": count, "day": day},
		NotificationData.Urgency.INFORMATIONAL, "Contract")


func mark_read(id: int) -> void:
	for row: NotificationData in items:
		if row.id != id:
			continue
		if not row.read:
			row.read = true
			changed.emit()
		return


func resolve(type: StringName, trigger_id: int) -> void:
	if _mark_read_of(type, trigger_id):
		changed.emit()


func read_contract(entry_id: int) -> void:
	var touched: bool = _mark_read_of(NotificationData.TYPE_CONTRACT_COMPLETED, entry_id)
	if _mark_read_of(NotificationData.TYPE_CONTRACT_FAILED, entry_id):
		touched = true
	if touched:
		changed.emit()


func read_offer(offer_id: int) -> void:
	resolve(NotificationData.TYPE_LOAN_OFFER, offer_id)


func has_unread() -> bool:
	for row: NotificationData in items:
		if not row.read:
			return true
	return false


#Counts unread rows; pass a kind from NotificationData.KINDS to count that kind alone.
func unread_count(filter: String = FILTER_ALL) -> int:
	var total: int = 0
	for row: NotificationData in items:
		if row.read:
			continue
		if not _passes(row, filter):
			continue
		total += 1
	return total


#Counts read rows; the same filter rule as unread_count().
func read_count(filter: String = FILTER_ALL) -> int:
	var total: int = 0
	for row: NotificationData in items:
		if not row.read:
			continue
		if not _passes(row, filter):
			continue
		total += 1
	return total


#Test hook: the row with this id, or null when it is gone.
func by_id(id: int) -> NotificationData:
	for row: NotificationData in items:
		if row.id == id:
			return row
	return null


#Test hook: marks every unread row read, or every unread row of one kind.
func mark_all_read(kind: String = FILTER_ALL) -> void:
	var touched: bool = false
	for row: NotificationData in items:
		if row.read:
			continue
		if not _passes(row, kind):
			continue
		row.read = true
		touched = true
	if touched:
		changed.emit()


func listed(unread_tab: bool, sort: StringName = SORT_URGENCY, filter: String = FILTER_ALL) -> Array[NotificationData]:
	var out: Array[NotificationData] = []
	for row: NotificationData in items:
		if row.read == unread_tab:
			continue
		if not _passes(row, filter):
			continue
		out.append(row)
	if sort == SORT_RECENCY:
		out.sort_custom(_by_recency)
	else:
		out.sort_custom(_by_urgency)
	return out


func latest(type: StringName, trigger_id: int) -> NotificationData:
	var found: NotificationData = null
	for row: NotificationData in items:
		if row.type == type and row.trigger_id == trigger_id:
			found = row
	return found


func rows_of(type: StringName, trigger_id: int) -> Array[NotificationData]:
	var out: Array[NotificationData] = []
	for row: NotificationData in items:
		if row.type == type and row.trigger_id == trigger_id:
			out.append(row)
	return out


func add_rule(type: StringName, rule: Dictionary) -> void:
	rules[type] = rule


#Test hook.
func remove_rule(type: StringName) -> void:
	rules.erase(type)


#Raises every open trigger whose deadline came inside its rule's "urgent_hours" (URGENT_HOURS when unset)
#and re-fires a read row. Every raise and re-fire alerts, except the first raise of a seeded trigger.
func escalate(now: int) -> bool:
	var touched: bool = false
	for key: Variant in rules.keys():
		var type: StringName = StringName(key)
		var rule: Dictionary = rules[key]
		var open_fn: Callable = rule.get("open", Callable())
		var hours_fn: Callable = rule.get("hours_left", Callable())
		var make_fn: Callable = rule.get("make", Callable())
		if not open_fn.is_valid() or not hours_fn.is_valid():
			continue
		var kind: String = String(rule.get("kind", ""))
		var urgent_hours: float = float(rule.get("urgent_hours", URGENT_HOURS))
		var open_ids: Array = open_fn.call()
		for raw: Variant in open_ids:
			var trigger_id: int = int(raw)
			if float(hours_fn.call(trigger_id)) >= urgent_hours:
				continue
			if not _needs_urgent(type, trigger_id, now):
				continue
			var snap: Dictionary = {}
			if make_fn.is_valid():
				snap = make_fn.call(trigger_id)
			_drop_rows_of(type, trigger_id)
			var row: NotificationData = _append(type, trigger_id, snap, NotificationData.Urgency.URGENT, kind, now)
			if _suppress_on_open(type, trigger_id):
				row.alerted = true
				row.read = true
			elif _seeded.erase(_seed_key(type, trigger_id)):
				row.alerted = true
			else:
				_announce(row)
			touched = true
	if touched:
		changed.emit()
	return touched


func reset() -> void:
	items.clear()
	_seeded.clear()
	_next_id = 1
	changed.emit()


func _append(type: StringName, trigger_id: int, snap: Dictionary, urgency: int, kind: String,
		minute: int) -> NotificationData:
	var row := NotificationData.new()
	row.id = _next_id
	_next_id += 1
	row.type = type
	row.trigger_id = trigger_id
	row.snap = snap.duplicate(true)
	row.urgency = urgency
	row.kind = NotificationData.kind_for(type, kind)
	row.minute = minute
	items.append(row)
	return row


#The arrival cue fires once per row.
func _announce(row: NotificationData) -> void:
	if row.alerted:
		return
	row.alerted = true
	alerted.emit(row)


func _seed_key(type: StringName, trigger_id: int) -> String:
	return "%s:%d" % [type, trigger_id]


#An empty filter and FILTER_ALL both pass every row; anything else matches the row kind.
func _passes(row: NotificationData, filter: String) -> bool:
	if filter == "" or filter == FILTER_ALL:
		return true
	return row.kind == filter


func _needs_urgent(type: StringName, trigger_id: int, now: int) -> bool:
	var last: NotificationData = latest(type, trigger_id)
	if last == null or last.urgency != NotificationData.Urgency.URGENT:
		return true
	return last.read and now - last.minute >= REFIRE_MINUTES


#The expiry/urgency types that dismiss themselves while their own contract is the open one.
func _suppress_on_open(type: StringName, trigger_id: int) -> bool:
	if trigger_id != open_contract_id:
		return false
	return type == NotificationData.TYPE_EXPIRY_WARNING or type == NotificationData.TYPE_EXPIRED


func _dismiss_urgency_for(trigger_id: int) -> void:
	var touched: bool = false
	for row: NotificationData in items:
		if row.trigger_id != trigger_id:
			continue
		if row.type != NotificationData.TYPE_EXPIRY_WARNING and row.type != NotificationData.TYPE_EXPIRED:
			continue
		if not row.read:
			row.read = true
			touched = true
	if touched:
		changed.emit()


func _mark_read_of(type: StringName, trigger_id: int) -> bool:
	var touched: bool = false
	for row: NotificationData in items:
		if row.type == type and row.trigger_id == trigger_id and not row.read:
			row.read = true
			touched = true
	return touched


func _drop_rows_of(type: StringName, trigger_id: int) -> void:
	var kept: Array[NotificationData] = []
	for row: NotificationData in items:
		if row.type == type and row.trigger_id == trigger_id:
			continue
		kept.append(row)
	items = kept


func _drop_type(type: StringName) -> void:
	var kept: Array[NotificationData] = []
	for row: NotificationData in items:
		if row.type == type:
			continue
		kept.append(row)
	items = kept


func _by_recency(a: NotificationData, b: NotificationData) -> bool:
	if a.minute != b.minute:
		return a.minute > b.minute
	return a.id > b.id


func _by_urgency(a: NotificationData, b: NotificationData) -> bool:
	if a.urgency != b.urgency:
		return a.urgency > b.urgency
	return _by_recency(a, b)
