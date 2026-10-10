@tool
class_name ToolModalDialog extends ModalDialog

#ModalDialog for editor tools, made from ToolModalDialog.tscn; its close X reads Icons, so _init primes them.
#The editor has no UiSfx autoload, so there present and close skip the summon and dismiss sounds.


func _init() -> void:
	ToolIcons.prime()


func present() -> void:
	if not visible and not Engine.is_editor_hint():
		UiSfx.play_summon(summon_sfx)
	show()
	_layout()
	GuiFrameStack.push(self)
	_on_present()


func close() -> void:
	if visible and not Engine.is_editor_hint():
		UiSfx.play_dismiss(dismiss_sfx)
	hide()
	GuiFrameStack.remove(self)
	closed.emit()
	if free_on_close:
		queue_free()
