class_name CustomizeBlock extends Control

#One module of the Customize tree: the upgrade icon in its tier colour, the tier chunks in an inset
#tube, and the name and monthly fee under the square. An unavailable module dims to 0.45 and
#refuses the click; a fully owned one glows on the shared pulse and its chunks shine left to right.
#The Base module carries the My Mercday logo and tracks the progress of the whole tree.

signal pressed_block(id: String)

const BASE_ID: String = "base"
const BG: Color = GuiColors.BLUE
const BG_MAX: Color = GuiColors.BLUE_LO
const HI: Color = GuiColors.BLUE_HI
const HI_MAX: Color = GuiColors.BLUE
const LO: Color = GuiColors.EDGE_LO
const BASE_BG: Color = GuiColors.INK
const BASE_HI: Color = GuiColors.BOX_BG
const BASE_LO: Color = Color.BLACK
const RING: Color = GuiColors.ORANGE
const RING_MAX: Color = GuiColors.RAMP_YELLOW
const RING_OFF: Color = GuiColors.BLUE_LO
const RING_BASE_OFF: Color = GuiColors.BLUE_HI
const NAME_COLOR: Color = GuiColors.CREAM
const FEE_COLOR: Color = GuiColors.CREAM
const FEE_OFF: Color = GuiColors.MUTED
const TUBE_BG: Color = GuiColors.TUBE_BG
const TUBE_HI: Color = GuiColors.BLUE_HI
const TUBE_LO: Color = GuiColors.BLUE_LO
const CHUNK_BG: Color = GuiColors.ROW_HOVER
const CHUNK_HI: Color = GuiColors.BLUE_LO
const CHUNK_LO: Color = GuiColors.ROW_FILL
const LL_COLOR: Color = GuiColors.RED
const DIM_ALPHA: float = 0.45
const BEVEL: float = 3.0
const RING_WIDTH: float = 2.0
const ICON_SCALE: int = 3
const ICON_TOP: float = 12.0
const MASK_SCALE: int = 1
const PIP_H: float = 8.0
const PIP_W: float = 7.0
const PIP_W_TIGHT: float = 6.0
const PIP_GAP: float = 2.0
const PIP_PAD_X: float = 3.0
const PIP_PAD_Y: float = 2.0
const PIP_LIFT: float = 8.0
const TUBE_TIGHT_MAX: int = 8
#Caption: a name wraps inside LABEL_WIDTH onto at most NAME_MAX_LINES lines NAME_PITCH apart, and FEE_SPACE keeps the fee
#tile clear of the last line. The block is centred by its ink: capitals rise CAP_RISE_EM of the em above the baseline
#and the fee tile hangs FEE_TILE_DROP below its baseline (NoteIcon.draw_run).
const LABEL_WIDTH: float = 144.0
const NAME_MAX_LINES: int = 2
const NAME_PITCH: float = 10.0
const FEE_SPACE: float = 6.0
const CAP_RISE_EM: float = 0.625
const FEE_TILE_DROP: float = 1.0
const SUFFIX: String = "/month"
const NAME_FONT: FontVariation = GuiStyle.SILK_BOLD
const FEE_FONT: FontVariation = GuiStyle.SILK
const NAME_SIZE: int = 10
const FEE_SIZE: int = 12

@export var upgrade_id: String = ""

var _tier: int = 0
var _max: int = 1
var _fee: int = 0
var _tiers: Dictionary = {}
var _usable: bool = true
var _enterprise: bool = true
var _gated: bool = false
var _glow: float = 0.0
var _sweep: PackedFloat32Array = PackedFloat32Array()
var _hovered: bool = false
var _down: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_cursor()
	_apply_size()
	PulseClock.pulse.connect(_on_pulse)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func setup(id: String) -> void:
	upgrade_id = id
	_max = maxi(1, UpgradeDefs.tier_count(id)) if id != BASE_ID else 1
	_apply_size()
	queue_redraw()


func is_base() -> bool:
	return upgrade_id == BASE_ID


