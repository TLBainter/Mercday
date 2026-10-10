@tool
class_name ToolIcons extends RefCounted

#The editor skips the static init of a script without @tool, so Icons starts with empty tables there.
#Tool widgets call prime() before they draw an icon; in the game the tables are already filled.


static func prime() -> void:
	if Engine.is_editor_hint() and Icons.ids().is_empty():
		Icons._static_init()
