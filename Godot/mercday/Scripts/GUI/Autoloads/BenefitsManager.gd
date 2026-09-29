extends Node

#The employee side of the Finance Viewer: the three benefits the guild pays on top of a wage, the
#vacation policy, the rows of the Payroll list, what a wage change costs in goodwill and what
#firing a merc costs. The Payroll tab of wave 3 renders these rows; nothing here draws.
#PayrollLogic holds the formulas and VacationPolicy the policy numbers.

signal changed
#The first day of a calendar month with profit sharing switched on; the payout itself is deferred.
signal profit_share_due(pct: int)

#PLACEHOLDER defaults and thresholds until the designer sets them: every benefit starts off, and
#a merc counts as a friend above the neutral relationship value of the Relationships tab.
const DEFAULT_PROFIT_PCT: int = 0
const DEFAULT_PER_CONTRACT: int = 0
const DEFAULT_ODD_DEFAULT: int = 0
const DEFAULT_BONUS_PCT: int = 0
const GOOD_RELATION: int = MercView.NEUTRAL_RELATION

const PERCENT_MAX: int = 100
const NO_MAX: int = -1
const MONTHS_PER_YEAR: int = VacationPolicy.MONTHS_PER_YEAR
const LOCK_TEXT: String = "Only Available or Resting mercs can have their salary changed"
const REJECT_SECONDS: float = 0.42
const HOURS_PER_DAY: float = 24.0
const LOAN_NOTE: String = "Pursuing a loan."
const UNDER_MONTH_TEXT: String = "Under a Month"
const ON_COLOR: Color = PayrollLogic.OK_COLOR
const OFF_COLOR: Color = PayrollLogic.OFF_COLOR
const NOTE_COLOR: Color = PayrollLogic.NOTE_COLOR
const FRIEND_COLOR: Color = PayrollLogic.OVER_COLOR
const PLAIN_COLOR: Color = Color("#f3ead7")
const PAYDAY_GOOD_DAYS: int = 20
const PAYDAY_OK_DAYS: int = 9
const PAYDAY_WARN_DAYS: int = 4

const BENEFIT_DEFS: Array[Dictionary] = [
	{"key": "profit", "field": "profit_pct", "label": "Profit Sharing",
		"desc": "Share of monthly net profit paid out to mercs.", "unit": "percent"},
	{"key": "contract", "field": "per_contract", "label": "Per-Contract Bonuses",
		"desc": "Share of each contract reward paid to the mercs who ran it.", "unit": "percent"},
	{"key": "odd", "field": "odd_default", "label": "Odd Job Default Bonus",
		"desc": "Default notes paid for side tasks, like sending a merc to pursue a loan.",
		"unit": "notes"},
]
#Only these two statuses may have a wage changed or be let go.
const SALARY_STATUSES: Array[int] = [GuiTypes.MercStatus.AVAILABLE, GuiTypes.MercStatus.RESTING]
const STATUS_NOTES: Dictionary = {
	GuiTypes.MercStatus.AVAILABLE: "Ready for action. Salary can be changed.",
	GuiTypes.MercStatus.RESTING: "Recovering. Salary can be changed.",
	GuiTypes.MercStatus.VACATION: "Away from the guild.",
	GuiTypes.MercStatus.FIRED: "No longer employed by the guild.",
	GuiTypes.MercStatus.DEAD: "Deceased.",
	GuiTypes.MercStatus.MISSING: "Missing.",
	GuiTypes.MercStatus.CAPTURED: "Held captive.",
}
const TRAIT_KINDS: Array[Dictionary] = [
	{"kind": "Knowledge", "field": "knowledges"},
	{"kind": "Tool", "field": "tools"},
	{"kind": "Perk", "field": "perks"},
]

var profit_pct: int = DEFAULT_PROFIT_PCT
var per_contract: int = DEFAULT_PER_CONTRACT
var odd_default: int = DEFAULT_ODD_DEFAULT
#The policy as the screens read it; _policy holds the same numbers as an object.
var vacation: Dictionary = {}
#Merc uid to the vacation days it has already taken.
var vacation_taken: Dictionary = {}
#Merc uid to true once it has been let go; the merc is out of the guild and holds no row.
var fired: Dictionary = {}
var _policy: VacationPolicy = VacationPolicy.new()
var _tick_day: int = -1
#True while a writer of this manager runs, so the roster signal it raises adds no second
#changed signal on top of the one the writer emits itself.
var _quiet: bool = false
var _seeded: bool = false


