class_name SalaryProbe

#What generated mercs ask for: one line per hire in hire order, then the asking salary spread.
#Run: godot --headless --path . -- --salary-probe=20

const NAME_WIDTH := 22


static func run(n: int) -> bool:
	var count: int = maxi(1, n)
	var hired: Array[MercenaryData] = []
	var salaries: Array[int] = []
	print("SALARY PROBE: %d mercs hired in order" % count)
	print("%s %5s %7s %5s %7s %8s" % ["MERC".rpad(NAME_WIDTH), "LEVEL", "RARITY", "NEED", "SALARY",
		"OPINION"])
	for i: int in range(count):
		TestFixtures.reset_generator_rolls()
		var merc: MercenaryData = MercGenerator.generate(i)
		if merc == null:
			continue
		var rarity: int = SalarySystem.rarity_score(merc)
		var need: int = SalarySystem.need_score(merc, hired)
		SalarySystem.hire(merc, hired, CampaignClock.now())
		salaries.append(merc.monthly_salary)
		print("%s %5d %7d %5d %7d %8d" % [merc.merc_name.substr(0, NAME_WIDTH).rpad(NAME_WIDTH),
			ExperienceSystem.current_level(merc), rarity, need, merc.monthly_salary,
			merc.guild_opinion])
		hired.append(merc)
	_distribution(salaries)
	return true


#The asking salary spread: the range, the mean and a count per salary, low to high.
static func _distribution(salaries: Array[int]) -> void:
	if salaries.is_empty():
		print("SALARY PROBE: no mercs generated")
		return
	var counts: Dictionary = {}
	var total: int = 0
	var low: int = salaries[0]
	var high: int = salaries[0]
	for salary: int in salaries:
		counts[salary] = int(counts.get(salary, 0)) + 1
		total += salary
		low = mini(low, salary)
		high = maxi(high, salary)
	print("SALARY SPREAD: %d mercs, %d to %d notes, mean %.2f"
		% [salaries.size(), low, high, float(total) / float(salaries.size())])
	var keys: Array = counts.keys()
	keys.sort()
	for key: Variant in keys:
		var many: int = int(counts[key])
		print("  %5d notes  %2d  %s" % [int(key), many, "#".repeat(many)])