#Reads one tree state: the owned tier, the fee it bills, and whether the module can be clicked.
func refresh(tiers: Dictionary, enterprise: bool) -> void:
	_enterprise = enterprise
	_tiers = tiers
	if is_base():
		_tier = 0
		_max = 1
		_fee = SubscriptionManager.service_fee(SubscriptionManager.Plan.ENTERPRISE)
		_gated = false
		_usable = false
		_apply_cursor()
		queue_redraw()
		return
	_max = maxi(1, UpgradeDefs.tier_count(upgrade_id))
	_tier = clampi(int(tiers.get(upgrade_id, 0)), 0, _max)
	_fee = UpgradeDefs.monthly_of(upgrade_id, _tier)
	_gated = not UpgradeDefs.requirement_met(upgrade_id, tiers)
	_usable = enterprise and not _gated
	_apply_cursor()
	queue_redraw()


func tier() -> int:
	return _tier


func max_tier() -> int:
	return _max


func is_maxed() -> bool:
	return not is_base() and _tier >= _max


func is_usable() -> bool:
	return _usable


func is_gated() -> bool:
	return _gated


func name_text() -> String:
	return TreeLayout.BASE_NAME if is_base() else UpgradeDefs.name_of(upgrade_id)


#The lines the name prints on, wrapped to LABEL_WIDTH.
func name_lines() -> PackedStringArray:
	return wrap_name(name_text())


func desc_text() -> String:
	if is_base():
		return TreeLayout.BASE_DESC
	return String(UpgradeDefs.of(upgrade_id).get("desc", ""))


func kind_text() -> String:
	if is_base():
		return TreeLayout.BASE_KIND
	return TreeLayout.cat_label(UpgradeDefs.category_of(upgrade_id))


func monthly_fee() -> int:
	return _fee


func fee_text() -> String:
	return str(_fee)


func fee_color() -> Color:
	if is_base():
		return FEE_COLOR
	return FEE_COLOR if _tier > 0 else FEE_OFF


#The face lifts under the pointer and sinks while pressed, like a button face; a module the plan
#cannot use stays flat.
func bg_color() -> Color:
	var base: Color = BASE_BG if is_base() else (BG_MAX if is_maxed() else BG)
	if is_down():
		return base.darkened(BevelButton.PRESS_DROP)
	if _hovered and _usable:
		return base.lightened(BevelButton.HOVER_LIFT)
	return base


#Pressed means a left press is held on a module the plan can use.
func is_down() -> bool:
	return _down and _usable


func hi_color() -> Color:
	return _edge(not is_down())


func lo_color() -> Color:
	return _edge(is_down())


func ring_color() -> Color:
	if is_base():
		return RING if _enterprise else RING_BASE_OFF
	if not _enterprise:
		return RING_OFF
	return RING_MAX if is_maxed() else RING


func icon_color() -> Color:
	return TreeLayout.block_color(upgrade_id, _tiers)


func alpha_value() -> float:
	if is_base():
		return 1.0
	return 1.0 if _usable else DIM_ALPHA


#The fill of one tier chunk: its own rank colour when owned, else the empty tube colour.
func pip_color(i: int) -> Color:
	if i < _tier:
		return GuiColors.tier_color(i, _max)
	return CHUNK_BG


func glow_factor() -> float:
	if not is_maxed():
		return 1.0
	return PulseClock.glow_of(_glow)


#Chunk i shines a step behind chunk i minus one once every tier is owned.
func pip_glow(i: int) -> float:
	if not is_maxed():
		return 1.0
	return PulseClock.sweep_of(_sweep, i)


#The click a headless run makes; a drag on the canvas suppresses the real one. A dimmed module plays the Bad Click cue.
func press() -> void:
	if not _usable:
		if not is_base() and not _tree_panning():
			UiSfx.play_disabled_press(self)
		return
	pressed_block.emit(upgrade_id)


#The SkillTree two parents up reports a pan; read by method name, since a SkillTree type here would close a
#preload loop through TreeCanvas.tscn and CustomizeBlock.tscn.
func _tree_panning() -> bool:
	var tree: Node = null if get_parent() == null else get_parent().get_parent()
	return tree != null and tree.has_method(&"is_dragging") and bool(tree.call(&"is_dragging"))


