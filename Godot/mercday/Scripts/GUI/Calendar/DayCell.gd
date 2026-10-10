class_name DayCell extends ListRow

#One day of the month grid, drawn on its own face with no child nodes: the day number with "+N" for the
#types past MAX_ICONS at the far end of its line, up to MAX_ICONS event type icons below, a Today chip
#under them, a light tint on weekend days and a dimmed face for past days. A selected cell wears the
#orange frame of ListRow. Everything sits above the vacation bar lanes of WeekBars.

const MAX_ICONS: int = 3
const ICON_GAP: float = 2.0
const PAD: float = 5.0
const ICONS_TOP: float = 26.0
const CHIP_TOP: float = 44.0
const NUMBER_SIZE: int = 14
const CHIP_SIZE: int = 9
const CHIP_PAD: Vector2 = Vector2(3.0, 1.0)
const TODAY_WORD: String = "Today"
const WEEKEND_TINT: Color = Color(GuiColors.LIGHT_BLUE, 0.10)
const PAST_SHADE: Color = Color(0.0, 0.0, 0.0, 0.30)
const NUMBER_COLOR: Color = GuiColors.CREAM
const MORE_COLOR: Color = GuiColors.DIM_TEXT
const CHIP_FILL: Color = GuiColors.ORANGE
const CHIP_TEXT: Color = GuiColors.INK

#Day index of the cell; -1 for a slot past the end of the month.
var day: int = -1
var is_today: bool = false
var past: bool = false
var weekend: bool = false
#The icon ids drawn, one per event type in source order, and how many more types the day holds.
var shown_icons: Array[String] = []
var more: int = 0


func _init() -> void:
	super()
	focus_mode = Control.FOCUS_NONE
	clip_contents = true


#day_of_month is the number drawn; events are that day's CalendarEvents.
func show_day(day_index: int, day_of_month: int, today: int, is_weekend: bool, events: Array[CalendarEvent]) -> void:
	day = day_index
	text = str(day_of_month)
	is_today = day_index == today
	past = day_index < today
	weekend = is_weekend
	shown_icons.clear()
	var seen: Array[StringName] = []
	for event: CalendarEvent in events:
		if seen.has(event.source.type):
			continue
		seen.append(event.source.type)
		if shown_icons.size() < MAX_ICONS:
			shown_icons.append(event.source.icon_id)
	more = seen.size() - shown_icons.size()
	queue_redraw()


func more_text() -> String:
	return "+%d" % more if more > 0 else ""


#The face boxes in cell coordinates, also read by the layout checks.
func number_rect() -> Rect2:
	return Rect2(Vector2(PAD, PAD), _text_size(text, NUMBER_SIZE))


func more_rect() -> Rect2:
	var span: Vector2 = _text_size(more_text(), CHIP_SIZE)
	return Rect2(Vector2(size.x - PAD - span.x, PAD), span)


func today_rect() -> Rect2:
	return Rect2(Vector2(PAD, CHIP_TOP), (_text_size(TODAY_WORD, CHIP_SIZE) + CHIP_PAD * 2.0).ceil())


func _draw_face(rect: Rect2) -> void:
	if weekend:
		draw_rect(rect.grow(-edge), WEEKEND_TINT)
	var font: Font = GuiStyle.SILK_BOLD
	_draw_text(font, number_rect(), text, NUMBER_SIZE, _fx.label(NUMBER_COLOR))
	if more > 0:
		_draw_text(font, more_rect(), more_text(), CHIP_SIZE, MORE_COLOR)
	var at := Vector2(PAD, ICONS_TOP)
	for id: String in shown_icons:
		Icons.draw(self, id, at)
		at.x += Icons.CELL + ICON_GAP
	if is_today:
		var chip: Rect2 = today_rect()
		draw_rect(chip, CHIP_FILL)
		_draw_text(font, chip.grow_individual(-CHIP_PAD.x, -CHIP_PAD.y, 0.0, 0.0), TODAY_WORD, CHIP_SIZE, CHIP_TEXT)
	if past:
		draw_rect(rect.grow(-edge), PAST_SHADE)


func _draw_text(font: Font, box: Rect2, line: String, font_size: int, tint: Color) -> void:
	draw_string(font, box.position + Vector2(0.0, font.get_ascent(font_size)), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		font_size, tint)


func _text_size(line: String, font_size: int) -> Vector2:
	return GuiStyle.SILK_BOLD.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
