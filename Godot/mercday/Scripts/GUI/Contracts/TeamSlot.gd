class_name TeamSlot extends PanelContainer

#One place on the dispatch team, SLOT_WIDTH px wide. A header band names the role: slot 0 is the
#pinned leader, the rest carry a dropdown. Empty the slot invites a click or a drop and states
#whether it is required; filled it shows a face row of portrait and level badge, who took it, how
#well they match and the traits that matter. The ring around it says whether the slot is the leader,
#required, optional or already filled, and turns green under a drag.

signal dropped(uid: int, slot: int)
signal cleared(slot: int)
signal role_changed(slot: int, role: String)
signal clicked(slot: int)
signal swapped(from_slot: int, to_slot: int)
#UiSfx hooks the slot through these: pressed sounds a slot click, sfx_hovered a hover outside a drag.
signal pressed
signal sfx_hovered

const DEFAULT_ROLE: String = "Support"
const EMPTY_TEXT: String = "Click or drag a merc here"
const REQUIRED_TEXT: String = "Required"
const HEADER_HEIGHT: int = 24
const PORTRAIT_SIZE: int = 56
const TRAIT_ROWS: int = 2
const SLOT_WIDTH: int = 120
#How far the role caret sits from the right edge (role style margin in TeamSlot.tscn): clear of the 20 px X plus a gap.
const ARROW_MARGIN: int = 28

#Ring colours by state; an optional empty slot draws nothing solid and takes the dashed ring.
const OVER_COLOR: Color = GuiColors.GREEN
const LEADER_COLOR: Color = GuiColors.ORANGE
const REQUIRED_COLOR: Color = GuiColors.ORANGE_LO
const FILLED_COLOR: Color = GuiColors.BLUE
const OPTIONAL_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const OPTIONAL_TEXT_COLOR: Color = GuiColors.MUTED
const DASH_COLOR: Color = GuiColors.BLUE_HI
const DASH_ALPHA: float = 0.55
const RING_WIDTH: int = 3
const DASH_LENGTH: float = 6.0
const BG_EMPTY: Color = GuiColors.ROW_FILL
const BG_FILLED: Color = GuiColors.ROW_HOVER
#How far the filled body fades while its ghost rides the cursor.
const HELD_ALPHA: float = 0.45

@onready var header: Control = $Rows/Head
@onready var leader_band: PanelContainer = $Rows/Head/Band
@onready var leader_label: Label = $Rows/Head/Band/Label
@onready var role_option: OptionDropdown = $Rows/Head/Role
@onready var remove_button: Button = $Rows/Head/Remove
@onready var empty_button: Button = $Rows/Body/Empty
@onready var plus_icon: IconRect = $Rows/Body/Empty/Box/Plus
@onready var prompt_label: Label = $Rows/Body/Empty/Box/Prompt
@onready var caption_label: Label = $Rows/Body/Empty/Box/Requirement/Caption
@onready var caption_dot: ColorRect = $Rows/Body/Empty/Box/Requirement/Dot
@onready var caption_tag: Label = $Rows/Body/Empty/Box/Requirement/Tag
@onready var filled_box: VBoxContainer = $Rows/Body/Filled
@onready var face_row: HBoxContainer = $Rows/Body/Filled/Face
@onready var portrait: MercPortrait = $Rows/Body/Filled/Face/Portrait
@onready var name_label: Label = $Rows/Body/Filled/Name
@onready var level_badge: LevelBadge = $Rows/Body/Filled/Face/Level
@onready var tradition_module: TraditionModule = $Rows/Body/Filled/Tradition
@onready var sigil: TraditionSigil = $Rows/Body/Filled/Tradition/Row/SigilBox/Center/Sigil
@onready var tradition_label: Label = $Rows/Body/Filled/Tradition/Row/Name
@onready var stars: Stars = $Rows/Body/Filled/Stars
@onready var traits_caption: Label = $Rows/Body/Filled/TraitsCaption
@onready var traits_scroll: ScrollContainer = $Rows/Body/Filled/Traits
@onready var trait_a: TraitRow = $Rows/Body/Filled/Traits/Pad/List/TraitA
@onready var trait_b: TraitRow = $Rows/Body/Filled/Traits/Pad/List/TraitB
@onready var divider: HSeparator = $Rows/Body/Filled/Traits/Pad/List/Divider
@onready var shared_a: TraitRow = $Rows/Body/Filled/Traits/Pad/List/SharedA
@onready var shared_b: TraitRow = $Rows/Body/Filled/Traits/Pad/List/SharedB
@onready var bevel: BevelEdges = $Rows/Head/Bevel

@export var required: bool = false:
	set(value):
		required = value
		_apply_ring()

var slot: int = 0
var view: MercView = null
var match_stars: float = 0.0
#True while a drag hovers this slot; cleared when the drag ends or the pointer leaves.
var drag_over: bool = false
#True from the moment this slot hands out a drag payload until the release that ends it.
var _drag_started: bool = false
#True while this slot's ghost rides the cursor.
var _held: bool = false
#Every descendant that would have swallowed a drop before it reached this slot.
var _forwarded: Array[Control] = []
#The roles a slot below the leader offers; empty falls back to slot_roles().
var offered: Array[String] = []


