class_name GenQuality
#Posting quality 0..1 from nearness, short work, issuer satisfaction and matched elements.


static func score(km: int, hours: float, satisfaction: int, matched: int) -> float:
	var q: float = GenConstants.QUALITY_W_NEAR * (1.0 - float(km) / GenConstants.QUALITY_KM_SPAN) \
			+ GenConstants.QUALITY_W_SHORT * (1.0 - hours / GenConstants.QUALITY_HOURS_SPAN) \
			+ GenConstants.QUALITY_W_GENEROUS * float(satisfaction) / 100.0 \
			+ GenConstants.QUALITY_W_MATCH * minf(1.0, float(matched) / GenConstants.QUALITY_MATCH_FULL)
	return clampf(q, 0.0, 1.0)


#A promo-matched posting closes part of the gap to 1 by its match percent.
static func promo_lift(q: float, match_pct: float) -> float:
	return clampf(q + (1.0 - q) * match_pct * GenConstants.PROMO_QUALITY_LIFT, 0.0, 1.0)
