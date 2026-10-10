class_name GenType
#Type and row pick: repeat types weigh less, and the row's length balances the roster's long share.


#The authored Time when set, else the board's event formula.
static func row_hours(row: ContractData) -> float:
	if row == null:
		return 0.0
	if row.time_minutes > 0:
		return row.time_minutes / float(CampaignClock.MINUTES_PER_HOUR)
	return float(ContractBoard.completion_hours(row))


static func is_long(row: ContractData) -> bool:
	return row_hours(row) >= GenConstants.LONG_HOURS


#Type name -> weight; each open roster or pool contract of a type multiplies its weight by TYPE_REPEAT_FACTOR.
static func type_weights(types: Array[String], open_types: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for type_name: String in types:
		out[type_name] = pow(GenConstants.TYPE_REPEAT_FACTOR, open_types.count(type_name))
	return out


#"" when no type has weight.
static func pick_type(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for type_name: String in weights:
		total += maxf(0.0, float(weights[type_name]))
	if total <= 0.0:
		return ""
	var roll: float = rng.randf() * total
	var last: String = ""
	for type_name: String in weights:
		var w: float = maxf(0.0, float(weights[type_name]))
		if w <= 0.0:
			continue
		last = type_name
		roll -= w
		if roll < 0.0:
			return type_name
	return last


#Forced rows replace rows; a long share above BALANCE_SHARE prefers short rows, below it long rows.
static func pick_row(rows: Array[ContractData], long_share: float, forced: Array[ContractData],
		rng: RandomNumberGenerator) -> ContractData:
	var pool: Array[ContractData] = forced if not forced.is_empty() else rows
	if pool.is_empty():
		return null
	var preferred: Array[ContractData] = pool
	if long_share > GenConstants.BALANCE_SHARE:
		preferred = pool.filter(func(r: ContractData) -> bool: return not is_long(r))
	elif long_share < GenConstants.BALANCE_SHARE:
		preferred = pool.filter(func(r: ContractData) -> bool: return is_long(r))
	if preferred.is_empty():
		preferred = pool
	return preferred[rng.randi_range(0, preferred.size() - 1)]
