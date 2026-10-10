class_name GuiPayrollTests

#BenefitsManager, PayrollLogic and VacationPolicy off a fresh campaign: the three benefits, the
#vacation policy, the Payroll rows, the wage change rules and the fire rules. Every case restarts
#the game and resets the manager, so the roster, the bank and the clock read the same every run.
#Statuses the campaign cannot reach on its own are forced on the merc resource itself.

const BASE_SALARY: int = 100
#Roster sizes hired up to by the cases that read past the start roster: the status case reads the fourth merc,
#the unique trait case the sixth and the fire case the tenth once four are let go.
const STATUS_ROSTER: int = 4
const TRAITS_ROSTER: int = 6
const FIRE_ROSTER: int = 10
#Years the cases run the clock on before dating a hire back; a hire before year one reads nothing.
const CLOCK_YEARS: int = 4
const ROW_KEYS: Array[String] = ["uid", "name", "level", "level_text", "tradition",
	"tradition_color", "status", "status_text", "status_color", "salary", "salary_color",
	"locked", "lock_text", "note", "employed_text", "vacation_left", "opinion", "heritage",
	"ancestry", "age", "unique"]
const PREVIEW_KEYS: Array[String] = ["base", "salary", "delta", "pct", "delta_text", "shift",
	"opinion", "preview", "title", "color", "was", "step_max", "affordable"]
const SUMMARY_KEYS: Array[String] = ["name", "level_text", "tradition", "employed_text",
	"salary", "notes", "friends", "friends_text", "friends_color", "opinion", "drop",
	"opinion_after"]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	SubscriptionManager.max_out()
	_case_defaults(res)
	_case_benefit_clamp(res)
	_case_benefit_rows(res)
	_case_benefit_change(res)
	_case_policy_clamp(res)
	_case_vacation_rows(res)
	_case_vacation_days(res)
	_case_employed_text(res)
	_case_salary_color(res)
	_case_opinion_shift(res)
	_case_logic_text(res)
	_case_unique_of(res)
	_case_salary_locked(res)
	_case_can_raise(res)
	_case_apply_salary(res)
	_case_status_note(res)
	_case_payroll_rows(res)
	_case_unique_traits(res)
	_case_fire_summary(res)
	_case_fire(res)
	_case_contract_bonus(res)
	_case_tick(res)
	_case_payday(res)
	_case_max_at(res)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	BenefitsManager.reset()
	SubscriptionManager.max_out()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI PAYROLL")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	BenefitsManager.reset()


#The keys the dictionary lacks, each followed by a space; empty when it carries all of them.
static func _missing(dict: Dictionary, keys: Array) -> String:
	var out: String = ""
	for key: Variant in keys:
		if not dict.has(key):
			out += str(key) + " "
	return out


static func _uid(index: int) -> int:
	if index < 0 or index >= GameState.roster.size():
		return 0
	return GameState.roster[index].uid


#A wage and an opinion the case can predict; the generator picks its own otherwise.
static func _set_pay(uid: int, salary: int, opinion: int) -> void:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return
	merc.monthly_salary = maxi(1, salary)
	merc.guild_opinion = clampi(opinion, SalarySystem.OPINION_MIN, SalarySystem.OPINION_MAX)
	GameState.refresh_views()


#The clock cannot run before the first year, so the cases move it on before dating a hire back.
static func _advance_clock() -> void:
	var minute: int = TrynnCalendar.month_start_minute(TrynnCalendar.START_YEAR + CLOCK_YEARS, 5)
	CampaignClock.advance_to(minute + 12 * CampaignClock.MINUTES_PER_HOUR)


#Dates the hire back so employment_months reads exactly this many months.
static func _set_months(uid: int, months: int) -> void:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return
	_advance_clock()
	var date: Dictionary = TrynnCalendar.date_of(CampaignClock.now())
	var month: int = int(date["month"]) - months
	var year: int = int(date["year"])
	while month < 0:
		month += TrynnCalendar.MONTHS.size()
		year -= 1
	merc.hired_minute = TrynnCalendar.month_start_minute(year, month)
	GameState.refresh_views()


#The mood a merc left the guild with: the payroll no longer holds a removed merc, the record does.
static func _left_opinion(uid: int) -> int:
	var record: RemovedMercRecord = GameState.removed_by_uid(uid)
	return record.guild_opinion if record != null else 0


static func _rest(uid: int, kind: String) -> void:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return
	merc.rest_lockout_kind = kind
	merc.rest_lockout_start = CampaignClock.now()
	merc.rest_lockout_until = CampaignClock.now() + CampaignClock.MINUTES_PER_DAY
	GameState.refresh_views()


static func _wake(uid: int) -> void:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return
	merc.rest_lockout_kind = ""
	merc.rest_lockout_until = 0
	merc.rest_lockout_start = -1
	GameState.refresh_views()


static func _case_defaults(res: Dictionary) -> void:
	_fresh()
	TestFixtures.check(res, "profit sharing starts off", BenefitsManager.profit_pct == 0,
		str(BenefitsManager.profit_pct))
	TestFixtures.check(res, "per contract bonus starts off", BenefitsManager.per_contract == 0,
		str(BenefitsManager.per_contract))
	TestFixtures.check(res, "odd job default starts off", BenefitsManager.odd_default == 0,
		str(BenefitsManager.odd_default))
	var policy: VacationPolicy = BenefitsManager.policy()
	TestFixtures.check(res, "policy starts at three days", policy.start == 3, str(policy.start))
	TestFixtures.check(res, "policy earns one day", policy.add_days == 1, str(policy.add_days))
	TestFixtures.check(res, "policy earns every one", policy.every == 1, str(policy.every))
	TestFixtures.check(res, "policy earns per year", policy.unit == "years", policy.unit)
	TestFixtures.check(res, "policy runs one week", policy.max_len == 1, str(policy.max_len))
	TestFixtures.check(res, "policy length is weeks", policy.max_unit == "weeks", policy.max_unit)
	TestFixtures.check(res, "policy allows two at once", policy.max_at == 2, str(policy.max_at))
	TestFixtures.check(res, "policy gap is three", policy.gap == 3, str(policy.gap))
	TestFixtures.check(res, "policy gap is months", policy.gap_unit == "months", policy.gap_unit)
	TestFixtures.check(res, "policy needs approval", policy.approval, "approval off")
	TestFixtures.check(res, "vacation mirror matches the policy",
		BenefitsManager.vacation == policy.to_dict(), str(BenefitsManager.vacation))
	TestFixtures.check(res, "nothing taken yet", BenefitsManager.vacation_taken.is_empty(),
		str(BenefitsManager.vacation_taken.size()))
	TestFixtures.check(res, "nobody fired yet", BenefitsManager.fired.is_empty(),
		str(BenefitsManager.fired.size()))


static func _case_benefit_clamp(res: Dictionary) -> void:
	_fresh()
	var hits: Array[int] = [0]
	var counter: Callable = func() -> void:
		hits[0] += 1
	BenefitsManager.changed.connect(counter)
	BenefitsManager.set_benefit("profit", -5)
	TestFixtures.check(res, "a percent below zero clamps to zero",
		BenefitsManager.benefit("profit") == 0, str(BenefitsManager.benefit("profit")))
	BenefitsManager.set_benefit("profit", 0)
	TestFixtures.check(res, "zero percent stays zero", BenefitsManager.benefit("profit") == 0,
		str(BenefitsManager.benefit("profit")))
	BenefitsManager.set_benefit("profit", 100)
	TestFixtures.check(res, "a hundred percent holds", BenefitsManager.profit_pct == 100,
		str(BenefitsManager.profit_pct))
	BenefitsManager.set_benefit("profit", 140)
	TestFixtures.check(res, "a percent past a hundred clamps",
		BenefitsManager.profit_pct == 100, str(BenefitsManager.profit_pct))
	BenefitsManager.set_benefit("contract", 140)
	TestFixtures.check(res, "the contract bonus clamps the same way",
		BenefitsManager.per_contract == 100, str(BenefitsManager.per_contract))
	BenefitsManager.set_benefit("odd", -5)
	TestFixtures.check(res, "notes below zero clamp to zero", BenefitsManager.odd_default == 0,
		str(BenefitsManager.odd_default))
	BenefitsManager.set_benefit("odd", 140)
	TestFixtures.check(res, "notes have no ceiling", BenefitsManager.odd_default == 140,
		str(BenefitsManager.odd_default))
	TestFixtures.check(res, "every set emits changed", hits[0] == 7, str(hits[0]))
	BenefitsManager.set_benefit("nope", 5)
	TestFixtures.check(res, "an unknown benefit is ignored", hits[0] == 7, str(hits[0]))
	TestFixtures.check(res, "an unknown benefit reads zero",
		BenefitsManager.benefit("nope") == 0, str(BenefitsManager.benefit("nope")))
	BenefitsManager.changed.disconnect(counter)


