class_name ContractListItem extends Button

#One roster row: the striped contract thumbnail with its status band on top, the name over the
#difficulty stars and the pay, and the level tile at the right. A settled posting greys out and an
#open posting running out of time carries the urgency pulse over its image.

signal selected(entry_id: int)
signal hovered(row_view: ContractView)
signal unhovered

const BUTTON_HEIGHT: int = 68
const SELECTED_FILL: Color = Color("#15223d")
const NORMAL_FILL: Color = Color("#0e1628")
const HOVER_FILL: Color = Color("#15223d")
const SELECTED_EDGE: Color = Color("#f28c28")
const NORMAL_EDGE: Color = Color("#0a0f1c")
const EDGE_PX: int = 3
const BOX_MARGIN: float = 6.0
const CLOSED_TINT: Color = Color("#8a97ad")
#The view statuses that count as closed (B4). FAILED is a display status only; a failed posting
#carries COMPLETED here, so both names sit in the table.
const CLOSED_STATUSES: Array[int] = [GuiTypes.ContractStatus.COMPLETED,
	GuiTypes.ContractStatus.EXPIRED, GuiTypes.ContractStatus.REJECTED,
	GuiTypes.ContractStatus.FAILED]

@onready var image: ContractImageBox = $Row/Image
@onready var name_label: Label = $Row/Text/Name
@onready var stars: DifficultyStars = $Row/Text/Stars
@onready var reward_label: Label = $Row/Text/Line/Reward
@onready var mark: StatusMark = $Mark
@onready var pulse: UrgencyPulse = $Row/Image/Pulse
@onready var strip_label: Label = $Row/Image/Strip/Text
@onready var level_badge: LevelBadge = $Row/Level

var view: ContractView = null
var is_selected: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	pressed.connect(_on_pressed)
	level_badge.mouse_filter = MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_entered)
	mouse_exited.connect(_on_exited)
	_refresh()


func set_view(new_view: ContractView) -> void:
	view = new_view
	_refresh()


func set_selected(on: bool) -> void:
	is_selected = on
	if is_node_ready():
		_apply_boxes()


func entry_id() -> int:
	return view.entry_id if view != null else -1


func _refresh() -> void:
	if not is_node_ready():
		return
	_apply_boxes()
	if view == null:
		return
	name_label.text = view.name
	stars.rating = view.difficulty
	reward_label.text = "%d" % view.reward
	mark.kind = view.shown_mark()
	pulse.active = pulses(view)
	modulate = CLOSED_TINT if greys(view) else Color.WHITE
	strip_label.text = view.shown_status_text()
	strip_label.add_theme_color_override("font_color", view.shown_status_color())
	level_badge.level = view.contract_level
	image.set_image_path(view.image)


#The row never shows the theme's blue button look: every state carries a row box and the focus
#ring is emptied, so only the selection ring reads.
func _apply_boxes() -> void:
	if is_selected:
		var box: StyleBoxFlat = selected_box()
		add_theme_stylebox_override("normal", box)
		add_theme_stylebox_override("hover", box)
		add_theme_stylebox_override("pressed", box)
	else:
		add_theme_stylebox_override("normal", normal_box())
		add_theme_stylebox_override("hover", hover_box())
		add_theme_stylebox_override("pressed", hover_box())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func normal_box() -> StyleBoxFlat:
	return _row_box(NORMAL_FILL, NORMAL_EDGE)


static func hover_box() -> StyleBoxFlat:
	return _row_box(HOVER_FILL, NORMAL_EDGE)


static func selected_box() -> StyleBoxFlat:
	return _row_box(SELECTED_FILL, SELECTED_EDGE)


static func _row_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_width_left = EDGE_PX
	box.border_width_top = EDGE_PX
	box.border_width_right = EDGE_PX
	box.border_width_bottom = EDGE_PX
	box.border_color = edge
	box.content_margin_left = BOX_MARGIN
	box.content_margin_right = BOX_MARGIN
	box.content_margin_top = BOX_MARGIN
	box.content_margin_bottom = BOX_MARGIN
	return box


func strip_text() -> String:
	return strip_label.text if is_node_ready() else ""


func strip_color() -> Color:
	return strip_label.get_theme_color("font_color") if is_node_ready() else Color.WHITE


func badge() -> LevelBadge:
	return level_badge


func image_box() -> ContractImageBox:
	return image


func _on_pressed() -> void:
	selected.emit(entry_id())


func _on_entered() -> void:
	if view != null:
		hovered.emit(view)


func _on_exited() -> void:
	unhovered.emit()


#Only a posting still on offer can run out of time, so a settled or running one never flashes.
static func pulses(row: ContractView) -> bool:
	return row != null and row.status == GuiTypes.ContractStatus.AVAILABLE \
		and row.urgency == GuiTypes.Urgency.HIGH


#Completed, Failed, Expired and Rejected postings are closed; the filter hides each one unless its
#own option is on.
static func is_closed(row: ContractView) -> bool:
	return row != null and CLOSED_STATUSES.has(row.status)


#A settled posting greys out, but not while its results sit unopened: that row still reads as news.
static func greys(row: ContractView) -> bool:
	return is_closed(row) and not row.is_unclaimed()
