class_name ResultsTimeline

#Every key of the contract results sequence and every value as a pure function of one clock.
#The panel keeps the clock; nothing here holds state, so a suite can read any moment directly.

const BARS_START: float = 0.2
const BARS_END: float = 1.4
const FATES: float = 1.2
const FATE_POP: float = 0.2
const TOLD: float = 2.5
const VERDICT_IN: float = 2.3
const VERDICT_HOLD: float = 2.55
const VERDICT_SHRINK: float = 2.9
const VERDICT_FLY: float = 3.2
const VERDICT_DOCKED: float = 3.75
const VERDICT_BIG: float = 2.4
const VERDICT_SMALL: float = 0.8
const BOUNCE_RATE: float = 18.0
const BOUNCE_DECAY: float = 3.0
const BOUNCE_SIZE: float = 0.05
const DIM_FADE: float = 0.4
const XP_START: float = 3.8
const XP_END: float = 6.0
const REWARD_START: float = 6.0
const REWARD_END: float = 6.8
const EXPENSE_START: float = 6.8
const EXPENSE_END: float = 7.4
const NET_START: float = 7.4
const NET_END: float = 8.0
const BONUS_START: float = 8.3
const BONUS_END: float = 9.4
const PAYOUT_START: float = 8.2
const PAYOUT_END: float = 9.7
const PAY_START: float = 8.5
const PAY_SPAN: float = 0.8
const ROW_STAGGER: float = 0.12
const NOTE_STAGGER: float = 0.07
const NOTE_FLIGHT: float = 0.6
const NOTE_ARC_PX: float = 70.0
const NOTES_PER_ROW: int = 5
const END_WITH_BONUS: float = 9.7
const END_PLAIN: float = 8.2
const FLY_SECONDS: float = 1.6

#Experience offsets, all measured from XP_START.
const XP_FILL_SPAN: float = 1.2
const XP_LEVEL_SPAN: float = 0.8
const XP_TEXT_SPAN_UP: float = 2.0
const XP_FLASH_IN: float = 1.0
const XP_FLASH_OUT: float = 1.5
const XP_PLUS_AT: float = 1.3
const XP_GLOW_IN: float = 1.2
const XP_GLOW_OUT: float = 1.9
const XP_CARRY_SPAN: float = 0.7
const FLIP_RATE: float = 10.0

const ACCENT: Color = Color("#f28c28")
const SUCCESS: Color = Color("#6cc36a")
const FAILURE: Color = Color("#e8583f")
const SUCCESS_DARK: Color = Color("#2f6a2e")
const FAILURE_DARK: Color = Color("#7a2a1e")
const CAPTURED: Color = Color("#f2b33d")
const CREAM: Color = Color("#f3ead7")
const MUTED: Color = Color("#5e7699")
const SKY: Color = Color("#9cc6ef")
const GOLD: Color = Color("#f2d33d")
const GOLD_HI: Color = Color("#fff08a")
const RING_IDLE: Color = Color("#1f3560")
const RING_DEAD: Color = Color("#a83a28")
const RING_CAPTURED: Color = Color("#b8862a")
const OVERLAY_BARS: Color = Color("#c8cdd8")
const XP_FILL: Color = Color("#f2b33d")
const XP_FILL_UP: Color = Color("#f2d33d")
const XP_FILL_FLASH: Color = Color("#fff08a")

const SUCCESS_TEXT: String = "SUCCESS!"
const FAILURE_TEXT: String = "FAILURE"
const TITLE_TEXT: String = "Contract Complete"
const PENDING_TEXT: String = "..."
const BLANK_TEXT: String = "-"
const REWARD_LABEL: String = "Reward"
const REWARD_LOST_LABEL: String = "Reward (Forfeited)"
const NET_LABEL: String = "Notes Earned"
const COST_LABEL: String = "Total Cost"
const EXPENSE_LABEL: String = "Expenses"

