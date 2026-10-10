class_name GenDeadline
#Deadline of a posting: expected travel plus completion, slack by quality and issuer face, and the urgency tier.


#One-way travel by the mode plus the work once there.
static func expected_minutes(mode_key: String, km: int, completion_minutes: int) -> int:
	return Reachability.base_minutes(mode_key, km) + completion_minutes


static func slack_minutes(expected: int, q: float, face: int) -> int:
	var slack: int = roundi(float(expected) * lerpf(GenConstants.SLACK_LO, GenConstants.SLACK_HI, q)) \
			+ GenConstants.SLACK_OPINION_H * CampaignClock.MINUTES_PER_HOUR * maxi(0, face)
	return maxi(slack, GenConstants.DEADLINE_MIN_H * CampaignClock.MINUTES_PER_HOUR)


static func deadline(now: int, expected: int, slack: int) -> int:
	return now + expected + slack


#2 under URGENT_H hours of slack, 1 under SOON_H, else 0.
static func urgency(slack: int) -> int:
	if slack < GenConstants.URGENT_H * CampaignClock.MINUTES_PER_HOUR:
		return 2
	if slack < GenConstants.SOON_H * CampaignClock.MINUTES_PER_HOUR:
		return 1
	return 0
