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

const LEADER_ROLE: String = "Leader"
const DEFAULT_ROLE: String = "Support"
const EMPTY_TEXT: String = "Click or drag a merc here"
const REQUIRED_TEXT: String = "Required"
const HEADER_HEIGHT: int = 24
const PORTRAIT_SIZE: int = 56
const TRAIT_ROWS: int = 2
const SLOT_WIDTH: int = 120
#How far the dropdown arrow sits from the right edge: clear of the 20 px X button plus a gap.
const ARROW_MARGIN: int = 28
const ARROW_SIZE: Vector2i = Vector2i(8, 5)
const ARROW_COLOR: Color = Color("#f3ead7")

#Ring colours by state; an optional empty slot draws nothing solid and takes the dashed ring.
const OVER_COLOR: Color = Color("#6cc36a")
const LEADER_COLOR: Color = Color("#f28c28")
const REQUIRED_COLOR: Color = Color("#b85a12")
const FILLED_COLOR: Color = Color("#2b4f8a")
const OPTIONAL_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const OPTIONAL_TEXT_COLOR: Color = Color("#5e7699")
const DASH_COLOR: Color = Color("#3b6fb6")
const DASH_ALPHA: float = 0.55
const RING_WIDTH: int = 3
const DASH_LENGTH: float = 6.0
const BG_EMPTY: Color = Color("#0e1628")
const BG_FILLED: Color = Color("#15223d")
#How far the filled body fades while its ghost rides the cursor.
const HELD_ALPHA: float = 0.45

@onready var header: Control = $Rows/Head
@onready var leader_band: PanelContainer = $Rows/Head/Band
@onready var leader_label: Label = $Rows/Head/Band/Label
@onready var role_option: OptionButton = $Rows/Head/Role
@onready var remove_button: Button = $Rows/Head/Remove
@onready var empty_button: Button = $Rows/Body/Empty
@onready var plus_label: Label = $Rows/Body/Empty/Box/Plus
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
@onready var stars: DifficultyStars = $Rows/Body/Filled/Stars
@onready var traits_caption: Label = $Rows/Body/Filled/TraitsCaption
@onready var traits_scroll: ScrollContainer = $Rows/Body/Filled/Traits
@onready var trait_a: TraitRow = $Rows/Body/Filled/Traits/List/TraitA
@onready var trait_b: TraitRow = $Rows/Body/Filled/Traits/List/TraitB
@onready var divider: HSeparator = $Rows/Body/Filled/Traits/List/Divider
@onready var shared_a: TraitRow = $Rows/Body/Filled/Traits/List/SharedA
@onready var shared_b: TraitRow = $Rows/Body/Filled/Traits/List/SharedB
@onready var bevel_top: ColorRect = $Rows/Head/BevelTop
@onready var bevel_bottom: ColorRect = $Rows/Head/BevelBottom

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


func _ready() -> void:
	for role_name: String in slot_roles():
		role_option.add_item(role_name)
	role_option.selected = 0
	role_option.item_selected.connect(_on_role_selected)
	role_option.add_theme_icon_override("arrow", arrow_texture())
	role_option.add_theme_constant_override("arrow_margin", ARROW_MARGIN)
	remove_button.pressed.connect(func() -> void: cleared.emit(slot))
	empty_button.pressed.connect(func() -> void: clicked.emit(slot))
	prompt_label.text = EMPTY_TEXT
	leader_label.text = LEADER_ROLE.to_upper()
	mouse_exited.connect(_on_mouse_exited)
	level_badge.mouse_filter = MOUSE_FILTER_IGNORE
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


#The cream triangle the theme leaves off the dropdown, so a role reads as pickable when it is taken.
static func arrow_texture() -> ImageTexture:
	var img: Image = Image.create_empty(ARROW_SIZE.x, ARROW_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in ARROW_SIZE.y:
		var wide: int = maxi(ARROW_SIZE.x - y * 2, 2)
		var left: int = int((ARROW_SIZE.x - wide) / 2.0)
		for x: int in wide:
			img.set_pixel(left + x, y, ARROW_COLOR)
	return ImageTexture.create_from_image(img)


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
		if role_name != LEADER_ROLE:
			out.append(role_name)
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
	bevel_top.visible = not leader
	bevel_bottom.visible = not leader
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
	traits_caption.visible = not traits.is_empty()
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
		return LEADER_ROLE
	if not is_node_ready():
		return DEFAULT_ROLE
	var options: Array[String] = slot_roles()
	var index: int = role_option.selected
	if index < 0 or index >= options.size():
		return DEFAULT_ROLE
	return options[index]


func set_role(role_name: String) -> void:
	if not is_node_ready():
		return
	var index: int = slot_roles().find(role_name)
	role_option.selected = index if index >= 0 else 0


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
		var entry: Dictionary = entries[i]
		var value: float = float(entry.get("value", 0.0))
		row.set_trait(str(entry.get("name", "")), DispatchLogic.to_stars(value), shared)
		row.visible = true


func _refresh() -> void:
	if not is_node_ready():
		return
	var filled: bool = view != null
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
	stars.rating = match_stars


#Paints the ring: a solid border in the state colour, or a dashed one for an optional empty slot.
#The header band runs the full inner width, so only the bottom keeps a content margin.
func _apply_ring() -> void:
	if not is_node_ready():
		return
	var box := StyleBoxFlat.new()
	box.bg_color = BG_FILLED if is_filled() else BG_EMPTY
	box.border_color = ring_color()
	box.border_width_left = RING_WIDTH
	box.border_width_top = RING_WIDTH
	box.border_width_right = RING_WIDTH
	box.border_width_bottom = RING_WIDTH
	box.content_margin_left = float(RING_WIDTH)
	box.content_margin_top = float(RING_WIDTH)
	box.content_margin_right = float(RING_WIDTH)
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
	clicked.emit(slot)
	accept_event()


func _on_role_selected(index: int) -> void:
	var options: Array[String] = slot_roles()
	if index >= 0 and index < options.size():
		role_changed.emit(slot, options[index])


#A filled slot can be dragged onto another slot; the two trade places.
#The ghost waits on the viewport: set_drag_preview is only legal once a drag is under way.
func _get_drag_data(at_position: Vector2) -> Variant:
	if view == null:
		return null
	_drag_started = true
	if is_inside_tree() and get_viewport().gui_is_dragging():
		set_drag_preview(MercDragGhost.build(view, match_stars, Vector2.ZERO, at_position))
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


static func _trait_names(traits: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in traits:
		out.append(str(entry.get("name", "")))
	return out