func _ready() -> void:
	_fill_roles()
	role_option.option_selected.connect(_on_role_selected)
	#Open, the role keeps its own hover look (margins fit for the caret) rather than the blue open style.
	role_option.open_style = role_option.toggle.get_theme_stylebox("hover")
	CloseX.style(remove_button, CloseX.SCALE_MINI)
	remove_button.custom_minimum_size = Vector2(20, 20)
	remove_button.pressed.connect(func() -> void: cleared.emit(slot))
	empty_button.pressed.connect(func() -> void: clicked.emit(slot))
	prompt_label.text = EMPTY_TEXT
	leader_label.text = ContractResultData.ROLE_LEADER.to_upper()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	level_badge.mouse_filter = MOUSE_FILTER_IGNORE
	#A STOP star row would drop the slot's hover and replay it on the way back; PASS keeps its tooltip.
	#The trait strips and the portrait take it too, before the drop walk below so none registers as a forwarder.
	stars.mouse_filter = MOUSE_FILTER_PASS
	for row: TraitRow in [trait_a, trait_b, shared_a, shared_b]:
		row.stars.mouse_filter = MOUSE_FILTER_PASS
	portrait.mouse_filter = MOUSE_FILTER_PASS
	_forward_drops(self)
	#The scroll bar is an internal STOP child, so the walk above never reaches it.
	var bar: VScrollBar = traits_scroll.get_v_scroll_bar()
	bar.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
	_forwarded.append(bar)
	_refresh()


#Godot stops its drop search at the first STOP control that refuses the data, so the buttons and the
#role picker covering the slot would eat every drop. Each one hands the question back to the slot.
func _forward_drops(node: Node) -> void:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		if control.mouse_filter == MOUSE_FILTER_STOP:
			control.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
			_forwarded.append(control)
		_forward_drops(control)


func forwarded_controls() -> Array[Control]:
	return _forwarded


#The first word of a name; the whole string when it carries no space.
static func first_name(full: String) -> String:
	var cut: int = full.find(" ")
	if cut < 0:
		return full.strip_edges()
	return full.substr(0, cut).strip_edges()


#The roles a slot below the leader may carry; the leader is pinned and never offered.
static func slot_roles() -> Array[String]:
	var out: Array[String] = []
	for role_name: String in GuiTypes.ROLES:
		if role_name != ContractResultData.ROLE_LEADER:
			out.append(role_name)
	return out


func set_offered(roles: Array[String]) -> void:
	offered.assign(roles)
	if is_node_ready():
		_fill_roles()


func role_list() -> Array[String]:
	if offered.is_empty():
		return slot_roles()
	var out: Array[String] = []
	out.assign(offered)
	return out


func set_slot(index: int, caption: String) -> void:
	slot = index
	if not is_node_ready():
		return
	var leader: bool = index == 0
	caption_label.text = caption
	var tint: Color = LEADER_COLOR if caption == REQUIRED_TEXT else OPTIONAL_TEXT_COLOR
	caption_label.add_theme_color_override("font_color", tint)
	caption_dot.visible = leader
	caption_tag.visible = leader
	leader_band.visible = leader
	role_option.visible = not leader
	role_option.disabled = leader
	bevel.visible = not leader
	_apply_ring()


#"over", "leader", "required", "optional" or "filled", in that order of precedence.
func ring_state() -> String:
	if drag_over:
		return "over"
	if slot == 0:
		return "leader"
	if not is_filled():
		return "required" if required else "optional"
	return "filled"


func ring_color() -> Color:
	match ring_state():
		"over":
			return OVER_COLOR
		"leader":
			return LEADER_COLOR
		"required":
			return REQUIRED_COLOR
		"optional":
			return OPTIONAL_COLOR
	return FILLED_COLOR


func set_member(new_view: MercView, new_stars: float, traits: Array[Dictionary],
		shared: Array[Dictionary]) -> void:
	view = new_view
	match_stars = new_stars
	_refresh()
	if not is_node_ready() or view == null:
		return
	traits_caption.visible = true
	_fill_rows(trait_rows(), traits, false)
	var show_shared: bool = slot > 0 and not shared.is_empty()
	divider.visible = show_shared
	var lent: Array[Dictionary] = []
	if show_shared:
		lent = shared
	_fill_rows(shared_rows(), lent, true)


func clear_member() -> void:
	view = null
	match_stars = 0.0
	_refresh()


func trait_rows() -> Array[TraitRow]:
	var out: Array[TraitRow] = []
	out.append(trait_a)
	out.append(trait_b)
	return out


func shared_rows() -> Array[TraitRow]:
	var out: Array[TraitRow] = []
	out.append(shared_a)
	out.append(shared_b)
	return out


func merc_uid() -> int:
	return view.uid if view != null else 0


func is_filled() -> bool:
	return view != null


