class_name BatchReport
extends RefCounted

#Table and ratio helpers the event batches share; the pct and ratio formatters stay in TestFixtures.


#The dashes row under a table heading: one rule per width, laid out by fmt.
static func rule(widths: Array, fmt: String) -> String:
	var cells: Array = []
	for width: int in widths:
		cells.append("-".repeat(width))
	return fmt % cells


#part as a percentage of whole; -1 when whole is not positive.
static func share(part: int, whole: int) -> float:
	if whole <= 0:
		return -1.0
	return float(part) / float(whole) * 100.0


#part divided by whole; -1 when whole is not positive.
static func per(part: int, whole: int) -> float:
	if whole <= 0:
		return -1.0
	return float(part) / float(whole)


#Mean level of the mercs; -1 when there are none.
static func level_mean(mercs: Array[MercenaryData]) -> float:
	if mercs.is_empty():
		return -1.0
	var total: float = 0.0
	for merc: MercenaryData in mercs:
		total += float(merc.stats.get("level", 0.0))
	return total / float(mercs.size())
