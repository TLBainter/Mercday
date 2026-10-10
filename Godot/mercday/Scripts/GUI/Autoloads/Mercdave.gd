extends Node

#The MercDave assistant state: which hints the player read, the scope the overlay last reported, the
#unread badge, a marker per unread hint on screen and the open card. A hint is read once its card opens. Read
#state lives in memory only, so hints return each launch; nothing is written to user://.

signal changed
#New text on the card: a hint opened from a closed card, a different hint, or Tell Me More.
signal spoke

const LAYER_GROUP: StringName = &"mercdave_layer"
const SYS_FACE: int = 2

var scope_key: StringName = &""
var unread: Array[StringName] = []
var marks: Array[StringName] = []
var current: StringName = &""
var showing_more: bool = false
var card_open: bool = false
#The shown hint's 0-based place in its chain and the chain length; -1 and 0 when it opened already read.
var step: int = -1
var step_total: int = 0

var _read: Dictionary = {}
var _card_scope: StringName = &""
#The index in marks of the mark that followed the shown one, wrapped to 0 past the end; -1 when none.
var _next: int = -1


func _ready() -> void:
	HintBook.ensure_loaded()


func is_read(id: StringName) -> bool:
	return _read.has(id)


func is_available(id: StringName) -> bool:
	return HintBook.is_valid(id) and HintBook.hint(id).trigger.is_met()


#Asks the overlay layer for one scan on the next idle frame; repeat requests in a frame merge.
func request_scan() -> void:
	get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED | SceneTree.GROUP_CALL_UNIQUE, LAYER_GROUP, &"scan")


#The layer's scan report: ids whose targets sit in the topmost scope, and the subset on screen.
func set_scope(key: StringName, present_ids: Array[StringName], visible_ids: Array[StringName]) -> void:
	var fresh: Array[StringName] = []
	for id: StringName in HintBook.ids():
		if present_ids.has(id) and not is_read(id) and is_available(id):
			fresh.append(id)
	var shown: Array[StringName] = []
	for id: StringName in fresh:
		if visible_ids.has(id):
			shown.append(id)
	var moved: bool = key != scope_key or fresh != unread or shown != marks
	scope_key = key
	unread = fresh
	marks = shown
	if card_open and (key != _card_scope or (current != HintBook.SYS_NONE and not present_ids.has(current))):
		_shut()
		moved = true
	if moved:
		changed.emit()


#Opens the card on id and marks it read; the counter counts this read: 1 of N at open, Next Hint steps on and wraps.
func show_hint(id: StringName, chained: bool = false) -> void:
	var at: int = marks.find(id)
	if id != HintBook.SYS_NONE and not is_read(id):
		if chained:
			step += 1
		else:
			step = 0
			step_total = marks.size()
		_read[id] = true
		unread.erase(id)
		marks.erase(id)
		if chained:
			step_total = maxi(step_total, step + 1 + marks.size())
		_next = at if at < marks.size() else 0
	elif id != current or not card_open:
		step = -1
		step_total = 0
		_next = -1
	var fresh: bool = not card_open or id != current
	current = id
	showing_more = false
	card_open = true
	_card_scope = scope_key
	changed.emit()
	if fresh:
		spoke.emit()


func has_next() -> bool:
	return _next >= 0 and not marks.is_empty()


#Ok closes the card; the hint was read when it opened.
func ok() -> void:
	_shut()
	changed.emit()
	request_scan()


#Next Hint: shows the mark after the shown hint, wrapping to the first remaining; the card closes when none remains.
func next_hint() -> void:
	if not card_open or current == HintBook.SYS_NONE or current == &"":
		return
	if has_next():
		show_hint(marks[_next] if _next < marks.size() else marks[0], true)
	else:
		close()
	request_scan()


func tell_more() -> void:
	if not card_open or showing_more or not HintBook.has_more(current):
		return
	showing_more = true
	changed.emit()
	spoke.emit()


#The tab press: closes an open card, else opens the first marker or the no-hints card.
func toggle() -> void:
	if card_open:
		close()
	else:
		show_hint(HintBook.SYS_NONE if marks.is_empty() else marks[0])


func close() -> void:
	_shut()
	changed.emit()


#The opinion face the card shows: the hint face, more_level() during Tell Me More, 2 for sys_none.
func face_level() -> int:
	var shown_hint: MercdaveHint = HintBook.hint(current)
	if shown_hint == null:
		return SYS_FACE
	return shown_hint.more_level() if showing_more else shown_hint.face


#Test suites only: forgets read hints and the card.
func reset_for_tests() -> void:
	_read.clear()
	scope_key = &""
	unread.clear()
	marks.clear()
	_shut()
	changed.emit()


func _shut() -> void:
	card_open = false
	current = &""
	showing_more = false
	_card_scope = &""
	step = -1
	step_total = 0
	_next = -1
