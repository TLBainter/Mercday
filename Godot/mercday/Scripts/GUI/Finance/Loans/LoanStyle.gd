class_name LoanStyle

#The looks only the Loans page screens share: padded boxes, the shaded page button and the stat value
#cell. The palette, the fonts and the common builders come from GuiColors and GuiStyle.

const ODDS_CAPTION: String = "Approval Odds"


static func padded(bg: Color, left: int, top: int, right: int, bottom: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = GuiStyle.flat(bg)
	style.content_margin_left = float(left)
	style.content_margin_top = float(top)
	style.content_margin_right = float(right)
	style.content_margin_bottom = float(bottom)
	return style


static func panel(bg: Color, pad_h: int, pad_v: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", padded(bg, pad_h, pad_v, pad_h, pad_v))
	return box


#Every page button is the core BevelButton scene, shaded from the colour the caller asks for.
static func button(value: String, bg: Color, fg: Color, height: float) -> Button:
	var node: BevelButton = BevelButton.make(value, &"blue", Vector2(0.0, height))
	dress_button(node, bg, fg)
	return node


#The page button look on a BevelButton: the shade the caller asks for and the bold 13 px label.
static func dress_button(node: BevelButton, bg: Color, fg: Color) -> void:
	shade(node, bg, fg)
	node.add_theme_font_override("font", GuiStyle.SILK_BOLD)
	node.add_theme_font_size_override("font_size", 13)


#Dresses a Loans dialog: the title in the ring colour, the 11 px kicker, the close tip and the
#page look on the cancel and confirm pair.
static func dress(dialog: ModalDialog, tip: String) -> void:
	dialog.title_label.add_theme_color_override(&"font_color", dialog.ring_color)
	dialog.kicker_label.add_theme_font_size_override(&"font_size", 11)
	dialog.close_button.tooltip_text = tip
	dress_button(dialog.cancel_button, GuiColors.BLUE, GuiColors.CREAM)
	dress_button(dialog.confirm_button, GuiColors.GREEN, GuiColors.INK)


#The fill, bevel edges and label colour of a page button; its hover and press shades follow the fill.
static func shade(node: BevelButton, bg: Color, fg: Color) -> void:
	node.set_colors(bg, bg.lightened(0.25), bg.darkened(0.35), fg)


#A stat value: an amount with the notes glyph when notes is true, else a bold line of text.
static func value_cell(notes: bool, size: int, color: Color) -> Control:
	if notes:
		return GuiStyle.notes(0, size, color)
	return GuiStyle.label("", GuiStyle.SILK_BOLD, size, color)


#Writes a value_cell node: the amount into a notes label, the text into a plain one.
static func set_value(node: Control, text: String, amount: int) -> void:
	if node is NotesLabel:
		(node as NotesLabel).amount = amount
	else:
		(node as Label).text = text


#One envoy module: the portrait, the name, the tradition when large, and the fit stars.
static func envoy_card(row: Dictionary, side: float, art: Array[MercPortrait], large: bool) -> PanelContainer:
	var card: PanelContainer = panel(GuiColors.ROW_HOVER, 6 if large else 8, 6)
	var line: HBoxContainer = GuiStyle.hbox(8)
	line.add_child(LoanGlyphs.envoy_face(row, side, art))
	var col: VBoxContainer = GuiStyle.vbox(4)
	col.add_child(GuiStyle.label(String(row.get("name", "")), GuiStyle.SILK_BOLD, 10 if large else 9,
		GuiColors.CREAM))
	if large:
		var tradition: String = String(row.get("tradition", ""))
		col.add_child(GuiStyle.label(tradition, GuiStyle.BODY, 12, GuiTypes.tradition_color(tradition)))
	var stars: Stars = Stars.fit_stars(1)
	stars.value = float(row.get("fit", 0.5))
	col.add_child(stars)
	line.add_child(col)
	card.add_child(line)
	return card


#The approval odds block: the caption, the percent at Head/Value and the meter at Shell/Meter.
static func odds_block() -> VBoxContainer:
	var col: VBoxContainer = GuiStyle.vbox(6)
	var top: HBoxContainer = GuiStyle.hbox(8)
	top.name = "Head"
	top.add_child(GuiStyle.label(ODDS_CAPTION, GuiStyle.SILK, 11, GuiColors.ORANGE))
	top.add_child(GuiStyle.spacer())
	var value: Label = GuiStyle.label("", GuiStyle.SILK_BOLD, 20, GuiColors.CREAM)
	value.name = "Value"
	top.add_child(value)
	col.add_child(top)
	var shell: PanelContainer = panel(GuiColors.INK, 2, 2)
	shell.name = "Shell"
	var meter := SuccessMeter.new()
	meter.name = "Meter"
	meter.stretch = true
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_child(meter)
	col.add_child(shell)
	return col


#Writes an odds block: the percent in its odds colour and the meter fill.
static func set_odds(label: Label, meter: SuccessMeter, value: int) -> void:
	label.text = "%d%%" % value
	label.add_theme_color_override("font_color", LoanLogic.odds_color(value))
	meter.odds = value
