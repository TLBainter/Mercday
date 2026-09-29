class_name CrewCandidates

#Builds the merc candidate rows for an Odd Job crew picker from the live roster.
#Fit comes from a host Callable so each screen can score mercs its own way.

static func from_roster(fit: Callable, exclude: Array[int] = []) -> Array[Dictionary]:
	var busy: Array[int] = GameState.busy_uids()
	var rows: Array[Dictionary] = []
	for view: MercView in GameState.roster:
		if exclude.has(view.uid):
			continue
		if busy.has(view.uid):
			continue
		if view.status != GuiTypes.MercStatus.AVAILABLE and view.status != GuiTypes.MercStatus.RESTING:
			continue
		if GameState.has_method("is_away") and GameState.is_away(view.uid):
			continue
		var raw: float = float(fit.call(view.uid))
		var half_step: float = clampf(roundf(raw * 2.0) / 2.0, 0.5, 5.0)
		rows.append({"id": view.uid, "name": view.name, "fit": half_step})
	rows.sort_custom(_by_fit_then_name)
	return rows


static func _by_fit_then_name(a: Dictionary, b: Dictionary) -> bool:
	if a["fit"] != b["fit"]:
		return a["fit"] > b["fit"]
	return String(a["name"]) < String(b["name"])
