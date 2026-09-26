class_name ChartTooltip extends TooltipPanel

#The chart hover tooltip: the day of the hovered bucket and one line per plotted series.


#rows are {label, value}; the value is already formatted.
func set_point(day: int, rows: Array[Dictionary]) -> void:
	var lines: Array[String] = []
	for row: Dictionary in rows:
		lines.append("%s: %s" % [String(row.get("label", "")), String(row.get("value", ""))])
	set_text("Day %d" % day, "\n".join(lines))
