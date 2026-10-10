class_name ContractListItem extends ListRow

#One roster row: the striped contract thumbnail with its status band on top, the name over the
#difficulty stars and the pay, and the level tile at the right. A settled posting greys out and an
#open posting running out of time carries the urgency pulse over its image.

signal pressed_row(entry_id: int)
signal hovered(row_view: ContractView)
signal unhovered

const BUTTON_HEIGHT: int = 68
const CLOSED_TINT: Color = GuiColors.DIM_TEXT
#The view statuses that count as closed. FAILED is a display status only; a failed posting
#carries COMPLETED here, so both names sit in the table.
const CLOSED_STATUSES: Array[int] = [GuiTypes.ContractStatus.COMPLETED,
	GuiTypes.ContractStatus.EXPIRED, GuiTypes.ContractStatus.REJECTED,
	GuiTypes.ContractStatus.FAILED]
const STORY_ICON: String = "scroll"

@onready var image: ContractImageBox = $Row/Image
@onready var name_label: Label = $Row/Text/Name
@onready var stars: Stars = $Row/Text/Stars
@onready var line: HBoxContainer = $Row/Text/Line
@onready var reward_label: Label = $Row/Text/Line/Reward
@onready var mark: StatusMark = $Row/Image/Mark
@onready var pulse: UrgencyPulse = $Row/Image/Pulse
@onready var strip_label: Label = $Row/Image/Strip/Text
@onready var level_badge: LevelBadge = $Row/Level

var view: ContractView = null
#The scroll ahead of the note on a story posting, built in code; Row/Image keeps the pulse last.
var story_icon: IconRect


func _ready() -> void:
	super()
	custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	pressed.connect(_on_pressed)
	level_badge.mouse_filter = MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_entered)
	mouse_exited.connect(_on_exited)
	story_icon = IconRect.new()
	story_icon.name = "Story"
	story_icon.icon_id = STORY_ICON
	story_icon.trimmed = true
	story_icon.pixel_scale = 1
	story_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	story_icon.mouse_filter = MOUSE_FILTER_IGNORE
	story_icon.visible = false
	line.add_child(story_icon)
	line.move_child(story_icon, 0)
	_refresh()


func set_view(new_view: ContractView) -> void:
	view = new_view
	_refresh()


func entry_id() -> int:
	return view.entry_id if view != null else -1


func _refresh() -> void:
	if not is_node_ready():
		return
	if view == null:
		return
	name_label.text = view.name
	stars.value = view.difficulty
	reward_label.text = "%d" % view.reward
	story_icon.visible = view.story
	mark.kind = view.shown_mark()
	pulse.active = pulses(view)
	modulate = CLOSED_TINT if greys(view) else Color.WHITE
	strip_label.text = view.shown_status_text()
	strip_label.add_theme_color_override("font_color", view.shown_status_color())
	level_badge.level = view.contract_level
	image.set_image_path(view.image)


func strip_text() -> String:
	return strip_label.text if is_node_ready() else ""


func strip_color() -> Color:
	return strip_label.get_theme_color("font_color") if is_node_ready() else Color.WHITE


func badge() -> LevelBadge:
	return level_badge


func image_box() -> ContractImageBox:
	return image


func _on_pressed() -> void:
	pressed_row.emit(entry_id())


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
