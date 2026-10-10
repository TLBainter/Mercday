class_name ConfirmDialog extends ModalDialog

#Modal yes/no, multi choice or recap popup: a titled message over a dimmed backdrop.
#ask(), ask_buttons(), ask_recap() and ask_rich() are the entry points; each rebuilds the rows and
#shows it. The severity drives the box ring and title colour. The backdrop click is inert by design.

signal chosen(index: int)
signal shown
signal dialog_hidden

enum Severity {ORANGE, RED, GREEN, INFO}
enum Kind {GO, BAD, WARN, NEUTRAL}

const BUTTON_SIZE := Vector2(96.0, 32.0)
const BOX_WIDTH := 460.0
const KIND_FILL: Array[Color] = [GuiColors.GREEN, GuiColors.RED, GuiColors.BLUE, GuiColors.BLUE]
#The shading palette of BevelButton each dialog kind is built from.
const KIND_SHADE: Array[StringName] = [&"go", &"danger", &"blue", &"neutral"]
const BLOCK_GAP := 6
const ROW_GAP := 10
const SEVERITY_COLORS: Array[Color] = [GuiColors.ORANGE, GuiColors.RED, GuiColors.GREEN,
	GuiColors.SKY]
const OUTCOME_BORDER := 3

@export var message: String = ""
@export var buttons: Array[String] = []
@export var kinds: Array[int] = []

@onready var message_label: Label = $Box/Pad/Rows/Message

var _severity: int = Severity.ORANGE
var _confirm_kind: int = Kind.GO
var _button_kinds: Array[int] = []
var _team_rows: Array[Dictionary] = []
var _stat_rows: Array[Dictionary] = []
var _team_box: VBoxContainer = null
var _stat_box: VBoxContainer = null
var _recap_box: VBoxContainer = null
var _stat_values: Array[Label] = []
var _stat_glyphs: Array[NoteIcon] = []
var _rich: ConfirmRich = null
var _rich_box: VBoxContainer = null
var _kicker_label: Label = null
var _crew_box: VBoxContainer = null
var _money_box: VBoxContainer = null
var _money_labels: Array[Label] = []
var _outcome_box: PanelContainer = null
var _outcome_label: Label = null


func _ready() -> void:
	super()
	closed.connect(dialog_hidden.emit)
	_rebuild()


#The safe answer sits first, so the cancel label leads and the confirm label carries the kind.
func ask(new_title: String, new_message: String, new_confirm_label: String = "Yes",
		new_cancel_label: String = "No", new_severity: int = Severity.ORANGE,
		new_confirm_kind: int = Kind.GO) -> void:
	_confirm_kind = new_confirm_kind
	_set_pair(new_confirm_label, new_cancel_label)
	_open(new_title, new_message, [], [], new_severity, [], [], null)


func ask_buttons(new_title: String, new_message: String, labels: Array[String],
		new_severity: int = Severity.ORANGE, new_kinds: Array[int] = []) -> void:
	_open(new_title, new_message, labels, new_kinds, new_severity, [], [], null)


#The dispatch recap: the team above the numbers, then the buttons. The last one continues.
func ask_recap(new_title: String, new_message: String, team_rows: Array[Dictionary],
		stat_rows: Array[Dictionary], labels: Array[String],
		new_severity: int = Severity.GREEN, new_kinds: Array[int] = []) -> void:
	_open(new_title, new_message, labels, new_kinds, new_severity, team_rows, stat_rows, null)


#The rich recap for a spend or legal outcome: a kicker line, crew and money rows and an outcome
#box, above the standard cancel and cta pair. cta carries the full button text the caller composed.
func ask_rich(new_title: String, new_message: String, cta: String, rich: ConfirmRich,
		kind: int = Kind.GO) -> void:
	_confirm_kind = kind
	_set_pair(cta, "Cancel")
	_open(new_title, new_message, [], [], Severity.ORANGE, [], [], rich)


func button_count() -> int:
	return button_row.get_child_count()


func press(i: int) -> void:
	(button_row.get_child(i) as Button).pressed.emit()


func severity() -> int:
	return _severity


func button_kind(i: int) -> int:
	if i < 0 or i >= _button_kinds.size():
		return -1
	return _button_kinds[i]


func button_labels() -> Array[String]:
	var out: Array[String] = []
	for child: Node in button_row.get_children():
		out.append((child as Button).text)
	return out


func severity_color() -> Color:
	return SEVERITY_COLORS[clampi(_severity, 0, SEVERITY_COLORS.size() - 1)]