static func _case_benefit_rows(res: Dictionary) -> void:
	_fresh()
	BenefitsManager.set_benefit("profit", 25)
	BenefitsManager.set_benefit("odd", 40)
	var rows: Array[Dictionary] = BenefitsManager.benefit_rows()
	TestFixtures.check(res, "three benefit rows list", rows.size() == 3, str(rows.size()))
	if rows.size() < 3:
		return
	var profit: Dictionary = rows[0]
	TestFixtures.check(res, "the first row is profit sharing",
		String(profit["key"]) == "profit", String(profit["key"]))
	TestFixtures.check(res, "the profit row is labelled",
		String(profit["label"]) == "Profit Sharing", String(profit["label"]))
	TestFixtures.check(res, "the profit row reads a percent",
		String(profit["value_text"]) == "25%", String(profit["value_text"]))
	TestFixtures.check(res, "a benefit that pays reads green",
		profit["color"] == PayrollLogic.OK_COLOR, str(profit["color"]))
	TestFixtures.check(res, "the profit row steps a percentage",
		String(profit["step_label"]) == "Percentage", String(profit["step_label"]))
	TestFixtures.check(res, "the profit row stops at a hundred",
		int(profit["step_max"]) == 100, str(profit["step_max"]))
	TestFixtures.check(res, "the profit row describes itself",
		String(profit["desc"]).ends_with("paid out to mercs."), String(profit["desc"]))
	var contract: Dictionary = rows[1]
	TestFixtures.check(res, "the second row is the contract bonus",
		String(contract["key"]) == "contract", String(contract["key"]))
	TestFixtures.check(res, "a benefit switched off reads muted",
		contract["color"] == PayrollLogic.OFF_COLOR, str(contract["color"]))
	TestFixtures.check(res, "a benefit switched off reads zero percent",
		String(contract["value_text"]) == "0%", String(contract["value_text"]))
	var odd: Dictionary = rows[2]
	TestFixtures.check(res, "the third row is the odd job default",
		String(odd["key"]) == "odd", String(odd["key"]))
	TestFixtures.check(res, "the odd job row reads notes",
		String(odd["value_text"]) == "40", String(odd["value_text"]))
	TestFixtures.check(res, "the odd job row is a notes benefit",
		String(odd["unit"]) == "notes", String(odd["unit"]))
	TestFixtures.check(res, "the odd job row steps notes per job",
		String(odd["step_label"]) == "Notes per Job", String(odd["step_label"]))
	TestFixtures.check(res, "the odd job row has no ceiling",
		int(odd["step_max"]) == -1, str(odd["step_max"]))
	TestFixtures.check(res, "the odd job row keeps its value",
		int(odd["value"]) == 40, str(odd["value"]))


static func _case_benefit_change(res: Dictionary) -> void:
	_fresh()
	BenefitsManager.set_benefit("profit", 10)
	var up: Dictionary = BenefitsManager.benefit_change("profit", 25)
	TestFixtures.check(res, "a raised benefit reads the gain",
		String(up["text"]) == "+15%", String(up["text"]))
	TestFixtures.check(res, "a raised benefit reads green",
		up["color"] == PayrollLogic.OK_COLOR, str(up["color"]))
	TestFixtures.check(res, "a raised benefit names the old value",
		String(up["was"]) == "Was 10%", String(up["was"]))
	var down: Dictionary = BenefitsManager.benefit_change("profit", 5)
	TestFixtures.check(res, "a lowered benefit reads the loss",
		String(down["text"]) == "-5%", String(down["text"]))
	TestFixtures.check(res, "a lowered benefit reads red",
		down["color"] == PayrollLogic.OVER_COLOR, str(down["color"]))
	var flat: Dictionary = BenefitsManager.benefit_change("profit", 10)
	TestFixtures.check(res, "an unchanged benefit reads no move",
		String(flat["text"]) == "+/-0%", String(flat["text"]))
	TestFixtures.check(res, "an unchanged benefit reads sky blue",
		flat["color"] == PayrollLogic.FLAT_COLOR, str(flat["color"]))
	var clamped: Dictionary = BenefitsManager.benefit_change("profit", 400)
	TestFixtures.check(res, "a benefit change clamps before it reads",
		String(clamped["text"]) == "+90%", String(clamped["text"]))
	var notes: Dictionary = BenefitsManager.benefit_change("odd", 12)
	TestFixtures.check(res, "a notes change drops the percent sign",
		String(notes["text"]) == "+12", String(notes["text"]))
	TestFixtures.check(res, "a notes change names the old notes",
		String(notes["was"]) == "Was 0", String(notes["was"]))
	TestFixtures.check(res, "a benefit change never writes the value",
		BenefitsManager.profit_pct == 10, str(BenefitsManager.profit_pct))


static func _case_policy_clamp(res: Dictionary) -> void:
	_fresh()
	BenefitsManager.set_vacation({"unit": "months", "every": 99})
	TestFixtures.check(res, "a monthly period stops at twenty four",
		BenefitsManager.policy().every == 24, str(BenefitsManager.policy().every))
	BenefitsManager.set_vacation({"unit": "years"})
	TestFixtures.check(res, "a unit change clamps the period",
		BenefitsManager.policy().every == 10, str(BenefitsManager.policy().every))
	BenefitsManager.set_vacation({"every": 0})
	TestFixtures.check(res, "a period below one clamps up",
		BenefitsManager.policy().every == 1, str(BenefitsManager.policy().every))
	BenefitsManager.set_vacation({"max_unit": "days", "max_len": 99})
	TestFixtures.check(res, "a length in days stops at sixty",
		BenefitsManager.policy().max_len == 60, str(BenefitsManager.policy().max_len))
	BenefitsManager.set_vacation({"max_unit": "weeks"})
	TestFixtures.check(res, "a length unit change clamps the count",
		BenefitsManager.policy().max_len == 12, str(BenefitsManager.policy().max_len))
	BenefitsManager.set_vacation({"gap_unit": "weeks", "gap": 99})
	TestFixtures.check(res, "a gap in weeks stops at fifty two",
		BenefitsManager.policy().gap == 52, str(BenefitsManager.policy().gap))
	BenefitsManager.set_vacation({"gap_unit": "months"})
	TestFixtures.check(res, "a gap unit change clamps the count",
		BenefitsManager.policy().gap == 24, str(BenefitsManager.policy().gap))
	BenefitsManager.set_vacation({"start": -4, "max_at": -1})
	TestFixtures.check(res, "starting days never go below zero",
		BenefitsManager.policy().start == 0, str(BenefitsManager.policy().start))
	TestFixtures.check(res, "simultaneous mercs never go below zero",
		BenefitsManager.policy().max_at == 0, str(BenefitsManager.policy().max_at))
	BenefitsManager.set_vacation({"unit": "weeks"})
	TestFixtures.check(res, "an unknown period unit falls back to months",
		BenefitsManager.policy().unit == "months", BenefitsManager.policy().unit)
	BenefitsManager.set_vacation({"max_unit": "years"})
	TestFixtures.check(res, "an unknown length unit falls back to weeks",
		BenefitsManager.policy().max_unit == "weeks", BenefitsManager.policy().max_unit)
	BenefitsManager.set_vacation({"gap_unit": "days"})
	TestFixtures.check(res, "an unknown gap unit falls back to months",
		BenefitsManager.policy().gap_unit == "months", BenefitsManager.policy().gap_unit)
	TestFixtures.check(res, "the vacation mirror follows every change",
		int(BenefitsManager.vacation["gap"]) == BenefitsManager.policy().gap,
		str(BenefitsManager.vacation))


static func _row_text(rows: Array[Dictionary], key: String) -> String:
	for row: Dictionary in rows:
		if String(row["key"]) == key:
			return String(row["value_text"])
	return ""


