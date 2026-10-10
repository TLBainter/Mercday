class_name FinanceStubPage
extends Control

#A stand in page for the Finance host tests: it records what the shell asks of it and draws nothing.
#The tests point each page path here, so none of the four real pages is loaded.

var hide_roster: bool = false
var shown: int = 0
var offer_id: int = -1
var stock_id: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func page_shown() -> void:
	shown += 1


func open_offer(id: int) -> void:
	offer_id = id


func open_stock(id: int) -> void:
	stock_id = id