func team_row_count() -> int:
	if _team_box == null:
		return 0
	return _team_box.get_child_count()


func stat_row_count() -> int:
	if _stat_box == null:
		return 0
	return _stat_box.get_child_count()


func stat_value_text(i: int) -> String:
	if i < 0 or i >= _stat_values.size():
		return ""
	return _stat_values[i].text


func stat_has_glyph(i: int) -> bool:
	if i < 0 or i >= _stat_glyphs.size():
		return false
	return _stat_glyphs[i] != null


func rich_kicker_text() -> String:
	return _kicker_label.text if _kicker_label != null else ""


func money_row_count() -> int:
	if _money_box == null:
		return 0
	return _money_box.get_child_count()


func outcome_text() -> String:
	return _outcome_label.text if _outcome_label != null else ""


func has_outcome_box() -> bool:
	return _outcome_box != null


func _on_present() -> void:
	shown.emit()


#The base pair keeps the texts and shades of the yes/no buttons _rebuild makes.
func _set_pair(yes: String, no: String) -> void:
	cancel_kind = _shade_of(Kind.NEUTRAL)
	confirm_kind = _shade_of(_confirm_kind)
	confirm_text = yes
	cancel_text = no


func _open(new_title: String, new_message: String, labels: Array[String], new_kinds: Array[int],
		new_severity: int, team_rows: Array[Dictionary], stat_rows: Array[Dictionary],
		rich: ConfirmRich) -> void:
	title = new_title
	message = new_message
	buttons = labels
	kinds = new_kinds
	_severity = new_severity
	_team_rows = team_rows
	_stat_rows = stat_rows
	_rich = rich
	_rebuild()
	present()


func _rebuild() -> void:
	if not is_node_ready():
		return
	title_label.add_theme_color_override(&"font_color", severity_color())
	message_label.text = message
	ring_color = severity_color()
	_clear_recap()
	_build_recap()
	_clear_rich()
	_build_rich()
	GuiNodes.clear(button_row)
	_button_kinds.clear()
	cancel_button = null
	confirm_button = null
	if buttons.is_empty():
		cancel_button = _add_button(cancel_text, Kind.NEUTRAL, press_cancel)
		confirm_button = _add_button(confirm_text, _confirm_kind, press_confirm)
	else:
		for i: int in buttons.size():
			_add_button(buttons[i], _kind_at(i), _on_choice.bind(i))


#One kind per label; with none given every button reads neutral but the last, which continues.
func _kind_at(i: int) -> int:
	if i >= 0 and i < kinds.size():
		return clampi(kinds[i], 0, KIND_FILL.size() - 1)
	return Kind.GO if i == buttons.size() - 1 else Kind.NEUTRAL


func _clear_recap() -> void:
	_stat_values.clear()
	_stat_glyphs.clear()
	if _recap_box != null:
		rows.remove_child(_recap_box)
		_recap_box.queue_free()
		_recap_box = null
	_team_box = null
	_stat_box = null


func _build_recap() -> void:
	if _team_rows.is_empty() and _stat_rows.is_empty():
		return
	_team_box = GuiStyle.vbox(BLOCK_GAP)
	for row: Dictionary in _team_rows:
		_team_box.add_child(_team_row(row))
	_stat_box = GuiStyle.vbox(BLOCK_GAP)
	for row: Dictionary in _stat_rows:
		_stat_box.add_child(_stat_row(row))
	_recap_box = GuiStyle.vbox(BLOCK_GAP)
	_recap_box.add_child(_team_box)
	_recap_box.add_child(_stat_box)
	_add_block(_recap_box)


#A block built for one ask sits above the buttons.
func _add_block(block: Control) -> void:
	rows.add_child(block)
	rows.move_child(button_row, rows.get_child_count() - 1)


func _clear_rich() -> void:
	_money_labels.clear()
	if _rich_box != null:
		rows.remove_child(_rich_box)
		_rich_box.queue_free()
		_rich_box = null
	_kicker_label = null
	_crew_box = null
	_money_box = null
	_outcome_box = null
	_outcome_label = null