static func _case_vacation_rows(res: Dictionary) -> void:
	_fresh()
	var rows: Array[Dictionary] = BenefitsManager.vacation_rows()
	TestFixtures.check(res, "six policy rows list", rows.size() == 6, str(rows.size()))
	TestFixtures.check(res, "starting days read plural",
		_row_text(rows, "start") == "3 Days", _row_text(rows, "start"))
	TestFixtures.check(res, "earned days read per year",
		_row_text(rows, "earned") == "+1 Day / Year", _row_text(rows, "earned"))
	TestFixtures.check(res, "max length reads singular",
		_row_text(rows, "max_len") == "1 Week", _row_text(rows, "max_len"))
	TestFixtures.check(res, "simultaneous mercs read plural",
		_row_text(rows, "max_at") == "2 Mercs", _row_text(rows, "max_at"))
	TestFixtures.check(res, "the gap reads plural months",
		_row_text(rows, "gap") == "3 Months", _row_text(rows, "gap"))
	TestFixtures.check(res, "approval reads required",
		_row_text(rows, "approval") == "Required", _row_text(rows, "approval"))
	BenefitsManager.set_vacation({"start": 1, "add_days": 0, "max_at": 1, "approval": false})
	rows = BenefitsManager.vacation_rows()
	TestFixtures.check(res, "one starting day reads singular",
		_row_text(rows, "start") == "1 Day", _row_text(rows, "start"))
	TestFixtures.check(res, "no earned days read none",
		_row_text(rows, "earned") == "None", _row_text(rows, "earned"))
	TestFixtures.check(res, "one merc at a time reads singular",
		_row_text(rows, "max_at") == "1 Merc", _row_text(rows, "max_at"))
	TestFixtures.check(res, "approval off reads not required",
		_row_text(rows, "approval") == "Not Required", _row_text(rows, "approval"))
	BenefitsManager.set_vacation({"add_days": 2, "every": 2})
	rows = BenefitsManager.vacation_rows()
	TestFixtures.check(res, "a longer period reads the count",
		_row_text(rows, "earned") == "+2 Days / 2 Years", _row_text(rows, "earned"))
	BenefitsManager.set_vacation({"gap": 1, "gap_unit": "weeks", "max_len": 3,
		"max_unit": "days"})
	rows = BenefitsManager.vacation_rows()
	TestFixtures.check(res, "a one week gap reads singular",
		_row_text(rows, "gap") == "1 Week", _row_text(rows, "gap"))
	TestFixtures.check(res, "a length in days reads plural",
		_row_text(rows, "max_len") == "3 Days", _row_text(rows, "max_len"))


static func _case_vacation_days(res: Dictionary) -> void:
	_fresh()
	var uid: int = _uid(0)
	_set_months(uid, 0)
	TestFixtures.check(res, "a new hire holds the starting days",
		BenefitsManager.vacation_days_max(uid) == 3,
		str(BenefitsManager.vacation_days_max(uid)))
	_set_months(uid, 11)
	TestFixtures.check(res, "eleven months earns one day",
		BenefitsManager.vacation_days_max(uid) == 4,
		str(BenefitsManager.vacation_days_max(uid)))
	_set_months(uid, 23)
	TestFixtures.check(res, "twenty three months earns two days",
		BenefitsManager.vacation_days_max(uid) == 5,
		str(BenefitsManager.vacation_days_max(uid)))
	BenefitsManager.set_vacation({"unit": "months"})
	_set_months(uid, 0)
	TestFixtures.check(res, "a monthly policy starts the same",
		BenefitsManager.vacation_days_max(uid) == 3,
		str(BenefitsManager.vacation_days_max(uid)))
	_set_months(uid, 11)
	TestFixtures.check(res, "a monthly policy earns every month",
		BenefitsManager.vacation_days_max(uid) == 14,
		str(BenefitsManager.vacation_days_max(uid)))
	_set_months(uid, 23)
	TestFixtures.check(res, "a monthly policy keeps earning",
		BenefitsManager.vacation_days_max(uid) == 26,
		str(BenefitsManager.vacation_days_max(uid)))
	TestFixtures.check(res, "nothing taken leaves the whole allowance",
		BenefitsManager.vacation_days_left(uid) == 26,
		str(BenefitsManager.vacation_days_left(uid)))
	BenefitsManager.add_vacation_taken(uid, 4)
	TestFixtures.check(res, "days taken come off the allowance",
		BenefitsManager.vacation_days_left(uid) == 22,
		str(BenefitsManager.vacation_days_left(uid)))
	TestFixtures.check(res, "days taken are remembered",
		BenefitsManager.vacation_days_taken(uid) == 4,
		str(BenefitsManager.vacation_days_taken(uid)))
	BenefitsManager.add_vacation_taken(uid, -9)
	TestFixtures.check(res, "days taken never go below zero",
		BenefitsManager.vacation_days_taken(uid) == 0,
		str(BenefitsManager.vacation_days_taken(uid)))
	BenefitsManager.add_vacation_taken(uid, 99)
	TestFixtures.check(res, "days left never go below zero",
		BenefitsManager.vacation_days_left(uid) == 0,
		str(BenefitsManager.vacation_days_left(uid)))
	TestFixtures.check(res, "an unknown merc has no allowance",
		BenefitsManager.vacation_days_max(-1) == 3,
		str(BenefitsManager.vacation_days_max(-1)))


static func _case_employed_text(res: Dictionary) -> void:
	_fresh()
	var uid: int = _uid(0)
	_set_months(uid, 0)
	TestFixtures.check(res, "a fresh hire reads under a month",
		BenefitsManager.employed_text(uid) == "Under a Month",
		BenefitsManager.employed_text(uid))
	_set_months(uid, 1)
	TestFixtures.check(res, "one month reads singular",
		BenefitsManager.employed_text(uid) == "Employed for 1 Month",
		BenefitsManager.employed_text(uid))
	_set_months(uid, 2)
	TestFixtures.check(res, "two months read plural",
		BenefitsManager.employed_text(uid) == "Employed for 2 Months",
		BenefitsManager.employed_text(uid))
	_set_months(uid, 10)
	TestFixtures.check(res, "ten months read a year",
		BenefitsManager.employed_text(uid) == "Employed for 1 Year, 0 Months",
		BenefitsManager.employed_text(uid))
	_set_months(uid, 14)
	TestFixtures.check(res, "fourteen months read a year and four",
		BenefitsManager.employed_text(uid) == "Employed for 1 Year, 4 Months",
		BenefitsManager.employed_text(uid))
	_set_months(uid, 21)
	TestFixtures.check(res, "twenty one months read two years and one",
		BenefitsManager.employed_text(uid) == "Employed for 2 Years, 1 Month",
		BenefitsManager.employed_text(uid))


static func _case_salary_color(res: Dictionary) -> void:
	TestFixtures.check(res, "a wage above the bank reads red",
		PayrollLogic.salary_color(200, 100) == PayrollLogic.OVER_COLOR,
		str(PayrollLogic.salary_color(200, 100)))
	TestFixtures.check(res, "a wage above a tenth of the bank reads orange",
		PayrollLogic.salary_color(50, 100) == PayrollLogic.WARN_COLOR,
		str(PayrollLogic.salary_color(50, 100)))
	TestFixtures.check(res, "a wage at a tenth of the bank reads green",
		PayrollLogic.salary_color(10, 100) == PayrollLogic.OK_COLOR,
		str(PayrollLogic.salary_color(10, 100)))
	TestFixtures.check(res, "a small wage reads green",
		PayrollLogic.salary_color(5, 100) == PayrollLogic.OK_COLOR,
		str(PayrollLogic.salary_color(5, 100)))
	TestFixtures.check(res, "an empty bank reads red",
		PayrollLogic.salary_color(1, 0) == PayrollLogic.OVER_COLOR,
		str(PayrollLogic.salary_color(1, 0)))


