class_name ContractResults extends Control

#The contract results screen: resource bars, fates, the verdict that slams in and docks, the
#experience and level-ups, the money tally, the merc bonus payout and the money fly. One clock
#drives all of it: every node is set from ResultsTimeline at the clock value.

signal finished(entry_id: int)

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Results/ResultRow.tscn")
const BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const PANEL_BEVEL: float = 4.0
const BEVEL_HI: Color = GuiColors.EDGE_HI
const BEVEL_LO: Color = GuiColors.EDGE_LO
const SHADOW_OFFSET: Vector2 = Vector2(10.0, 10.0)
const SHADOW_GROW: float = 4.0
const DIM_ALPHA: float = 0.6
const NOTE_SIZE: Vector2 = Vector2(14.0, 18.0)
const NOTE_RING: float = 2.0
const CONTINUE_BEVEL: float = 3.0
const GREEN_FILL: Color = GuiColors.GREEN
const GREEN_HI: Color = GuiColors.GREEN_HI
const GREEN_LO: Color = GuiColors.GREEN_LO
const GREEN_FG: Color = GuiColors.INK
const DISABLED_ALPHA: float = 0.4
const WAIT_TIP: String = "Tallying results..."
const TITLE_SPACING: int = 1
const CLOSE_INSET: float = 10.0

@onready var backdrop: ColorRect = $Backdrop
@onready var panel_shadow: ColorRect = $PanelShadow
@onready var panel: PanelContainer = $Center/Panel
@onready var dock_slot: Control = $Center/Panel/Body/Header/Left/DockSlot
@onready var title_label: Label = $Center/Panel/Body/Header/Left/Title
@onready var name_label: Label = $Center/Panel/Body/Header/Left/Name
@onready var stars: Stars = $Center/Panel/Body/Header/Left/Stars
@onready var notes_box: NotesEarned = $Center/Panel/Body/Header/Notes
@onready var rows_box: VBoxContainer = $Center/Panel/Body/Rows
@onready var continue_button: BevelButton = $Center/Panel/Body/Foot/Continue
@onready var overlay: Control = $Center/Panel/Overlay
@onready var dim: ColorRect = $Center/Panel/Overlay/Dim
@onready var note_layer: Control = $Center/Panel/Overlay/NoteLayer
@onready var verdict: VerdictBox = $Center/Panel/Overlay/Verdict
@onready var close_button: Button = $Center/Panel/Overlay/Close

var _result: ContractResultData = null
var _rows: Array[ResultRow] = []
var _clock: float = 0.0
var _running: bool = false
var _flew: bool = false
var _sounded: bool = false
#The money cue plays on the first open of a result only; a reopened result flies in silence.
var _cue_fly: bool = false
var _done: bool = false
var _blue: bool = false
var _styled: bool = false


func _ready() -> void:
	add_child(TimeHold.new())
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.color = GuiColors.BACKDROP
	var spaced: FontVariation = BOLD.duplicate() as FontVariation
	spaced.spacing_glyph = TITLE_SPACING
	title_label.add_theme_font_override("font", spaced)
	title_label.text = ResultsTimeline.TITLE_TEXT
	panel.draw.connect(_on_panel_draw)
	note_layer.draw.connect(_on_notes_draw)
	continue_button.pressed.connect(press_continue)
	CloseX.style(close_button, CloseX.SCALE_WINDOW)
	close_button.pressed.connect(press_continue)
	continue_button.edge = CONTINUE_BEVEL
	_style_continue(false)
	_apply()


#Opens one result: the clock opens where the timeline says, at zero or at the verdict, and runs.
func show_result(data: ContractResultData) -> void:
	_result = data
	_clock = ResultsTimeline.start_time(data)
	_flew = false
	_sounded = false
	_cue_fly = data != null and GameState.is_unclaimed(data.entry_id)
	_done = false
	_running = data != null
	if data != null:
		name_label.text = data.name
		name_label.tooltip_text = data.name
		stars.value = data.difficulty
		verdict.set_result(data)
		notes_box.set_result(data)
	_build_rows()
	_apply()


#Places the clock by hand; the panel stops running so a test can read one moment.
func set_time(t: float) -> void:
	_running = false
	_clock = clampf(t, 0.0, ResultsTimeline.total_time(_result))
	_apply()


func time() -> float:
	return _clock


func skip_to_end() -> void:
	set_time(ResultsTimeline.total_time(_result))


func is_finished() -> bool:
	return _result != null and ResultsTimeline.continue_enabled(_result, _clock)


func press_continue() -> void:
	if _result == null or _done or not is_finished():
		return
	_done = true
	GameState.mark_seen(_result.entry_id)
	finished.emit(_result.entry_id)


func result() -> ContractResultData:
	return _result


func rows() -> Array[ResultRow]:
	return _rows


func row_of(index: int) -> ResultRow:
	if index < 0 or index >= _rows.size():
		return null
	return _rows[index]


