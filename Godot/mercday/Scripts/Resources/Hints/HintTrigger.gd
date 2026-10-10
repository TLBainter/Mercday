class_name HintTrigger extends Resource

#The base of every MercDave hint trigger: whether its condition holds, the signals that can change
#that answer, and its data problems. A hint needs one; this base alone never fires.


func is_met() -> bool:
	return false


#Connects on_change to every signal that can change is_met(), once each.
func watch(_on_change: Callable) -> void:
	pass


func problems() -> PackedStringArray:
	return PackedStringArray(["abstract trigger"])
