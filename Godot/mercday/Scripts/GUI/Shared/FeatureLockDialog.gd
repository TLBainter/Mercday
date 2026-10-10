class_name FeatureLockDialog extends ModalDialog

#The "you need a bigger plan" modal: the dialog chrome with a gold ring instead of orange around a
#LockPanel, whose Take Me There hands off to the Plans screen or, when the guild already holds
#Enterprise, to the Customize upgrade.

signal take_me_there(target: Dictionary)

const BOX_WIDTH: float = 520.0
const ICON_SCALE: int = LockPanel.ICON_SCALE

@onready var lock_panel: LockPanel = $Box/Pad/Rows/Lock
@onready var lock_icon: TextureRect = $Box/Pad/Rows/Lock/IconRow/LockIcon
@onready var line1_label: Label = $Box/Pad/Rows/Lock/Line1
@onready var line2_label: Label = $Box/Pad/Rows/Lock/Line2
@onready var take_me_there_button: Button = $Box/Pad/Rows/Lock/Buttons/TakeMeThere


func _ready() -> void:
	super()
	ring_color = GuiColors.LOCK_GOLD
	button_row.hide()
	lock_panel.take_me_there.connect(_on_take_me_there)


func open_for(lock: FeatureLock) -> void:
	if lock == null:
		return
	open(FeatureLock.to_props(lock))


func open(props: Dictionary) -> void:
	lock_panel.set_lock(props)
	present()


func press_take_me_there() -> void:
	lock_panel.press_take_me_there()


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)
	close()