func _ready() -> void:
	GameState.roster_changed.connect(_on_roster_changed)
	GameState.day_changed.connect(_on_day_changed)
	GameState.results_recorded.connect(_on_results_recorded)
	reset()


#Back to the published defaults: every benefit off, the default policy, nothing taken or fired.
func reset() -> void:
	profit_pct = DEFAULT_PROFIT_PCT
	per_contract = DEFAULT_PER_CONTRACT
	odd_default = DEFAULT_ODD_DEFAULT
	_policy = VacationPolicy.new()
	vacation = _policy.to_dict()
	vacation_taken.clear()
	fired.clear()
	_tick_day = -1
	_seeded = GameState.started
	changed.emit()


func _on_roster_changed() -> void:
	if _seed_if_started():
		return
	if _quiet:
		return
	changed.emit()


func _on_day_changed(_day_index: int) -> void:
	if _seed_if_started():
		return
	tick(CampaignClock.now())


#Reseeds once, on the first signal after a campaign starts; true when this call did it.
func _seed_if_started() -> bool:
	if _seeded or not GameState.started:
		return false
	reset()
	return true


#One calendar day of guild business at a time: every day passed since the last tick is handled
#in order, and the first call after reset() only records the day.
func tick(now: int) -> void:
	var today: int = TrynnCalendar.day_index(now)
	if _tick_day < 0:
		_tick_day = today
		return
	while _tick_day < today:
		_tick_day += 1
		_day_passed(_tick_day)


#The 1st of a calendar month owes the profit share while the benefit is switched on.
func _day_passed(day: int) -> void:
	var date: Dictionary = TrynnCalendar.date_of(day * CampaignClock.MINUTES_PER_DAY)
	if int(date["day"]) == 1 and profit_pct > 0:
		profit_share_due.emit(profit_pct)


func benefit_def(key: String) -> Dictionary:
	for def: Dictionary in BENEFIT_DEFS:
		if String(def["key"]) == key:
			return def
	return {}


func benefit(key: String) -> int:
	var def: Dictionary = benefit_def(key)
	if def.is_empty():
		return 0
	return int(get(String(def["field"])))


#A percentage benefit holds 0 to 100; a notes benefit has no ceiling and never goes below 0.
func clamp_benefit(key: String, value: int) -> int:
	var def: Dictionary = benefit_def(key)
	if def.is_empty():
		return 0
	if String(def["unit"]) == "notes":
		return maxi(0, value)
	return clampi(value, 0, PERCENT_MAX)


func set_benefit(key: String, value: int) -> void:
	var def: Dictionary = benefit_def(key)
	if def.is_empty():
		return
	set(String(def["field"]), clamp_benefit(key, value))
	changed.emit()


func benefit_text(key: String, value: int) -> String:
	var def: Dictionary = benefit_def(key)
	if not def.is_empty() and String(def["unit"]) == "notes":
		return str(value)
	return str(value) + "%"


func step_label(key: String) -> String:
	var def: Dictionary = benefit_def(key)
	if not def.is_empty() and String(def["unit"]) == "notes":
		return "Notes per Job"
	return "Percentage"


func step_max(key: String) -> int:
	var def: Dictionary = benefit_def(key)
	if not def.is_empty() and String(def["unit"]) == "notes":
		return NO_MAX
	return PERCENT_MAX


func benefit_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def: Dictionary in BENEFIT_DEFS:
		var key: String = String(def["key"])
		var value: int = benefit(key)
		out.append({"key": key, "label": String(def["label"]), "desc": String(def["desc"]),
			"value": value, "value_text": benefit_text(key, value),
			"color": ON_COLOR if value != 0 else OFF_COLOR, "unit": String(def["unit"]),
			"step_label": step_label(key), "step_max": step_max(key)})
	return out


#What the benefit edit dialog shows while a new value is dialled in.
func benefit_change(key: String, new_value: int) -> Dictionary:
	var old_value: int = benefit(key)
	var wanted: int = clamp_benefit(key, new_value)
	var delta: int = wanted - old_value
	return {"text": PayrollLogic.sign_text(delta) + benefit_text(key, absi(delta)),
		"color": PayrollLogic.delta_color(delta), "was": "Was " + benefit_text(key, old_value)}


func policy() -> VacationPolicy:
	return _policy


func set_vacation(policy_values: Dictionary) -> void:
	_policy.merge(policy_values)
	vacation = _policy.to_dict()
	changed.emit()


func vacation_rows() -> Array[Dictionary]:
	return _policy.rows()


func employment_months(uid: int) -> int:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return 0
	return GameState.employment_months(merc)


