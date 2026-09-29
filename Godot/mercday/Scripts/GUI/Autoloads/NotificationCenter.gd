extends Node

#The one notification store. Every system that wants the player's attention pushes a row here and
#the HUD bell, the notification panel and the escalation pass all read this list.
#The center seeds nothing on its own: GameState pushes the contract rows and the finance layer
#registers its own rule for offers and stock moves.

signal changed

#A deadline closer than this becomes URGENT.
const URGENT_HOURS: float = 72.0
#An urgent row that was read re-fires after this many minutes while its trigger is still open.
const REFIRE_MINUTES: int = 480
const FILTER_ALL: String = "All"
const SORT_URGENCY := &"urgency"
const SORT_RECENCY := &"recency"

var items: Array[NotificationData] = []
var rules: Dictionary = {}

var _next_id: int = 1


func push(type: StringName, trigger_id: int, snap: Dictionary = {},
		urgency: int = NotificationData.Urgency.INFORMATIONAL, kind: String = "") -> NotificationData:
	var row: NotificationData = _append(type, trigger_id, snap, urgency, kind, CampaignClock.now())
	changed.emit()
	return row


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


#The row with this id, or null when it is gone.
func by_id(id: int) -> NotificationData:
	for row: NotificationData in items:
		if row.id == id:
			return row
	return null


#Marks every unread row read, or every unread row of one kind.
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


func remove_rule(type: StringName) -> void:
	rules.erase(type)


#Raises every open trigger whose deadline came inside URGENT_HOURS and re-fires a read row.
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
		var open_ids: Array = open_fn.call()
		for raw: Variant in open_ids:
			var trigger_id: int = int(raw)
			if float(hours_fn.call(trigger_id)) >= URGENT_HOURS:
				continue
			if not _needs_urgent(type, trigger_id, now):
				continue
			var snap: Dictionary = {}
			if make_fn.is_valid():
				snap = make_fn.call(trigger_id)
			_drop_rows_of(type, trigger_id)
			_append(type, trigger_id, snap, NotificationData.Urgency.URGENT, kind, now)
			touched = true
	if touched:
		changed.emit()
	return touched


func reset() -> void:
	items.clear()
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


func _by_recency(a: NotificationData, b: NotificationData) -> bool:
	if a.minute != b.minute:
		return a.minute > b.minute
	return a.id > b.id


func _by_urgency(a: NotificationData, b: NotificationData) -> bool:
	if a.urgency != b.urgency:
		return a.urgency > b.urgency
	return _by_recency(a, b)
