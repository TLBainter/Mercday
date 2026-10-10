class_name TravelForecaster
extends ExpenseForecaster
#Travel fares net of refunds, grouped by travel mode, scaled by how far the contracts on offer lie against
#the trips of the window. With no history it estimates one round trip to an average offer at the cheapest mode.

#Leave unset to read the offers on the board; a test hands its own list to set_offers().
var _offers: Array[ContractView] = []
var _offers_set: bool = false


func set_offers(list: Array[ContractView]) -> void:
	_offers = list
	_offers_set = true


func reasons() -> Array[String]:
	return [GameState.REASON_TRAVEL]


func credit_reasons() -> Array[String]:
	return [GameState.REASON_TRAVEL_REFUND]


func group_of(row: TransactionData) -> String:
	return row.mode


#Average offered distance over average trip distance of the window's fares; 1.0 when either is unknown.
func driver_scale(rows: Array[TransactionData], _today: int) -> float:
	var trip_km: float = 0.0
	var trips: int = 0
	for row: TransactionData in rows:
		if row.reason == GameState.REASON_TRAVEL and row.distance_km > 0:
			trip_km += row.distance_km
			trips += 1
	var offered: float = average_offer_km()
	if trips == 0 or offered <= 0.0:
		return 1.0
	return offered / (trip_km / trips)


func fallback(_today: int) -> Dictionary:
	var offers: Array[ContractView] = offered()
	if offers.is_empty():
		return {}
	var km: int = roundi(average_offer_km())
	var crew: int = 0
	for contract: ContractView in offers:
		crew += contract.merc_min
	crew = maxi(1, roundi(float(crew) / offers.size()))
	var best_key: String = ""
	var best: int = -1
	for mode: Dictionary in GuiTypes.TRAVEL_MODES:
		var fare: int = DispatchLogic.travel_cost(mode, crew, crew, km) * 2
		if fare > 0 and (best < 0 or fare < best):
			best = fare
			best_key = String(mode["key"])
	if best <= 0:
		return {}
	return {"total": best, "groups": {best_key: best}}


func average_offer_km() -> float:
	var offers: Array[ContractView] = offered()
	var km: int = 0
	var counted: int = 0
	for contract: ContractView in offers:
		if contract.distance_km > 0:
			km += contract.distance_km
			counted += 1
	return 0.0 if counted == 0 else float(km) / counted


#The contracts open for taking.
func offered() -> Array[ContractView]:
	var source: Array[ContractView] = _offers if _offers_set else GameState.contracts
	var out: Array[ContractView] = []
	for contract: ContractView in source:
		if contract != null and contract.status == GuiTypes.ContractStatus.AVAILABLE:
			out.append(contract)
	return out