#"Employed for 1 Year, 4 Months" at fourteen months; a year is ten game months.
func employed_text(uid: int) -> String:
	var months: int = employment_months(uid)
	if months <= 0:
		return UNDER_MONTH_TEXT
	var years: int = int(months / float(MONTHS_PER_YEAR))
	var rest: int = months % MONTHS_PER_YEAR
	var text: String = "Employed for "
	if years > 0:
		text += VacationPolicy.plural(years, "Year") + ", "
	return text + VacationPolicy.plural(rest, "Month")


func vacation_days_max(uid: int) -> int:
	return _policy.days_max(employment_months(uid))


func vacation_days_taken(uid: int) -> int:
	return int(vacation_taken.get(uid, 0))


func vacation_days_left(uid: int) -> int:
	return maxi(0, vacation_days_max(uid) - vacation_days_taken(uid))


func add_vacation_taken(uid: int, days: int) -> void:
	vacation_taken[uid] = maxi(0, vacation_days_taken(uid) + days)
	changed.emit()


func view_of(uid: int) -> MercView:
	for view: MercView in GameState.roster:
		if view != null and view.uid == uid:
			return view
	return null


#Everyone the guild still employs: the roster hides the dead and the captive, this drops the fired.
func employed_views() -> Array[MercView]:
	var out: Array[MercView] = []
	for view: MercView in GameState.roster:
		if view != null and not fired.has(view.uid):
			out.append(view)
	return out


#The status the Payroll list shows, with FIRED and DEAD on top of what GameState reports.
func status_of(uid: int) -> int:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return GuiTypes.MercStatus.FIRED if fired.has(uid) else GuiTypes.MercStatus.DEAD
	if merc.is_dead:
		return GuiTypes.MercStatus.DEAD
	if SalarySystem.is_captive(merc):
		return GuiTypes.MercStatus.CAPTURED
	if fired.has(uid):
		return GuiTypes.MercStatus.FIRED
	return int(GameState.merc_status(merc)["status"])


func salary_of(uid: int) -> int:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	return merc.monthly_salary if merc != null else 0


func opinion_of(uid: int) -> int:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	return merc.guild_opinion if merc != null else 0


func salary_locked(uid: int) -> bool:
	return not SALARY_STATUSES.has(status_of(uid))


#A raise is refused outright when the notes are not there; the screen flashes instead of clamping.
func can_raise(uid: int, new_salary: int) -> bool:
	if new_salary < 1:
		return false
	return new_salary <= salary_of(uid) or new_salary <= GameState.bank_notes


func salary_preview(uid: int, new_salary: int) -> Dictionary:
	var base: int = salary_of(uid)
	var opinion: int = opinion_of(uid)
	var delta: int = new_salary - base
	var pct: float = 0.0
	if base != 0:
		pct = float(delta) / float(base) * 100.0
	var shift: int = PayrollLogic.opinion_shift(base, new_salary, opinion)
	var preview: int = opinion + shift
	return {"base": base, "salary": new_salary, "delta": delta, "pct": pct,
		"delta_text": PayrollLogic.delta_text(base, new_salary), "shift": shift,
		"opinion": opinion, "preview": preview,
		"title": PayrollLogic.mood_title(preview, shift),
		"color": PayrollLogic.delta_color(delta), "was": "Was " + str(base),
		"step_max": maxi(new_salary, GameState.bank_notes),
		"affordable": can_raise(uid, new_salary)}


#Writes the wage through GameState and returns the opinion the merc now holds.
func apply_salary(uid: int, new_salary: int) -> int:
	var opinion: int = opinion_of(uid)
	if salary_locked(uid) or not can_raise(uid, new_salary):
		return opinion
	_quiet = true
	var after: int = GameState.set_salary(uid, new_salary)
	_quiet = false
	changed.emit()
	return after


func status_note(uid: int) -> String:
	var status: int = status_of(uid)
	if status == GuiTypes.MercStatus.CONTRACT:
		return _contract_note(uid)
	if status == GuiTypes.MercStatus.LOAN:
		return _loan_note(uid)
	return String(STATUS_NOTES.get(status, ""))


func _contract_note(uid: int) -> String:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	var hours: float = 0.0
	if merc != null:
		hours = float(GameState.merc_status(merc)["hours_left"])
	var days: int = maxi(0, ceili(hours / HOURS_PER_DAY))
	var text: String = VacationPolicy.plural(days, "Day") + " Left"
	var title: String = _contract_name(uid)
	if title == "":
		return text
	return title + " - " + text


func _contract_name(uid: int) -> String:
	var entry_id: int = _run_entry_of(uid)
	if entry_id < 0:
		return ""
	for view: ContractView in GameState.contracts:
		if view != null and view.entry_id == entry_id:
			return view.name
	return ""


