class_name ClientOverview
extends PanelContainer

#The right column of the client window: who the client is, how they feel about the guild, the
#contract history and, for a company, the year of share prices.

signal recent_pressed(entry_id: int)
signal stock_pressed(company_id: int)
signal take_me_there(target: Dictionary)

const STAT_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/StatTile.tscn")
const STARS_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/DifficultyStars.tscn")
const FACE_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/MoodFace.tscn")
const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Clients/ClientRecentRow.tscn")
const CELL_STYLE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/client_stat_cell.tres")
const LABEL_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const DASH_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const OUTLINE_PX: float = 4.0
const BEVEL_PX: float = 4.0
const BEVEL_HI: Color = Color("#28447a")
const BEVEL_LO: Color = Color("#111c33")
const MUTED: Color = Color("#9cc6ef")
const CREAM: Color = Color("#f3ead7")
const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")
const YELLOW: Color = Color("#f2d33d")
const FACE_PX: int = 96
const FACE_BAND: int = 6
const FACE_SCALE: int = 3
const CELL_HEIGHT: int = 45
const GRID_HEIGHT: int = 98
const STAR_SIZE: int = 2
const DASH_TEXT: String = "-"
const DASH_SIZE: int = 13
const CELL_LABEL_SIZE: int = 9
const ENTITLEMENT: String = "clientOpinion"
const NEUTRAL_TEXT: String = "Neutral"
const ORG_TITLE: String = "Company Details"
const OTHER_TITLE: String = "Details"
const REL_MIN: int = -5
const REL_MAX: int = 5
const STATS: Array[Dictionary] = [
	{"key": &"offered", "label": "Offered"},
	{"key": &"accepted", "label": "Accepted"},
	{"key": &"succeeded", "label": "Successful"},
	{"key": &"failed", "label": "Failed"},
	{"key": &"paid", "label": "Notes Earned"},
]

var client: ClientData = null

var _tiles: Array[StatTile] = []
var _faces: Array[MoodFace] = []
var _rows: Array[ClientRecentRow] = []
var _stars: DifficultyStars = null
var _dash: Label = null
var _prices: PackedFloat32Array = PackedFloat32Array()
var _company: int = -1

@onready var empty_label: Label = $Rows/Empty
@onready var body: VBoxContainer = $Rows/Body
@onready var face: TextureRect = $Rows/Body/Header/FaceHolder/Fill
@onready var name_label: Label = $Rows/Body/Header/Names/ClientName
@onready var kind_label: Label = $Rows/Body/Header/Names/KindLine
@onready var where_label: Label = $Rows/Body/Header/Names/Where
@onready var rel_value: Label = $Rows/Body/Relation/RelRows/RelValue
@onready var faces_row: HBoxContainer = $Rows/Body/Relation/RelRows/Faces
@onready var lock_button: FeatureLock = $Rows/Body/Relation/RelRows/Lock
@onready var stats_grid: GridContainer = $Rows/Body/Lower/Left/Stats
@onready var recent_items: VBoxContainer = $Rows/Body/Lower/Left/RecentPanel/RecentScroll/Items
@onready var recent_empty: PanelContainer = $Rows/Body/Lower/Left/RecentPanel/RecentScroll/Items/Empty
@onready var right_head: Label = $Rows/Body/Lower/Right/RightHead
@onready var summary_label: Label = $Rows/Body/Lower/Right/Summary/SumRows/SumText
@onready var chart: ClientStockChart = $Rows/Body/Lower/Right/Chart


func _ready() -> void:
	face.texture = ClientGlyphs.hatch(FACE_PX, FACE_BAND)
	_build_stats()
	_build_faces()
	if not lock_button.take_me_there.is_connected(_on_take_me_there):
		lock_button.take_me_there.connect(_on_take_me_there)
	if not chart.pressed.is_connected(_on_chart_pressed):
		chart.pressed.connect(_on_chart_pressed)
	if not SubscriptionManager.changed.is_connected(_on_plan_changed):
		SubscriptionManager.changed.connect(_on_plan_changed)
	_render()


