class_name GenMatch
#The match step: a chance to restrict the row pick to rows whose boosts the available mercs can use.


static func chance(blended: float) -> float:
	return clampf(GenConstants.MATCH_BASE + GenConstants.MATCH_SLOPE * (0.5 - blended),
		GenConstants.MATCH_MIN, GenConstants.MATCH_MAX)


#The row's knowledge, tool and tradition boost entries held by at least one of mercs; each entry counts once.
static func matched_elements(row: ContractData, mercs: Array[MercenaryData]) -> int:
	if row == null:
		return 0
	var count: int = 0
	for name: String in row.knowledge_boosts:
		if mercs.any(func(m: MercenaryData) -> bool: return ContractModifiers.knowledge_matches(m, name)):
			count += 1
	for name: String in row.tool_boosts:
		if mercs.any(func(m: MercenaryData) -> bool: return ContractModifiers.tool_matches(m, name)):
			count += 1
	for name: String in row.tradition_boosts:
		if mercs.any(func(m: MercenaryData) -> bool: return ContractModifiers.tradition_matches(m, name)):
			count += 1
	return count


static func matching_rows(rows: Array[ContractData], mercs: Array[MercenaryData]) -> Array[ContractData]:
	var out: Array[ContractData] = []
	for row: ContractData in rows:
		if matched_elements(row, mercs) > 0:
			out.append(row)
	return out
