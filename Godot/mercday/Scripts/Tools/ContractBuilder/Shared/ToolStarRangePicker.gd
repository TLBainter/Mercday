@tool
class_name ToolStarRangePicker extends StarRangePicker

#StarRangePicker for editor tools. The editor has no UiSfx autoload and MinLock and MaxLock keep placeholder
#FeatureLocks there, so the editor path skips the hover sound and the lock signal; row_locks stays empty.
#Edit ToolStarRangePicker.tscn as text and never save it from the scene editor: that save writes runtime state into it.


func _init() -> void:
	ToolIcons.prime()


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		super()


func _ready() -> void:
	if not Engine.is_editor_hint():
		super()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(_stars_x(ROW_MAX) + _stars_width(), maxf(_star_px(), LOCK_H))
	min_lock.hide()
	max_lock.hide()
	refresh()


func _track_pointer(pos: Vector2) -> void:
	if not Engine.is_editor_hint():
		super(pos)
		return
	var hit: Vector2 = _hit(pos)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hit.x >= 0.0 else Control.CURSOR_ARROW
	if hit.x < 0.0:
		_hover_star = NO_STAR
		return
	_hover_star = Vector2i(int(hit.x), ceili(hit.y))
