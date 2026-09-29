class_name LockTooltip extends TooltipPanel

#FeatureLock's icon-mode hover tooltip: the "Locked" title plus the two copy lines, wrapped at
#the prototype's 260 px tooltip width.

const BODY_WIDTH: float = 260.0


func _ready() -> void:
	super._ready()
	body_label.custom_minimum_size.x = BODY_WIDTH
