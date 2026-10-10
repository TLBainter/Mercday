class_name GenPriority
#Provision order of the pool (proposal 5.15).


#Types allowed x places allowed x difficulty band width; an inactive criterion counts as the full set.
static func niche(campaign: Dictionary) -> float:
	var type_count: int = (campaign.get("types", []) as Array).size()
	if type_count == 0:
		type_count = ContractLibrary.contract_type_names().size()
	var place_count: int = (campaign.get("places", []) as Array).size()
	if place_count == 0:
		place_count = GenConstants.DISTANCE_KM.size()
	var lo: float = float(campaign.get("diff_lo", 0.0))
	var hi: float = float(campaign.get("diff_hi", 0.0))
	var width: float = hi - lo
	if lo == 0.0 and hi == 0.0:
		width = GenConstants.DIFF_MAX - GenConstants.DIFF_MIN
	return float(type_count * place_count) * width


#Story first; campaign entries by match_pct, ties to the smaller niche; urgency; quality; older pooled_minute; stable.
static func sort(entries: Array[BoardEntry], now: int, slack_fn: Callable, niche_fn: Callable) -> Array[BoardEntry]:
	var keyed: Array[Dictionary] = []
	for i: int in entries.size():
		var entry: BoardEntry = entries[i]
		var promo: bool = entry.campaign_id != 0
		keyed.append({
			"entry": entry, "index": i, "story": entry.story, "promo": promo,
			"match": entry.match_pct if promo else 0.0,
			"niche": float(niche_fn.call(entry)) if promo else 0.0,
			"urgency": GenDeadline.urgency(int(slack_fn.call(entry))),
			"quality": entry.quality, "pooled": entry.pooled_minute,
		})
	keyed.sort_custom(_before)
	var out: Array[BoardEntry] = []
	for row: Dictionary in keyed:
		out.append(row["entry"] as BoardEntry)
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["story"] != b["story"]:
		return a["story"]
	if a["promo"] != b["promo"]:
		return a["promo"]
	if a["match"] != b["match"]:
		return a["match"] > b["match"]
	if a["niche"] != b["niche"]:
		return a["niche"] < b["niche"]
	if a["urgency"] != b["urgency"]:
		return a["urgency"] > b["urgency"]
	if a["quality"] != b["quality"]:
		return a["quality"] > b["quality"]
	if a["pooled"] != b["pooled"]:
		return a["pooled"] < b["pooled"]
	return a["index"] < b["index"]
