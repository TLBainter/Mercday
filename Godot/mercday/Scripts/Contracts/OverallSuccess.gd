class_name OverallSuccess

#Overall Success Chance: the merc's base success chance shifted by contract boosts, event relevance and penalties.

const STAT_KEY := "base_success_chance"


static func base(merc: MercenaryData) -> float:
	if merc == null:
		return 0.0
	return float(merc.stats.get(STAT_KEY, 0.0))


static func relevance_percent(merc: MercenaryData, event: EventData) -> float:
	if merc == null or event == null:
		return 0.0
	for name: String in event.knowledges:
		if ContractModifiers.knowledge_matches(merc, name):
			return ContractLibrary.config().mishap_relevance_bonus_percent
	for name: String in event.tools:
		if ContractModifiers.tool_matches(merc, name):
			return ContractLibrary.config().mishap_relevance_bonus_percent
	return 0.0


static func for_merc(contract: ContractData, team: Array[MercenaryData], merc: MercenaryData, event: EventData) -> Dictionary:
	var base_value: float = base(merc)
	var boost: float = ContractModifiers.boost_percent(contract, merc)
	var relevance: float = relevance_percent(merc, event)
	var penalty: float = ContractPenalty.percent_for(contract, merc, team.size())
	var net: float = boost + relevance - penalty
	var value: float = maxf(0.0, base_value * (1.0 + net / 100.0))
	return {
		"base": base_value,
		"boost_percent": boost,
		"relevance_percent": relevance,
		"penalty_percent": penalty,
		"net_percent": net,
		"value": value,
		"delta": value - base_value,
	}


static func apply_event_delta(contract: ContractData, team: Array[MercenaryData], event: EventData) -> Dictionary:
	var record: Dictionary = {}
	for merc: MercenaryData in team:
		if merc == null:
			continue
		var info: Dictionary = for_merc(contract, team, merc, event)
		var delta: float = float(info["delta"])
		record[merc] = delta
		merc.stats[STAT_KEY] = float(merc.stats.get(STAT_KEY, 0.0)) + delta
	return record


#Subtracts the stored delta so stat changes made during the event survive the revert.
static func revert_event_delta(record: Dictionary) -> void:
	for merc: MercenaryData in record:
		if merc == null:
			continue
		merc.stats[STAT_KEY] = float(merc.stats.get(STAT_KEY, 0.0)) - float(record[merc])


static func describe(merc: MercenaryData, info: Dictionary) -> String:
	return "OVERALL SUCCESS: %s base %.1f boosts +%.1f%% relevance +%.1f%% penalties -%.1f%% net %.1f%% -> %.1f (delta %.1f)" % [
		merc.merc_name if merc != null else "?",
		float(info.get("base", 0.0)),
		float(info.get("boost_percent", 0.0)),
		float(info.get("relevance_percent", 0.0)),
		float(info.get("penalty_percent", 0.0)),
		float(info.get("net_percent", 0.0)),
		float(info.get("value", 0.0)),
		float(info.get("delta", 0.0)),
	]
