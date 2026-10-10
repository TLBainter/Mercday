@tool
class_name ToolOptionDropdown extends OptionDropdown

#OptionDropdown for editor tools: the @tool subclass makes the editor run the original's code on this node.
#The caret icon reads the Icons tables, so _init primes them first; OptionDropdown has no _init of its own.
#Edit ToolOptionDropdown.tscn as text and never save it from the scene editor: that save writes runtime state into it.


func _init() -> void:
	ToolIcons.prime()
