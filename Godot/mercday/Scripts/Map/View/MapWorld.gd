@tool
class_name MapWorld extends Node3D

#Root of Scenes/Map/World.tscn, the one map world: hand-owned, never written by a tool.
#The game instances it through MapView.tscn; MapWorld._ready is the only bind_globals caller.


func _ready() -> void:
	if not MapData.has_bake():
		push_warning("MapWorld: no baked terrain at " + MapData.TERRAIN_INDEX)
		return
	MapWorldBind.bind_globals()
	if Engine.is_editor_hint() and not ProjectSettings.settings_changed.is_connected(_rebind):
		ProjectSettings.settings_changed.connect(_rebind)


func _rebind() -> void:
	MapWorldBind.bind_globals()
