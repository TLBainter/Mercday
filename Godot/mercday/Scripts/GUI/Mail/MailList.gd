class_name MailList extends ListPanel

#The mail of one folder, newest first, with the Archived toggle in the head. A row press reports its id through
#picked; the rows are rebuilt only when the listed ids change, else redrawn in place.

signal picked(id: StringName)
signal archived_toggled(on: bool)

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Mail/MailRow.tscn")

@export var archived_path: NodePath

var archived_button: BevelButton = null
var _rows: Array[MailRow] = []
var _ids: Array[StringName] = []


func _ready() -> void:
	super()
	archived_button = get_node(archived_path) as BevelButton
	archived_button.toggled.connect(_on_archived_toggled)


func set_mail(list: Array[MailInstance], selected: StringName = &"") -> void:
	var ids: Array[StringName] = []
	var unread: int = 0
	for m: MailInstance in list:
		ids.append(m.id)
		unread += 0 if m.read else 1
	if ids != _ids:
		clear_items()
		_rows.clear()
		for m: MailInstance in list:
			var row: MailRow = ROW_SCENE.instantiate() as MailRow
			items().add_child(row)
			row.set_mail(m)
			row.pressed.connect(_on_row_pressed.bind(m.id))
			_rows.append(row)
		_ids = ids
	else:
		for i: int in _rows.size():
			_rows[i].set_mail(list[i])
	select_id(selected)
	head.count_text = "%d emails . %d unread" % [list.size(), unread]


func select_id(id: StringName) -> void:
	for row: MailRow in _rows:
		row.selected = row.mail != null and row.mail.id == id


func row_for(id: StringName) -> MailRow:
	for row: MailRow in _rows:
		if row.mail != null and row.mail.id == id:
			return row
	return null


func rows() -> Array[MailRow]:
	return _rows.duplicate()


func is_archived() -> bool:
	return archived_button.button_pressed


#Sets the toggle without reporting it, for a viewer that jumps to an archived mail.
func set_archived(on: bool) -> void:
	archived_button.set_pressed_no_signal(on)


func _on_archived_toggled(on: bool) -> void:
	archived_toggled.emit(on)


func _on_row_pressed(id: StringName) -> void:
	picked.emit(id)
