class_name ContractIssuer extends RefCounted

#The one placeholder issuer rule until contracts carry a real issuer: every board entry id names
#a kind and, within that kind, an index. Only the orgs kind maps onto a StockMarket company.

const KINDS: Array[StringName] = [&"orgs", &"people", &"places"]
const PEOPLE: int = 8
const PLACES: int = 8


static func kind_of(entry_id: int) -> StringName:
	return KINDS[posmod(entry_id, 3)]


static func index_of(entry_id: int, count: int) -> int:
	if count < 1:
		return 0
	return posmod(floori(entry_id / 3.0), count)


static func company_of(entry_id: int, company_count: int) -> int:
	if kind_of(entry_id) != &"orgs" or company_count < 1:
		return -1
	return index_of(entry_id, company_count)
