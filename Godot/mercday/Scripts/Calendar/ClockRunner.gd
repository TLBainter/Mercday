class_name ClockRunner extends Node

#Drives campaign time from real seconds. Every whole real second at a running speed the clock
#moves to the next multiple of the step strictly above now, so a speed change snaps onto the new
#grid and every later tick adds one full step. All grids are anchored at minute 0, which puts the
#8 hour grid on 0:00, 8:00 and 16:00. A tick that runs long drops the seconds it covered instead
#of catching them up, so the clock never races after a battle.

enum Speed {SLOW, PAUSE, PLAY, FAST, VERY_FAST}

const STEPS: Array[int] = [1, 0, 5, 60, 480]

signal speed_changed(speed: int)
signal ticked(from_minute: int, to_minute: int)
signal day_changed(day_index: int)
signal month_changed(year: int, month: int)

var speed: int = Speed.PAUSE
#GameState sets this to its ordered processor; unset, a tick only moves the clock.
var processor: Callable = Callable()
var busy: bool = false

var _accumulated: float = 0.0


func set_speed(level: int) -> void:
	speed = clampi(level, 0, STEPS.size() - 1)
	_accumulated = 0.0
	speed_changed.emit(speed)


#The next multiple of the current step strictly above now; the current minute while paused.
func next_target() -> int:
	var step: int = STEPS[speed]
	if step <= 0:
		return CampaignClock.now()
	return (int(CampaignClock.now() / float(step)) + 1) * step


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
