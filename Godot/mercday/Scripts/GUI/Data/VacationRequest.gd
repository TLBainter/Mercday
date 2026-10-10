class_name VacationRequest extends RefCounted

#One vacation, mailed or not: whose, when, how long and where it stands. Days are TrynnCalendar day
#indexes (GameState.day() values). TAKEN reads as approved.

enum State {PENDING, APPROVED, DENIED, REJECTED, TAKEN, CANCELLED, MERGED}

#The states a calendar span shows.
const LIVE_STATES: Array[int] = [State.PENDING, State.APPROVED, State.TAKEN]

#The request mail; &"" for a row made with approval OFF.
var mail_id: StringName = &""
var merc_uid: int = -1
var start_day: int = 0
var days: int = 0
var state: int = State.PENDING
var asked_day: int = 0
#The next reminder day; -1 when none is due.
var remind_day: int = -1
#True when made with approval OFF.
var auto: bool = false
#Vacation days already added to vacation_taken.
var counted: int = 0


func end_day() -> int:
	return start_day + days - 1


func is_live() -> bool:
	return LIVE_STATES.has(state)


func overlaps(from_day: int, to_day: int) -> bool:
	return start_day <= to_day and end_day() >= from_day
