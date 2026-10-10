extends Node

#Campaign-lifetime knowledge: which merc uid has seen which token on which other uid,
#plus the directional relationship value each merc holds toward each other merc.
#Every stored relation also carries the campaign day it opened and the day it last moved.
#Memory only; nothing is written to disk.

const RELATION_MIN := 0
const RELATION_MAX := 10

var _next_uid: int = 0
var _known: Dictionary = {}
var _relations: Dictionary = {}  #viewer_uid -> {target_uid -> int}
var _known_since: Dictionary = {}  #viewer_uid -> {target_uid -> campaign day}
var _last_changed: Dictionary = {}  #viewer_uid -> {target_uid -> campaign day}


func next_uid() -> int:
	_next_uid += 1
	return _next_uid


func learn(viewer_uid: int, target_uid: int, token: String) -> void:
	if viewer_uid <= 0 or target_uid <= 0 or token == "":
		return
	if not _known.has(viewer_uid):
		_known[viewer_uid] = {}
	var by_target: Dictionary = _known[viewer_uid]
	if not by_target.has(target_uid):
		by_target[target_uid] = [] as Array[String]
	var tokens: Array = by_target[target_uid]
	if not tokens.has(token):
		tokens.append(token)


func known(viewer_uid: int, target_uid: int) -> Array[String]:
	var result: Array[String] = []
	var by_target: Dictionary = _known.get(viewer_uid, {}) as Dictionary
	for token: String in (by_target.get(target_uid, []) as Array):
		result.append(token)
	return result


func has_relation(viewer_uid: int, target_uid: int) -> bool:
	return (_relations.get(viewer_uid, {}) as Dictionary).has(target_uid)


#-1 means no value is stored for that direction yet.
func relation(viewer_uid: int, target_uid: int) -> int:
	return int((_relations.get(viewer_uid, {}) as Dictionary).get(target_uid, -1))


func set_relation(viewer_uid: int, target_uid: int, value: int) -> void:
	if viewer_uid <= 0 or target_uid <= 0 or viewer_uid == target_uid:
		return
	if not _relations.has(viewer_uid):
		_relations[viewer_uid] = {}
	var by_target: Dictionary = _relations[viewer_uid]
	var clamped: int = clampi(value, RELATION_MIN, RELATION_MAX)
	var first: bool = not by_target.has(target_uid)
	var moved: bool = first or int(by_target[target_uid]) != clamped
	by_target[target_uid] = clamped
	var day: int = TrynnCalendar.day_index(CampaignClock.now())
	if first:
		_stamp(_known_since, viewer_uid, target_uid, day)
	if moved:
		_stamp(_last_changed, viewer_uid, target_uid, day)


#The campaign day the pair's value was first stored; -1 when nothing is stored.
func relation_known_since(viewer_uid: int, target_uid: int) -> int:
	return int((_known_since.get(viewer_uid, {}) as Dictionary).get(target_uid, -1))


#The campaign day the pair's value last moved; -1 when nothing is stored.
func relation_last_changed(viewer_uid: int, target_uid: int) -> int:
	return int((_last_changed.get(viewer_uid, {}) as Dictionary).get(target_uid, -1))


#No-op when the direction has no stored value; returns the value after the change, or -1.
func adjust_relation(viewer_uid: int, target_uid: int, delta: int) -> int:
	if not has_relation(viewer_uid, target_uid):
		return -1
	set_relation(viewer_uid, target_uid, relation(viewer_uid, target_uid) + delta)
	return relation(viewer_uid, target_uid)


func relation_count() -> int:
	var total := 0
	for viewer_uid: int in _relations.keys():
		total += (_relations[viewer_uid] as Dictionary).size()
	return total


func forget(uid: int) -> void:
	_forget_relations(_known, uid)
	_forget_relations(_relations, uid)
	_forget_relations(_known_since, uid)
	_forget_relations(_last_changed, uid)


func clear() -> void:
	_known.clear()
	_relations.clear()
	_known_since.clear()
	_last_changed.clear()


func _stamp(store: Dictionary, viewer_uid: int, target_uid: int, day: int) -> void:
	if not store.has(viewer_uid):
		store[viewer_uid] = {}
	(store[viewer_uid] as Dictionary)[target_uid] = day


func _forget_relations(store: Dictionary, uid: int) -> void:
	store.erase(uid)
	for viewer_uid: int in store.keys():
		(store[viewer_uid] as Dictionary).erase(uid)