const GRAY_DEAD: float = 1.0
const BRIGHT_DEAD: float = 0.6
const GRAY_CAPTURED: float = 0.5
const BRIGHT_CAPTURED: float = 0.7


static func clamp01(value: float) -> float:
	return clampf(value, 0.0, 1.0)


#The prototype easing: fast in, soft out, clamped at both ends.
static func ease_out(value: float) -> float:
	var v: float = clamp01(value)
	return 1.0 - (1.0 - v) * (1.0 - v)


static func fates_on(t: float) -> bool:
	return t >= FATES


static func told(t: float) -> bool:
	return t >= TOLD


static func end_time(result: ContractResultData) -> float:
	if result != null and result.bonus() > 0:
		return END_WITH_BONUS
	return END_PLAIN


static func total_time(result: ContractResultData) -> float:
	return end_time(result) + FLY_SECONDS


static func continue_enabled(result: ContractResultData, t: float) -> bool:
	return t >= total_time(result)


static func verdict_text(result: ContractResultData) -> String:
	if result != null and result.failed:
		return FAILURE_TEXT
	return SUCCESS_TEXT


static func verdict_color(result: ContractResultData) -> Color:
	if result != null and result.failed:
		return FAILURE
	return SUCCESS


static func verdict_dark(result: ContractResultData) -> Color:
	if result != null and result.failed:
		return FAILURE_DARK
	return SUCCESS_DARK


#Orange until the verdict finishes docking, then the outcome colour.
static func accent_color(result: ContractResultData, t: float) -> Color:
	if t < VERDICT_DOCKED:
		return ACCENT
	return verdict_color(result)


static func verdict_move(t: float) -> float:
	return ease_out((t - VERDICT_FLY) / (VERDICT_DOCKED - VERDICT_FLY))


static func verdict_opacity(t: float) -> float:
	if t < VERDICT_IN:
		return 0.0
	return clamp01(_slam(t) * 2.0)


static func dim_opacity(t: float) -> float:
	if t < VERDICT_IN:
		return 0.0
	return clamp01(_slam(t) * 2.0) * (1.0 - clamp01((t - VERDICT_FLY) / DIM_FADE))


static func verdict_scale(t: float, dock_scale: float) -> float:
	var base: float = _verdict_base(t)
	return base + (dock_scale - base) * verdict_move(t)


static func verdict_position(t: float, center: Vector2, dock: Vector2) -> Vector2:
	return center.lerp(dock, verdict_move(t))


static func fate_scale(t: float) -> float:
	return 1.0 + 0.5 * (1.0 - clamp01((t - FATES) / FATE_POP))


static func bar_value(before: int, after: int, t: float) -> float:
	var span: float = ease_out((t - BARS_START) / (BARS_END - BARS_START))
	return float(before) + float(after - before) * span


static func status_text(member: ResultMemberData, t: float) -> String:
	if member == null:
		return PENDING_TEXT
	if not fates_on(t):
		return PENDING_TEXT
	return member.fate_name()


static func status_color(member: ResultMemberData, t: float) -> Color:
	if not fates_on(t) or member == null:
		return SKY
	if member.fate == ResultMemberData.Fate.DEAD:
		return FAILURE
	if member.fate == ResultMemberData.Fate.CAPTURED:
		return CAPTURED
	return SUCCESS


static func ring_color(member: ResultMemberData, t: float, failed: bool) -> Color:
	if member == null:
		return RING_IDLE
	if mvp_on(member, t, failed):
		return GOLD
	if not fates_on(t):
		return RING_IDLE
	if member.fate == ResultMemberData.Fate.DEAD:
		return RING_DEAD
	if member.fate == ResultMemberData.Fate.CAPTURED:
		return RING_CAPTURED
	return RING_IDLE


