class_name ContractTooltip extends TooltipPanel

#Hover panel over a contract list row: what the posting is, how hard it is, what it pays,
#how far the crew travels and how long the work runs. The list owns one shared instance.

const STORY_LINE: String = "Story contract"

@onready var difficulty_label: Label = $Rows/Difficulty
@onready var urgency_label: Label = $Rows/Urgency
@onready var issuer_label: Label = $Rows/Issuer

var view: ContractView = null


func set_contract(new_view: ContractView) -> void:
	view = new_view
	if not is_node_ready():
		return
	if view == null:
		set_text("", "")
		difficulty_label.text = ""
		urgency_label.text = ""
		issuer_label.text = ""
		return
	set_text(view.name, body_text(view))
	difficulty_label.text = "Difficulty %s" % view.difficulty_name()
	difficulty_label.add_theme_color_override("font_color", view.difficulty_color())
	urgency_label.text = "Urgency %s" % String(GuiTypes.URGENCY_NAMES.get(view.urgency, ""))
	urgency_label.add_theme_color_override("font_color", GuiTypes.urgency_color(view.urgency))
	issuer_label.text = "Issuer %s" % (view.issuer if view.issuer != "" else "Unknown")


#The plain lines: type and level, reward, distance, how long the contract runs and a story mark.
#The difficulty has its own coloured label, so it never doubles up here.
static func body_text(row: ContractView) -> String:
	if row == null:
		return ""
	var lines: Array[String] = []
	lines.append("%s, LVL %d" % [row.type, row.contract_level])
	lines.append("Reward %d N" % row.reward)
	lines.append("Distance %d km" % row.distance_km)
	lines.append("Completion %d h" % row.completion_hours)
	if row.story:
		lines.append(STORY_LINE)
	return "\n".join(lines)