func _run_entry_of(uid: int) -> int:
	var sources: Array[Dictionary] = [GameState.active_contracts, GameState.queued]
	for source: Dictionary in sources:
		for id: int in source:
			var run: ActiveRun = source[id] as ActiveRun
			if run != null and run.uids().has(uid):
				return id
	return -1


func _loan_note(uid: int) -> String:
	var manager: Node = get_node_or_null("/root/FinanceManager")
	if manager != null and manager.has_method("loan_note"):
		var text: String = String(manager.call("loan_note", uid))
		if text != "":
			return text
	return LOAN_NOTE


#One row per merc of the roster, in roster order; a merc the guild let go has no row at all.
func payroll_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var money: int = GameState.bank_notes
	for view: MercView in GameState.roster:
		if view == null:
			continue
		var status: int = status_of(view.uid)
		var locked: bool = not SALARY_STATUSES.has(status)
		out.append({"uid": view.uid, "name": view.name, "level": view.level,
			"level_text": "%02d" % view.level, "tradition": view.tradition,
			"tradition_color": GuiTypes.tradition_color(view.tradition), "status": status,
			"status_text": GuiTypes.merc_status_text(status),
			"status_color": GuiTypes.merc_status_color(status),
			"salary": view.monthly_salary,
			"salary_color": PayrollLogic.salary_color(view.monthly_salary, money),
			"locked": locked, "lock_text": LOCK_TEXT if locked else "",
			"note": status_note(view.uid), "employed_text": employed_text(view.uid),
			"vacation_left": vacation_days_left(view.uid), "opinion": view.guild_opinion,
			"heritage": view.heritage, "ancestry": ancestry_of(view.uid),
			"age": view.age_group, "unique": unique_traits(view.uid)})
	return out


#What the wages cost a month; a merc that has been let go is never paid.
func payroll_total() -> int:
	var total: int = GameState.month_expenses()
	if GameState.has_method("payroll_mercs"):
		return total
	for uid: int in fired:
		var merc: MercenaryData = GameState.merc_by_uid(uid)
		if merc == null or merc.is_dead or SalarySystem.is_captive(merc):
			continue
		total -= merc.monthly_salary
	return maxi(0, total)


#The minute the next wages come due. GameState owns the rule; this mirrors it when that reader is
#missing, so the tile never reads zero.
func next_payday_minute() -> int:
	if GameState.has_method("next_payday_minute"):
		return int(GameState.call("next_payday_minute"))
	var now: int = CampaignClock.now()
	var date: Dictionary = TrynnCalendar.date_of(now)
	var hour: int = int(GameState.SALARY_HOUR)
	var at: int = TrynnCalendar.first_weekday_minute(int(date["year"]), int(date["month"]), hour)
	if at > now:
		return at
	var next: Dictionary = TrynnCalendar.date_of(TrynnCalendar.next_month_start(now))
	return TrynnCalendar.first_weekday_minute(int(next["year"]), int(next["month"]), hour)


func payday_minutes_left() -> int:
	return maxi(0, next_payday_minute() - CampaignClock.now())


func payday_days_left() -> int:
	return int(payday_minutes_left() / float(TrynnCalendar.MINUTES_PER_DAY))


#"12 Days" two days out or more, "1 Day" on the last day, else whole hours rounded up, never zero.
func payday_text() -> String:
	var days: int = payday_days_left()
	if days >= 1:
		return VacationPolicy.plural(days, "Day")
	var hours: int = maxi(1, ceili(payday_minutes_left() / float(TrynnCalendar.MINUTES_PER_HOUR)))
	return VacationPolicy.plural(hours, "Hour")


func payday_color() -> Color:
	var days: int = payday_days_left()
	if days >= PAYDAY_GOOD_DAYS:
		return ON_COLOR
	if days >= PAYDAY_OK_DAYS:
		return PLAIN_COLOR
	if days >= PAYDAY_WARN_DAYS:
		return PayrollLogic.WARN_COLOR
	return PayrollLogic.OVER_COLOR


func ancestry_of(uid: int) -> String:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null or merc.ancestry == null:
		return ""
	return merc.ancestry.ancestry_name


func bloodline_of(uid: int) -> String:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null or merc.bloodline == null:
		return ""
	return merc.bloodline.ancestry_name


