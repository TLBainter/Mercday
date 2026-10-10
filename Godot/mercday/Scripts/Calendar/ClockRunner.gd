class_name ClockRunner extends Node

#Drives campaign time from real seconds. Every whole real second at a running speed the clock
#moves to the next multiple of the step strictly above now, so a speed change snaps onto the new
#grid and every later tick adds one full step. All grids are anchored at minute 0, which puts the
#60 minute grid on every full hour and the 15 minute grid on :00, :15, :30 and :45. A tick that
#runs long drops the seconds it covered instead of catching them up, so the clock never races
#after a battle. From DAY_END to DAY_START the day rates give way to AFTER_HOURS_STEPS, and the
#fastest speed jumps straight to the next DAY_START instead of stepping. A screen that needs time
#frozen calls hold() and release(); the first hold pauses and the last release restores the speed
#from before it, and a set_speed during a hold only changes the speed that comes back.

enum Speed {SLOW, PAUSE, PLAY, FAST, VERY_FAST}

const STEPS: Array[int] = [1, 0, 5, 15, 60]
const AFTER_HOURS_STEPS: Array[int] = [1, 0, 30, 60, 0]
const DAY_START: int = 480
const DAY_END: int = 1080

signal speed_changed(speed: int)
signal hold_changed(held: bool)
signal ticked(from_minute: int, to_minute: int)
signal day_changed(day_index: int)
signal month_changed(year: int, month: int)

var speed: int = Speed.PAUSE
#GameState sets this to its ordered processor; unset, a tick only moves the clock.
var processor: Callable = Callable()
var busy: bool = false

var _accumulated: float = 0.0
var _holders: Dictionary = {}
var _held_speed: int = Speed.PAUSE


func set_speed(level: int) -> void:
	level = clampi(level, 0, STEPS.size() - 1)
	if is_held():
		_held_speed = level
		return
	speed = level
	_accumulated = 0.0
	speed_changed.emit(speed)


func is_held() -> bool:
	return not _holders.is_empty()


#Freezes time for holder; a second hold by the same holder changes nothing.
func hold(holder: Object) -> void:
	var key: int = holder.get_instance_id()
	if _holders.has(key):
		return
	var was_held: bool = is_held()
	_holders[key] = true
	if was_held:
		return
	_held_speed = speed
	if speed != Speed.PAUSE:
		speed = Speed.PAUSE
		_accumulated = 0.0
		speed_changed.emit(speed)
	hold_changed.emit(true)


#Drops the hold of holder; the last one out brings back the speed from before the first.
func release(holder: Object) -> void:
	if not _holders.erase(holder.get_instance_id()) or is_held():
		return
	if speed != _held_speed:
		speed = _held_speed
		_accumulated = 0.0
		speed_changed.emit(speed)
	hold_changed.emit(false)


static func is_after_hours(minute: int) -> bool:
	var of_day: int = TrynnCalendar.minute_of_day(minute)
	return of_day >= DAY_END or of_day < DAY_START


#The next multiple of the current step strictly above now; the current minute while paused. After
#hours the step comes from AFTER_HOURS_STEPS, and a zero there on a running speed means a jump to
#the next DAY_START.
func next_target() -> int:
	var now: int = CampaignClock.now()
	var step: int = STEPS[speed]
	if step <= 0:
		return now
	if is_after_hours(now):
		step = AFTER_HOURS_STEPS[speed]
		if step <= 0:
			var day_start: int = TrynnCalendar.day_index(now) * CampaignClock.MINUTES_PER_DAY + DAY_START
			return day_start if now < day_start else day_start + CampaignClock.MINUTES_PER_DAY
	return (int(now / float(step)) + 1) * step


#One step of campaign time. Ignored while paused or while a previous tick is still running.
func tick() -> void:
	if busy or STEPS[speed] <= 0:
		return
	busy = true
	var from_minute: int = CampaignClock.now()
	var target: int = next_target()
	if processor.is_valid():
		await processor.call(target)
	else:
		CampaignClock.advance_to(target)
	var to_minute: int = CampaignClock.now()
	ticked.emit(from_minute, to_minute)
	_emit_boundaries(from_minute, to_minute)
	busy = false


func _process(delta: float) -> void:
	if speed == Speed.PAUSE or busy:
		return
	_accumulated += delta
	if _accumulated < 1.0:
		return
	_accumulated = 0.0
	tick()


#One day_changed per day boundary crossed and one month_changed per month boundary crossed.
func _emit_boundaries(from_minute: int, to_minute: int) -> void:
	var first: int = TrynnCalendar.day_index(from_minute)
	var last: int = TrynnCalendar.day_index(to_minute)
	for day: int in range(first + 1, last + 1):
		day_changed.emit(day)
	var start: int = TrynnCalendar.next_month_start(from_minute)
	while start <= to_minute:
		var date: Dictionary = TrynnCalendar.date_of(start)
		month_changed.emit(int(date["year"]), int(date["month"]))
		start = TrynnCalendar.next_month_start(start)
