class_name KitStub extends Control

#Stub content scene the GUI KIT suite opens through ViewerPopup, mirroring a wave 3 viewer's
#guarded members (hide_list, select_entry) so ViewerPopup's guard pattern has something real to hit.

var opened_with: int = -1
var hide_list: bool = false


func select_entry(entry_id: int) -> void:
	opened_with = entry_id
