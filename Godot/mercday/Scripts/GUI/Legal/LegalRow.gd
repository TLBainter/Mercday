class_name LegalRow extends PanelContainer

#The skeleton every Legal list row shares: the blue row panel, the Review button and the unread
#dot on the top right corner. NotificationDot.attach repins the dot after each sort of the panel,
#so no row keeps its own sort hook. A row builds its columns in _build and fills them in _refresh.

const REVIEW_TEXT: String = "Review"
const REVIEW_WIDTH: int = 96
const REVIEW_HEIGHT: int = 30
const REVIEW_FONT: int = 11
const COL_ACTION: int = 150
const DOT_INSET: Vector2 = Vector2(2, 2)

var review_button: Button = null
var dot: NotificationDot = null


func _ready() -> void:
	_build()
	_refresh()


func press_review() -> void:
	if review_button != null and not review_button.disabled:
		review_button.pressed.emit()


#The id of the record the row shows, or -1 while it shows none.
func row_id() -> int:
	return -1


func _build() -> void:
	pass


func _refresh() -> void:
	pass


#Paints the row panel, adds the row's content and pins the unlit dot over it.
func _mount(content: Control) -> void:
	add_theme_stylebox_override(&"panel", LegalStyle.row_style(GuiColors.BLUE_LO))
	add_child(content)
	dot = NotificationDot.attach(self, DOT_INSET)
	dot.on = false


func _review(width: int = REVIEW_WIDTH, font_size: int = REVIEW_FONT) -> Button:
	review_button = LegalStyle.button(REVIEW_TEXT, &"neutral", REVIEW_HEIGHT, font_size)
	review_button.name = "Review"
	(review_button as BevelButton).min_size = Vector2(float(width), float(REVIEW_HEIGHT))
	review_button.pressed.connect(_on_review)
	return review_button


#The fixed Action column the list heads line up with; the button keeps its own width inside it and
#the column sits centred on the row's height.
func _action_column() -> Control:
	var action: Control = Control.new()
	action.name = "Action"
	action.custom_minimum_size = Vector2(float(COL_ACTION), float(REVIEW_HEIGHT))
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.add_child(_review())
	return action


#Each row reports its Review through its own review_pressed signal.
func _on_review() -> void:
	pass
