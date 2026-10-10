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
		if GameState.is_away(view.uid):
			continue
		var raw: float = float(fit.call(view.uid))
		var half_step: float = GuiTypes.snap_half(raw)
		rows.append({"id": view.uid, "name": view.name, "fit": half_step})
	rows.sort_custom(by_fit_then_name)
	return rows


#Best fit first; equal fits fall back to the name. Every merc picker list sorts with it.
static func by_fit_then_name(a: Dictionary, b: Dictionary) -> bool:
	var fit_a: float = float(a.get("fit", 0.0))
	var fit_b: float = float(b.get("fit", 0.0))
	if fit_a != fit_b:
		return fit_a > fit_b
	return String(a.get("name", "")) < String(b.get("name", ""))
