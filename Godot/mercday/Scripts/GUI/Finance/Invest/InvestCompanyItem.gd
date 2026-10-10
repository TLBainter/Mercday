class_name InvestCompanyItem extends BevelButton

#One company row of the Invest roster: the hatch logo with its one day change strip, the name,
#the price in its change colour and the owned line. The unread dot sits on the top right corner.

const STRIP_ALPHA: float = 0.8

@onready var hatch: TextureRect = $Row/LogoBox/Hatch
@onready var strip: ColorRect = $Row/LogoBox/Strip
@onready var strip_label: Label = $Row/LogoBox/Strip/ChangeMini
@onready var name_label: Label = $Row/TextCol/NameLabel
@onready var price_label: Label = $Row/TextCol/PriceLabel
@onready var owned_label: Label = $Row/TextCol/OwnedLabel

var company_id: int = -1

var _selected: bool = false
var _dot: NotificationDot = null


func _init() -> void:
	pressed_fill = InvestText.NAVY2
	click_move = ButtonFx.ClickMove.NONE
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING
	_paint_selection()


func _ready() -> void:
	super()
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size.y = 60.0
	hatch.texture = InvestGlyphs.hatch(InvestGlyphs.LOGO_LARGE)
	strip.color = Color(InvestText.INK.r, InvestText.INK.g, InvestText.INK.b, STRIP_ALPHA)
	_dot = NotificationDot.attach(self)
	_dot.on = false
	refresh()


func setup(k: int) -> void:
	company_id = k
	if is_node_ready():
		refresh()


func set_selected(on: bool) -> void:
	_selected = on
	_paint_selection()
	if is_node_ready():
		refresh()
	queue_redraw()


func refresh() -> void:
	if not is_node_ready():
		return
	var row: Dictionary = StockMarket.company(company_id)
	if row.is_empty():
		name_label.text = ""
		price_label.text = ""
		owned_label.text = ""
		strip_label.text = ""
		if _dot != null:
			_dot.on = false
		queue_redraw()
		return
	var pct: float = float(row["change_pct"])
	var tint: Color = InvestText.change_color(pct)
	name_label.text = String(row["name"])
	price_label.text = InvestText.price_text(float(row["price"]))
	price_label.add_theme_color_override("font_color", tint)
	strip_label.text = InvestText.change_text(pct)
	strip_label.add_theme_color_override("font_color", tint)
	var holding: Dictionary = StockMarket.holding(company_id)
	var shares: int = int(holding.get("shares", 0))
	owned_label.text = InvestText.shares_text(shares) if shares > 0 else "Not owned"
	owned_label.add_theme_color_override("font_color",
		InvestText.YELLOW if shares > 0 else InvestText.SKY)
	if _dot != null:
		_dot.on = StockMarket.has_unread(company_id)
	queue_redraw()


func name_text() -> String:
	return name_label.text


func price_text() -> String:
	return price_label.text


func change_text() -> String:
	return strip_label.text


func change_color() -> Color:
	return price_label.get_theme_color("font_color")


func owned_text() -> String:
	return owned_label.text


func has_dot() -> bool:
	return _dot != null and _dot.visible


func dot() -> NotificationDot:
	return _dot


func is_selected() -> bool:
	return _selected


func fx_active() -> bool:
	return super() or _selected


#The selected row takes the pressed fill with its orange ring on both bands; an idle row keeps the ink edge low.
func _paint_selection() -> void:
	if _selected:
		set_colors(InvestText.NAVY2, InvestText.ORANGE, InvestText.ORANGE, text_color)
	else:
		set_colors(InvestText.NAVY, InvestText.NAVY.lightened(0.18), InvestText.INK, text_color)