static func portrait_gray(member: ResultMemberData, t: float) -> float:
	if member == null or not fates_on(t):
		return 0.0
	if member.fate == ResultMemberData.Fate.DEAD:
		return GRAY_DEAD
	if member.fate == ResultMemberData.Fate.CAPTURED:
		return GRAY_CAPTURED
	return 0.0


static func portrait_brightness(member: ResultMemberData, t: float) -> float:
	if member == null or not fates_on(t):
		return 1.0
	if member.fate == ResultMemberData.Fate.DEAD:
		return BRIGHT_DEAD
	if member.fate == ResultMemberData.Fate.CAPTURED:
		return BRIGHT_CAPTURED
	return 1.0


static func mvp_on(member: ResultMemberData, t: float, failed: bool) -> bool:
	return member != null and member.mvp and not failed and told(t)


static func pay_value(member: ResultMemberData, index: int, t: float) -> int:
	if member == null or not member.alive():
		return 0
	var start: float = PAY_START + float(index) * ROW_STAGGER
	return int(round(float(member.pay) * ease_out((t - start) / PAY_SPAN)))


static func pay_text(member: ResultMemberData, index: int, t: float, failed: bool) -> String:
	if not told(t):
		return "+0"
	if member == null or not member.alive() or failed:
		return BLANK_TEXT
	return "+%d" % pay_value(member, index, t)


static func pay_color(member: ResultMemberData, _index: int, t: float, failed: bool) -> Color:
	if not told(t):
		return SKY
	if member == null or not member.alive() or failed:
		return MUTED
	if member.pay > 0:
		return GOLD
	return SKY


#The fill, the level box and the two texts of one experience column.
static func xp_state(member: ResultMemberData, t: float) -> Dictionary:
	var out: Dictionary = {
		"fill": 0.0,
		"level": 0,
		"plus": false,
		"flash": false,
		"glow": false,
		"text": PENDING_TEXT,
		"number": "",
		"need": 0,
		"color": XP_FILL,
		"fill_color": XP_FILL,
	}
	if member == null:
		return out
	var need: int = maxi(1, member.xp_need)
	out["level"] = member.level_before
	out["need"] = need
	if not member.alive():
		out["fill"] = clamp01(float(member.xp_before) / float(need))
		out["text"] = BLANK_TEXT if fates_on(t) else PENDING_TEXT
		out["color"] = MUTED if fates_on(t) else XP_FILL
		return out
	var need_after: int = need if member.xp_need_after <= 0 else member.xp_need_after
	var rel: float = t - XP_START
	var up: bool = member.levelled()
	var shown: int = need
	var fill: float = 0.0
	if not up:
		fill = float(member.xp_before) + float(member.xp_gained) * ease_out(rel / XP_FILL_SPAN)
		fill /= float(need)
	elif rel < XP_FLASH_OUT:
		var room: float = float(need - member.xp_before)
		fill = (float(member.xp_before) + room * ease_out(rel / XP_LEVEL_SPAN)) / float(need)
		if rel >= XP_FLASH_IN:
			out["flash"] = int(rel * FLIP_RATE) % 2 == 0
			out["fill_color"] = XP_FILL_FLASH if bool(out["flash"]) else XP_FILL_UP
	else:
		var carry: int = maxi(0, member.xp_before + member.xp_gained - need)
		shown = maxi(1, need_after)
		fill = float(carry) * ease_out((rel - XP_FLASH_OUT) / XP_CARRY_SPAN) / float(shown)
	out["fill"] = clamp01(fill)
	out["plus"] = up and rel >= XP_PLUS_AT
	out["glow"] = up and rel >= XP_GLOW_IN and rel < XP_GLOW_OUT
	out["level"] = member.level_after if bool(out["plus"]) else member.level_before
	out["need"] = shown
	var span: float = XP_TEXT_SPAN_UP if up else XP_FILL_SPAN
	var gained: int = int(round(float(member.xp_gained) * ease_out(rel / span)))
	out["text"] = "+%d XP" % gained if fates_on(t) else PENDING_TEXT
	out["number"] = "%d / %d" % [int(round(float(out["fill"]) * float(shown))), shown]
	return out


