class_name SalarySystem

#Merc wages: what a merc asks at hire, what the guild owes each month and how a raise or a cut moves
#the guild's opinion of them. The asking salary is stored flat at hire and only a change replaces it.
#Employment months are the caller's business; TrynnCalendar owns that arithmetic.

#Raise breakpoints as [percent, opinion delta], read high to low; over 100% each further step adds one.
const RAISE_STEPS: Array[Array] = [[100.0, 4], [50.0, 3], [25.0, 2], [15.0, 1]]
const RAISE_EXTRA_PERCENT: float = 50.0
#Cut breakpoints as [percent below zero, opinion delta], read deep to shallow.
const CUT_STEPS: Array[Array] = [[30.0, -7], [25.0, -6], [20.0, -5], [15.0, -4], [10.0, -3], [5.0, -2], [1.0, -1]]
const OPINION_MIN: int = -5
const OPINION_MAX: int = 5
#Opinion a merc starts at before their Wile is added.
const OPINION_BASE: int = -1
#A cut that leaves this wage or less drops the merc to the lowest opinion.
const TANK_SALARY: int = 1
const FIRE_DROP_SHARE: float = 0.75
#Notes asked per level, per rarity point and per need point.
const ASK_LEVEL: int = 2
const ASK_RARITY: int = 2
const ASK_NEED: int = 2


