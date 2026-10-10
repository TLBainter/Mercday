class_name MercPortrait extends SubViewportContainer

#Renders characterScene.tscn into a small SubViewport for a merc portrait icon. set_merc shows the merc's
#appearance resource (else the adult look rolled from its seed over its pool), stores the uid and the tooltip name and
#centres the status badge on the portrait. The viewport shows pixel_size / stretch_shrink px of the 64 px SV frame from the head
#down (48x48 at multiples of 48, 44x44 or 56x56 at those sizes), or the whole frame when full_body is on.

const CROP_SIZE: int = 48
const FULL_SIZE: int = CharacterBaker.FRAME_SIZE
const HEAD_OFFSET: Vector2 = Vector2(0, -5)

@export var pixel_size: int = 48:
	set(value):
		pixel_size = value
		_refresh()
@export var full_body: bool = false:
	set(value):
		full_body = value
		_refresh()
@export var frame: int = 0:
	set(value):
		frame = value
		_refresh()
#Off hides the status badge at this site.
@export var show_badge: bool = true:
	set(value):
		show_badge = value
		_apply_badge()

@onready var view: SubViewport = $View
@onready var character: CharacterSprite = $View/Character
@onready var camera: Camera2D = $View/Camera

var merc_uid: int = 0

var _badge: IconRect = null
var _badge_status: int = GuiTypes.MercStatus.AVAILABLE
var _badge_fraction: float = -1.0


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = Vector2(pixel_size, pixel_size)
	stretch_shrink = shrink_for(pixel_size, full_body)
	camera.position = Vector2.ZERO if full_body else HEAD_OFFSET
	if character != null:
		character.set_motion(0, frame)
	_rearm()
	_apply_badge()


func _rearm() -> void:
	if view != null:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_merc(merc_view: MercView) -> void:
	if merc_view == null:
		merc_uid = 0
		tooltip_text = ""
		_show_appearance(null)
		_badge_status = GuiTypes.MercStatus.AVAILABLE
		_badge_fraction = -1.0
		_apply_badge()
		return
	merc_uid = merc_view.uid
	tooltip_text = merc_view.name
	_badge_status = merc_view.status
	_badge_fraction = merc_view.status_fraction_left
	var app: CharacterAppearance = merc_view.appearance
	if app == null and merc_view.appearance_seed == 0:
		app = _roster_appearance(merc_view.uid)
	if app == null:
		app = _rolled(merc_view.uid, merc_view.appearance_seed)
	_show_appearance(app)
	_apply_badge()


#For a site that holds only a uid: sets the face, uid and tooltip and leaves the badge alone.
func show_uid(uid: int, display_name: String) -> void:
	merc_uid = uid
	tooltip_text = display_name
	if uid <= 0:
		_show_appearance(null)
		return
	var app: CharacterAppearance = _roster_appearance(uid)
	_show_appearance(app if app != null else _rolled(uid, 0))


func _roster_appearance(uid: int) -> CharacterAppearance:
	var live: MercView = GameState.view_by_uid(uid)
	return live.appearance if live != null else null


#A view without a seed (picker rows, uid-only sites) takes the roster merc's seed, else the uid.
func _seed_for(uid: int, appearance_seed: int) -> int:
	if appearance_seed != 0:
		return appearance_seed
	var live: MercView = GameState.view_by_uid(uid)
	return live.appearance_seed if live != null and live.appearance_seed != 0 else uid


#A roll with no stored appearance uses the roster merc's resolved pool, so it matches the generated look.
func _rolled(uid: int, appearance_seed: int) -> CharacterAppearance:
	var pool: ResolvedPool = AppearanceRules.resolve(GameState.merc_by_uid(uid))
	return CharacterAppearance.roll(_seed_for(uid, appearance_seed), true, pool)


func _show_appearance(app: CharacterAppearance) -> void:
	if character == null:
		character = get_node_or_null(^"View/Character") as CharacterSprite
	if character != null:
		character.set_appearance(app)
	_rearm()


func _apply_badge() -> void:
	if not is_node_ready():
		return
	var id: String = GuiTypes.badge_id(_badge_status)
	if not show_badge or id == "":
		if _badge != null:
			_badge.visible = false
		return
	if _badge == null:
		_badge = IconRect.new()
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badge.trimmed = true
		add_child(_badge)
	_badge.tint = GuiTypes.badge_color(_badge_status, _badge_fraction)
	var art: Vector2i = Icons.tex(id, true).get_size()
	_badge.set_id(id, maxi(1, int(pixel_size / float(maxi(art.x, art.y)))))
	_badge.size = _badge.custom_minimum_size
	_badge.position = ((Vector2(pixel_size, pixel_size) - _badge.size) / 2.0).floor()
	_badge.visible = true


#Test probe: the atlas id the badge shows, empty when it is hidden.
func badge_id() -> String:
	return _badge.icon_id if badge_shown() else ""


func badge_shown() -> bool:
	return _badge != null and _badge.visible


func badge_tint() -> Color:
	return _badge.tint if _badge != null else Color.WHITE


func badge_node() -> IconRect:
	return _badge


#Test probe: sets the idle (motion 0) frame the sprite shows.
func set_frame(f: int) -> void:
	frame = f


static func shrink_for(size_px: int, whole: bool = false) -> int:
	return maxi(1, int(size_px / float(FULL_SIZE if whole else CROP_SIZE)))