func _exit_tree() -> void:
	if SubscriptionManager.changed.is_connected(_on_plan_changed):
		SubscriptionManager.changed.disconnect(_on_plan_changed)


func show_client(data: ClientData) -> void:
	client = data
	if is_node_ready():
		_render()


func set_stock(company_id: int, prices: PackedFloat32Array) -> void:
	_company = company_id
	_prices = prices.duplicate()
	if is_node_ready():
		_render_chart()


func hide_stock() -> void:
	set_stock(-1, PackedFloat32Array())


func chart_button() -> ClientStockChart:
	return chart


func lock() -> FeatureLock:
	return lock_button


func lock_shown() -> bool:
	return lock_button.visible


func faces() -> Array[MoodFace]:
	var out: Array[MoodFace] = _faces.duplicate()
	return out


func filled_face() -> int:
	for i: int in _faces.size():
		if _faces[i].filled:
			return i + REL_MIN
	return 0


func tiles() -> Array[StatTile]:
	var out: Array[StatTile] = _tiles.duplicate()
	return out


func recent_rows() -> Array[ClientRecentRow]:
	var out: Array[ClientRecentRow] = _rows.duplicate()
	return out


func stars() -> DifficultyStars:
	return _stars


func empty_shown() -> bool:
	return empty_label.visible


func empty_text() -> String:
	return empty_label.text


func name_text() -> String:
	return name_label.text


func kind_text() -> String:
	return kind_label.text


func where_text() -> String:
	return where_label.text


func relationship_text() -> String:
	return rel_value.text


func relationship_color() -> Color:
	return rel_value.get_theme_color(&"font_color")


func right_title() -> String:
	return right_head.text


func summary_text() -> String:
	return summary_label.text


func avg_text() -> String:
	return _dash.text if _dash != null else ""


func stars_shown() -> bool:
	return _stars != null and _stars.visible


func recent_empty_shown() -> bool:
	return recent_empty.visible


func entitled() -> bool:
	return bool(SubscriptionManager.entitlements().get(ENTITLEMENT, false))


static func relationship_line(value: int) -> String:
	if value == 0:
		return NEUTRAL_TEXT
	return "Opinion %+d" % value


func _draw() -> void:
	var left: float = OUTLINE_PX
	var top: float = OUTLINE_PX
	var right: float = size.x - OUTLINE_PX
	var bottom: float = size.y - OUTLINE_PX
	draw_rect(Rect2(left, top, right - left, BEVEL_PX), BEVEL_HI)
	draw_rect(Rect2(left, top, BEVEL_PX, bottom - top), BEVEL_HI)
	draw_rect(Rect2(left, bottom - BEVEL_PX, right - left, BEVEL_PX), BEVEL_LO)
	draw_rect(Rect2(right - BEVEL_PX, top, BEVEL_PX, bottom - top), BEVEL_LO)


func _build_stats() -> void:
	stats_grid.custom_minimum_size.y = float(GRID_HEIGHT)
	stats_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for row: Dictionary in STATS:
		var cell: PanelContainer = _cell()
		var tile: StatTile = STAT_SCENE.instantiate()
		cell.add_child(tile)
		stats_grid.add_child(cell)
		tile.compact = true
		tile.label = String(row.get("label", ""))
		tile.show_glyph = false
		_tiles.append(tile)
	var last: PanelContainer = _cell()
	var pad := MarginContainer.new()
	pad.add_theme_constant_override(&"margin_left", 8)
	pad.add_theme_constant_override(&"margin_top", 6)
	pad.add_theme_constant_override(&"margin_right", 8)
	pad.add_theme_constant_override(&"margin_bottom", 6)
	last.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	pad.add_child(box)
	var caption := Label.new()
	caption.text = "Avg Difficulty"
	caption.add_theme_font_override(&"font", LABEL_FONT)
	caption.add_theme_font_size_override(&"font_size", CELL_LABEL_SIZE)
	caption.add_theme_color_override(&"font_color", MUTED)
	box.add_child(caption)
	_stars = STARS_SCENE.instantiate()
	box.add_child(_stars)
	_stars.star_size = STAR_SIZE
	_dash = Label.new()
	_dash.text = DASH_TEXT
	_dash.add_theme_font_override(&"font", DASH_FONT)
	_dash.add_theme_font_size_override(&"font_size", DASH_SIZE)
	_dash.add_theme_color_override(&"font_color", MUTED)
	box.add_child(_dash)
	stats_grid.add_child(last)