static func _case_opinion_shift(res: Dictionary) -> void:
	var wanted: Array[Array] = [[115, 1], [125, 2], [150, 3], [200, 4], [250, 5], [99, -1],
		[90, -3]]
	for row: Array in wanted:
		var new_salary: int = int(row[0])
		var shift: int = PayrollLogic.opinion_shift(BASE_SALARY, new_salary, 0)
		TestFixtures.check(res, "a wage of %d shifts the opinion" % new_salary,
			shift == int(row[1]), str(shift))
		TestFixtures.check(res, "a wage of %d matches the salary system" % new_salary,
			shift == SalarySystem.opinion_delta(BASE_SALARY, new_salary), str(shift))
	TestFixtures.check(res, "a thirty percent cut lands on the floor",
		PayrollLogic.opinion_shift(BASE_SALARY, 70, 0) == -5,
		str(PayrollLogic.opinion_shift(BASE_SALARY, 70, 0)))
	TestFixtures.check(res, "the salary system would cut deeper than the floor",
		SalarySystem.opinion_delta(BASE_SALARY, 70) == -7,
		str(SalarySystem.opinion_delta(BASE_SALARY, 70)))
	TestFixtures.check(res, "a raise on a happy merc stops at the ceiling",
		PayrollLogic.opinion_shift(BASE_SALARY, 200, 5) == 0,
		str(PayrollLogic.opinion_shift(BASE_SALARY, 200, 5)))
	TestFixtures.check(res, "a big raise part way up stops at the ceiling",
		PayrollLogic.opinion_shift(BASE_SALARY, 250, 3) == 2,
		str(PayrollLogic.opinion_shift(BASE_SALARY, 250, 3)))
	TestFixtures.check(res, "a cut on an angry merc stops at the floor",
		PayrollLogic.opinion_shift(BASE_SALARY, 70, -5) == 0,
		str(PayrollLogic.opinion_shift(BASE_SALARY, 70, -5)))
	TestFixtures.check(res, "a cut part way down stops at the floor",
		PayrollLogic.opinion_shift(BASE_SALARY, 70, -3) == -2,
		str(PayrollLogic.opinion_shift(BASE_SALARY, 70, -3)))
	TestFixtures.check(res, "a cut to one note tanks the opinion",
		PayrollLogic.opinion_shift(BASE_SALARY, 1, 3) == -8,
		str(PayrollLogic.opinion_shift(BASE_SALARY, 1, 3)))
	TestFixtures.check(res, "a raise from nothing shifts nothing",
		PayrollLogic.opinion_shift(0, 1, 0) == 0,
		str(PayrollLogic.opinion_shift(0, 1, 0)))
	TestFixtures.check(res, "an unchanged wage shifts nothing",
		PayrollLogic.opinion_shift(BASE_SALARY, BASE_SALARY, 2) == 0,
		str(PayrollLogic.opinion_shift(BASE_SALARY, BASE_SALARY, 2)))


static func _case_logic_text(res: Dictionary) -> void:
	TestFixtures.check(res, "a raise reads the notes and the percent",
		PayrollLogic.delta_text(100, 115) == "+15 (+15%)", PayrollLogic.delta_text(100, 115))
	TestFixtures.check(res, "a cut reads the notes and the percent",
		PayrollLogic.delta_text(100, 90) == "-10 (-10%)", PayrollLogic.delta_text(100, 90))
	TestFixtures.check(res, "no change reads no move",
		PayrollLogic.delta_text(100, 100) == "+/-0 (+/-0%)", PayrollLogic.delta_text(100, 100))
	TestFixtures.check(res, "a percent rounds to the nearest whole",
		PayrollLogic.delta_text(100, 133) == "+33 (+33%)", PayrollLogic.delta_text(100, 133))
	TestFixtures.check(res, "a wage of nothing has no percent",
		PayrollLogic.delta_text(0, 5) == "+5 (+/-0%)", PayrollLogic.delta_text(0, 5))
	TestFixtures.check(res, "a raise reads green",
		PayrollLogic.delta_color(5) == PayrollLogic.OK_COLOR, str(PayrollLogic.delta_color(5)))
	TestFixtures.check(res, "a cut reads red",
		PayrollLogic.delta_color(-5) == PayrollLogic.OVER_COLOR,
		str(PayrollLogic.delta_color(-5)))
	TestFixtures.check(res, "no move reads sky blue",
		PayrollLogic.delta_color(0) == PayrollLogic.FLAT_COLOR,
		str(PayrollLogic.delta_color(0)))
	TestFixtures.check(res, "a happy merc costs seven opinion to fire",
		PayrollLogic.fire_drop(5) == 7, str(PayrollLogic.fire_drop(5)))
	TestFixtures.check(res, "a neutral merc costs three opinion to fire",
		PayrollLogic.fire_drop(0) == 3, str(PayrollLogic.fire_drop(0)))
	TestFixtures.check(res, "an angry merc costs nothing to fire",
		PayrollLogic.fire_drop(-5) == 0, str(PayrollLogic.fire_drop(-5)))
	TestFixtures.check(res, "the hold does nothing before the delay",
		is_equal_approx(PayrollLogic.hold_rate(0.3), 0.0), str(PayrollLogic.hold_rate(0.3)))
	TestFixtures.check(res, "the hold starts at four a second",
		is_equal_approx(PayrollLogic.hold_rate(0.35), 4.0), str(PayrollLogic.hold_rate(0.35)))
	TestFixtures.check(res, "the hold ramps up",
		is_equal_approx(PayrollLogic.hold_rate(1.35), 52.0), str(PayrollLogic.hold_rate(1.35)))
	TestFixtures.check(res, "the hold stops at a hundred a second",
		is_equal_approx(PayrollLogic.hold_rate(5.0), 100.0), str(PayrollLogic.hold_rate(5.0)))
	TestFixtures.check(res, "a neutral mood is named",
		PayrollLogic.mood_label(0) == "Neutral", PayrollLogic.mood_label(0))
	TestFixtures.check(res, "a good mood is numbered",
		PayrollLogic.mood_label(3) == "+3", PayrollLogic.mood_label(3))
	TestFixtures.check(res, "a bad mood is numbered",
		PayrollLogic.mood_label(-2) == "-2", PayrollLogic.mood_label(-2))
	TestFixtures.check(res, "a mood past the ceiling clamps",
		PayrollLogic.mood_label(9) == "+5", PayrollLogic.mood_label(9))
	TestFixtures.check(res, "the mood colour comes from the face widget",
		PayrollLogic.mood_color(0) == MoodFace.GUILD_COLORS[5],
		str(PayrollLogic.mood_color(0)))
	TestFixtures.check(res, "the dialog title carries the signed shift",
		PayrollLogic.mood_title(3, 2) == "+3 (+2)", PayrollLogic.mood_title(3, 2))
	TestFixtures.check(res, "a falling title carries the minus",
		PayrollLogic.mood_title(-5, -3) == "-5 (-3)",
		PayrollLogic.mood_title(-5, -3))
	TestFixtures.check(res, "a still title carries a bare zero",
		PayrollLogic.mood_title(0, 0) == "Neutral (0)", PayrollLogic.mood_title(0, 0))


static func _case_unique_of(res: Dictionary) -> void:
	var rows: Array[Dictionary] = [
		{"names": ["Alpha", "Beta"]},
		{"names": ["Alpha"]},
		{"names": ["Alpha"]},
	]
	var mine: Array[String] = ["Alpha", "Beta"]
	var pick: Dictionary = PayrollLogic.unique_of(rows, mine)
	TestFixtures.check(res, "the rarest trait wins", String(pick.get("name", "")) == "Beta",
		str(pick))
	TestFixtures.check(res, "the rarest trait counts its holders",
		int(pick.get("holders", -1)) == 1, str(pick))
	TestFixtures.check(res, "the rarest trait counts the guild",
		int(pick.get("total", -1)) == 3, str(pick))
	TestFixtures.check(res, "a lone holder reads as the only one",
		String(pick.get("rarity", "")) == "Only this merc", str(pick))
	var tied: Array[Dictionary] = [{"names": ["Alpha", "Beta"]}, {"names": ["Alpha", "Beta"]}]
	var tie: Dictionary = PayrollLogic.unique_of(tied, mine)
	TestFixtures.check(res, "a tie goes to the first trait listed",
		String(tie.get("name", "")) == "Alpha", str(tie))
	TestFixtures.check(res, "a shared trait counts the holders",
		String(tie.get("rarity", "")) == "2 of 2 mercs", str(tie))
	var none: Array[String] = []
	TestFixtures.check(res, "a merc with no traits has no rarest",
		PayrollLogic.unique_of(rows, none).is_empty(), str(PayrollLogic.unique_of(rows, none)))
	var empty: Array[Dictionary] = []
	TestFixtures.check(res, "an empty guild still names the trait",
		String(PayrollLogic.unique_of(empty, mine).get("name", "")) == "Alpha",
		str(PayrollLogic.unique_of(empty, mine)))
	TestFixtures.check(res, "the rarity text counts of the total",
		PayrollLogic.rarity_text(2, 3) == "2 of 3 mercs", PayrollLogic.rarity_text(2, 3))