#True while the tree has a popover open or a drag under way; read by method name for the same reason.
func _tree_hover_blocked() -> bool:
	var tree: Node = null if get_parent() == null else get_parent().get_parent()
	return tree != null and tree.has_method(&"hover_blocked") and bool(tree.call(&"hover_blocked"))


func _apply_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _usable else Control.CURSOR_ARROW


func _apply_size() -> void:
	var side: float = TreeLayout.block_size(upgrade_id)
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)


func _on_hover(on: bool) -> void:
	_hovered = on
	if not on:
		_down = false
	elif not _usable and not is_base() and not _tree_panning() and not _tree_hover_blocked():
		UiSfx.play_disabled_hover(self)
	queue_redraw()


#The light bevel colour of this module when lit is true, else its dark one.
func _edge(lit: bool) -> Color:
	if is_base():
		return BASE_HI if lit else BASE_LO
	if lit:
		return HI_MAX if is_maxed() else HI
	return LO


func _on_pulse(g: float, sweep: PackedFloat32Array) -> void:
	if not is_maxed():
		return
	_glow = g
	_sweep = sweep
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_down = click.pressed
	queue_redraw()
	if not click.pressed:
		press()


func _draw() -> void:
	var side: float = TreeLayout.block_size(upgrade_id)
	var box: Rect2 = Rect2(Vector2.ZERO, Vector2(side, side))
	var a: float = alpha_value()
	var ring: Color = GuiColors.fade(ring_color(), a)
	_paint_bands(box, ring, ring, RING_WIDTH)
	_paint_bands(box.grow(-RING_WIDTH), GuiColors.fade(hi_color(), a),
		GuiColors.fade(lo_color(), a), BEVEL)
	draw_rect(box.grow(-(RING_WIDTH + BEVEL)), GuiColors.fade(bg_color(), a))
	_draw_icon(side, a)
	if not is_base():
		_draw_pips(side, a)
		_draw_mask(side, a)
	_draw_labels(side, a)


#Four bands of px along the edges of rect that never overlap, so a dimmed module shows no doubled
#corner: the top and bottom run the full width and the left and right fit between them.
func _paint_bands(rect: Rect2, edge_hi: Color, edge_lo: Color, px: float) -> void:
	BevelButton.paint_edges(self, rect, edge_hi, edge_lo, px,
		BevelButton.BEVEL_TOP | BevelButton.BEVEL_BOTTOM)
	BevelButton.paint_edges(self, rect.grow_individual(0.0, -px, 0.0, -px), edge_hi, edge_lo, px,
		BevelButton.BEVEL_LEFT | BevelButton.BEVEL_RIGHT)


func _draw_icon(side: float, a: float) -> void:
	var span: float = 16.0 * float(ICON_SCALE)
	var tint: Color = GuiColors.brighter(icon_color(), glow_factor())
	var at: Vector2 = Vector2((side - span) / 2.0,
		(side - span) / 2.0 if is_base() else ICON_TOP)
	if is_base():
		Icons.draw_texture(self, Icons.baked("mercday", ICON_SCALE, Icons.MODE_GRAY), at, 1,
			Color(tint.r, tint.g, tint.b, a))
		return
	var icon_id: String = TreeIcons.id_of(upgrade_id)
	if icon_id == "":
		return
	Icons.draw(self, icon_id, at, ICON_SCALE, Color(tint.r, tint.g, tint.b, a), false)