func _cell() -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(0.0, float(CELL_HEIGHT))
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_stylebox_override(&"panel", CELL_STYLE)
	return cell


func _build_faces() -> void:
	for i: int in range(REL_MAX - REL_MIN + 1):
		var moodface: MoodFace = FACE_SCENE.instantiate()
		faces_row.add_child(moodface)
		moodface.guild = true
		moodface.opinion = i + REL_MIN
		moodface.pixel_scale = FACE_SCALE
		moodface.filled = false
		moodface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_faces.append(moodface)


func _render() -> void:
	var has: bool = client != null
	empty_label.visible = not has
	body.visible = has
	if not has:
		return
	name_label.text = client.name
	kind_label.text = client.kind_line()
	where_label.text = client.where_text()
	right_head.text = ORG_TITLE if client.kind == &"orgs" else OTHER_TITLE
	summary_label.text = client.about
	_render_relationship()
	_render_stats()
	_render_recent()
	_render_chart()


func _render_relationship() -> void:
	var open: bool = entitled()
	rel_value.visible = open
	faces_row.visible = open
	lock_button.visible = not open
	if not open or client == null:
		return
	var value: int = clampi(client.relationship, REL_MIN, REL_MAX)
	rel_value.text = relationship_line(value)
	rel_value.add_theme_color_override(&"font_color", MoodFace.GUILD_COLORS[value - REL_MIN])
	for i: int in _faces.size():
		var seat: int = i + REL_MIN
		_faces[i].filled = seat == value
		_faces[i].tooltip_text = relationship_line(seat)


func _render_stats() -> void:
	for i: int in _tiles.size():
		var key: StringName = StringName(STATS[i].get("key", &""))
		_tiles[i].set_stat({"amount": _stat_value(key), "color": _stat_color(key),
			"glyph": key == &"paid"})
	var shown: bool = client != null and client.accepted > 0
	if _stars != null:
		_stars.visible = shown
		if shown:
			_stars.rating = roundf(client.avg_difficulty * 2.0) / 2.0
	if _dash != null:
		_dash.visible = not shown


func _render_recent() -> void:
	for row: ClientRecentRow in _rows:
		recent_items.remove_child(row)
		row.queue_free()
	_rows.clear()
	if client != null:
		for entry: Dictionary in client.recent:
			var row: ClientRecentRow = ROW_SCENE.instantiate()
			recent_items.add_child(row)
			row.set_row(entry)
			row.pressed_row.connect(_on_row_pressed)
			_rows.append(row)
	recent_empty.visible = _rows.is_empty()


func _render_chart() -> void:
	var is_org: bool = client != null and client.kind == &"orgs"
	chart.set_prices(_company, _prices)
	chart.visible = is_org and _prices.size() >= ClientStockChart.MIN_PRICES


func _stat_value(key: StringName) -> int:
	if client == null:
		return 0
	if key == &"accepted":
		return client.accepted
	if key == &"succeeded":
		return client.succeeded
	if key == &"failed":
		return client.failed
	if key == &"paid":
		return client.paid
	return client.offered


func _stat_color(key: StringName) -> Color:
	if key == &"succeeded":
		return GREEN
	if key == &"failed":
		return RED
	if key == &"paid":
		return YELLOW
	return CREAM


func _on_row_pressed(entry_id: int) -> void:
	recent_pressed.emit(entry_id)


func _on_chart_pressed() -> void:
	if chart.company_id >= 0:
		stock_pressed.emit(chart.company_id)


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)


func _on_plan_changed() -> void:
	if is_node_ready():
		_render_relationship()
