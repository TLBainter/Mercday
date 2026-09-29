class_name MetricDef extends Resource

#One line of the metrics list. source is "Merc", "Contract" or "Guild"; agg is "SUM", "LAST",
#"AVG" or "EVENT_AVG". EVENT_AVG reads a second stored key, "<key>_n", for the per day count.
#description is the tooltip line of the toggle; fmt is the axis format, "money", "int", "op" or
#"float". lock_key names the entitlement a row needs before the guild may plot it, empty when the
#row is always open, and upgrade_id names the upgrade that entitlement comes from.

@export var key: String = ""
@export var label: String = ""
@export var source: String = ""
@export var agg: String = "SUM"
@export var default_on: bool = false
@export var description: String = ""
@export var fmt: String = "float"
@export var lock_key: String = ""
@export var upgrade_id: String = ""


static func make(key_text: String, label_text: String, source_text: String, agg_text: String,
		on_by_default: bool, description_text: String = "", fmt_text: String = "float",
		lock_text: String = "", upgrade_text: String = "") -> MetricDef:
	var def := MetricDef.new()
	def.key = key_text
	def.label = label_text
	def.source = source_text
	def.agg = agg_text
	def.default_on = on_by_default
	def.description = description_text
	def.fmt = fmt_text
	def.lock_key = lock_text
	def.upgrade_id = upgrade_text
	return def
