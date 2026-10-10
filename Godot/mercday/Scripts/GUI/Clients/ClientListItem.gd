class_name ClientListItem
extends ListRow

#One row of the client list: a hatched portrait stand-in, the name and sub type, and how many
#contracts this client has had the guild accept.

var client: ClientData = null

@onready var name_label: Label = $Row/Names/ClientName
@onready var sub_label: Label = $Row/Names/Sub
@onready var count_label: Label = $Row/Right/Count


func _ready() -> void:
	super()
	focus_mode = Control.FOCUS_NONE
	_render()


func set_client(row: ClientData) -> void:
	client = row
	if is_node_ready():
		_render()


func client_key() -> String:
	if client == null:
		return ""
	return client.key()


func name_text() -> String:
	return name_label.text


func sub_text() -> String:
	return sub_label.text


func count_text() -> String:
	return count_label.text


#The lower band of the frame: orange while the row is selected, ink while idle.
func edge_color() -> Color:
	return lo


func _render() -> void:
	if client == null:
		name_label.text = ""
		sub_label.text = ""
		count_label.text = "0"
		tooltip_text = ""
		return
	name_label.text = client.name
	sub_label.text = client.sub
	count_label.text = "%d" % client.accepted
	tooltip_text = client.where_text()
