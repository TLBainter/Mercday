class_name StockMoveBody extends Label

#The body of a stock move row: one line with the signed percent, in the row's own colour.

const SINCE_TEXT: String = "% since you last checked"

var _row: NotificationData = null


func _ready() -> void:
	_refresh()


func apply(data: NotificationData) -> void:
	_row = data
	_refresh()


func line_text() -> String:
	if _row == null:
		return ""
	var sign_text: String = "+" if _row.rising() else "-"
	return sign_text + ("%.1f" % absf(_row.pct())) + SINCE_TEXT


func line_color() -> Color:
	if _row == null:
		return NotificationData.TITLE_STOCK_UP
	return _row.title_color()


func _refresh() -> void:
	text = line_text()
	add_theme_color_override("font_color", line_color())
