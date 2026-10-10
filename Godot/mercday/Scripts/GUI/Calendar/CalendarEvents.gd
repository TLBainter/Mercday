class_name CalendarEvents extends RefCounted

#Collects the events and bars of every source for a day range, leaving out the types the filter
#turned off. The filter set lives for the session only; nothing is written to disk.

signal changed

#Type to true for every type the filter turned off.
static var _off: Dictionary = {}

var _sources: Array[CalendarSource] = []
#[Signal, Callable] pairs connected by watch(true).
var _links: Array[Array] = []


func _init(sources: Array[CalendarSource]) -> void:
	_sources = sources.duplicate()


static func set_enabled(type: StringName, on: bool) -> void:
	if on:
		_off.erase(type)
	else:
		_off[type] = true


static func enabled(type: StringName) -> bool:
	return not _off.has(type)


#Day index to Array[CalendarEvent] for d0 through d1, in source order, enabled types only.
func by_day(d0: int, d1: int) -> Dictionary:
	var out: Dictionary = {}
	for source: CalendarSource in _sources:
		if not enabled(source.type):
			continue
		for event: CalendarEvent in source.events_between(d0, d1):
			if not CalendarSource.within(event.day, d0, d1):
				continue
			if not out.has(event.day):
				var list: Array[CalendarEvent] = []
				out[event.day] = list
			(out[event.day] as Array[CalendarEvent]).append(event)
	return out


#The bars of every enabled source for d0 through d1.
func spans(d0: int, d1: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for source: CalendarSource in _sources:
		if enabled(source.type):
			out.append_array(source.spans_between(d0, d1))
	return out


#Connects every source's change signals to changed, once per signal; false disconnects them all.
func watch(on: bool) -> void:
	for link: Array in _links:
		var sig: Signal = link[0]
		var relay: Callable = link[1]
		if sig.is_connected(relay):
			sig.disconnect(relay)
	_links.clear()
	if not on:
		return
	var seen: Array[Signal] = []
	for source: CalendarSource in _sources:
		for sig: Signal in source.change_signals():
			if seen.has(sig):
				continue
			seen.append(sig)
			var count: int = _arg_count(sig)
			var relay: Callable = changed.emit.unbind(count) if count > 0 else Callable(changed.emit)
			sig.connect(relay)
			_links.append([sig, relay])


static func _arg_count(sig: Signal) -> int:
	for row: Dictionary in sig.get_object().get_signal_list():
		if StringName(row["name"]) == sig.get_name():
			return (row["args"] as Array).size()
	return 0
