class_name TimeHold extends Node

#Child of a screen that freezes campaign time while the screen shows. It holds the clock whenever the
#parent is visible in the tree and lets go when the parent hides or leaves the tree.


func _ready() -> void:
	get_parent().visibility_changed.connect(_sync)
	_sync()


func _exit_tree() -> void:
	GameState.release_time(self)


func _sync() -> void:
	if (get_parent() as CanvasItem).is_visible_in_tree():
		GameState.hold_time(self)
	else:
		GameState.release_time(self)