#Knowledges and tools by their own rarity, the primary ancestry, and every piece of carried gear.
#Bloodline, hybrid and recessive ancestries and the heritage never count.
static func rarity_score(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	var total: int = 0
	for k: UtilityTraitData in merc.knowledges:
		if k != null:
			total += RarityRank.rank(k.utility_rarity)
	for t: UtilityTraitData in merc.tools:
		if t != null:
			total += RarityRank.rank(t.utility_rarity)
	if merc.ancestry != null:
		total += RarityRank.rank(merc.ancestry.rarity)
	for item: ItemData in carried_gear(merc):
		total += RarityRank.rank(item.item_rarity)
	return total


#Held weapons and armor, then the loose inventory, the item list and one entry per ammo type in stock.
static func carried_gear(merc: MercenaryData) -> Array[ItemData]:
	var out: Array[ItemData] = []
	if merc == null:
		return out
	for slot: Variant in [merc.equipped_weapon, merc.offhand_weapon, merc.equipped_armor]:
		if slot is ItemData:
			out.append(slot as ItemData)
	for entry: Variant in merc.inventory:
		var data: Variant = (entry as Dictionary).get("data", null) if entry is Dictionary else entry
		if data is ItemData:
			out.append(data as ItemData)
	for entry: Variant in merc.items:
		if entry is ItemData:
			out.append(entry as ItemData)
	for ammo_name: Variant in merc.ammo_inventory:
		if int(merc.ammo_inventory[ammo_name]) <= 0:
			continue
		var ammo: ItemData = DataManager.ammo.get(String(ammo_name), null) as ItemData
		if ammo != null:
			out.append(ammo)
	return out


#What this merc brings that nobody hired before them already has; the first hire scores every point.
static func need_score(merc: MercenaryData, earlier: Array[MercenaryData]) -> int:
	if merc == null:
		return 0
	var total: int = 0
	if merc.tradition != null and not _shares(merc, earlier, "tradition"):
		total += 3
	if merc.ancestry != null and not _shares(merc, earlier, "ancestry"):
		total += 1
	if merc.heritage != null and not _shares(merc, earlier, "heritage"):
		total += 1
	for k: UtilityTraitData in merc.knowledges:
		if k != null and GuildRoster.holders("knowledge:" + k.utility_name, null, earlier) == 0:
			total += 1
	for t: UtilityTraitData in merc.tools:
		if t != null and GuildRoster.holders("tool:" + t.utility_name, null, earlier) == 0:
			total += 1
	return total


#True when an earlier hire has a row in `field` (tradition, ancestry or heritage) with the merc's own <field>_name.
static func _shares(merc: MercenaryData, earlier: Array[MercenaryData], field: String) -> bool:
	var mine: Resource = merc.get(field) as Resource
	if mine == null:
		return false
	var name_key: String = field + "_name"
	for other: MercenaryData in earlier:
		if other == null:
			continue
		var theirs: Resource = other.get(field) as Resource
		if theirs != null and theirs.get(name_key) == mine.get(name_key):
			return true
	return false


static func asking_salary(merc: MercenaryData, earlier: Array[MercenaryData]) -> int:
	if merc == null:
		return 1
	var level: int = ExperienceSystem.current_level(merc)
	return maxi(1, ASK_LEVEL * level + ASK_RARITY * rarity_score(merc)
		+ ASK_NEED * need_score(merc, earlier))


#Signs the merc on: their place in the hire order, the minute, the agreed wage and their opening opinion.
static func hire(merc: MercenaryData, earlier: Array[MercenaryData], now: int) -> void:
	if merc == null:
		return
	merc.hire_index = earlier.size()
	merc.hired_minute = now
	merc.monthly_salary = asking_salary(merc, earlier)
	merc.guild_opinion = clampi(OPINION_BASE + int(roundf(float(merc.stats.get("wile", 0.0)))),
		OPINION_MIN, OPINION_MAX)


static func is_captive(merc: MercenaryData) -> bool:
	if merc == null:
		return false
	return not MercPool.captive_record(merc.merc_uid).is_empty()


#What the guild owes on the next debit: the dead cost nothing and a captive's wage is withheld.
static func month_expenses(mercs: Array[MercenaryData]) -> int:
	var total: int = 0
	for merc: MercenaryData in mercs:
		if merc == null or merc.is_dead or is_captive(merc):
			continue
		total += merc.monthly_salary
	return total


#One month's wages: the caller moves the bank by "total"; a captive's wage is recorded, never paid.
static func monthly_debit(mercs: Array[MercenaryData], stamp: String) -> Dictionary:
	var prefix: String = "" if stamp == "" else stamp + " "
	var total: int = 0
	var backpay: int = 0
	var lines: Array[String] = []
	for merc: MercenaryData in mercs:
		if merc == null or merc.is_dead:
			continue
		if is_captive(merc):
			merc.backpay += merc.monthly_salary
			backpay += merc.monthly_salary
			lines.append("%sBACKPAY: %s %d notes (captive)" % [prefix, merc.merc_name, merc.monthly_salary])
			continue
		total += merc.monthly_salary
		lines.append("%sSALARY: %s %d notes" % [prefix, merc.merc_name, merc.monthly_salary])
	return {"total": total, "backpay": backpay, "lines": lines}


#Opinion the merc takes from a wage change; a salary of 0 or less has no percent to measure against.
static func opinion_delta(old_salary: int, new_salary: int) -> int:
	if old_salary <= 0:
		return 0
	var percent: float = float(new_salary - old_salary) * 100.0 / float(old_salary)
	if percent >= 100.0:
		return 4 + int(floorf((percent - 100.0) / RAISE_EXTRA_PERCENT))
	for step: Array in RAISE_STEPS:
		if percent >= float(step[0]):
			return int(step[1])
	for step: Array in CUT_STEPS:
		if percent <= -float(step[0]):
			return int(step[1])
	return 0


#The opinion a merc holds after a wage change: the raise or cut step, or the floor when a cut tanks the wage.
static func opinion_after(old_salary: int, new_salary: int, opinion: int) -> int:
	var shift: int = opinion_delta(old_salary, new_salary)
	if new_salary < old_salary and new_salary <= TANK_SALARY:
		shift = OPINION_MIN - opinion
	return clampi(opinion + shift, OPINION_MIN, OPINION_MAX)


#Writes the new wage and moves the opinion with it; returns the opinion the merc now holds.
static func apply_salary_change(merc: MercenaryData, new_salary: int) -> int:
	if merc == null:
		return 0
	var old_salary: int = merc.monthly_salary
	merc.monthly_salary = maxi(1, new_salary)
	return adjust_opinion(merc, opinion_after(old_salary, merc.monthly_salary, merc.guild_opinion) - merc.guild_opinion)


#Moves the merc's guild opinion by delta inside OPINION_MIN..OPINION_MAX; returns the opinion it now holds.
static func adjust_opinion(merc: MercenaryData, delta: int) -> int:
	if merc == null:
		return 0
	merc.guild_opinion = clampi(merc.guild_opinion + delta, OPINION_MIN, OPINION_MAX)
	return merc.guild_opinion