#The four money rows of the Notes Earned box at one moment.
static func money_state(result: ContractResultData, t: float) -> Dictionary:
	var out: Dictionary = {
		"reward": 0,
		"expenses": 0,
		"net": 0,
		"bonus": 0,
		"reward_label": REWARD_LABEL,
		"expense_label": EXPENSE_LABEL,
		"net_label": NET_LABEL,
		"bonus_label": "",
		"reward_color": CREAM,
		"net_color": SUCCESS,
		"bonus_visible": false,
	}
	if result == null:
		return out
	var lost: bool = result.failed and told(t)
	var total: int = result.bonus()
	var paid: float = ease_out((t - BONUS_START) / (BONUS_END - BONUS_START))
	out["reward"] = _count(result.reward, t, REWARD_START, REWARD_END)
	out["expenses"] = _count(result.expenses, t, EXPENSE_START, EXPENSE_END)
	out["bonus"] = int(round(float(total) * paid))
	if result.failed:
		out["net"] = -_count(result.expenses, t, NET_START, NET_END)
	else:
		var grown: float = ease_out((t - NET_START) / (NET_END - NET_START))
		out["net"] = int(round(float(result.net()) * grown - float(total) * paid))
	out["reward_label"] = REWARD_LOST_LABEL if lost else REWARD_LABEL
	out["reward_color"] = MUTED if lost else CREAM
	out["net_label"] = COST_LABEL if lost else NET_LABEL
	out["net_color"] = SUCCESS if result.net() >= 0 else FAILURE
	out["bonus_label"] = "Merc Bonus (%d%%)" % result.bonus_pct
	out["bonus_visible"] = total > 0 and t >= PAYOUT_START
	return out


#Every note in flight: the row it is paid to and how far along the arc it sits.
static func pay_notes(result: ContractResultData, t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if result == null or result.bonus() <= 0 or t < PAYOUT_START or t >= PAYOUT_END:
		return out
	for k: int in result.members.size():
		var member: ResultMemberData = result.members[k]
		if member == null or not member.alive() or member.pay <= 0:
			continue
		for j: int in NOTES_PER_ROW:
			var start: float = PAYOUT_START + float(k) * ROW_STAGGER + float(j) * NOTE_STAGGER
			var progress: float = clamp01((t - start) / NOTE_FLIGHT)
			if progress <= 0.0 or progress >= 1.0:
				continue
			out.append({"index": k, "progress": progress})
	return out


#Where one flying note sits between the Notes Earned box and a pay cell.
static func note_point(from: Vector2, to: Vector2, progress: float) -> Vector2:
	var point: Vector2 = from.lerp(to, progress)
	point.y -= NOTE_ARC_PX * sin(PI * progress)
	return point


static func _count(total: int, t: float, from: float, to: float) -> int:
	return int(round(float(total) * ease_out((t - from) / (to - from))))


static func _slam(t: float) -> float:
	return clamp01((t - VERDICT_IN) / (VERDICT_HOLD - VERDICT_IN))


static func _verdict_base(t: float) -> float:
	if t < VERDICT_IN:
		return VERDICT_BIG
	var slam: float = _slam(t)
	if slam < 1.0:
		return VERDICT_BIG - (VERDICT_BIG - 1.0) * ease_out(slam)
	if t < VERDICT_SHRINK:
		var wave: float = maxf(0.0, sin((t - VERDICT_HOLD) * BOUNCE_RATE))
		var decay: float = maxf(0.0, 1.0 - (t - VERDICT_HOLD) * BOUNCE_DECAY)
		return 1.0 + BOUNCE_SIZE * wave * decay
	var shrink: float = ease_out((t - VERDICT_SHRINK) / (VERDICT_FLY - VERDICT_SHRINK))
	return 1.0 - (1.0 - VERDICT_SMALL) * shrink
