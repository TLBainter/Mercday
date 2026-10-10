class_name GenPosting
#One pool entry of the daily round: level, difficulty, place, quality, deadline and value (proposal 5.8-5.14).

#Why the last generate_one returned null before the build: "level gate", "no <group> seat" or "".
static var null_reason: String = ""


#Null when no row can be drawn or the build fails; applied names the campaign criteria it must meet.
static func generate_one(ctx: Dictionary, board: ContractBoard, now: int, rng: RandomNumberGenerator, issuer: int,
		applied: Array[String] = [], campaign: Dictionary = {}) -> BoardEntry:
	null_reason = ""
	var places: Array[Dictionary] = ctx["places"]
	if applied.has("places"):
		places = GenPick.only_places(places, campaign["places"])
	var centre: float = float(ctx["level_centre"])
	var shares: Dictionary = shares_of(board, float(ctx["diff_centre"]))
	var row: ContractData = GenPick.row(ctx, shares, rng, applied, campaign, places)
	if row == null:
		return null
	var level: int = int(ctx.get("level", 0))
	if level <= 0:
		level = GenLevel.roll(centre, rng)
	if not ContractGenerator.level_ok(row, level):
		row = GenPick.row(ctx, shares, rng, applied, campaign, places, level)
		if row == null:
			null_reason = "level gate"
			ContractGenerator.note_no_row(level)
			return null
	var seat: int = GenIssuer.for_row(row, issuer, board, now, rng)
	if seat < 0:
		null_reason = "no %s seat" % ContractBoard.group_of_word(row.issuer_type)
		return null
	var base: float = GenDifficulty.for_row(row, float(ctx["diff_centre"]), float(shares["diff_mean"]), rng)
	var scaled: float = base * ContractGenerator.difficulty_multiplier(float(level) / maxf(1.0, centre))
	var difficulty: float = clampf(scaled, GenConstants.DIFF_MIN, GenConstants.DIFF_MAX)
	if applied.has("difficulty"):
		difficulty = clampf(difficulty, float(campaign["diff_lo"]), float(campaign["diff_hi"]))
	var spot: Dictionary = GenLocation.pick(row, places, shares["near"], shares["far"], rng)
	var contract: ContractData = ContractGenerator.generate_row(row, level, ContractGenerator.snap_half(difficulty),
		str(spot["place"]))
	if contract == null:
		return null
	var entry := BoardEntry.new()
	entry.contract = contract
	entry.issuer_id = seat
	entry.issuer = ContractBoard.issuer_text(contract, seat)
	entry.issuer_type = ContractBoard.issuer_word(contract, seat)
	entry.distance_km = int(spot["km"])
	entry.completion_hours = ContractBoard.completion_hours(contract)
	entry.merc_min = ContractBoard.merc_min_for(contract)
	entry.campaign_id = int(campaign.get("id", 0))
	var active: int = GenPromo.active(campaign).size()
	entry.match_pct = float(applied.size()) / float(active) if active > 0 else 0.0
	var hours: float = GenType.row_hours(contract)
	var face: int = IssuerOpinion.face(seat)
	entry.quality = GenQuality.score(entry.distance_km, hours, IssuerOpinion.satisfaction(seat),
		GenMatch.matched_elements(row, ctx["available"]))
	if not campaign.is_empty():
		entry.quality = GenQuality.promo_lift(entry.quality, entry.match_pct)
	var expected: int = expected_minutes(entry, centre)
	var slack: int = GenDeadline.slack_minutes(expected, entry.quality, face)
	entry.deadline_minute = GenDeadline.deadline(now, expected, slack)
	var expense: int = GenExpense.expense(GenExpense.mode_for(centre, entry.distance_km), entry.distance_km,
		contract.max_mercs)
	var raw: float = GenValue.raw(face, level, contract.difficulty, expense, hours, float(GenDeadline.urgency(slack)))
	entry.value = GenValue.value(level, raw, entry.quality, GenExpense.travel_add(expense, entry.quality))
	contract.reward_notes = entry.value
	return entry


#One-way travel in the tier mode for the roster level plus the work.
static func expected_minutes(entry: BoardEntry, level_centre: float) -> int:
	var mode: String = GenExpense.mode_for(level_centre, entry.distance_km)
	return GenDeadline.expected_minutes(mode, entry.distance_km, Reachability.completion_minutes(entry))


#A fresh deadline from now, as at generation (story entries at provision).
static func fresh_deadline(entry: BoardEntry, now: int, level_centre: float) -> int:
	var expected: int = expected_minutes(entry, level_centre)
	var face: int = IssuerOpinion.face(entry.issuer_id)
	return GenDeadline.deadline(now, expected, GenDeadline.slack_minutes(expected, entry.quality, face))


#Open postings plus the pool: long, near and far shares, mean difficulty and the open types.
static func shares_of(board: ContractBoard, diff_centre: float) -> Dictionary:
	var held: Array[BoardEntry] = board.available()
	held.append_array(board.pool.entries)
	var out: Dictionary = {"long": 0.0, "near": 0.0, "far": 0.0, "diff_mean": diff_centre, "types": []}
	if held.is_empty():
		return out
	var diff_sum: float = 0.0
	for entry: BoardEntry in held:
		out["long"] += 1.0 if entry.contract != null and GenType.is_long(entry.contract) else 0.0
		out["near"] += 1.0 if entry.distance_km <= GenConstants.NEAR_KM else 0.0
		out["far"] += 1.0 if entry.distance_km >= GenConstants.FAR_KM else 0.0
		diff_sum += entry.contract.difficulty if entry.contract != null else diff_centre
		(out["types"] as Array).append(entry.contract_type())
	for key: String in ["long", "near", "far"]:
		out[key] = float(out[key]) / float(held.size())
	out["diff_mean"] = diff_sum / float(held.size())
	return out
