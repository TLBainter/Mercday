class_name ViewerPopup extends SubWindow

#Modal host for one viewer scene over another: a SubWindow with its own frame and backdrop looks, no
#scanline and a clipped holder. The static helpers open the wave 3 popup targets and skip silently
#when the target is missing.

const SCENE_PATH: String = "res://Scenes/GUI/Shared/ViewerPopup.tscn"
const FINANCE_PATH: String = "res://Scenes/GUI/Finance/FinanceViewer.tscn"

const CONTRACT_WIDTH: float = 940.0
const FINANCE_WIDTH: float = 1280.0

const CONTRACT: Dictionary = {"width": CONTRACT_WIDTH}
#A settled contract shows little, so its popup takes the height of what it shows.
const COMPLETED: Dictionary = {"width": CONTRACT_WIDTH, "fit": true}
const INVEST: Dictionary = {"width": FINANCE_WIDTH}
const HIRING: Dictionary = {"width": FINANCE_WIDTH}
const MERC: Dictionary = {"width": 988.0}


func frame_size() -> Vector2:
	return content_size()


#Instantiates ViewerPopup.tscn on host, sized to preset, and opens path behind an existence
#check; null when the scene is missing so a caller can fall back to the existing placeholder.
#A preset with "fit" set fits the popup height to the content.
static func show_scene(host: Node, path: String, preset: Dictionary,
		setup: Callable = Callable()) -> ViewerPopup:
	if not ResourceLoader.exists(path):
		return null
	var popup_scene: PackedScene = load(SCENE_PATH)
	var popup: ViewerPopup = popup_scene.instantiate()
	popup.content_width = float(preset.get("width", 1280.0))
	popup.free_on_close = true
	host.add_child(popup)
	popup.open(load(path), setup)
	if bool(preset.get("fit", false)):
		popup.fit_to_content()
	return popup


static func show_contract(host: Node, entry_id: int) -> ViewerPopup:
	var setup := func(node: Node) -> void:
		if "hide_list" in node:
			node.hide_list = true
	var settled: bool = GameState.result_of(entry_id) != null and not GameState.is_unclaimed(entry_id)
	var popup: ViewerPopup = show_scene(host, "res://Scenes/GUI/Contracts/ContractViewer.tscn",
		COMPLETED if settled else CONTRACT, setup)
	if popup == null:
		return null
	var content: Node = popup.current()
	if content != null and content.has_method("select_entry"):
		content.call("select_entry", entry_id)
	return popup


static func show_applicant(host: Node, applicant: ApplicantData) -> ViewerPopup:
	var setup := func(node: Node) -> void:
		if "hide_roster" in node:
			node.hide_roster = true
	var popup: ViewerPopup = show_scene(host, "res://Scenes/GUI/Mercs/MercViewer.tscn", MERC, setup)
	if popup == null:
		return null
	var content: Node = popup.current()
	if content != null and content.has_method("show_applicant"):
		content.call("show_applicant", applicant)
	return popup


static func show_invest(host: Node, company_id: int) -> ViewerPopup:
	var setup := func(node: Node) -> void:
		if "invest_only" in node:
			node.invest_only = true
	var popup: ViewerPopup = show_scene(host, FINANCE_PATH, INVEST, setup)
	if popup == null:
		return null
	var content: Node = popup.current()
	if content != null and content.has_method("open_stock"):
		content.call("open_stock", company_id)
	return popup


#The View Applicants window: the Finance window on its Hiring page alone, held to one campaign.
static func show_hiring(host: Node, campaign_id: int) -> ViewerPopup:
	var setup := func(node: Node) -> void:
		if "hiring_only" in node:
			node.hiring_only = true
		if "fixed_campaign" in node:
			node.fixed_campaign = campaign_id
	return show_scene(host, FINANCE_PATH, HIRING, setup)