func _draw_pips(side: float, a: float) -> void:
	var w: float = PIP_W_TIGHT if _max > TUBE_TIGHT_MAX else PIP_W
	var inner: float = float(_max) * w + float(maxi(0, _max - 1)) * PIP_GAP
	var tube: Rect2 = Rect2((side - inner - PIP_PAD_X * 2.0) / 2.0,
		side - PIP_LIFT - PIP_H - PIP_PAD_Y * 2.0, inner + PIP_PAD_X * 2.0,
		PIP_H + PIP_PAD_Y * 2.0)
	draw_rect(tube, GuiColors.fade(TUBE_BG, a))
	draw_rect(Rect2(tube.position, Vector2(tube.size.x, 1.0)), GuiColors.fade(TUBE_LO, a))
	draw_rect(Rect2(tube.position + Vector2(0.0, tube.size.y - 1.0), Vector2(tube.size.x, 1.0)),
		GuiColors.fade(TUBE_HI, a))
	for i: int in range(_max):
		var at: Vector2 = tube.position + Vector2(PIP_PAD_X + float(i) * (w + PIP_GAP), PIP_PAD_Y)
		var c: Color = GuiColors.brighter(pip_color(i), pip_glow(i))
		draw_rect(Rect2(at, Vector2(w, PIP_H)), GuiColors.fade(c, a))
		var hi: Color = c.lerp(Color.WHITE, 0.4) if i < _tier else CHUNK_HI
		var lo: Color = c.lerp(Color.BLACK, 0.35) if i < _tier else CHUNK_LO
		draw_rect(Rect2(at, Vector2(w, 1.0)), GuiColors.fade(hi, a))
		draw_rect(Rect2(at + Vector2(0.0, PIP_H - 1.0), Vector2(w, 1.0)), GuiColors.fade(lo, a))


#Upgrades that also sit in Less Legal carry the bandit mask in the corner.
func _draw_mask(side: float, a: float) -> void:
	if not UpgradeDefs.in_category(upgrade_id, "lessLegal"):
		return
	if UpgradeDefs.category_of(upgrade_id) == "lessLegal":
		return
	var span: float = 16.0
	Icons.draw(self, "less_legal", Vector2(side - span - 4.0, 4.0), MASK_SCALE,
		Color(LL_COLOR.r, LL_COLOR.g, LL_COLOR.b, a), false)


#Greedy word wrap of a module name to LABEL_WIDTH. Once NAME_MAX_LINES lines are open the rest stays on the last one.
static func wrap_name(text: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var line: String = ""
	for word: String in text.split(" ", false):
		var joined: String = word if line == "" else line + " " + word
		if line != "" and lines.size() < NAME_MAX_LINES - 1 and name_width(joined) > LABEL_WIDTH:
			lines.append(line)
			line = word
		else:
			line = joined
	lines.append(line)
	return lines


static func name_width(text: String) -> float:
	return NAME_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAME_SIZE).x


#How far the name capitals rise above their baseline.
static func name_rise() -> float:
	return CAP_RISE_EM * float(NAME_SIZE)


#Ink height of a caption with line_count name lines: the top of the first capitals to the bottom of the fee tile.
static func caption_height(line_count: int) -> float:
	var extra: float = float(maxi(1, line_count) - 1) * NAME_PITCH
	return name_rise() + extra + FEE_SPACE + NoteIcon.TILE_SIZE_PX.y


#Baselines of a caption under a module of the given side, in module space: one per name line, then the fee last.
#The ink is centred in the gap TreeLayout leaves between the node stub and the line that resumes.
static func caption_baselines(side: float, line_count: int) -> PackedFloat32Array:
	var count: int = maxi(1, line_count)
	var gap_mid: float = side + (TreeLayout.NODE_STUB + TreeLayout.LABEL_DROP) / 2.0
	var first: float = roundf(gap_mid - caption_height(count) / 2.0 + name_rise())
	var out: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(count):
		out.append(first + float(i) * NAME_PITCH)
	out.append(out[count - 1] + FEE_SPACE + NoteIcon.TILE_SIZE_PX.y - FEE_TILE_DROP)
	return out


func _draw_labels(side: float, a: float) -> void:
	var lines: PackedStringArray = name_lines()
	var rows: PackedFloat32Array = caption_baselines(side, lines.size())
	var left: float = (side - LABEL_WIDTH) / 2.0
	var tint: Color = GuiColors.fade(NAME_COLOR, a)
	for i: int in range(lines.size()):
		draw_string(NAME_FONT, Vector2(left, rows[i]), lines[i], HORIZONTAL_ALIGNMENT_CENTER,
			LABEL_WIDTH, NAME_SIZE, tint)
	NoteIcon.draw_run(self, FEE_FONT, FEE_SIZE, fee_text(), SUFFIX, side / 2.0,
		rows[rows.size() - 1], GuiColors.fade(fee_color(), a))