func notes() -> NotesEarned:
	return notes_box


func verdict_box() -> VerdictBox:
	return verdict


func title_color() -> Color:
	return title_label.get_theme_color("font_color")


func continue_style() -> Color:
	return continue_button.fill


func continue_ready() -> bool:
	return not continue_button.disabled


func panel_size() -> Vector2:
	return panel.size


func _process(delta: float) -> void:
	if not _running:
		return
	var span: float = ResultsTimeline.total_time(_result)
	_clock = minf(_clock + delta, span)
	if _clock >= span:
		_running = false
	_apply()


func _build_rows() -> void:
	for row: ResultRow in _rows:
		row.queue_free()
	_rows.clear()
	if _result == null:
		return
	for i: int in _result.members.size():
		var member: ResultMemberData = _result.members[i]
		var row: ResultRow = ROW_SCENE.instantiate() as ResultRow
		rows_box.add_child(row)
		row.set_member(member, i, _result.failed, _view_of(member))
		_rows.append(row)


func _view_of(member: ResultMemberData) -> MercView:
	return member.merc_view() if member != null else null


func _apply() -> void:
	if not is_node_ready():
		return
	var t: float = _clock
	var accent: Color = ResultsTimeline.accent_color(_result, t)
	title_label.add_theme_color_override("font_color", accent)
	notes_box.apply_time(t)
	for row: ResultRow in _rows:
		row.apply_time(t)
	var dim_op: float = ResultsTimeline.dim_opacity(t)
	dim.visible = dim_op > 0.0
	dim.color = Color(dim.color.r, dim.color.g, dim.color.b, DIM_ALPHA * dim_op)
	verdict.apply_time(t, overlay.size / 2.0, _dock_rect())
	if not _sounded and _result != null and t >= ResultsTimeline.VERDICT_IN:
		_sounded = true
		GameSfx.play_result(_result)
	var ready_now: bool = is_finished()
	_style_continue(_result != null and _result.failed and ResultsTimeline.told(t))
	continue_button.disabled = not ready_now
	continue_button.modulate.a = 1.0 if ready_now else DISABLED_ALPHA
	continue_button.tooltip_text = "" if ready_now else WAIT_TIP
	close_button.visible = ready_now
	_place_close()
	_place_shadow()
	if not _flew and _result != null and t >= ResultsTimeline.end_time(_result):
		_flew = true
		GameState.fly_money(_result.fly_amount(), _cue_fly)
	note_layer.queue_redraw()
	panel.queue_redraw()


func _style_continue(blue: bool) -> void:
	if blue == _blue and _styled:
		return
	_blue = blue
	_styled = true
	if blue:
		continue_button.kind = &"blue"
	else:
		continue_button.set_colors(GREEN_FILL, GREEN_HI, GREEN_LO, GREEN_FG)


#The slot above the title, in the coordinates of the overlay the verdict lives in.
func _dock_rect() -> Rect2:
	var origin: Vector2 = dock_slot.get_global_rect().position - overlay.global_position
	return Rect2(origin, dock_slot.size)


func _place_close() -> void:
	close_button.size = CloseX.size(CloseX.SCALE_WINDOW)
	close_button.position = Vector2(overlay.size.x - CLOSE_INSET - 30.0 - 3.0,
		CLOSE_INSET - 3.0)


func _place_shadow() -> void:
	var rect: Rect2 = panel.get_global_rect()
	panel_shadow.global_position = rect.position + SHADOW_OFFSET - Vector2(SHADOW_GROW, SHADOW_GROW)
	panel_shadow.size = rect.size + Vector2(SHADOW_GROW, SHADOW_GROW) * 2.0


func _on_panel_draw() -> void:
	var rect := Rect2(Vector2.ZERO, panel.size)
	var accent: Color = ResultsTimeline.accent_color(_result, _clock)
	BevelButton.paint_ring(panel, rect, accent, PANEL_BEVEL)
	BevelButton.paint_edges(panel, rect, BEVEL_HI, BEVEL_LO, PANEL_BEVEL)


#The bonus notes in flight, from the Notes Earned box to the pay cell of every living member.
func _on_notes_draw() -> void:
	if _result == null:
		return
	var flying: Array[Dictionary] = ResultsTimeline.pay_notes(_result, _clock)
	if flying.is_empty():
		return
	var from: Vector2 = _local(notes_box.net_anchor())
	for note: Dictionary in flying:
		var row: ResultRow = row_of(int(note["index"]))
		if row == null:
			continue
		var to: Vector2 = _local(row.pay_anchor())
		var point: Vector2 = NoteIcon.arc_point(from, to, float(note["progress"]),
			ResultsTimeline.NOTE_ARC_PX)
		NoteIcon.draw_tile(note_layer, Rect2(point - NOTE_SIZE / 2.0, NOTE_SIZE), true, NOTE_RING)


func _local(point: Vector2) -> Vector2:
	return point - note_layer.global_position
