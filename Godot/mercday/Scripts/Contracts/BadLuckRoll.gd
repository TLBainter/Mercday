class_name BadLuckRoll

#d100 against the team's average Luck; every full step above it adds one extra enemy.

static var forced_d100: int = -1


static func roll(team: Array[MercenaryData], step: int) -> Dictionary:
	var d100: int = Dice.forced_or_d100(forced_d100)
	forced_d100 = -1
	var avg: float = PartyStats.average_stat(team, "luck")
	var extra: int = maxi(0, int(floor((float(d100) - avg) / float(maxi(1, step)))))
	return {
		"d100": d100,
		"average_luck": avg,
		"extra": extra,
		"line": "BAD LUCK ROLL: d100 %d vs average Luck %.1f -> +%d" % [d100, avg, extra],
	}
