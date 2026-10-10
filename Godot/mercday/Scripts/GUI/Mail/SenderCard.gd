class_name SenderCard extends TooltipPanel

#Hover card of a mail sender. A seat client shows its kind line, where it is and how far, and its opinion; a Mail
#Senders row shows its kind and where lines only. A merc shows level, status, vacation days left and Guild Opinion.
#A locked opinion reads "<Feature>: requires <what>": the plan's name below Enterprise or for a lock with no upgrade,
#else the upgrade that unlocks it. The card is a hover tooltip and holds no button.

const LEVEL_TEXT: String = "Level %d"
const LEFT_TEXT: String = "Vacation days left: %d"
const GUILD_TEXT: String = "Guild Opinion %+d"
const GUILD_NEUTRAL_TEXT: String = "Guild Opinion: Neutral"
const LOCK_TEXT: String = "%s: requires %s"
const UPGRADE_TEXT: String = "the %s upgrade"
const CLIENT_FEATURE: String = "Client Opinion"
const CLIENT_PLAN: String = SubscriptionManager.PLAN_NAMES[SubscriptionManager.Plan.ENTERPRISE]

@onready var opinion_label: Label = $Rows/Opinion
@onready var lock_label: Label = $Rows/Lock

var sender: Object = null


#Fills the card for a ClientData or a MercenaryData; anything else empties it.
func set_sender(who: Object) -> void:
	sender = who
	if who is MercenaryData:
		_show_merc(who as MercenaryData)
	elif who is ClientData:
		_show_client(who as ClientData)
	else:
		set_text("", "")
		opinion_label.visible = false
		lock_label.visible = false


#Every row the card shows, in order: the body lines, then the opinion or its lock text.
func row_texts() -> Array[String]:
	var out: Array[String] = []
	if body_label.visible:
		for line: String in body_label.text.split("\n"):
			out.append(line)
	for label: Label in [opinion_label, lock_label]:
		if label.visible:
			out.append(label.text)
	return out


func locked_text() -> String:
	return lock_label.text if lock_label.visible else ""


#What a lock row requires: the plan, or on Enterprise the named upgrade of a lock that has one.
static func lock_text(feature: String, plan: String, upgrade_id: String) -> String:
	if SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE and upgrade_id != "":
		return LOCK_TEXT % [feature, UPGRADE_TEXT % UpgradeDefs.display_name(upgrade_id)]
	return LOCK_TEXT % [feature, plan]


func _show_client(client: ClientData) -> void:
	if client.kind == MailSenders.MAIL_KIND:
		var lines: PackedStringArray = PackedStringArray([client.kind_line()])
		var where: String = client.location if client.km < 0 else client.where_text()
		if where != "":
			lines.append(where)
		set_text(client.name, "\n".join(lines))
		opinion_label.visible = false
		lock_label.visible = false
		return
	set_text(client.name, "\n".join(PackedStringArray([client.kind_line(), client.where_text()])))
	var open: bool = bool(SubscriptionManager.entitlements().get(ClientOverview.ENTITLEMENT, false))
	var value: int = clampi(client.relationship, ClientOverview.REL_MIN, ClientOverview.REL_MAX)
	var upgrade: String = String((MetricsLocks.METRIC_UPGRADES[ClientOverview.ENTITLEMENT] as Dictionary)["upgrade_id"])
	_set_opinion(open, ClientOverview.relationship_line(value), value, lock_text(CLIENT_FEATURE, CLIENT_PLAN, upgrade))


func _show_merc(merc: MercenaryData) -> void:
	var status: int = int(GameState.merc_status(merc)["status"])
	set_text(merc.merc_name, "\n".join(PackedStringArray([LEVEL_TEXT % ExperienceSystem.current_level(merc),
		GuiTypes.merc_status_text(status), LEFT_TEXT % BenefitsManager.vacation_days_left(merc.merc_uid)])))
	var key: String = MercLocks.K_GUILD_OPINION
	var open: bool = MercLocks.entitled(key, SubscriptionManager.entitlements())
	var value: int = clampi(merc.guild_opinion, ClientOverview.REL_MIN, ClientOverview.REL_MAX)
	var text: String = GUILD_TEXT % value if value != 0 else GUILD_NEUTRAL_TEXT
	_set_opinion(open, text, value, lock_text(MercLocks.feature_of(key), MercLocks.plan_of(key),
		MercLocks.upgrade_id_of(key)))


func _set_opinion(open: bool, text: String, value: int, locked: String) -> void:
	opinion_label.visible = open
	lock_label.visible = not open
	opinion_label.text = text
	opinion_label.add_theme_color_override(&"font_color", MoodFace.GUILD_COLORS[value - ClientOverview.REL_MIN])
	lock_label.text = locked
