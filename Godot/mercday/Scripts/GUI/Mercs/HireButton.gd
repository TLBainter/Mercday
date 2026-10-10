class_name HireButton extends BevelButton

#The Hire tile at the foot of the roster: a merc module in all but name, the add person glyph in a
#portrait frame beside the word Hire over a line counting who could take an offer. The tile reads
#its own gate, so it greys and refuses the press while the guild holds no free merc slot or no
#applicant is open to an offer, and the line under the title says which.

const ICON_ID: String = "add_person"
const ICON_SCALE: int = 3
const BUTTON_HEIGHT: int = 68
const LABEL_TEXT: String = "Hire"
const TIP_OPEN: String = "Hire a merc from the applicant pool"
const NO_SLOTS: String = "No free merc slots"
const NO_APPLICANTS: String = "No applicants to hire"
const SUB_ONE: String = "1 available applicant"
const SUB_MANY: String = "%d available applicants"
const BLOCKED_MODULATE: Color = Color(0.65, 0.65, 0.65, 1.0)

@onready var row: HBoxContainer = $Row
@onready var glyph_frame: Panel = $Row/GlyphHolder/Frame
@onready var glyph: TextureRect = $Row/GlyphHolder/Glyph
@onready var title_label: Label = $Row/Names/Title
@onready var sub_label: Label = $Row/Names/Sub


func _init() -> void:
	kind = &"go"
	click_move = ButtonFx.ClickMove.NONE
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.NONE


func _ready() -> void:
	super()
	custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	set_colors(GuiColors.ROW_FILL, GuiColors.GO_HI, GuiColors.GO_LO, GuiColors.CREAM)
	title_label.text = LABEL_TEXT
	GameState.roster_changed.connect(_refresh)
	PromotionsManager.applicants_changed.connect(_refresh)
	SubscriptionManager.changed.connect(_refresh)
	_refresh()


#Why the tile is barred; empty when a hire can be made.
func block_reason() -> String:
	if PromotionsManager.free_slots() <= 0:
		return NO_SLOTS
	if PromotionsManager.open_applicants() <= 0:
		return NO_APPLICANTS
	return ""


func title_text() -> String:
	return title_label.text if is_node_ready() else LABEL_TEXT


func sub_text() -> String:
	return sub_label.text if is_node_ready() else ""


#The line under the title: the count of applicants who could take an offer, or the bar in the way.
func _sub_line(reason: String) -> String:
	if reason != "":
		return reason
	var open: int = PromotionsManager.open_applicants()
	return SUB_ONE if open == 1 else SUB_MANY % open


func _refresh() -> void:
	if not is_node_ready():
		return
	var reason: String = block_reason()
	disabled = reason != ""
	tooltip_text = reason if disabled else TIP_OPEN
	sub_label.text = _sub_line(reason)
	glyph.texture = Icons.baked(ICON_ID, ICON_SCALE,
		Icons.MODE_GRAY if disabled else Icons.MODE_PLAIN)
	row.modulate = BLOCKED_MODULATE if disabled else Color.WHITE
	queue_redraw()
