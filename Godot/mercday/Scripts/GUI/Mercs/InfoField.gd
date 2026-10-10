class_name InfoField extends PanelContainer

#A captioned read-only row of the Overview tab, the header lineage boxes, the contract issuer boxes
#and the Dispatch preview column. Plain rows print a value string; the salary and the level mode rows
#hand a widget to the slot instead and leave the value blank. A row whose entitlement key is unmet
#keeps its caption and shows the lock where its value would read.

@export var caption: String = "":
	set(value):
		caption = value
		_refresh()
@export var value: String = "":
	set(new_value):
		value = new_value
		_refresh()
#The MercLocks key that gates the value, or "" for a row every plan may read.
@export var lock_key: String = "":
	set(value):
		lock_key = value
		gate.lock_key = value
		_refresh()
@export var caption_variation: StringName = &"SmallLabel":
	set(variation):
		caption_variation = variation
		_refresh()
@export var value_variation: StringName = &"":
	set(variation):
		value_variation = variation
		_refresh()
#A row in a narrow column cuts a long value instead of widening the column.
@export var clip_value: bool = false:
	set(on):
		clip_value = on
		_refresh()
#Lights the notes glyph after the value, as the money rows of the Dispatch preview do.
@export var show_note: bool = false:
	set(on):
		show_note = on
		_refresh()
#A colour with zero alpha leaves the value in its theme colour.
@export var value_color: Color = Color(0, 0, 0, 0):
	set(color):
		value_color = color
		_refresh()

@onready var caption_label: Label = $Rows/Caption
@onready var line: HBoxContainer = $Rows/Line
@onready var value_label: Label = $Rows/Line/Value
@onready var note_icon: NoteIcon = $Rows/Line/Note
@onready var slot: VBoxContainer = $Rows/Slot
@onready var lock: FeatureLock = $Rows/Lock

var gate: LockGate = LockGate.new()


func _init() -> void:
	add_child(gate, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	gate.changed.connect(_refresh)
	_refresh()


func set_field(new_caption: String, new_value: String) -> void:
	caption = new_caption
	value = new_value


func add_widget(node: Control) -> void:
	if not is_node_ready():
		return
	slot.add_child(node)
	slot.visible = true


func value_text() -> String:
	return value_label.text if is_node_ready() else value


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption
	caption_label.theme_type_variation = caption_variation
	value_label.theme_type_variation = value_variation
	value_label.clip_text = clip_value
	if value_color.a > 0.0:
		value_label.add_theme_color_override("font_color", value_color)
	elif value_label.has_theme_color_override("font_color"):
		value_label.remove_theme_color_override("font_color")
	var shut: bool = gate.is_locked()
	value_label.text = value
	value_label.visible = value != "" and not shut
	note_icon.visible = show_note and not shut
	line.visible = value_label.visible or note_icon.visible
	gate.fill(lock)
	lock.visible = shut
	slot.visible = slot.get_child_count() > 0 and not shut
