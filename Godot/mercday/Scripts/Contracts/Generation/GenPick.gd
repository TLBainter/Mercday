class_name GenPick
#The daily round's row draw and the promo criteria a hit can still meet (proposal 5.6, 5.7, 5.15).


#The hit's criteria, each unmeetable one swapped for a meetable unused one; empty when it had some and none hold.
static func criteria(hit: Dictionary, campaign: Dictionary, ctx: Dictionary, excluded: Array[int]) -> Array[String]:
	var asked: Array = hit.get("criteria", [])
	var spare: Array[String] = []
	spare.assign(GenPromo.active(campaign).filter(func(c: String) -> bool:
		return not asked.has(c) and meetable(c, campaign, ctx, excluded)))
	var out: Array[String] = []
	for c: String in asked:
		if meetable(c, campaign, ctx, excluded):
			out.append(c)
		elif not spare.is_empty():
			out.append(spare.pop_front())
	return out


static func meetable(c: String, campaign: Dictionary, ctx: Dictionary, excluded: Array[int]) -> bool:
	match c:
		"types":
			var rows_by_type: Dictionary = ctx["rows_by_type"]
			return (campaign["types"] as Array).any(func(t: String) -> bool:
				return not (rows_by_type.get(t, []) as Array).is_empty())
		"places":
			return not GenLocation.candidates(null, only_places(ctx["places"], campaign["places"])).is_empty()
		"issuers":
			return (campaign["issuers"] as Array).any(func(id: int) -> bool:
				return not excluded.has(id) and IssuerOpinion.has_seat(id))
	return true


#Type by weight, then row: a match roll forces rows the Available mercs can boost; criteria narrow both.
static func row(ctx: Dictionary, shares: Dictionary, rng: RandomNumberGenerator, applied: Array[String],
		campaign: Dictionary, places: Array[Dictionary], level: int = 0) -> ContractData:
	var rows_by_type: Dictionary = _fitting(ctx["rows_by_type"], level, applied)
	var types: Array[String] = []
	for type_name: String in rows_by_type:
		if not (rows_by_type[type_name] as Array).is_empty() \
				and (not applied.has("types") or (campaign["types"] as Array).has(type_name)):
			types.append(type_name)
	var forced: Dictionary = {}
	if rng.randf() < GenMatch.chance(float(ctx["rates"]["blended"])):
		for type_name: String in types:
			var hits: Array[ContractData] = GenMatch.matching_rows(rows_by_type[type_name], ctx["available"])
			if not hits.is_empty():
				forced[type_name] = hits
	if not forced.is_empty():
		types.assign(forced.keys())
	var open_types: Array[String] = []
	open_types.assign(shares["types"])
	var picked: String = GenType.pick_type(GenType.type_weights(types, open_types), rng)
	if picked == "":
		return null
	var rows: Array[ContractData] = []
	rows.assign(rows_by_type[picked])
	var must: Array[ContractData] = []
	must.assign(forced.get(picked, []))
	if applied.has("places"):
		rows = _placed(rows, places)
		must = _placed(must, places)
	return GenType.pick_row(rows, float(shares["long"]), must, rng)


#The places whose country is one a campaign names.
static func only_places(places: Array[Dictionary], names: Array) -> Array[Dictionary]:
	var countries: Array[String] = []
	for place: String in names:
		countries.append(GenLocation.country_of(place))
	var out: Array[Dictionary] = []
	out.assign(places.filter(func(p: Dictionary) -> bool: return countries.has(str(p["name"]))))
	return out


#Rows with a permitted, reachable place among places; all of rows when none has one.
static func _placed(rows: Array[ContractData], places: Array[Dictionary]) -> Array[ContractData]:
	var out: Array[ContractData] = []
	out.assign(rows.filter(func(r: ContractData) -> bool: return not GenLocation.candidates(r, places).is_empty()))
	return out if not out.is_empty() else rows


#rows_by_type narrowed to the rows that fit level and the issuers criterion; the argument itself when neither applies.
static func _fitting(rows_by_type: Dictionary, level: int, applied: Array[String]) -> Dictionary:
	if level <= 0 and not applied.has("issuers"):
		return rows_by_type
	var out: Dictionary = {}
	for type_name: String in rows_by_type:
		var kept: Array[ContractData] = []
		for r: ContractData in rows_by_type[type_name]:
			if _fits(r, level, applied):
				kept.append(r)
		out[type_name] = kept
	return out


#The campaign issuers criterion names org seats only, so it keeps blank and org rows.
static func _fits(r: ContractData, level: int, applied: Array[String]) -> bool:
	return (level <= 0 or ContractGenerator.level_ok(r, level)) \
		and (not applied.has("issuers") or r.issuer_type == "" or r.issuer_type == "org")
