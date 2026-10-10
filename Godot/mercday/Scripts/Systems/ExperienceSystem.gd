class_name ExperienceSystem

#Lifetime experience and level ups. Level is floor(xp / 100); xp only ever rises.
#Encounter awards run at the end of a battle event, level ups at contract end.

const XP_PER_LEVEL := 100


static func level_for(xp: int) -> int:
	return int(maxi(0, xp) / float(XP_PER_LEVEL))


static func xp_for_level(level: int) -> int:
	return maxi(0, level) * XP_PER_LEVEL


static func enemy_xp(merc_level: int, enemy_level: int) -> int:
	if enemy_level >= 2 * merc_level and enemy_level > merc_level:
		return 25
	if enemy_level > merc_level:
		return 11
	if enemy_level == merc_level:
		return 10
	if enemy_level <= int(merc_level / 2.0):
		return 1
	return 5


static func current_level(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	return int(merc.stats.get("level", 0))


static func award(merc: MercenaryData, amount: int, reason: String) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or amount <= 0 or merc.merc_uid <= 0:
		return lines
	merc.xp += amount
	lines.append("XP AWARD: %s +%d (%s) total %d" % [merc.merc_name, amount, reason, merc.xp])
	return lines


#Writes the level the xp total implies without any lifepath roll.
static func set_level_from_xp(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	var target: int = level_for(merc.xp)
	if target == current_level(merc):
		return target
	_write_level(merc, target)
	return target


#One level at a time so every level gained gets its own lifepath roll and its own level-up picks.
static func resolve_level_ups(merc: MercenaryData) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or merc.merc_uid <= 0:
		return lines
	var target: int = level_for(merc.xp)
	var cur: int = current_level(merc)
	while cur < target:
		cur += 1
		_write_level(merc, cur)
		lines.append("LEVEL UP: %s is now level %d (%d xp)" % [merc.merc_name, cur, merc.xp])
		lines.append_array(LifepathProgression.on_level_up(merc))
		lines.append_array(LevelUpSystem.on_level(merc, cur))
	return lines


#Primes the stats, writes the level and refreshes everything derived from it.
static func _write_level(merc: MercenaryData, level: int) -> void:
	StatCalculator.prime(merc)
	merc.stats["level"] = float(level)
	StatCalculator.refresh(merc)


#`dealt` is attacker -> {target -> total damage} for the whole encounter.
static func award_encounter(team_a: Array[MercenaryData], enemies: Array[MercenaryData],
		dealt: Dictionary, event_name: String) -> Array[String]:
	var lines: Array[String] = []
	var levels: Dictionary = {}
	for merc: MercenaryData in team_a:
		if merc == null:
			continue
		levels[merc] = current_level(merc)
	var totals: Dictionary = {}
	var details: Dictionary = {}
	for enemy: MercenaryData in enemies:
		if enemy == null or not (enemy.is_dead or enemy.current_hp <= 0 or enemy.off_field):
			continue
		var e_level: int = current_level(enemy)
		for merc: MercenaryData in team_a:
			if merc == null or merc.merc_uid <= 0 or merc.is_dead:
				continue
			var full: int = enemy_xp(int(levels.get(merc, 0)), e_level)
			var by_target: Dictionary = dealt.get(merc, {})
			var hit: bool = int(by_target.get(enemy, 0)) > 0
			var amount: int = full if hit else int(full / 2.0)
			if amount <= 0:
				continue
			totals[merc] = int(totals.get(merc, 0)) + amount
			if not details.has(merc):
				var fresh: Array[String] = []
				details[merc] = fresh
			var parts: Array[String] = details[merc]
			parts.append("%s L%d %s %d" % [enemy.merc_name, e_level, "hit" if hit else "assist", amount])
	for merc: MercenaryData in team_a:
		if not totals.has(merc):
			continue
		var detail: Array[String] = details[merc]
		lines.append_array(award(merc, int(totals[merc]), "%s: %s" % [event_name, ", ".join(detail)]))
	return lines


#10 x difficulty to every living merc when the verdict is Succeeded.
static func award_contract(run: ContractRun) -> Array[String]:
	var lines: Array[String] = []
	if run == null or run.contract == null or run.verdict != "Succeeded":
		return lines
	var amount: int = int(round(10.0 * run.contract.difficulty))
	var label: String = "contract %s difficulty %s" % [run.contract.contract_type,
		_fmt_difficulty(run.contract.difficulty)]
	for merc: MercenaryData in run.living_team():
		lines.append_array(award(merc, amount, label))
	return lines


static func _fmt_difficulty(value: float) -> String:
	return String.num(value, 1).trim_suffix(".0")