static func _case_salary_locked(res: Dictionary) -> void:
	_fresh()
	var uid: int = _uid(0)
	TestFixtures.check(res, "an available merc can be paid differently",
		not BenefitsManager.salary_locked(uid), str(BenefitsManager.status_of(uid)))
	_rest(uid, RestSystem.KIND_BREATHER)
	TestFixtures.check(res, "a resting merc can be paid differently",
		not BenefitsManager.salary_locked(uid), str(BenefitsManager.status_of(uid)))
	_rest(uid, RestSystem.KIND_FURLOUGH)
	TestFixtures.check(res, "a merc on vacation is locked",
		BenefitsManager.salary_locked(uid), str(BenefitsManager.status_of(uid)))
	TestFixtures.check(res, "vacation reads as vacation",
		BenefitsManager.status_of(uid) == GuiTypes.MercStatus.VACATION,
		str(BenefitsManager.status_of(uid)))
	_wake(uid)
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	merc.on_contract = true
	GameState.refresh_views()
	TestFixtures.check(res, "a merc out on a contract is locked",
		BenefitsManager.salary_locked(uid), str(BenefitsManager.status_of(uid)))
	merc.on_contract = false
	merc.is_dead = true
	GameState.refresh_views()
	TestFixtures.check(res, "a dead merc is locked", BenefitsManager.salary_locked(uid),
		str(BenefitsManager.status_of(uid)))
	TestFixtures.check(res, "a dead merc reads as dead",
		BenefitsManager.status_of(uid) == GuiTypes.MercStatus.DEAD,
		str(BenefitsManager.status_of(uid)))
	merc.is_dead = false
	GameState.refresh_views()
	var other: int = _uid(1)
	TestFixtures.check(res, "a merc let go is locked",
		BenefitsManager.fire(other) and BenefitsManager.salary_locked(other),
		str(BenefitsManager.status_of(other)))


static func _case_can_raise(res: Dictionary) -> void:
	_fresh()
	var uid: int = _uid(0)
	_set_pay(uid, BASE_SALARY, 0)
	GameState.bank_notes = 500
	TestFixtures.check(res, "a wage of nothing is refused", not BenefitsManager.can_raise(uid, 0),
		"0")
	TestFixtures.check(res, "the wage it already pays is allowed",
		BenefitsManager.can_raise(uid, BASE_SALARY), str(BASE_SALARY))
	TestFixtures.check(res, "a cut needs no notes", BenefitsManager.can_raise(uid, 90), "90")
	TestFixtures.check(res, "a raise within the bank is allowed",
		BenefitsManager.can_raise(uid, 400), "400")
	TestFixtures.check(res, "a raise of the whole bank is allowed",
		BenefitsManager.can_raise(uid, 500), "500")
	TestFixtures.check(res, "a raise past the bank is refused",
		not BenefitsManager.can_raise(uid, 501), "501")
	GameState.bank_notes = 0
	TestFixtures.check(res, "an empty bank still allows a cut",
		BenefitsManager.can_raise(uid, 50), "50")
	TestFixtures.check(res, "an empty bank refuses a raise",
		not BenefitsManager.can_raise(uid, 150), "150")
	GameState.bank_notes = 300
	var view: Dictionary = BenefitsManager.salary_preview(uid, 150)
	TestFixtures.check(res, "the wage step stops at the bank",
		int(view["step_max"]) == 300, str(view["step_max"]))
	TestFixtures.check(res, "an affordable wage reads affordable", bool(view["affordable"]),
		str(view["affordable"]))


static func _case_apply_salary(res: Dictionary) -> void:
	_fresh()
	var uid: int = _uid(0)
	_set_pay(uid, BASE_SALARY, 0)
	GameState.bank_notes = 1000
	var view: Dictionary = BenefitsManager.salary_preview(uid, 115)
	var missing: String = _missing(view, PREVIEW_KEYS)
	TestFixtures.check(res, "the wage preview carries every field", missing == "", missing)
	TestFixtures.check(res, "the preview holds the wage it pays now",
		int(view["base"]) == BASE_SALARY, str(view["base"]))
	TestFixtures.check(res, "the preview holds the notes of the move",
		int(view["delta"]) == 15, str(view["delta"]))
	TestFixtures.check(res, "the preview reads the move",
		String(view["delta_text"]) == "+15 (+15%)", String(view["delta_text"]))
	TestFixtures.check(res, "a fifteen percent raise moves the mood one",
		int(view["shift"]) == 1, str(view["shift"]))
	TestFixtures.check(res, "the preview holds the mood after",
		int(view["preview"]) == 1, str(view["preview"]))
	TestFixtures.check(res, "the preview names the old wage",
		String(view["was"]) == "Was 100", String(view["was"]))
	var flat_view: Dictionary = BenefitsManager.salary_preview(uid, BASE_SALARY)
	TestFixtures.check(res, "an unchanged wage leaves the move blank",
		String(flat_view["delta_text"]) == "", String(flat_view["delta_text"]))
	TestFixtures.check(res, "an unchanged wage leaves the old-wage note blank",
		String(flat_view["was"]) == "", String(flat_view["was"]))
	var seen: Dictionary = {"n": 0}
	var counter: Callable = func() -> void:
		seen["n"] = int(seen["n"]) + 1
	BenefitsManager.changed.connect(counter)
	var after: int = BenefitsManager.apply_salary(uid, 115)
	TestFixtures.check(res, "a raise tells the screens once", int(seen["n"]) == 1,
		str(seen["n"]))
	BenefitsManager.changed.disconnect(counter)
	TestFixtures.check(res, "the raise moves the mood as previewed", after == 1, str(after))
	TestFixtures.check(res, "the raise is written", BenefitsManager.salary_of(uid) == 115,
		str(BenefitsManager.salary_of(uid)))
	TestFixtures.check(res, "a raise takes nothing from the bank", GameState.bank_notes == 1000,
		str(GameState.bank_notes))
	_rest(uid, RestSystem.KIND_FURLOUGH)
	var held: int = BenefitsManager.apply_salary(uid, 200)
	TestFixtures.check(res, "a locked merc keeps their wage",
		BenefitsManager.salary_of(uid) == 115, str(BenefitsManager.salary_of(uid)))
	TestFixtures.check(res, "a locked merc keeps their mood", held == 1, str(held))
	_wake(uid)
	GameState.bank_notes = 50
	var poor: int = BenefitsManager.apply_salary(uid, 900)
	TestFixtures.check(res, "an unaffordable raise is refused",
		BenefitsManager.salary_of(uid) == 115, str(BenefitsManager.salary_of(uid)))
	TestFixtures.check(res, "a refused raise leaves the mood alone", poor == 1, str(poor))
	_set_pay(uid, BASE_SALARY, 5)
	var tank: Dictionary = BenefitsManager.salary_preview(uid, PayrollLogic.TANK_SALARY)
	TestFixtures.check(res, "a wage cut to one note bottoms the mood",
		int(tank["preview"]) == SalarySystem.OPINION_MIN, str(tank["preview"]))
	TestFixtures.check(res, "the bottoming shift is the whole way down",
		int(tank["shift"]) == SalarySystem.OPINION_MIN - 5, str(tank["shift"]))
	TestFixtures.check(res, "a cut reads red",
		tank["color"] == PayrollLogic.OVER_COLOR, str(tank["color"]))
	var sunk: int = BenefitsManager.apply_salary(uid, PayrollLogic.TANK_SALARY)
	TestFixtures.check(res, "tank: a committed cut to one note leaves the previewed mood",
		sunk == int(tank["preview"]) and BenefitsManager.opinion_of(uid) == int(tank["preview"])
		and BenefitsManager.salary_of(uid) == PayrollLogic.TANK_SALARY,
		"committed %d, previewed %d, wage %d" % [sunk, int(tank["preview"]), BenefitsManager.salary_of(uid)])


