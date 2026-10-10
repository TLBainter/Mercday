class_name SpeedButton extends BarIconButton

#One clock speed toggle. The face is the atlas icon of its own speed, drawn by BarIconButton. The
#owner (TimeMenu) manages which button in the group is pressed; this atom only reports its own click
#as a speed pick.

signal speed_selected(mode: int)

const LABELS: Dictionary = {
	0: "Slow",
	1: "Pause",
	2: "Play",
	3: "Fast Forward",
	4: "Fastest",
}

const ICON_IDS: Dictionary = {
	0: "speed_slow",
	1: "pause",
	2: "play",
	3: "speed_fast",
	4: "speed_faster",
}

@export var speed_mode: ClockRunner.Speed = ClockRunner.Speed.PLAY:
	set(value):
		speed_mode = value
		_refresh()


func _ready() -> void:
	super()
	pressed.connect(_on_pressed)
	_refresh()


func _on_pressed() -> void:
	speed_selected.emit(speed_mode)


func _refresh() -> void:
	if not is_node_ready():
		return
	tooltip_text = tooltip_for(speed_mode)
	queue_redraw()


static func label_for(mode: int) -> String:
	return String(LABELS.get(mode, ""))


#The label, then the clock rate in brackets, with the after hours rate when it differs; Pause has no
#rate and keeps the bare label.
static func tooltip_for(mode: int) -> String:
	var rate: String = rate_text(mode)
	if rate == "":
		return label_for(mode)
	var after: String = after_hours_text(mode)
	if after != "":
		rate += "; " + after
	return "%s (%s)" % [label_for(mode), rate]


#"15 minutes per second" or "1 hour per second", read from ClockRunner.STEPS; "" for a paused or unknown mode.
static func rate_text(mode: int) -> String:
	if mode < 0 or mode >= ClockRunner.STEPS.size():
		return ""
	return _step_text(ClockRunner.STEPS[mode])


#The rate from ClockRunner.AFTER_HOURS_STEPS, or the jump to the start of the day; "" when it matches the day rate.
static func after_hours_text(mode: int) -> String:
	if mode < 0 or mode >= ClockRunner.STEPS.size() or ClockRunner.STEPS[mode] <= 0:
		return ""
	var step: int = ClockRunner.AFTER_HOURS_STEPS[mode]
	if step == ClockRunner.STEPS[mode]:
		return ""
	if step <= 0:
		return "after hours jumps to %s" % TrynnCalendar.time_text(ClockRunner.DAY_START)
	return "after hours %s" % _step_text(step)


static func _step_text(step: int) -> String:
	if step <= 0:
		return ""
	if step % CampaignClock.MINUTES_PER_HOUR == 0:
		return _per_second(int(step / float(CampaignClock.MINUTES_PER_HOUR)), "hour")
	return _per_second(step, "minute")


static func _per_second(count: int, unit: String) -> String:
	return "%d %s%s per second" % [count, unit, "" if count == 1 else "s"]


static func icon_id(mode: int) -> String:
	return String(ICON_IDS.get(mode, ""))


func _face_id() -> String:
	return icon_id(speed_mode)
