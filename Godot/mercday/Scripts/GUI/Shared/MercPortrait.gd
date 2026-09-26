class_name MercPortrait extends SubViewportContainer

#Renders characterScene.tscn into a small SubViewport for a merc portrait icon. Every merc uses
#the Archer art for now (Q22 layers are swappable; per-merc art is a to-do); set_merc only stores
#the uid and the tooltip name.

const LAYERS: Array[String] = ["Backpack", "HairBack", "Cape", "Body", "Weapon", "OverCape",
	"Eyes", "HairFront", "Headwear", "Headwear Add-On"]
const FRAME_SIZE: int = 48

@export var pixel_size: int = 48:
	set(value):
		pixel_size = value
		_refresh()
@export var frame: int = 0:
	set(value):
		frame = value
		_refresh()

@onready var view: SubViewport = $View
@onready var display: Node2D = $"View/Character/Character Display"

var merc_uid: int = 0


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = Vector2(pixel_size, pixel_size)
	stretch_shrink = maxi(1, int(pixel_size / float(FRAME_SIZE)))
	for layer_name: String in LAYERS:
		var sprite: Sprite2D = layer(layer_name)
		if sprite != null:
			sprite.frame = frame
	_rearm()


func _rearm() -> void:
	if view != null:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_merc(merc_view: MercView) -> void:
	if merc_view == null:
		merc_uid = 0
		tooltip_text = ""
		return
	merc_uid = merc_view.uid
	tooltip_text = merc_view.name


func set_frame(f: int) -> void:
	frame = f


func set_layer_texture(layer_name: String, tex: Texture2D) -> void:
	var sprite: Sprite2D = layer(layer_name)
	if sprite == null:
		return
	sprite.texture = tex
	sprite.visible = true
	_rearm()


func clear_layer(layer_name: String) -> void:
	var sprite: Sprite2D = layer(layer_name)
	if sprite != null:
		sprite.visible = false
	_rearm()


func layer(layer_name: String) -> Sprite2D:
	if display == null:
		return null
	return display.get_node_or_null(NodePath(layer_name)) as Sprite2D


static func layers() -> Array[String]:
	return LAYERS


static func shrink_for(size_px: int) -> int:
	return maxi(1, int(size_px / float(FRAME_SIZE)))
