class_name TriggerGroup extends HintTrigger

#AND or OR over child triggers; a child may be another group, so groups nest.

const MODE_AND: int = 0
const MODE_OR: int = 1

@export_enum("AND", "OR") var mode: int = MODE_AND
@export var triggers: Array[HintTrigger] = []


func is_met() -> bool:
	if triggers.is_empty():
		return false
	for child: HintTrigger in triggers:
		var met: bool = child != null and child.is_met()
		if mode == MODE_OR and met:
			return true
		if mode == MODE_AND and not met:
			return false
	return mode == MODE_AND


func watch(on_change: Callable) -> void:
	for child: HintTrigger in triggers:
		if child != null:
			child.watch(on_change)


func problems() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if triggers.is_empty():
		out.append("TriggerGroup has no triggers")
	for i: int in range(triggers.size()):
		if triggers[i] == null:
			out.append("TriggerGroup entry %d is empty" % (i + 1))
		else:
			out.append_array(triggers[i].problems())
	return out
