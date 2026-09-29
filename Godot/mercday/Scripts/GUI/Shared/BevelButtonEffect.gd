class_name BevelButtonEffect extends Node

#The effect hook of a BevelButton. The button instances the script named by its effect export
#once, keeps it as a child and calls attach(button) when it is ready; draw(button) runs at the
#end of every paint of that button, so a subclass paints over the finished face. Both are empty
#here and a subclass fills in what it needs.


func attach(_button: BevelButton) -> void:
	pass


func draw(_button: BevelButton) -> void:
	pass