static func _case_status_note(res: Dictionary) -> void:
	_fresh()
	TestFixtures.add_mercs(STATUS_ROSTER - GameState.mercs.size())
	var uid: int = _uid(0)
	TestFixtures.check(res, "an available merc is ready for action",
		BenefitsManager.status_note(uid) == "Ready for action. Salary can be changed.",
		BenefitsManager.status_note(uid))
	_rest(uid, RestSystem.KIND_BREATHER)
	TestFixtures.check(res, "a resting merc is recovering",
		BenefitsManager.status_note(uid) == "Recovering. Salary can be changed.",
		BenefitsManager.status_note(uid))
	_rest(uid, RestSystem.KIND_FURLOUGH)
	TestFixtures.check(res, "a merc on vacation is away",
		BenefitsManager.status_note(uid) == "Away from the guild.",
		BenefitsManager.status_note(uid))
	_wake(uid)
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	merc.on_contract = true
	GameState.refresh_views()
	TestFixtures.check(res, "a merc out on a contract counts the days left",
		BenefitsManager.status_note(uid).ends_with("Days Left"),
		BenefitsManager.status_note(uid))
	merc.on_contract = false
	GameState.refresh_views()
	var gone: int = _uid(1)
	BenefitsManager.fire(gone)
	TestFixtures.check(res, "a merc let go is no longer employed",
		BenefitsManager.status_note(gone) == "No longer employed by the guild.",
		BenefitsManager.status_note(gone))
	var lost: int = _uid(2)
	var dead: MercenaryData = GameState.merc_by_uid(lost)
	dead.is_dead = true
	GameState.refresh_views()
	TestFixtures.check(res, "a dead merc is deceased",
		BenefitsManager.status_note(lost) == "Deceased.", BenefitsManager.status_note(lost))
	dead.is_dead = false
	GameState.refresh_views()
	TestFixtures.check(res, "a captive merc is held",
		String(BenefitsManager.STATUS_NOTES[GuiTypes.MercStatus.CAPTURED]) == "Held captive.",
		String(BenefitsManager.STATUS_NOTES[GuiTypes.MercStatus.CAPTURED]))
	TestFixtures.check(res, "a merc chasing a loan says so",
		BenefitsManager.LOAN_NOTE == "Pursuing a loan.", BenefitsManager.LOAN_NOTE)


static func _case_payroll_rows(res: Dictionary) -> void:
	_fresh()
	GameState.bank_notes = 1000
	var rows: Array[Dictionary] = BenefitsManager.payroll_rows()
	TestFixtures.check(res, "payroll lists every merc of the roster",
		rows.size() == GameState.roster.size(), str(rows.size()))
	var missing: String = _missing(rows[0], ROW_KEYS) if rows.size() > 0 else ""
	TestFixtures.check(res, "a payroll row carries every field", missing == "", missing)
	var order: bool = true
	for i: int in range(rows.size()):
		if int(rows[i]["uid"]) != GameState.roster[i].uid:
			order = false
	TestFixtures.check(res, "payroll keeps the roster order", order, str(rows.size()))
	var uid: int = _uid(0)
	_set_pay(uid, 120, 0)
	rows = BenefitsManager.payroll_rows()
	var shown: MercView = BenefitsManager.view_of(uid)
	shown.level = 7
	rows = BenefitsManager.payroll_rows()
	TestFixtures.check(res, "a level reads as two digits",
		String(rows[0]["level_text"]) == "%02d" % shown.level, String(rows[0]["level_text"]))
	shown.level = 14
	rows = BenefitsManager.payroll_rows()
	TestFixtures.check(res, "a level of ten or more reads as it stands",
		String(rows[0]["level_text"]) == "%02d" % shown.level, String(rows[0]["level_text"]))
	TestFixtures.check(res, "an available merc is not locked", not bool(rows[0]["locked"]),
		str(rows[0]["locked"]))
	TestFixtures.check(res, "an unlocked row has no lock note",
		String(rows[0]["lock_text"]) == "", String(rows[0]["lock_text"]))
	GameState.bank_notes = 5000
	rows = BenefitsManager.payroll_rows()
	TestFixtures.check(res, "an affordable wage reads green",
		rows[0]["salary_color"] == PayrollLogic.OK_COLOR, str(rows[0]["salary_color"]))
	GameState.bank_notes = 1000
	rows = BenefitsManager.payroll_rows()
	TestFixtures.check(res, "a wage past a tenth of the bank reads orange",
		rows[0]["salary_color"] == PayrollLogic.WARN_COLOR, str(rows[0]["salary_color"]))
	GameState.bank_notes = 100
	rows = BenefitsManager.payroll_rows()
	TestFixtures.check(res, "a wage past the bank reads red",
		rows[0]["salary_color"] == PayrollLogic.OVER_COLOR, str(rows[0]["salary_color"]))
	GameState.bank_notes = 1000
	var gone: int = _uid(1)
	var wage: int = BenefitsManager.salary_of(gone)
	var before: int = GameState.month_expenses()
	var listed: int = rows.size()
	BenefitsManager.fire(gone)
	rows = BenefitsManager.payroll_rows()
	TestFixtures.check(res, "a merc let go stops listing",
		rows.size() == listed - 1 and rows.size() == GameState.roster.size(), str(rows.size()))
	var found: bool = false
	for row: Dictionary in rows:
		if int(row["uid"]) == gone:
			found = true
	TestFixtures.check(res, "the row of a merc let go is off the list", not found, str(gone))
	var want: int = maxi(0, before - wage)
	TestFixtures.check(res, "the wage bill drops the merc let go",
		BenefitsManager.payroll_total() == want, str(BenefitsManager.payroll_total()))


#Hand-set trait lists on the views; nothing here refreshes them away.
static func _clear_traits() -> void:
	for view: MercView in GameState.roster:
		view.knowledges.clear()
		view.tools.clear()
		view.perks.clear()


static func _case_unique_traits(res: Dictionary) -> void:
	_fresh()
	TestFixtures.add_mercs(TRAITS_ROSTER - GameState.mercs.size())
	_clear_traits()
	var mine: MercView = BenefitsManager.view_of(_uid(0))
	mine.knowledges.append("Shared")
	mine.knowledges.append("Rare")
	mine.tools.append("Hammer")
	mine.perks.append({"name": "Lucky"})
	for index: int in [1, 2]:
		var other: MercView = BenefitsManager.view_of(_uid(index))
		other.knowledges.append("Shared")
		other.tools.append("Hammer")
	var rows: Array[Dictionary] = BenefitsManager.unique_traits(_uid(0))
	TestFixtures.check(res, "a merc lists one rarest of each kind", rows.size() == 3,
		str(rows.size()))
	TestFixtures.check(res, "the knowledge kind comes first",
		rows.size() == 3 and String(rows[0]["kind"]) == "Knowledge", str(rows))
	TestFixtures.check(res, "the rarest knowledge is the one nobody else holds",
		rows.size() == 3 and String(rows[0]["name"]) == "Rare", str(rows))
	TestFixtures.check(res, "a knowledge nobody shares reads as the only one",
		rows.size() == 3 and String(rows[0]["rarity"]) == "Only this merc", str(rows))
	TestFixtures.check(res, "the tool kind comes second",
		rows.size() == 3 and String(rows[1]["kind"]) == "Tool", str(rows))
	TestFixtures.check(res, "a shared tool counts its holders",
		rows.size() == 3 and int(rows[1]["holders"]) == 3, str(rows))
	TestFixtures.check(res, "the guild total counts the employed",
		rows.size() == 3 and int(rows[1]["total"]) == GameState.roster.size(), str(rows))
	TestFixtures.check(res, "the perk kind comes last",
		rows.size() == 3 and String(rows[2]["kind"]) == "Perk"
		and String(rows[2]["name"]) == "Lucky", str(rows))
	TestFixtures.check(res, "a merc with no traits lists nothing",
		BenefitsManager.unique_traits(_uid(5)).is_empty(),
		str(BenefitsManager.unique_traits(_uid(5))))
	TestFixtures.check(res, "a uid nobody holds lists nothing",
		BenefitsManager.unique_traits(-1).is_empty(), "-1")
	BenefitsManager.fired[_uid(2)] = true
	rows = BenefitsManager.unique_traits(_uid(0))
	TestFixtures.check(res, "a merc let go stops counting as a holder",
		rows.size() == 3 and int(rows[1]["holders"]) == 2, str(rows))
	TestFixtures.check(res, "a merc let go leaves the guild total",
		rows.size() == 3 and int(rows[1]["total"]) == GameState.roster.size() - 1, str(rows))
	BenefitsManager.fired.clear()


