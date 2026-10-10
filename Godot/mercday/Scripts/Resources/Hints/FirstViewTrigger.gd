class_name FirstViewTrigger extends HintTrigger

#Always met: the hint shows the first time its target is visible in the topmost scope, the gate
#every hint already has.


func is_met() -> bool:
	return true


func problems() -> PackedStringArray:
	return PackedStringArray()
