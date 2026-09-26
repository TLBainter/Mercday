class_name AttributeBox extends PanelContainer

#One attribute square of the Overview tab: the three letter abbreviation beside the current value.
#The maximum only shows in the tooltip (Q16).

const ABBREVIATIONS: Dictionary = {
	"cognition": "CGN", "dexterity": "DEX", "vigor": "VGR", "wile": "WIL",
}
const FULL_NAMES: Dictionary = {
	"cognition": "Cognition", "dexterity": "Dexterity", "vigor": "Vigor", "wile": "Wile",
}

@export var attribute_key: String = "cognition":
	set(value):
		attribute_key = value
		_refresh()
@export var current: int = 0:
	set(value):
		current = value
		_refresh()
@export var maximum: int = 0:
	set(value):
		maximum = value
		_refresh()

@onready var value_label: Label = $Row/ValueBox/Value
@onready var abbr_label: Label = $Row/Abbr


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_refresh()


func set_attribute(key: String, entry: Dictionary) -> void:
	attribute_key = key
	current = int(entry.get("current", 0))
	maximum = int(entry.get("max", 0))


func full_name() -> String:
	return String(FULL_NAMES.get(attribute_key, attribute_key))


func _refresh() -> void:
	if not is_node_ready():
		return
	abbr_label.text = String(ABBREVIATIONS.get(attribute_key, ""))
	value_label.text = str(current)
	tooltip_text = "%s: max %d" % [full_name(), maximum]