static func _case_fire_summary(res: Dictionary) -> void:
	_fresh()
	var uid: int = _uid(0)
	_set_pay(uid, 250, 5)
	_set_months(uid, 12)
	var mine: MercView = BenefitsManager.view_of(uid)
	mine.tradition = "Lonely"
	for view: MercView in GameState.roster:
		if view.uid == uid:
			continue
		view.tradition = "Common"
		view.relationships[uid] = BenefitsManager.GOOD_RELATION
	var summary: Dictionary = BenefitsManager.fire_summary(uid)
	var missing: String = _missing(summary, SUMMARY_KEYS)
	TestFixtures.check(res, "the fire summary carries every field", missing == "", missing)
	TestFixtures.check(res, "the fire summary names the merc",
		String(summary["name"]) == mine.name, String(summary["name"]))
	TestFixtures.check(res, "the fire summary holds the wage",
		int(summary["salary"]) == 250, str(summary["salary"]))
	TestFixtures.check(res, "the fire summary states how long they served",
		String(summary["employed_text"]) != "", String(summary["employed_text"]))
	TestFixtures.check(res, "firing a happy merc costs seven mood",
		int(summary["drop"]) == 7, str(summary["drop"]))
	TestFixtures.check(res, "the mood after firing stops at the floor",
		int(summary["opinion_after"]) == -2, str(summary["opinion_after"]))
	TestFixtures.check(res, "nobody likes them yet", int(summary["friends"]) == 0,
		str(summary["friends"]))
	TestFixtures.check(res, "no friends reads in the plural",
		String(summary["friends_text"]) == "0 mercs have a good relationship with this merc",
		String(summary["friends_text"]))
	TestFixtures.check(res, "no friends reads dim",
		summary["friends_color"] == PayrollLogic.OFF_COLOR, str(summary["friends_color"]))
	var friend: MercView = BenefitsManager.view_of(_uid(1))
	friend.relationships[uid] = BenefitsManager.GOOD_RELATION + 10
	summary = BenefitsManager.fire_summary(uid)
	TestFixtures.check(res, "a friend is counted", int(summary["friends"]) == 1,
		str(summary["friends"]))
	TestFixtures.check(res, "one friend reads in the singular",
		String(summary["friends_text"]) == "1 merc has a good relationship with this merc",
		String(summary["friends_text"]))
	TestFixtures.check(res, "a friend reads in the warning colour",
		summary["friends_color"] == PayrollLogic.OVER_COLOR, str(summary["friends_color"]))
	var notes: Array[Dictionary] = summary["notes"]
	var found: bool = false
	for note: Dictionary in notes:
		if String(note["text"]) == "You have no other Lonelys":
			found = note["color"] == PayrollLogic.NOTE_COLOR
	TestFixtures.check(res, "the last of a tradition is noted", found, str(notes))
	mine.tradition = "Common"
	notes = BenefitsManager.fire_summary(uid)["notes"]
	var shared: bool = true
	for note: Dictionary in notes:
		if String(note["text"]) == "You have no other Commons":
			shared = false
	TestFixtures.check(res, "a shared tradition is not noted", shared, str(notes))


static func _case_fire(res: Dictionary) -> void:
	_fresh()
	TestFixtures.add_mercs(FIRE_ROSTER - GameState.mercs.size())
	var seen: Dictionary = {"n": 0}
	var counter: Callable = func() -> void:
		seen["n"] = int(seen["n"]) + 1
	BenefitsManager.changed.connect(counter)
	var uid: int = _uid(0)
	_set_pay(uid, BASE_SALARY, 5)
	var kept: MercenaryData = GameState.merc_by_uid(uid)
	GameState.pip_modes[uid] = PipDefs.DEFAULT_MODE
	var roster_size: int = GameState.roster.size()
	TestFixtures.check(res, "an available merc can be let go", BenefitsManager.fire(uid), str(uid))
	TestFixtures.check(res, "firing a happy merc drops the mood to minus two",
		_left_opinion(uid) == -2, str(_left_opinion(uid)))
	TestFixtures.check(res, "a merc let go is remembered", BenefitsManager.is_fired(uid), str(uid))
	TestFixtures.check(res, "a merc let go leaves the guild the same minute",
		GameState.merc_by_uid(uid) == null and GameState.roster.size() == roster_size - 1,
		"roster %d was %d" % [GameState.roster.size(), roster_size])
	TestFixtures.check(res, "a merc let go takes its uid keys with it",
		not GameState.merc_extras.has(uid) and not GameState.pip_modes.has(uid)
		and not GameState.is_away(uid), str(GameState.merc_extras.has(uid)))
	var record: RemovedMercRecord = GameState.removed_by_uid(uid)
	TestFixtures.check(res, "a merc let go is filed in the removed queue",
		record != null and record.reason == "fired" and record.uid == uid
		and record.status == GuiTypes.MercStatus.FIRED, str(GameState.removed_count()))
	TestFixtures.check(res, "the record keeps the merc itself, the wage and the mood it left with",
		record != null and record.merc == kept and record.salary == BASE_SALARY
		and record.guild_opinion == -2 and record.name == kept.merc_name,
		str(record.to_dict()) if record != null else "no record")
	TestFixtures.check(res, "a merc let go reads fired",
		BenefitsManager.status_of(uid) == GuiTypes.MercStatus.FIRED,
		str(BenefitsManager.status_of(uid)))
	TestFixtures.check(res, "a merc let go cannot be let go twice",
		not BenefitsManager.fire(uid), str(uid))
	TestFixtures.check(res, "letting a merc go tells the screens once", int(seen["n"]) == 1,
		str(seen["n"]))
	BenefitsManager.changed.disconnect(counter)
	var neutral: int = _uid(1)
	_set_pay(neutral, BASE_SALARY, 0)
	BenefitsManager.fire(neutral)
	TestFixtures.check(res, "firing a neutral merc drops the mood three",
		_left_opinion(neutral) == -3, str(_left_opinion(neutral)))
	var angry: int = _uid(2)
	_set_pay(angry, BASE_SALARY, SalarySystem.OPINION_MIN)
	BenefitsManager.fire(angry)
	TestFixtures.check(res, "firing an angry merc cannot drop the mood further",
		_left_opinion(angry) == SalarySystem.OPINION_MIN, str(_left_opinion(angry)))
	var resting: int = _uid(3)
	_rest(resting, RestSystem.KIND_BREATHER)
	TestFixtures.check(res, "a resting merc can be let go", BenefitsManager.fire(resting),
		str(BenefitsManager.status_of(resting)))
	var away: int = _uid(4)
	_rest(away, RestSystem.KIND_FURLOUGH)
	TestFixtures.check(res, "a merc on vacation cannot be let go", not BenefitsManager.fire(away),
		str(BenefitsManager.status_of(away)))
	TestFixtures.check(res, "a refused firing is not remembered",
		not BenefitsManager.is_fired(away), str(away))
	_wake(away)
	var lost: int = _uid(5)
	var dead: MercenaryData = GameState.merc_by_uid(lost)
	dead.is_dead = true
	GameState.refresh_views()
	TestFixtures.check(res, "a dead merc cannot be let go", not BenefitsManager.fire(lost),
		str(BenefitsManager.status_of(lost)))
	dead.is_dead = false
	GameState.refresh_views()
	TestFixtures.check(res, "a uid nobody holds cannot be let go", not BenefitsManager.fire(-1),
		"-1")
	BenefitsManager.reset()
	TestFixtures.check(res, "a reset forgets who was let go", not BenefitsManager.is_fired(uid),
		str(BenefitsManager.fired.size()))


