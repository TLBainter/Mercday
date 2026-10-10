@tool
class_name PixelAtlasRectEditor extends VBoxContainer

#Bottom panel to edit atlas rects. Every edit is one undo action; commit writes the JSON.

signal atlas_changed

var undo: Object
var _own_undo: bool = false
var _atlas: PixelAtlas
var _list: ItemList
var _view: PixelAtlasRectView
var _zoom: int = 3


func _init() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	add_child(bar)
	for spec: Array in [["Revert", _revert], ["Save", commit]]:
		var b: Button = Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		bar.add_child(b)
	var body: HSplitContainer = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_list = ItemList.new()
	_list.custom_minimum_size.x = 200
	_list.item_selected.connect(_on_item)
	body.add_child(_list)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	_view = PixelAtlasRectView.new()
	_view.rect_requested.connect(_on_rect)
	_view.split_requested.connect(_on_split)
	sc.add_child(_view)


func edit(atlas: PixelAtlas) -> void:
	_atlas = atlas
	if undo != null and undo.has_signal("version_changed") and not undo.is_connected("version_changed", _refresh):
		undo.connect("version_changed", _refresh)
	_refresh()


func apply_rect(ur: Object, id: StringName, r: Rect2i) -> void:
	var e: PixelAtlasEntry = _atlas.entry(id) if _atlas != null else null
	if e == null:
		return
	var local: Rect2i = r
	if e.parent != &"":
		local = Rect2i(r.position - _atlas.rect_of(e.parent).position, r.size)
	ur.create_action("Edit atlas rect " + id)
	_add(ur, false, self, &"_set_rect", [id, local, true])
	_add(ur, true, self, &"_set_rect", [id, e.rect, e.edited])
	ur.commit_action()


func split(ur: Object, id: StringName, at: int, vertical: bool) -> void:
	var e: PixelAtlasEntry = _atlas.entry(id) if _atlas != null else null
	if e == null or at <= 0 or at >= (e.rect.size.x if vertical else e.rect.size.y):
		return
	var n: int = 1
	while _atlas.entries.has(StringName("%s_s%d" % [id, n])):
		n += 1
	ur.create_action("Split atlas rect " + id)
	_add(ur, false, _atlas, &"split", [id, at, vertical])
	_add(ur, true, _atlas, &"remove_entry", [StringName("%s_s%d" % [id, n])])
	_add(ur, true, self, &"_set_rect", [id, e.rect, e.edited])
	ur.commit_action()
	_refresh()


func commit() -> void:
	if _atlas == null:
		return
	var err: Error = _atlas.save_rects()
	if err != OK:
		push_error("PixelAtlasRectEditor: save failed (%s)" % error_string(err))


func _ur() -> Object:
	if undo == null:
		undo = UndoRedo.new()
		_own_undo = true
	return undo


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _own_undo and undo is UndoRedo:
		(undo as UndoRedo).free()


#UndoRedo takes a Callable; EditorUndoRedoManager takes the object, method name and arguments.
func _add(ur: Object, undo_side: bool, target: Object, method: StringName, args: Array) -> void:
	if ur is UndoRedo:
		var c: Callable = Callable(target, method).bindv(args)
		if undo_side:
			(ur as UndoRedo).add_undo_method(c)
		else:
			(ur as UndoRedo).add_do_method(c)
	else:
		ur.callv(&"add_undo_method" if undo_side else &"add_do_method", [target, method] + args)


func _set_rect(id: StringName, r: Rect2i, edited: bool) -> void:
	var e: PixelAtlasEntry = _atlas.entry(id) if _atlas != null else null
	if e == null:
		return
	e.rect = r
	e.edited = edited
	_refresh()


func _on_rect(id: StringName, r: Rect2i) -> void:
	apply_rect(_ur(), id, r)


func _on_split(id: StringName, at: int, vertical: bool) -> void:
	split(_ur(), id, at, vertical)


func _on_item(i: int) -> void:
	_view.select(_list.get_item_metadata(i))


func _revert() -> void:
	if _atlas != null:
		_atlas.reload()
		_refresh()
		atlas_changed.emit()


func _refresh() -> void:
	if _atlas == null:
		return
	_list.clear()
	for id: StringName in _atlas.entries:
		var e: PixelAtlasEntry = _atlas.entries[id]
		_list.set_item_metadata(_list.add_item(String(id) + (" *" if e.edited else "")), id)
	_view.show_atlas(_atlas, _zoom)
