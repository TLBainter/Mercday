class_name SfxConfig extends Resource

#Which SoundLibrary each cue plays and the buses the cues play on. UiSfx and GameSfx share the one
#instance saved as res://Resources/Audio/sfx_config.tres; a null library leaves its cue silent.

@export var ui_bus: StringName = &"UI"
@export var event_bus: StringName = &"Sound Effects"
@export_group("UX")
@export var click: SoundLibrary
@export var big_button_click: SoundLibrary
@export var upgrade_click: SoundLibrary
@export var slider: SoundLibrary
@export var summon_window: SoundLibrary
@export var dismiss_window: SoundLibrary
@export var equip: SoundLibrary
@export var unequip: SoundLibrary
@export var hover: SoundLibrary
#The hover of a disabled control; null keeps disabled controls silent until the designer supplies files.
@export var hover_disabled: SoundLibrary = null
#A press on a disabled control; null falls back to the reject cue.
@export var click_disabled: SoundLibrary = null
#The MercDave marker and the hint card buttons.
@export var mercdave_click: SoundLibrary
@export var mercdave_hover: SoundLibrary
@export_group("Events")
@export var captured: SoundLibrary
@export var contract_failure: SoundLibrary
@export var contract_success: SoundLibrary
@export var dead: SoundLibrary
@export var graph_draw: SoundLibrary
@export var alert_bad: SoundLibrary
@export var message_basic: SoundLibrary
@export var alert_neutral: SoundLibrary
@export var alert_positive: SoundLibrary
@export var money: SoundLibrary
@export var new_contract: SoundLibrary
@export var permit: SoundLibrary
@export var reject: SoundLibrary
#MercDave showing new text.
@export var mercdave_text: SoundLibrary
@export_group("Dispatch")
@export var dispatch_foot: SoundLibrary
@export var dispatch_caravan: SoundLibrary
@export var dispatch_horse: SoundLibrary
@export var dispatch_train: SoundLibrary
@export var dispatch_airship: SoundLibrary
@export var dispatch_teleport: SoundLibrary


#The library of a GuiTypes.TRAVEL_MODES key; a key with no library of its own plays dispatch_foot.
func dispatch_library(travel_key: String) -> SoundLibrary:
	var found: Variant = get("dispatch_" + travel_key)
	if found is SoundLibrary:
		return found
	return dispatch_foot