func _build_rich() -> void:
	if _rich == null:
		return
	_rich_box = GuiStyle.vbox(BLOCK_GAP)
	if not _rich.kicker.is_empty():
		_kicker_label = GuiStyle.label(_rich.kicker, GuiStyle.SILK, 9, GuiColors.SKY)
		_rich_box.add_child(_kicker_label)
	if not _rich.crew.is_empty():
		_crew_box = GuiStyle.vbox(BLOCK_GAP)
		for row: Dictionary in _rich.crew:
			_crew_box.add_child(_team_row(row))
		_rich_box.add_child(_crew_box)
	if not _rich.money.is_empty():
		_money_box = GuiStyle.vbox(BLOCK_GAP)
		for row: Dictionary in _rich.money:
			var money: Dictionary = {"label": row.get("label", ""),
				"value": str(int(row.get("amount", 0))), "glyph": true}
			if row.get("tint") is Color:
				money["color"] = row["tint"]
			_money_box.add_child(_stat_row(money, false))
		_rich_box.add_child(_money_box)
	if not _rich.outcome.is_empty():
		_outcome_box = _build_outcome(_rich.outcome, _rich.outcome_ok)
		_rich_box.add_child(_outcome_box)
	_add_block(_rich_box)


func _build_outcome(text: String, ok: bool) -> PanelContainer:
	var tint: Color = KIND_FILL[Kind.GO] if ok else KIND_FILL[Kind.BAD]
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = GuiStyle.flat(GuiColors.INK, OUTCOME_BORDER, tint)
	_set_margins(style, 10.0, 8.0)
	panel.add_theme_stylebox_override(&"panel", style)
	var line: HBoxContainer = GuiStyle.hbox(ROW_GAP)
	var icon := TextureRect.new()
	icon.texture = GuiGlyphs.check(tint)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(GuiGlyphs.CHECK_SIZE, GuiGlyphs.CHECK_SIZE)
	line.add_child(icon)
	_outcome_label = GuiStyle.label(text, GuiStyle.BODY, 12, GuiColors.CREAM)
	_outcome_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_outcome_label)
	panel.add_child(line)
	return panel


func _team_row(row: Dictionary) -> PanelContainer:
	var panel: PanelContainer = _row_panel(GuiColors.ROW_FILL)
	var line: HBoxContainer = GuiStyle.hbox(ROW_GAP)
	var merc_name: Label = GuiStyle.label(str(row.get("name", "")), GuiStyle.SILK_BOLD, 11,
		GuiColors.CREAM)
	merc_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(merc_name)
	var role: Label = GuiStyle.label(str(row.get("role", "")), GuiStyle.BODY, 10, GuiColors.ORANGE)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(role)
	panel.add_child(line)
	return panel


#A caption, a value and an optional notes glyph; a recap row records its value and glyph for the
#probes, a money row keeps its amount label in _money_labels.
func _stat_row(row: Dictionary, recap: bool = true) -> PanelContainer:
	var panel: PanelContainer = _row_panel(GuiColors.INK)
	var line: HBoxContainer = GuiStyle.hbox(ROW_GAP)
	var caption: Label = GuiStyle.label(str(row.get("label", "")), GuiStyle.SILK, 9, GuiColors.SKY)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(caption)
	var tint: Color = GuiColors.CREAM
	if row.get("color") is Color:
		tint = row["color"]
	var value: Label = GuiStyle.label(str(row.get("value", "")), GuiStyle.BODY, 14, tint)
	line.add_child(value)
	var glyph: NoteIcon = null
	if bool(row.get("glyph", false)):
		glyph = NoteIcon.new()
		glyph.pixel_scale = 1
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(glyph)
	if recap:
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stat_values.append(value)
		_stat_glyphs.append(glyph)
	else:
		_money_labels.append(value)
	panel.add_child(line)
	return panel


func _row_panel(fill: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = GuiStyle.flat(fill)
	_set_margins(style, 10.0, 6.0)
	panel.add_theme_stylebox_override(&"panel", style)
	return panel


func _set_margins(style: StyleBoxFlat, across: float, down: float) -> void:
	style.content_margin_left = across
	style.content_margin_right = across
	style.content_margin_top = down
	style.content_margin_bottom = down


#Every dialog button is the core BevelButton scene, so the shading is the one the whole game uses.
func _add_button(label: String, kind: int, target: Callable) -> BevelButton:
	var b: BevelButton = BevelButton.make(label, _shade_of(kind), BUTTON_SIZE)
	b.pressed.connect(target)
	button_row.add_child(b)
	_button_kinds.append(kind)
	return b


func _shade_of(kind: int) -> StringName:
	if kind < 0 or kind >= KIND_SHADE.size():
		return &"neutral"
	return KIND_SHADE[kind]


func _on_choice(i: int) -> void:
	close()
	chosen.emit(i)
