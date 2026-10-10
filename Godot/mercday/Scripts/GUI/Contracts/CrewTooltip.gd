class_name CrewTooltip extends TooltipPanel

#Hover panel over a crew portrait: who the merc is, the role they took and how well they fit. A
#settled contract's member shows how they came home and what they were paid in place of the fit.

const EMPTY_TITLE: String = "Empty"
const LEVEL_TEXT: String = "Level %d"
const LEVEL_UP_TEXT: String = "Level %d to %d"
const PAY_TEXT: String = "Pay %s"
const MVP_TEXT: String = "MVP"

@onready var role_label: Label = $Rows/Role
@onready var stars: Stars = $Rows/Match


func set_member(view: MercView, role: String, match_stars: float) -> void:
	stars.visible = true
	if view == null:
		set_text(EMPTY_TITLE, "")
		role_label.text = ""
		stars.value = 0.0
		return
	set_text(view.name, "%s\n%s" % [LEVEL_TEXT % view.level, view.tradition])
	role_label.text = role
	role_label.add_theme_color_override("font_color", view.tradition_color())
	stars.value = match_stars


#A member of a settled contract, read off the result on file: the level they reached, their
#tradition, how they came home and their pay. No fit stars; the contract is over.
func set_result_member(member: ResultMemberData) -> void:
	stars.visible = false
	stars.value = 0.0
	if member == null:
		set_text(EMPTY_TITLE, "")
		role_label.text = ""
		return
	var level: String = LEVEL_TEXT % member.level_before
	if member.levelled():
		level = LEVEL_UP_TEXT % [member.level_before, member.level_after]
	var lines: PackedStringArray = []
	lines.append(level)
	if not member.tradition.is_empty():
		lines.append(member.tradition)
	lines.append(member.fate_name())
	lines.append(PAY_TEXT % PayoutTooltip.notes_text(member.pay))
	if member.mvp:
		lines.append(MVP_TEXT)
	set_text(member.name, "\n".join(lines))
	role_label.text = member.role
	role_label.add_theme_color_override("font_color", GuiTypes.tradition_color(member.tradition))
