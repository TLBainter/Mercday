extends Node

#Campaign-lifetime knowledge: which merc uid has seen which token on which other uid,
#plus the directional relationship value each merc holds toward each other merc.
#Memory only; nothing is written to disk.

const RELATION_MIN := 0
const RELATION_MAX := 10

var _next_uid: int = 0
var _known: Dictionary = {}
var _relations: Dictionary = {}  #viewer_uid -> {target_uid -> int}


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
	(_relations[viewer_uid] as Dictionary)[target_uid] = clampi(value, RELATION_MIN, RELATION_MAX)


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
	_known.erase(uid)
	for viewer_uid: int in _known.keys():
		(_known[viewer_uid] as Dictionary).erase(uid)
	_relations.erase(uid)
	for viewer_uid: int in _relations.keys():
		(_relations[viewer_uid] as Dictionary).erase(uid)


func clear() -> void:
	_known.clear()
	_relations.clear()

