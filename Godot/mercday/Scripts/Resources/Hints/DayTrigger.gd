class_name DayTrigger extends HintTrigger

#Met once the campaign day index reaches min_day.

@export var min_day: int = 1


func is_met() -> bool:
	return GameState.day() >= min_day


func watch(on_change: Callable) -> void:
	var relay: Callable = on_change.unbind(1)
	if not GameState.day_changed.is_connected(relay):
		GameState.day_changed.connect(relay)


func problems() -> PackedStringArray:
	if min_day < 1:
		return PackedStringArray(["DayTrigger min_day %d is below 1" % min_day])
	return PackedStringArray()
