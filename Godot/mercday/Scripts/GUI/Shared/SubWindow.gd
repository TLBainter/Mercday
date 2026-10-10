class_name SubWindow extends GuiModal

#Modal overlay: dims the screen, frames a 1:1 canvas and swaps in one content scene. The canvas is
#content_width wide and content_height() tall: the content's own height after fit_to_content(), else
#frame_h when it is set, else the band above the bottom bar capped at 720. Every SubWindow is
#top_level, so one nested inside another still lays out at full screen scale. The bottom bar stays
#bright and clickable under the window.

#Width of the orange border drawn inside the canvas edge, over the content and under the close X.
const BORDER := 4.0
const CONTENT_WIDTH := 1280.0
const FRAME_H_DEFAULT := 720.0
const CLOSE_INSET := 10.0
#Width kept empty at the right of a window's top row so no tab sits under the close X.
const CLOSE_RESERVE := 56.0
#Shortest canvas a fitted window shrinks to, so a near empty content still reads as a window.
const FIT_MIN_H := 320.0

@export var frame_h: float = 0.0
@export var content_width: float = CONTENT_WIDTH
#A null style keeps the theme look of that panel.
@export var frame_style: StyleBox
@export var backdrop_style: StyleBox
@export var show_scanline: bool = true

@onready var frame: Panel = $Frame
@onready var holder: Control = $Holder
@onready var border: Panel = $Border
@onready var close_x: Button = $CloseX
@onready var scanline: ScanlineOverlay = $Scanline

var _content: Node = null
var _fitted: bool = false


func _ready() -> void:
	super()
	position = Vector2.ZERO
	if frame_style != null:
		frame.add_theme_stylebox_override(&"panel", frame_style)
	if backdrop_style != null:
		backdrop.add_theme_stylebox_override(&"panel", backdrop_style)
	scanline.visible = show_scanline
	CloseX.style(close_x, CloseX.SCALE_WINDOW)
	close_x.pressed.connect(close)
	_layout()


#A fitted window takes its content's minimum height, never under FIT_MIN_H and never over the band;
#otherwise the band decides the height when no caller pinned one.
func content_height() -> float:
	var box: Control = _content as Control
	if _fitted and box != null:
		return minf(maxf(box.get_combined_minimum_size().y + 2.0 * BORDER, FIT_MIN_H), band_cap())
	if frame_h > 0.0:
		return frame_h
	return band_cap()


#The band above the bottom bar capped at 720; a window off the tree has no viewport to ask, so it
#reports the full 720 canvas.
func band_cap() -> float:
	if not is_inside_tree():
		return FRAME_H_DEFAULT
	var band: float = GuiFrameStack.band_height(get_viewport().get_visible_rect().size.y)
	return minf(FRAME_H_DEFAULT, band)


func content_size() -> Vector2:
	return Vector2(content_width, content_height())


#The root and the backdrop cover the viewport through their full rect anchors, so nothing here
#writes size on them: that write is what the engine warns about when it lands after _ready.
func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var reserve: float = GuiFrameStack.bottom_reserve
	backdrop.offset_bottom = -reserve
	scanline.offset_bottom = -reserve
	var band: float = GuiFrameStack.band_height(view_size.y)
	var box: Vector2 = content_size()
	holder.scale = Vector2.ONE
	holder.pivot_offset = Vector2.ZERO
	holder.size = box
	holder.position = Vector2(floorf(maxf(0.0, (view_size.x - box.x) / 2.0)),
		floorf(maxf(0.0, (band - box.y) / 2.0)))
	frame.position = holder.position
	frame.size = holder.size
	border.position = holder.position
	border.size = holder.size
	close_x.size = CloseX.size(CloseX.SCALE_WINDOW)
	var art: float = float(CloseX.ART * CloseX.SCALE_WINDOW)
	var outline: float = float(CloseX.SCALE_WINDOW)
	close_x.position = holder.position + Vector2(box.x - CLOSE_INSET - art - outline,
		CLOSE_INSET - outline)


#Laid out at open time, since the bottom reserve is not known yet at _ready for a persistent window like the HUD's Popup.
func open(scene: PackedScene, setup: Callable = Callable(), width: float = 0.0) -> Node:
	_free_content()
	if scene == null:
		return null
	if width > 0.0:
		content_width = width
	_layout()
	var instance: Node = scene.instantiate()
	if setup.is_valid():
		setup.call(instance)
	holder.add_child(instance)
	if instance is Control:
		(instance as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
	_content = instance
	present()
	return instance


func current() -> Node:
	return _content


#Sizes the canvas to the open content and follows its minimum height while it stays open; the next
#open or close lets the window go back to frame_h or the band.
func fit_to_content() -> void:
	var box: Control = _content as Control
	if box == null:
		return
	_fitted = true
	if not box.minimum_size_changed.is_connected(_on_content_minimum_changed):
		box.minimum_size_changed.connect(_on_content_minimum_changed)
	_layout()


func is_fitted() -> bool:
	return _fitted


func _on_content_minimum_changed() -> void:
	if _fitted and is_inside_tree():
		_layout()


func close() -> void:
	_free_content()
	super()


func _free_content() -> void:
	var box: Control = _content as Control
	if box != null and box.minimum_size_changed.is_connected(_on_content_minimum_changed):
		box.minimum_size_changed.disconnect(_on_content_minimum_changed)
	_fitted = false
	if _content != null:
		_content.queue_free()
		_content = null


#Builds a one-off placeholder scene in memory; no file is needed for a single DescriptionLabel.
static func placeholder(text: String) -> PackedScene:
	var root_node := Control.new()
	root_node.name = "Placeholder"
	root_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label_node := Label.new()
	label_node.name = "DescriptionLabel"
	label_node.theme_type_variation = &"DescriptionLabel"
	label_node.text = text
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_node.add_child(label_node)
	label_node.owner = root_node
	var packed := PackedScene.new()
	packed.pack(root_node)
	root_node.queue_free()
	return packed
