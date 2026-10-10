class_name GenIssuer
#Picks the issuer seat of a posting, weighted by seat satisfaction and its group's record.


static func weight(id: int, now: int) -> float:
	var sat: float = maxf(GenConstants.ISSUER_MIN_WEIGHT, IssuerOpinion.satisfaction(id) / 100.0)
	return sat * (GenConstants.ISSUER_GROUP_BASE + IssuerOpinion.group_blended(IssuerOpinion.group_of(id), now))


#-1 when no seat is left; a non-empty only_ids restricts the candidates.
static func pick(excluded: Array[int], now: int, rng: RandomNumberGenerator, only_ids: Array[int] = []) -> int:
	var pool: Array[int] = only_ids if not only_ids.is_empty() else IssuerOpinion.ids()
	var ids: Array[int] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for id: int in pool:
		if excluded.has(id) or not IssuerOpinion.has_seat(id) or ids.has(id):
			continue
		var w: float = weight(id, now)
		ids.append(id)
		weights.append(w)
		total += w
	if ids.is_empty():
		return -1
	var roll: float = rng.randf() * total
	for i: int in range(ids.size()):
		roll -= weights[i]
		if roll < 0.0:
			return ids[i]
	return ids[ids.size() - 1]


#The seat a row's posting takes: issuer unless the row names another group, then a free seat of that group (-1: none).
static func for_row(row: ContractData, issuer: int, board: ContractBoard, now: int,
		rng: RandomNumberGenerator) -> int:
	var group: String = ContractBoard.group_of_word(row.issuer_type) if row != null else ""
	if group == "" or IssuerOpinion.group_of(issuer) == group:
		return issuer
	var ids: Array[int] = IssuerOpinion.ids_in_group(group)
	if ids.is_empty():
		return -1
	var excluded: Array[int] = GenProvision.busy_issuers(board)
	excluded.append_array(board.pool.issuer_ids())
	return pick(excluded, now, rng, ids)