func role() -> String:
	if slot == 0:
		return ContractResultData.ROLE_LEADER
	if not is_node_ready():
		return DEFAULT_ROLE
	var picked: String = String(role_option.selected)
	return picked if role_list().has(picked) else DEFAULT_ROLE


func set_role(role_name: String) -> void:
	if not is_node_ready():
		return
	var options: Array[String] = role_list()
	role_option.select(StringName(role_name if options.has(role_name) else options[0]))


func stars_value() -> float:
	return match_stars


func badge() -> LevelBadge:
	return level_badge


func is_held() -> bool:
	return _held


func _set_held(on: bool) -> void:
	_held = on
	if is_node_ready():
		filled_box.modulate = Color(1.0, 1.0, 1.0, HELD_ALPHA if on else 1.0)


func _fill_rows(rows: Array[TraitRow], entries: Array[Dictionary], shared: bool) -> void:
	for i: int in rows.size():
		var row: TraitRow = rows[i]
		if i >= entries.size():
			row.visible = false
			continue
		row.set_trait(row_text(entries[i]), MatchScore.stars(float(entries[i].get("pct", 0.0))), shared)
		row.visible = true


#A matched boost row as the slot shows it: the trait name and its real percent.
static func row_text(entry: Dictionary) -> String:
	return "%s +%d%%" % [str(entry.get("name", "")), roundi(float(entry.get("pct", 0.0)))]


func _refresh() -> void:
	if not is_node_ready():
		return
	var filled: bool = view != null
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if filled else Control.CURSOR_ARROW
	empty_button.visible = not filled
	filled_box.visible = filled
	remove_button.visible = filled
	_apply_ring()
	if not filled:
		tooltip_text = ""
		return
	portrait.pixel_size = PORTRAIT_SIZE
	portrait.set_merc(view)
	name_label.text = first_name(view.name)
	tooltip_text = "%s\nLevel %d\n%s" % [view.name, view.level, view.tradition]
	level_badge.level = view.level
	level_badge.current_xp = 0
	level_badge.next_level_xp = 1
	tradition_module.tradition = view.tradition
	stars.value = match_stars


#Paints the ring: a solid border in the state colour, or a dashed one for an optional empty slot.
#The header band runs the full inner width, so only the bottom keeps a content margin.
func _apply_ring() -> void:
	if not is_node_ready():
		return
	var bg: Color = BG_FILLED if is_filled() else BG_EMPTY
	var box: StyleBoxFlat = GuiStyle.flat(bg, RING_WIDTH, ring_color(), float(RING_WIDTH))
	box.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", box)
	queue_redraw()


func _draw() -> void:
	if ring_state() != "optional":
		return
	var inset: float = float(RING_WIDTH) * 0.5
	var rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var line_width: float = float(RING_WIDTH)
	var tint := Color(DASH_COLOR.r, DASH_COLOR.g, DASH_COLOR.b, DASH_ALPHA)
	draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), tint,
		line_width, DASH_LENGTH)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, tint,
		line_width, DASH_LENGTH)
	draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), tint,
		line_width, DASH_LENGTH)
	draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, tint,
		line_width, DASH_LENGTH)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	set_drag_over(false)
	_set_held(false)
	#The release that ended the drag can still reach _gui_input, so the guard falls at idle.
	_end_drag.call_deferred()


func _end_drag() -> void:
	_drag_started = false


func set_drag_over(on: bool) -> void:
	if drag_over == on:
		return
	drag_over = on
	_apply_ring()


func _on_mouse_entered() -> void:
	if not get_viewport().gui_is_dragging():
		sfx_hovered.emit()


func _on_mouse_exited() -> void:
	set_drag_over(false)


#The click lands on the release so a press can still begin a drag out of a filled slot.
func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _drag_started:
		_drag_started = false
		return
	pressed.emit()
	clicked.emit(slot)
	accept_event()


func _fill_roles() -> void:
	var listed: Array[String] = role_list()
	var rows: Array[Dictionary] = []
	for role_name: String in listed:
		rows.append({"key": StringName(role_name), "label": role_name})
	role_option.set_options(rows)
	var current: String = String(role_option.selected)
	role_option.select(StringName(current if listed.has(current) else listed[0]))


func _on_role_selected(key: StringName) -> void:
	if role_list().has(String(key)):
		role_changed.emit(slot, String(key))


#A filled slot can be dragged onto another slot; the two trade places.
func _get_drag_data(at_position: Vector2) -> Variant:
	if view == null:
		return null
	_drag_started = true
	MercDragGhost.attach(self, view, match_stars, Vector2.ZERO, at_position)
	_set_held(true)
	return {"slot": slot}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = accepts(data)
	set_drag_over(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	set_drag_over(false)
	if not (data is Dictionary):
		return
	var payload: Dictionary = data
	if payload.has("slot"):
		var from_slot: int = int(payload["slot"])
		if from_slot != slot:
			swapped.emit(from_slot, slot)
		return
	if payload.has("uid"):
		dropped.emit(int(payload["uid"]), slot)


static func accepts(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var payload: Dictionary = data
	return payload.has("uid") or payload.has("slot")
