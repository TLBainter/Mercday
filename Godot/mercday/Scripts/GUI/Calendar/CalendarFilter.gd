class_name CalendarFilter extends GridContainer

#One check row per distinct event type of the dialog's sources, ticked while the type is shown. A
#toggle writes CalendarEvents.set_enabled; the filter set itself lives there.

signal filters_changed

#Type to its FilterCheckRow.
var rows: Dictionary = {}


func build(sources: Array[CalendarSource]) -> void:
	for child: Node in get_children():
		child.queue_free()
	rows.clear()
	for source: CalendarSource in sources:
		if rows.has(source.type):
			continue
		var row: FilterCheckRow = FilterCheckRow.make_check(source.label, CalendarEvents.enabled(source.type), source.icon_id)
		row.name = "Filter_%s" % source.type
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.toggled.connect(_on_toggled.bind(source.type))
		add_child(row)
		rows[source.type] = row


#Ticks each row to the shared filter set, without a toggle going out.
func sync() -> void:
	for type: StringName in rows:
		var row: FilterCheckRow = rows[type]
		row.set_pressed_no_signal(CalendarEvents.enabled(type))
		row.on = CalendarEvents.enabled(type)


func _on_toggled(on: bool, type: StringName) -> void:
	CalendarEvents.set_enabled(type, on)
	filters_changed.emit()
