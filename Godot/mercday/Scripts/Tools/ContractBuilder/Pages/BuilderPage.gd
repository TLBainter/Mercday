@tool
class_name BuilderPage extends Control

#One page of the Contract Builder. The shell enables Next while is_complete() is true, calls load_draft
#when the page shows and store_draft when it leaves, and autosaves when the page calls notify_changed after an edit.

signal changed

var page_title: String = ""
var summary: String = ""
var body: VBoxContainer = null


func _ready() -> void:
	body = VBoxContainer.new()
	body.name = "Body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_theme_constant_override(&"separation", 8)
	add_child(body)
	body.add_child(_label(page_title, &"HeadingLabel"))
	var line: Label = _label(summary, &"DescriptionLabel")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(line)
	_build()


#Subclasses add their controls to body here.
func _build() -> void:
	pass


func is_complete() -> bool:
	return true


func load_draft(_draft: ContractDraft) -> void:
	pass


func store_draft(_draft: ContractDraft) -> void:
	pass


func notify_changed() -> void:
	changed.emit()


static func _label(text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
