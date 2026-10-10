class_name LockGate extends Node

#Follows the guild's plan for one MercLocks key while it sits in the tree: it says whether the key is
#shut, fills a FeatureLock from the key's row and emits changed on every plan change. A gate with no
#key is never shut, so a screen that only repaints on a plan change holds one for the signal alone.
#It listens from the moment its host is ready, so every FeatureLock inside the host hears a plan
#change first and the host has the last word on what shows.

signal changed

@export var lock_key: String = ""
@export var lock_height: float = MercLocks.LOCK_HEIGHT


func _enter_tree() -> void:
	var host: Node = get_parent()
	if host.is_node_ready():
		_listen()
	else:
		host.ready.connect(_listen, CONNECT_ONE_SHOT)


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(_on_plan_changed):
		SubscriptionManager.changed.disconnect(_on_plan_changed)


func is_locked() -> bool:
	return MercLocks.locked(lock_key, SubscriptionManager.entitlements())


#An empty or unknown key leaves the lock as it was, so the lock of a free row keeps its defaults.
func fill(lock: FeatureLock, label: String = "") -> void:
	MercLocks.apply(lock, lock_key, lock_height, label)


func _listen() -> void:
	SubscriptionManager.changed.connect(_on_plan_changed)


func _on_plan_changed() -> void:
	changed.emit()
