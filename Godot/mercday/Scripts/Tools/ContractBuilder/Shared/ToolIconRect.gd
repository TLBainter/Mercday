@tool
class_name ToolIconRect extends IconRect

#IconRect for editor tools; fills the Icons tables before the first bake.


func _init() -> void:
	ToolIcons.prime()
