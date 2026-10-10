@tool
class_name ToolTabButton extends TabButton

#TabButton for editor tools. The script swap in ToolTabButton.tscn writes the placeholder's export
#defaults over what TabButton._init set, so _ready copies those fx values back from a fresh TabButton.
#Edit ToolTabButton.tscn as text and never save it from the scene editor: that save writes runtime state into it.

const FX_EXPORTS: Array[StringName] = [&"click_move", &"click_shade", &"hover_move", &"hover_shade",
	&"stay_move", &"stay_shade", &"active_move", &"active_shade"]


func _init() -> void:
	ToolIcons.prime()
	super()


func _ready() -> void:
	if Engine.is_editor_hint():
		var fresh: TabButton = TabButton.new()
		for key: StringName in FX_EXPORTS:
			set(key, fresh.get(key))
		fresh.free()
	super()