#The rarest Knowledge, Tool and Perk of the merc, counted over the mercs still employed.
func unique_traits(uid: int) -> Array[Dictionary]:
	var subject: MercView = view_of(uid)
	if subject == null:
		return []
	var holders: Array[MercView] = employed_views()
	var out: Array[Dictionary] = []
	for kind: Dictionary in TRAIT_KINDS:
		var field: String = String(kind["field"])
		var names: Array[String] = _names_of(subject, field)
		if names.is_empty():
			continue
		var rows: Array[Dictionary] = []
		for view: MercView in holders:
			rows.append({"names": _names_of(view, field)})
		var pick: Dictionary = PayrollLogic.unique_of(rows, names)
		if pick.is_empty():
			continue
		out.append({"kind": String(kind["kind"]), "name": String(pick["name"]),
			"holders": int(pick["holders"]), "total": int(pick["total"]),
			"rarity": String(pick["rarity"])})
	return out


func _names_of(view: MercView, field: String) -> Array[String]:
	var out: Array[String] = []
	if view == null:
		return out
	var raw: Variant = view.get(field)
	if not (raw is Array):
		return out
	for item: Variant in (raw as Array):
		if item is Dictionary:
			out.append(String((item as Dictionary).get("name", "")))
		else:
			out.append(String(item))
	return out


#What the fire dialog states: what the guild loses with this merc and what the mood costs.
func fire_summary(uid: int) -> Dictionary:
	var view: MercView = view_of(uid)
	var opinion: int = opinion_of(uid)
	var drop: int = PayrollLogic.fire_drop(opinion)
	var friends: int = friend_count(uid)
	return {"name": view.name if view != null else "",
		"level_text": "%02d" % (view.level if view != null else 0),
		"tradition": view.tradition if view != null else "",
		"employed_text": employed_text(uid), "salary": salary_of(uid),
		"notes": fire_notes(uid), "friends": friends,
		"friends_text": friends_text(friends),
		"friends_color": FRIEND_COLOR if friends > 0 else OFF_COLOR,
		"opinion": opinion, "drop": drop,
		"opinion_after": maxi(SalarySystem.OPINION_MIN, opinion - drop)}


#A note per kind the guild would be left without: tradition, ancestry and bloodline.
func fire_notes(uid: int) -> Array[Dictionary]:
	var view: MercView = view_of(uid)
	var out: Array[Dictionary] = []
	var wanted: Array[Dictionary] = [
		{"value": view.tradition if view != null else "", "kind": "tradition"},
		{"value": ancestry_of(uid), "kind": "ancestry"},
		{"value": bloodline_of(uid), "kind": "bloodline"},
	]
	for row: Dictionary in wanted:
		var value: String = String(row["value"])
		if value == "" or _others_share(uid, String(row["kind"]), value):
			continue
		out.append({"text": "You have no other " + value + "s", "color": NOTE_COLOR})
	return out


func _others_share(uid: int, kind: String, value: String) -> bool:
	for view: MercView in employed_views():
		if view.uid == uid:
			continue
		var theirs: String = ""
		match kind:
			"tradition":
				theirs = view.tradition
			"ancestry":
				theirs = ancestry_of(view.uid)
			"bloodline":
				theirs = bloodline_of(view.uid)
		if theirs == value:
			return true
	return false


#The employed mercs that think well of this one.
func friend_count(uid: int) -> int:
	var count: int = 0
	for view: MercView in employed_views():
		if view.uid == uid:
			continue
		if int(view.relationships.get(uid, GOOD_RELATION)) > GOOD_RELATION:
			count += 1
	return count


func friends_text(friends: int) -> String:
	var verb: String = " merc has " if friends == 1 else " mercs have "
	return str(friends) + verb + "a good relationship with this merc"


func is_fired(uid: int) -> bool:
	return fired.has(uid)


#Lets a merc go: the guild mood drops and the merc leaves the guild the same minute, wage and
#row with them. No severance. The removed queue keeps what they were.
func fire(uid: int) -> bool:
	if not SALARY_STATUSES.has(status_of(uid)):
		return false
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return false
	merc.guild_opinion = maxi(SalarySystem.OPINION_MIN,
		merc.guild_opinion - PayrollLogic.fire_drop(merc.guild_opinion))
	fired[uid] = true
	_quiet = true
	GameState.remove_merc(uid, "fired", GuiTypes.MercStatus.FIRED)
	GameState.refresh_views()
	_quiet = false
	changed.emit()
	return true


#The per-contract bonus is the only writer of bonus_pct; the notes themselves are not moved yet.
func _on_results_recorded(entry_id: int) -> void:
	var result: ContractResultData = GameState.result_of(entry_id)
	if result == null:
		return
	result.bonus_pct = per_contract
	result.assign_pay()
