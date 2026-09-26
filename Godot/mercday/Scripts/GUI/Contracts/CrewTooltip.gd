class_name CrewTooltip extends TooltipPanel

#Hover panel over a crew portrait: who the merc is, the role they took and how well they fit.

@onready var role_label: Label = $Rows/Role
@onready var stars: DifficultyStars = $Rows/Match


func set_member(view: MercView, role: String, match_stars: float) -> void:
	if view == null:
		set_text("Empty", "")
		role_label.text = ""
		stars.rating = 0.0
		return
	set_text(view.name, "Level %d\n%s" % [view.level, view.tradition])
	role_label.text = role
	role_label.add_theme_color_override("font_color", view.tradition_color())
	stars.rating = match_stars
