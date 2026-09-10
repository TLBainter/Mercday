class_name CoverNearbyFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	return CoverSearch.cover_scan_score(merc, ctx)
