class_name MetricsTab extends PanelContainer

#The Metrics tab embeds the Metrics Viewer at runtime and never preloads it. When the scene is
#absent the slot shows the placeholder instead.

const METRICS_SCENE: String = "res://Scenes/GUI/Metrics/MetricsViewer.tscn"
const PLACEHOLDER_TEXT: String = "Metrics viewer not available"
const EMBED_SIZE: Vector2 = Vector2(680, 596)
const PREVIEW_DAYS: int = 462
const PREVIEW_MIN_DAYS: int = 30

static var _preview_uids: Array[int] = []

@onready var holder: Control = $Holder

var merc_uid: int = 0

var _embed: Control = null


func _ready() -> void:
	holder.custom_minimum_size = EMBED_SIZE
	_build()


func set_view(new_view: MercView) -> void:
	set_uid(new_view.uid if new_view != null else 0)


func set_uid(uid: int) -> void:
	if uid == merc_uid and _embed != null:
		return
	merc_uid = uid
	_build()


func embed() -> Control:
	return _embed


func is_placeholder() -> bool:
	return _embed != null and not _embed.has_method("lock_to_merc")


func seeded_preview() -> bool:
	return MetricsHistory.using_preview() and not _preview_uids.is_empty()


func _build() -> void:
	if not is_node_ready():
		return
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	_seed_preview()
	_embed = _make_embed()
	holder.add_child(_embed)
	_embed.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _embed.has_method("lock_to_merc"):
		_embed.call("lock_to_merc", merc_uid)


#A campaign with almost no recorded days shows an empty chart, so the tab fills the preview store
#with manufactured history keyed to the live roster. It stays on for the rest of the session.
func _seed_preview() -> void:
	if merc_uid <= 0:
		return
	var uids: Array[int] = _roster_uids()
	if uids.is_empty():
		return
	if MetricsHistory.using_preview():
		if _preview_uids == uids:
			return
	elif MetricsHistory.days() >= PREVIEW_MIN_DAYS:
		return
	MetricsHistory.seed_preview(PREVIEW_DAYS, uids)
	_preview_uids = uids.duplicate()


static func _roster_uids() -> Array[int]:
	var out: Array[int] = []
	for row: MercView in GameState.roster:
		if row != null:
			out.append(row.uid)
	return out


func _make_embed() -> Control:
	if ResourceLoader.exists(METRICS_SCENE):
		var scene: PackedScene = load(METRICS_SCENE)
		if scene != null:
			var view: Node = scene.instantiate()
			if view is Control and view.has_method("lock_to_merc"):
				return view as Control
			view.queue_free()
	var label := Label.new()
	label.name = "Placeholder"
	label.text = PLACEHOLDER_TEXT
	label.theme_type_variation = &"DescriptionLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
