class_name FinancePage
extends Control

#One page of the My Finance window. Its modals hang from the modal layer of the viewer, and a change
#that lands while the page is hidden only marks it dirty until the page shows again.

var _dirty: bool = false


#The node every modal of this page is parented to.
func modal_host() -> Control:
	return FinanceViewer.modal_host_for(self)


func is_dirty() -> bool:
	return _dirty


#A page on screen redraws at once; a hidden one waits for page_shown or its next show.
func mark_dirty() -> void:
	if is_node_ready() and is_visible_in_tree():
		_refresh()
	else:
		_dirty = true


#The viewer calls this each time the page becomes the shown one.
func page_shown() -> void:
	if _dirty:
		_refresh()


#Writes the whole page. A page overrides it and clears _dirty there.
func _refresh() -> void:
	_dirty = false


#A page that catches up whenever it shows connects visibility_changed here in its _ready.
func _on_visibility_changed() -> void:
	if _dirty and is_node_ready() and is_visible_in_tree():
		_refresh()
