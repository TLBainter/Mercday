class_name InvestCompanyItem extends Button

#One company row of the Invest roster: the hatch logo with its one day change strip, the name,
#the price in its change colour and the owned line. The unread dot sits on the top right corner.

const LOGO_BOX: Vector2i = Vector2i(40, 48)
const RING_WIDTH: float = 3.0
const STRIP_ALPHA: float = 0.8

@onready var hatch: TextureRect = $Row/LogoBox/Hatch
@onready var strip: ColorRect = $Row/LogoBox/Strip
@onready var strip_label: Label = $Row/LogoBox/Strip/ChangeMini
@onready var name_label: Label = $Row/TextCol/NameLabel
@onready var price_label: Label = $Row/TextCol/PriceLabel
@onready var owned_label: Label = $Row/TextCol/OwnedLabel

var company_id: int = -1

var _selected: bool = false
var _hovered: bool = false
var _dot: NotificationDot = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size.y = 60.0
	hatch.texture = InvestGlyphs.hatch(LOGO_BOX)
	strip.color = Color(InvestText.INK.r, InvestText.INK.g, InvestText.INK.b, STRIP_ALPHA)
	_dot = NotificationDot.attach(self)
	_dot.on = false
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	refresh()


func setup(k: int) -> void:
	company_id = k
	if is_node_ready():
		refresh()


func set_selected(on: bool) -> void:
	_selected = on
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


func _on_hover_in() -> void:
	_hovered = true
	queue_redraw()


func _on_hover_out() -> void:
	_hovered = false
	queue_redraw()


func _draw() -> void:
	var body: Color = InvestText.NAVY2 if (_selected or _hovered) else InvestText.NAVY
	draw_rect(Rect2(Vector2.ZERO, size), body, true)
	var ring: Color = InvestText.ORANGE if _selected else InvestText.INK
	var half: float = RING_WIDTH / 2.0
	var inner := Rect2(half, half, maxf(0.0, size.x - RING_WIDTH),
		maxf(0.0, size.y - RING_WIDTH))
	draw_rect(inner, ring, false, RING_WIDTH)
