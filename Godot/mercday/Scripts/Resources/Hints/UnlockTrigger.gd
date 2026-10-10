class_name UnlockTrigger extends HintTrigger

#Met while the guild holds an entitlement: a flag key that is true, or a numeric key at tier or above.

@export var entitlement: String = ""
@export var tier: int = 1


func is_met() -> bool:
	return entitlement != "" and FeatureLock.entitled(entitlement, tier)


func watch(on_change: Callable) -> void:
	if not SubscriptionManager.changed.is_connected(on_change):
		SubscriptionManager.changed.connect(on_change)


func problems() -> PackedStringArray:
	if entitlement == "":
		return PackedStringArray(["UnlockTrigger has no entitlement"])
	return PackedStringArray()
