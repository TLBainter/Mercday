class_name MenuGrid extends GridContainer

#3x3 grid of GridMenuButton tiles; GameHUD wires labels, icons, scenes and hover text at runtime.


func button(index: int) -> GridMenuButton:
	if index < 0 or index >= get_child_count():
		return null
	return get_child(index) as GridMenuButton