static func _case_contract_bonus(res: Dictionary) -> void:
	_fresh()
	BenefitsManager.set_benefit("contract", 20)
	var ids: Array[int] = ResultsPreview.seed_results()
	TestFixtures.check(res, "the seeded results are there", ids.size() >= 2, str(ids.size()))
	if ids.size() < 2:
		return
	var won: ContractResultData = GameState.result_of(ids[0])
	TestFixtures.check(res, "a recorded result is kept", won != null, str(ids[0]))
	if won == null:
		return
	TestFixtures.check(res, "the benefit writes the bonus share", won.bonus_pct == 20,
		str(won.bonus_pct))
	var paid: int = 0
	for member: ResultMemberData in won.members:
		paid += member.pay
	TestFixtures.check(res, "the pay handed out is the whole bonus", paid == won.bonus(),
		str(paid) + " of " + str(won.bonus()))
	TestFixtures.check(res, "the bonus is a fifth of the reward, before the expenses",
		won.bonus() == int(floor(float(won.reward) * 0.2)), str(won.bonus()))
	TestFixtures.check(res, "the guild keeps the rest",
		won.guild_share() == won.net() - won.bonus(), str(won.guild_share()))
	var lost: ContractResultData = GameState.result_of(ids[1])
	TestFixtures.check(res, "a failed contract pays no bonus",
		lost != null and lost.bonus() == 0, str(ids[1]))
	BenefitsManager.set_benefit("contract", 0)
	var again: Array[int] = ResultsPreview.seed_results()
	if again.size() < 1:
		return
	var plain: ContractResultData = GameState.result_of(again[0])
	TestFixtures.check(res, "no benefit pays no bonus",
		plain != null and plain.bonus_pct == 0 and plain.bonus() == 0, str(again[0]))


#The tick walks every calendar day passed, so a step or a jump over a month start owes the
#profit share once per 1st it crossed and the first call after a reset owes nothing.
static func _case_tick(res: Dictionary) -> void:
	_fresh()
	BenefitsManager.set_benefit("profit", 10)
	var seen: Dictionary = {"n": 0, "pct": 0}
	var counter: Callable = func(pct: int) -> void:
		seen["n"] = int(seen["n"]) + 1
		seen["pct"] = pct
	BenefitsManager.profit_share_due.connect(counter)
	var date: Dictionary = TrynnCalendar.date_of(CampaignClock.now())
	var first: int = TrynnCalendar.month_start_minute(int(date["year"]), int(date["month"]))
	BenefitsManager.tick(first)
	TestFixtures.check(res, "the first tick after a reset only records the day",
		int(seen["n"]) == 0, str(seen["n"]))
	BenefitsManager.tick(first)
	TestFixtures.check(res, "one day calls the profit share once", int(seen["n"]) == 0,
		str(seen["n"]))
	BenefitsManager.tick(first + CampaignClock.MINUTES_PER_DAY)
	TestFixtures.check(res, "the second of the month calls nothing", int(seen["n"]) == 0,
		str(seen["n"]))
	var second: int = TrynnCalendar.next_month_start(first)
	BenefitsManager.tick(second + CampaignClock.MINUTES_PER_DAY)
	TestFixtures.check(res, "a step over a month start calls the profit share once",
		int(seen["n"]) == 1, str(seen["n"]))
	TestFixtures.check(res, "the profit share carries the benefit",
		int(seen["pct"]) == 10, str(seen["pct"]))
	var fourth: int = TrynnCalendar.next_month_start(TrynnCalendar.next_month_start(second))
	seen["n"] = 0
	BenefitsManager.tick(fourth)
	TestFixtures.check(res, "a jump over two month starts calls the profit share twice",
		int(seen["n"]) == 2, str(seen["n"]))
	BenefitsManager.set_benefit("profit", 0)
	seen["n"] = 0
	BenefitsManager.tick(TrynnCalendar.next_month_start(fourth)
		+ CampaignClock.MINUTES_PER_DAY)
	TestFixtures.check(res, "no profit share benefit calls nothing", int(seen["n"]) == 0,
		str(seen["n"]))
	BenefitsManager.profit_share_due.disconnect(counter)
	BenefitsManager.reset()
#The payday countdown off the calendar: a fresh campaign sits on the 3rd of Erta at 8:00, so the
#next wages are 39 days out on the 2nd of Kusarra, and the text falls to whole hours on the last day.
static func _case_payday(res: Dictionary) -> void:
	_fresh()
	var now: int = CampaignClock.now()
	var due: int = BenefitsManager.next_payday_minute()
	TestFixtures.check(res, "the next payday is the minute GameState owns and is ahead of the clock",
		due > now and due == GameState.next_payday_minute(),
		"due %d state %d now %d" % [due, GameState.next_payday_minute(), now])
	TestFixtures.check(res, "the minutes left are the gap to that minute",
		BenefitsManager.payday_minutes_left() == due - now,
		"left %d gap %d" % [BenefitsManager.payday_minutes_left(), due - now])
	var days: int = BenefitsManager.payday_days_left()
	TestFixtures.check(res, "a fresh campaign on the 3rd of Erta is 39 days from payday",
		days == 39 and BenefitsManager.payday_text() == GuiDates.plural(39, "Day"),
		"days %d text '%s'" % [days, BenefitsManager.payday_text()])
	TestFixtures.check(res, "a payday that far out reads in the good colour",
		BenefitsManager.payday_color() == PayrollLogic.OK_COLOR,
		str(BenefitsManager.payday_color()))
	CampaignClock.advance_to(due - 15 * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "fifteen days out reads plainly",
		BenefitsManager.payday_days_left() == 15
			and BenefitsManager.payday_color() == GuiColors.CREAM,
		"days %d colour %s"
			% [BenefitsManager.payday_days_left(), BenefitsManager.payday_color()])
	CampaignClock.advance_to(due - 6 * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "six days out warns",
		BenefitsManager.payday_days_left() == 6
			and BenefitsManager.payday_color() == PayrollLogic.WARN_COLOR,
		"days %d colour %s"
			% [BenefitsManager.payday_days_left(), BenefitsManager.payday_color()])
	CampaignClock.advance_to(due - 2 * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "two days out reads over",
		BenefitsManager.payday_days_left() == 2
			and BenefitsManager.payday_text() == GuiDates.plural(2, "Day")
			and BenefitsManager.payday_color() == PayrollLogic.OVER_COLOR,
		"days %d text '%s'" % [BenefitsManager.payday_days_left(),
			BenefitsManager.payday_text()])
	CampaignClock.advance_to(due - 90)
	TestFixtures.check(res, "the last day counts in whole hours rounded up",
		BenefitsManager.payday_days_left() == 0
			and BenefitsManager.payday_text() == GuiDates.plural(2, "Hour"),
		"days %d text '%s'" % [BenefitsManager.payday_days_left(),
			BenefitsManager.payday_text()])
	CampaignClock.advance_to(due - 30)
	TestFixtures.check(res, "half an hour out still reads one hour",
		BenefitsManager.payday_text() == GuiDates.plural(1, "Hour"),
		BenefitsManager.payday_text())
	CampaignClock.advance_to(due)
	TestFixtures.check(res, "the payday minute itself points at the next month",
		BenefitsManager.next_payday_minute() > due
			and BenefitsManager.payday_minutes_left() > 0,
		"next %d due %d" % [BenefitsManager.next_payday_minute(), due])
	CampaignClock.reset()
	BenefitsManager.reset()


#The simultaneous vacation bound: the manager takes 0 to 50 mercs away at once and the dialog
#floors its own field at one.
static func _case_max_at(res: Dictionary) -> void:
	_fresh()
	BenefitsManager.set_vacation({"max_at": 999})
	TestFixtures.check(res, "the policy caps the mercs away at once at fifty",
		BenefitsManager.policy().max_at == VacationPolicy.MAX_AT_MAX
			and VacationPolicy.MAX_AT_MAX == 50,
		"max_at %d cap %d" % [BenefitsManager.policy().max_at, VacationPolicy.MAX_AT_MAX])
	var rows: Array[Dictionary] = BenefitsManager.vacation_rows()
	var text: String = ""
	for row: Dictionary in rows:
		if String(row.get("key", "")) == "max_at":
			text = String(row.get("value_text", ""))
	TestFixtures.check(res, "the Simultaneous row reads the capped count",
		text == GuiDates.plural(50, "Merc"), text)
	BenefitsManager.set_vacation({"max_at": -4})
	TestFixtures.check(res, "the policy floors the mercs away at once at none",
		BenefitsManager.policy().max_at == 0, str(BenefitsManager.policy().max_at))
	BenefitsManager.reset()
	TestFixtures.check(res, "a reset puts the count back to the default",
		BenefitsManager.policy().max_at == VacationPolicy.DEFAULT_MAX_AT,
		str(BenefitsManager.policy().max_at))
