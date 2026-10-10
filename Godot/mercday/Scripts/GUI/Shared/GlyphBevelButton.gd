class_name GlyphBevelButton extends BevelButton

#A bevelled icon-only button: no built-in text/icon padding, since the glyph rides in a child
#Glyph IconRect painted over the bevelled face. Same convention as InvestBevelButton, without
#the caption label that one adds for its Max button.

func _apply_boxes() -> void:
	var box := StyleBoxEmpty.new()
	for state: StringName in STATES:
		add_theme_stylebox_override(state, box)
