class_name GenPromo
#Campaign rolls: how many postings a campaign brings in a round and which of its criteria each meets (proposal 5.4).

const CRITERIA: Array[String] = ["types", "places", "difficulty", "issuers"]


static func chance_of(effect: float) -> float:
	return minf(GenConstants.PROMO_CHANCE_CAP, effect * GenConstants.PROMO_CHANCE_SCALE / 100.0)


#First hit at the chance, the k-th extra at chance x PROMO_CHAIN_DECAY^k, stopping at the first miss.
static func roll(effect: float, active: Array[String], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var p: float = chance_of(effect)
	var chance: float = p
	while rng.randf() < chance:
		hits.append(_hit(active, p, rng))
		chance *= GenConstants.PROMO_CHAIN_DECAY
	return hits


static func active(campaign: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not (campaign.get("types", []) as Array).is_empty():
		out.append("types")
	if not (campaign.get("places", []) as Array).is_empty():
		out.append("places")
	if float(campaign.get("diff_lo", 0.0)) != 0.0 or float(campaign.get("diff_hi", 0.0)) != 0.0:
		out.append("difficulty")
	if not (campaign.get("issuers", []) as Array).is_empty():
		out.append("issuers")
	return out


static func chance(campaign: Dictionary) -> float:
	return chance_of(float(campaign.get("effect", 0.0)))


static func hits(campaign: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = roll(float(campaign.get("effect", 0.0)), active(campaign), rng)
	for hit: Dictionary in out:
		hit["campaign_id"] = int(campaign.get("id", 0))
	return out


#One random active criterion always applies; each other applies on its own roll of the chance.
static func _hit(active_keys: Array[String], p: float, rng: RandomNumberGenerator) -> Dictionary:
	var applied: Array[String] = []
	if not active_keys.is_empty():
		var pick: int = rng.randi_range(0, active_keys.size() - 1)
		for i: int in active_keys.size():
			if i == pick or rng.randf() < p:
				applied.append(active_keys[i])
	var pct: float = 0.0 if active_keys.is_empty() else float(applied.size()) / float(active_keys.size())
	return {"criteria": applied, "match_pct": pct}
