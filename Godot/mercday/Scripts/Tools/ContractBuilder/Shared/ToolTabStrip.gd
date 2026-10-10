@tool
class_name ToolTabStrip extends TabStrip

#TabStrip for editor tools: build() is TabStrip.build() with the tool tab scene in place of TAB_SCENE.

const TOOL_TAB_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolTabButton.tscn")


func build() -> void:
	for old: TabButton in _buttons:
		remove_child(old)
		old.queue_free()
	_buttons.clear()
	for i: int in keys.size():
		var tab: TabButton = TOOL_TAB_SCENE.instantiate() as TabButton
		tab.name = String(keys[i])
		add_child(tab)
		tab.index = i
		tab.label = _entry(labels, i)
		tab.description = _entry(tips, i)
		tab.icon_id = _entry(icon_ids, i)
		tab.icon_scale = icon_scale
		tab.idle_mode = idle_mode
		tab.label_always = label_always
		tab.active = keys[i] == _active
		tab.tab_pressed.connect(_on_tab_pressed)
		_buttons.append(tab)
