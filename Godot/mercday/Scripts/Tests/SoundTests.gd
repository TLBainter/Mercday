class_name SoundTests

#The sound layer: the bus layout, the cue libraries, the AudioManager pool and frame queue, the UiSfx
#button hooks and pitch ramp, and the GameSfx event cues. Run with the sound-tests harness flag.

const SFX_RATE: int = 44100
const UI_BUS: String = "UI"
const EVENT_BUS: String = "Sound Effects"
const LIBRARY_DIR: String = "res://Resources/Audio/Libraries/"
const GRID_BUTTON_SCENE: String = "res://Scenes/GUI/Shared/GridMenuButton.tscn"
const BEVEL_SCENE: String = "res://Scenes/GUI/Shared/BevelButton.tscn"
const SUBWINDOW_SCENE: String = "res://Scenes/GUI/Shared/SubWindow.tscn"
const TIER_SCENE: String = "res://Scenes/GUI/Subscription/UpgradeTierDialog.tscn"
#A tier dialog hold slice a little over 1 / HOLD_RATE seconds, so each slice steps exactly once.
const TIER_SLICE: float = 0.17
const CHART_SCENE: String = "res://Scenes/GUI/Metrics/LineChart.tscn"
const MODULE_SCENE: String = "res://Scenes/GUI/Subscription/CustomizeBlock.tscn"
#Custom clickable controls that opt in to the UiSfx hook through a no-arg pressed signal.
const HOOK_SCENES: Array[String] = [
	"res://Scenes/GUI/Contracts/TeamSlot.tscn",
	"res://Scenes/GUI/Shared/StarRangePicker.tscn",
	"res://Scenes/GUI/Notifications/NotificationBell.tscn",
	"res://Scenes/GUI/Subscription/SkillTree.tscn",
]
const STEPPER_SCENE: String = "res://Scenes/GUI/Shared/QuantityStepper.tscn"
const PAYROLL_STEPPER_SCENE: String = "res://Scenes/GUI/Finance/Payroll/PayrollStepper.tscn"
const CHECKOUT_SCENE: String = "res://Scenes/GUI/Bazaar/CheckoutDialog.tscn"
const STREAM_TOTAL: int = 95
#Roster sizes the dispatch cases hire up to: five mercs for five slots and a sixth to press over a full team.
const SLOT_ROSTER: int = 5
const REFUSAL_ROSTER: int = 6
#Library name to the number of wav files the inventory gives it.
const LIBRARY_COUNTS: Dictionary = {
	"click": 6, "big_button_click": 5, "upgrade_click": 2, "slider": 1, "summon_window": 2,
	"dismiss_window": 1, "equip": 4, "unequip": 5, "hover": 4, "captured": 2, "contract_failure": 1,
	"contract_success": 1, "dead": 2, "dispatch_foot": 3, "graph_draw": 6, "alert_bad": 1,
	"message_basic": 1, "alert_neutral": 1, "alert_positive": 1, "money": 12, "new_contract": 2,
	"permit": 1, "reject": 3, "hover_disabled": 1, "click_disabled": 1,
	"dispatch_caravan": 5, "dispatch_train": 4, "dispatch_airship": 6, "dispatch_teleport": 3,
	"mercdave_click": 3, "mercdave_hover": 4, "mercdave_text": 1,
}


#Every AudioManager play heard since the last clear(), with the volume each one played at.
class PlayLog extends RefCounted:
	var streams: Array[AudioStream] = []
	var buses: Array[String] = []
	var pitches: Array[float] = []
	var volumes: Array[float] = []

	func record(stream: AudioStream, bus: String, pitch: float) -> void:
		streams.append(stream)
		buses.append(bus)
		pitches.append(pitch)
		volumes.append(AudioManager.last_volume_db)

	func clear() -> void:
		streams.clear()
		buses.clear()
		pitches.clear()
		volumes.clear()

	func size() -> int:
		return streams.size()

	func hits(library: SoundLibrary) -> int:
		var out: int = 0
		for stream: AudioStream in streams:
			if library != null and library.sounds.has(stream):
				out += 1
		return out

	#The volume of the first play drawn from library, or -INF when none was heard.
	func volume_of(library: SoundLibrary) -> float:
		for i: int in streams.size():
			if library != null and library.sounds.has(streams[i]):
				return volumes[i]
		return -INF

	#Exactly one play was heard, drawn from library, on bus.
	func only(library: SoundLibrary, bus: String) -> bool:
		return streams.size() == 1 and hits(library) == 1 and buses[0] == bus

	func pitch_is(want: float) -> bool:
		return not pitches.is_empty() and is_equal_approx(pitches[pitches.size() - 1], want)

	func text() -> String:
		var parts: PackedStringArray = PackedStringArray()
		for i: int in streams.size():
			parts.append("%s on %s at %.3f" % [streams[i].resource_path.get_file(), buses[i], pitches[i]])
		return "nothing" if parts.is_empty() else ", ".join(parts)


#A plain Button carrying the click_sfx and hover_sfx properties UiSfx reads.
class SfxProbe extends Button:
	var click_sfx: SoundLibrary = null
	var hover_sfx: SoundLibrary = null


#A plain Control that opts in to the UiSfx hook with a no-arg pressed and a no-arg sfx_hovered.
class HookProbe extends Control:
	signal pressed
	signal sfx_hovered

	func press() -> void:
		pressed.emit()

	func hover() -> void:
		sfx_hovered.emit()


#A Control whose pressed carries an argument, which keeps it out of the UiSfx hook.
class ArgProbe extends Control:
	signal pressed(value: int)

	func press(value: int) -> void:
		pressed.emit(value)


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var heard := PlayLog.new()
	AudioManager.played.connect(heard.record)
	_fresh()
	await _drain(host, heard)
	_case_buses(res, host, heard)
	_case_config(res, host, heard)
	_case_sample_rate(res, host, heard)
	_case_manager(res, host, heard)
	await _case_queue(res, host, heard)
	await _case_default_click(res, host, heard)
	await _case_big_button(res, host, heard)
	await _case_overrides(res, host, heard)
	await _case_hover_gate(res, host, heard)
	await _case_hover_replay(res, host, heard)
	await _case_notice_replay(res, host, heard)
	await _case_hover_cue(res, host, heard)
	await _case_generic_hook(res, host, heard)
	await _case_disabled_press(res, host, heard)
	await _case_disabled_push(res, host, heard)
	await _case_hover_pitch(res, host, heard)
	_case_hover_set(res, host, heard)
	await _case_disabled_hover(res, host, heard)
	await _case_step_reject(res, host, heard)
	await _case_custom_hooks(res, host, heard)
	await _case_star_hover(res, host, heard)
	await _case_block_reject(res, host, heard)
	await _case_pitch(res, host, heard)
	await _case_upgrade_dialog(res, host, heard)
	await _case_stepper_steps(res, host, heard)
	await _case_payroll_steps(res, host, heard)
	await _case_tier_hold(res, host, heard)
	await _case_summon_dismiss(res, host, heard)
	await _case_dispatched(res, host, heard)
	await _case_results(res, host, heard)
	await _case_notices(res, host, heard)
	await _case_events(res, host, heard)
	await _case_graph(res, host, heard)
	await _case_money_gate(res, host, heard)
	await _case_money_stack(res, host, heard)
	await _case_volume_queue(res, host, heard)
	await _case_alerted(res, host, heard)
	await _case_positive(res, host, heard)
	await _case_slot_equip(res, host, heard)
	await _case_dispatch_refusals(res, host, heard)
	await _case_hire_reject(res, host, heard)
	await _case_checkout_reject(res, host, heard)
	await _case_hire_confirm_reject(res, host, heard)
	await _case_payoff_reject(res, host, heard)
	await _case_launch_reject(res, host, heard)
	await _case_plan_switch_reject(res, host, heard)
	await _case_loan_accept_reject(res, host, heard)
	await _case_trade_reject(res, host, heard)
	await _case_dispatch_fade(res, host, heard)
	await _case_notice_level(res, host, heard)
	await _case_notice_order(res, host, heard)
	await _case_fly_cue(res, host, heard)
	await _case_graph_scrub(res, host, heard)
	await _case_chart_scrub(res, host, heard)
	AudioManager.stop_all()
	AudioManager.played.disconnect(heard.record)
	return TestFixtures.summarize(res, "SOUND")


#A paused new campaign, so no clock tick moves money or posts contracts while a case listens.
static func _fresh() -> void:
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()


#A reset files no offer, so the loan suite's four fixture offers are filed the way a landed offer is.
static func _lay_offers() -> void:
	var now: int = CampaignClock.now()
	for source: Dictionary in GuiLoanTests.FIXTURE_OFFERS:
		FinanceManager.offers.append(FinanceManager._make_offer(int(source["id"]), source,
			now + int(source["hours"]) * CampaignClock.MINUTES_PER_HOUR))
	FinanceManager.offers_changed.emit()


#Lets every queued cue flush, then forgets what was heard.
static func _drain(host: Node, heard: PlayLog) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	heard.clear()


#Waits out the hover window so the pointer counts as still.
static func _stale_pointer(host: Node) -> void:
	for _i: int in UiSfx.HOVER_FRAMES + 2:
		await host.get_tree().process_frame


static func _name_of(library: SoundLibrary) -> String:
	if library == null:
		return "null"
	for key: String in LIBRARY_COUNTS:
		if UiSfx.config.get(key) == library:
			return key
	return library.resource_path.get_file()


static func _names(list: Array[SoundLibrary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for library: SoundLibrary in list:
		parts.append(_name_of(library))
	return "[" + ", ".join(parts) + "]"


#Plays heard from library on bus.
static func _heard_from(heard: PlayLog, library: SoundLibrary, bus: String) -> int:
	var out: int = 0
	for i: int in heard.size():
		if library != null and library.sounds.has(heard.streams[i]) and heard.buses[i] == bus:
			out += 1
	return out


#The pitches heard from library, in play order.
static func _heard_pitches(heard: PlayLog, library: SoundLibrary) -> Array[float]:
	var out: Array[float] = []
	for i: int in heard.size():
		if library != null and library.sounds.has(heard.streams[i]):
			out.append(heard.pitches[i])
	return out


static func _player_text(player: AudioStreamPlayer) -> String:
	if player == null:
		return "no player"
	return "bus %s, pitch %.3f, playing %s" % [player.bus, player.pitch_scale, player.playing]


static func _send_of(index: int) -> String:
	return String(AudioServer.get_bus_send(index)) if index >= 0 else "missing"


static func _result(failed: bool, fates: Array[int]) -> ContractResultData:
	var result := ContractResultData.new()
	result.failed = failed
	for fate: int in fates:
		var member := ResultMemberData.new()
		member.fate = fate
		result.members.append(member)
	return result


static func _notice(type: StringName, urgency: int, snap: Dictionary = {}) -> NotificationData:
	var row := NotificationData.new()
	row.type = type
	row.urgency = urgency
	row.snap = snap
	return row


static func _stock_snap(pct: float) -> Dictionary:
	return {"company_id": 0, "company": "Test Co", "pct": pct, "band": 1 if pct >= 0.0 else -1}


static func _series(keys: Array[String], points: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in keys:
		var line: Array[Dictionary] = []
		for day: int in points:
			line.append({"day": day, "value": float(day + 1) * 3.0})
		out.append({"key": key, "label": key.capitalize(), "fmt": "int", "color": Color.WHITE,
			"points": line})
	return out


#The travel keys that own a dispatch library, each to its config slot.
static func _own_dispatch(cfg: SfxConfig) -> Dictionary:
	return {"caravan": cfg.dispatch_caravan, "train": cfg.dispatch_train, "airship": cfg.dispatch_airship,
		"teleport": cfg.dispatch_teleport}


static func _case_buses(res: Dictionary, _host: Node, _heard: PlayLog) -> void:
	var sfx: int = AudioServer.get_bus_index(EVENT_BUS)
	var ui: int = AudioServer.get_bus_index(UI_BUS)
	var music: int = AudioServer.get_bus_index("Music")
	TestFixtures.check(res, "the Sound Effects, UI and Music buses exist", sfx > 0 and ui > 0 and music > 0,
		"Sound Effects %d, UI %d, Music %d of %d buses" % [sfx, ui, music, AudioServer.bus_count])
	TestFixtures.check(res, "UI sends to Sound Effects and Sound Effects sends to Master",
		_send_of(ui) == EVENT_BUS and _send_of(sfx) == "Master",
		"UI to %s, Sound Effects to %s" % [_send_of(ui), _send_of(sfx)])
	var ui_db: float = AudioServer.get_bus_volume_db(ui) if ui >= 0 else 0.0
	TestFixtures.check(res, "the UI bus sits 6 dB under the event bus", is_equal_approx(ui_db, -6.0),
		"UI %.2f dB" % ui_db)
	TestFixtures.check(res, "bus_or_master keeps a real bus and sends a missing one to Master",
		AudioManager.bus_or_master("Nope") == "Master" and AudioManager.bus_or_master(UI_BUS) == UI_BUS
		and AudioManager.bus_or_master(EVENT_BUS) == EVENT_BUS and AudioManager.DEFAULT_BUS == EVENT_BUS,
		"Nope to %s, default %s" % [AudioManager.bus_or_master("Nope"), AudioManager.DEFAULT_BUS])


static func _case_sample_rate(res: Dictionary, _host: Node, _heard: PlayLog) -> void:
	var paths: Array[String] = []
	_collect_wavs("res://Sound/SFX", paths)
	var unloaded: Array[String] = []
	var off: Array[String] = []
	for path: String in paths:
		var wav: AudioStreamWAV = load(path) as AudioStreamWAV
		if wav == null:
			unloaded.append(path)
		elif wav.mix_rate != SFX_RATE:
			off.append("%s %d" % [path.trim_prefix("res://Sound/SFX/"), wav.mix_rate])
	TestFixtures.check(res, "every SFX wav loads as AudioStreamWAV", not paths.is_empty() and unloaded.is_empty(),
		"%d files, unloaded %s" % [paths.size(), str(unloaded)])
	TestFixtures.check(res, "every SFX wav is 44.1 kHz", off.is_empty(), TestFixtures.detail(off, paths.size(), "wavs"))
	var cfg: SfxConfig = UiSfx.config
	if cfg == null:
		return
	var slow: Array[String] = []
	var checked: int = 0
	for prop: Dictionary in cfg.get_property_list():
		var key: String = prop["name"]
		var value: Variant = cfg.get(key)
		if typeof(value) != TYPE_OBJECT or not (value is SoundLibrary):
			continue
		var library: SoundLibrary = value
		for stream: AudioStream in library.sounds:
			var wav: AudioStreamWAV = stream as AudioStreamWAV
			checked += 1
			if wav == null or wav.mix_rate != SFX_RATE:
				slow.append("%s %s" % [key, stream.resource_path.get_file() if stream != null else "null"])
	TestFixtures.check(res, "every config library stream is a 44.1 kHz AudioStreamWAV", checked > 0 and slow.is_empty(),
		TestFixtures.detail(slow, checked, "streams"))


static func _collect_wavs(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect_wavs(dir_path + "/" + sub, out)
	for file: String in dir.get_files():
		if file.get_extension().to_lower() == "wav":
			out.append(dir_path + "/" + file)


static func _case_config(res: Dictionary, _host: Node, _heard: PlayLog) -> void:
	var loaded: Resource = load(UiSfx.CONFIG_PATH)
	var cfg: SfxConfig = loaded as SfxConfig
	TestFixtures.check(res, "the saved config loads as the one SfxConfig UiSfx and GameSfx share",
		cfg != null and UiSfx.config == cfg and GameSfx.config == cfg, "loaded %s" % str(loaded))
	if cfg == null:
		return
	TestFixtures.check(res, "interface cues use the UI bus and event cues the Sound Effects bus",
		cfg.ui_bus == &"UI" and cfg.event_bus == &"Sound Effects",
		"ui %s, event %s" % [cfg.ui_bus, cfg.event_bus])
	var bad: Array[String] = []
	var total: int = 0
	var files: Dictionary = {}
	for key: String in LIBRARY_COUNTS:
		var library: SoundLibrary = cfg.get(key) as SoundLibrary
		var want: int = int(LIBRARY_COUNTS[key])
		if library == null:
			bad.append("%s unset" % key)
			continue
		if library != load(LIBRARY_DIR + key + ".tres"):
			bad.append("%s is not its library file" % key)
		if library.sounds.size() != want:
			bad.append("%s holds %d of %d" % [key, library.sounds.size(), want])
		for stream: AudioStream in library.sounds:
			if stream == null:
				bad.append("%s holds a null stream" % key)
				continue
			total += 1
			files[stream.resource_path] = true
	TestFixtures.check(res, "the 32 libraries are set with their inventory stream counts", bad.is_empty(),
		TestFixtures.detail(bad, LIBRARY_COUNTS.size(), "libraries"))
	TestFixtures.check(res, "the libraries hold 96 streams and use each wav file once",
		total == STREAM_TOTAL and files.size() == STREAM_TOTAL,
		"%d streams from %d distinct files" % [total, files.size()])
	var foot: SoundLibrary = cfg.dispatch_foot
	TestFixtures.check(res, "dispatch_library maps foot to dispatch_foot",
		foot != null and cfg.dispatch_library("foot") == foot, _name_of(cfg.dispatch_library("foot")))
	var own: Dictionary = _own_dispatch(cfg)
	var wrong: Array[String] = []
	for key: String in own:
		var library: SoundLibrary = own[key] as SoundLibrary
		if library == null or library == foot or cfg.dispatch_library(key) != library:
			wrong.append("'%s' to %s" % [key, _name_of(cfg.dispatch_library(key))])
	TestFixtures.check(res, "dispatch_library maps caravan, train, airship and teleport to their own libraries",
		wrong.is_empty(), TestFixtures.detail(wrong, own.size(), "keys"))
	var strays: Array[String] = []
	for key: String in ["horse", "", "nonsense"]:
		if cfg.dispatch_library(key) != foot:
			strays.append("'%s' to %s" % [key, _name_of(cfg.dispatch_library(key))])
	TestFixtures.check(res, "a travel key with no library of its own falls back to dispatch_foot",
		strays.is_empty(), TestFixtures.detail(strays, 3, "keys"))
	var silent: Array[String] = []
	for mode: Dictionary in GuiTypes.TRAVEL_MODES:
		var library: SoundLibrary = cfg.dispatch_library(String(mode["key"]))
		if library == null or library.is_empty():
			silent.append(String(mode["key"]))
	TestFixtures.check(res, "every travel mode resolves to a dispatch library with sounds", silent.is_empty(),
		TestFixtures.detail(silent, GuiTypes.TRAVEL_MODES.size(), "modes"))


static func _case_manager(res: Dictionary, _host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var stream: AudioStream = cfg.click.sounds[0]
	AudioManager.stop_all()
	heard.clear()
	var count: int = AudioManager.play_count
	var player: AudioStreamPlayer = AudioManager.play(stream, UI_BUS, 1.1)
	var started: bool = player != null and player.playing
	TestFixtures.check(res, "play hands back a pool player set to the stream, bus and pitch",
		player != null and player.get_parent() == AudioManager and player.stream == stream
		and player.bus == &"UI" and is_equal_approx(player.pitch_scale, 1.1), _player_text(player))
	TestFixtures.check(res, "the player play hands back is playing", started, _player_text(player))
	TestFixtures.check(res, "play records last, counts the play and emits played once",
		AudioManager.last.get("stream") == stream and AudioManager.last.get("bus") == UI_BUS
		and is_equal_approx(float(AudioManager.last.get("pitch", 0.0)), 1.1)
		and AudioManager.play_count == count + 1 and heard.only(cfg.click, UI_BUS), heard.text())
	var lost: AudioStreamPlayer = AudioManager.play(stream, "Nope")
	TestFixtures.check(res, "a play on a missing bus lands on Master",
		lost != null and lost.bus == &"Master" and AudioManager.last.get("bus") == "Master", _player_text(lost))
	heard.clear()
	count = AudioManager.play_count
	var empty := SoundLibrary.new()
	var nothing: bool = AudioManager.play(null) == null and AudioManager.play_library(empty) == null \
		and AudioManager.play_library(null) == null
	AudioManager.queue(empty)
	AudioManager.queue(null)
	TestFixtures.check(res, "a null stream or an empty library plays and queues nothing",
		nothing and heard.size() == 0 and AudioManager.play_count == count and AudioManager.pending_count() == 0,
		"%s, pending %d" % [heard.text(), AudioManager.pending_count()])
	AudioManager.stop_all()
	var first: AudioStreamPlayer = AudioManager.play(stream)
	var kids: int = AudioManager.get_child_count()
	first.stop()
	var again: AudioStreamPlayer = AudioManager.play(stream)
	TestFixtures.check(res, "a stopped player is reused before the pool grows",
		again == first and AudioManager.get_child_count() == kids,
		"same %s, children %d then %d" % [again == first, kids, AudioManager.get_child_count()])
	heard.clear()
	var burst: int = AudioManager.MAX_PLAYERS + 6
	for _i: int in burst:
		AudioManager.play(stream)
	TestFixtures.check(res, "a burst of plays never grows the pool past MAX_PLAYERS",
		AudioManager.get_child_count() <= AudioManager.MAX_PLAYERS and heard.size() == burst,
		"%d children after %d of %d plays" % [AudioManager.get_child_count(), heard.size(), burst])
	AudioManager.stop_all()
	var busy: int = 0
	for child: Node in AudioManager.get_children():
		var each: AudioStreamPlayer = child as AudioStreamPlayer
		if each != null and each.playing:
			busy += 1
	TestFixtures.check(res, "stop_all silences every pool player", busy == 0, "%d still playing" % busy)
	heard.clear()


static func _case_queue(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	heard.clear()
	AudioManager.queue(cfg.money, UI_BUS, 0.9)
	AudioManager.queue(cfg.money, UI_BUS, 1.1)
	AudioManager.queue(cfg.money, EVENT_BUS, 1.2)
	var waiting: int = AudioManager.pending_count()
	AudioManager.flush()
	TestFixtures.check(res, "three requests for one library in a frame wait as one and flush as one play",
		waiting == 1 and heard.size() == 1 and heard.hits(cfg.money) == 1 and AudioManager.pending_count() == 0,
		"pending %d, heard %s" % [waiting, heard.text()])
	TestFixtures.check(res, "the latest request's bus and pitch win",
		heard.size() == 1 and heard.buses[0] == EVENT_BUS and heard.pitch_is(1.2), heard.text())
	heard.clear()
	AudioManager.queue(cfg.money)
	AudioManager.queue(cfg.permit)
	AudioManager.queue(cfg.money)
	waiting = AudioManager.pending_count()
	await host.get_tree().process_frame
	TestFixtures.check(res, "two libraries wait as two and the deferred flush plays both by the next frame",
		waiting == 2 and heard.size() == 2 and heard.hits(cfg.money) == 1 and heard.hits(cfg.permit) == 1
		and AudioManager.pending_count() == 0, "pending %d, heard %s" % [waiting, heard.text()])
	TestFixtures.check(res, "a queue with no bus plays on Sound Effects", heard.buses.count(EVENT_BUS) == 2,
		heard.text())
	heard.clear()
	AudioManager.queue(cfg.money)
	await host.get_tree().process_frame
	AudioManager.queue(cfg.money)
	await host.get_tree().process_frame
	TestFixtures.check(res, "one library queued on two frames plays twice",
		heard.size() == 2 and heard.hits(cfg.money) == 2, heard.text())
	heard.clear()
	AudioManager.queue(cfg.money)
	AudioManager.stop_all()
	await host.get_tree().process_frame
	TestFixtures.check(res, "stop_all drops the waiting queue",
		heard.size() == 0 and AudioManager.pending_count() == 0, heard.text())


static func _case_default_click(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var button := Button.new()
	host.add_child(button)
	TestFixtures.check(res, "a Button entering the tree carries the hook mark of its own id",
		button.get_meta(UiSfx.HOOK_META, 0) == button.get_instance_id(),
		str(button.get_meta(UiSfx.HOOK_META, 0)))
	TestFixtures.check(res, "a plain Button clicks and hovers with the config defaults",
		UiSfx.click_library(button) == cfg.click and UiSfx.hover_library(button) == cfg.hover,
		"%s, %s" % [_name_of(UiSfx.click_library(button)), _name_of(UiSfx.hover_library(button))])
	heard.clear()
	button.pressed.emit()
	button.pressed.emit()
	button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "three presses in one frame play one click on UI at pitch 1",
		heard.only(cfg.click, UI_BUS) and heard.pitch_is(1.0), heard.text())
	var copy: Button = button.duplicate() as Button
	host.add_child(copy)
	TestFixtures.check(res, "a duplicated Button is hooked again under its own id",
		copy.get_meta(UiSfx.HOOK_META, 0) == copy.get_instance_id(),
		"mark %s, id %d" % [str(copy.get_meta(UiSfx.HOOK_META, 0)), copy.get_instance_id()])
	heard.clear()
	copy.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the duplicate clicks", heard.only(cfg.click, UI_BUS), heard.text())
	var box := CheckBox.new()
	host.add_child(box)
	heard.clear()
	box.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "any BaseButton kind clicks, a CheckBox too", heard.only(cfg.click, UI_BUS),
		heard.text())
	var loose := Button.new()
	heard.clear()
	loose.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a Button outside the tree is not hooked and stays silent",
		loose.get_meta(UiSfx.HOOK_META, 0) == 0 and heard.size() == 0, heard.text())
	loose.free()
	button.queue_free()
	copy.queue_free()
	box.queue_free()


static func _case_big_button(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var tile: GridMenuButton = (load(GRID_BUTTON_SCENE) as PackedScene).instantiate() as GridMenuButton
	host.add_child(tile)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a GridMenuButton carries big_button_click as its click_sfx",
		tile.click_sfx == cfg.big_button_click and UiSfx.click_library(tile) == cfg.big_button_click,
		"%s, %s" % [_name_of(tile.click_sfx), _name_of(UiSfx.click_library(tile))])
	TestFixtures.check(res, "a GridMenuButton keeps the default hover", UiSfx.hover_library(tile) == cfg.hover,
		_name_of(UiSfx.hover_library(tile)))
	var marker: HintMarker = HintMarker.new()
	host.add_child(marker)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a HintMarker clicks with mercdave_click and hovers with mercdave_hover",
		UiSfx.click_library(marker) == cfg.mercdave_click and UiSfx.hover_library(marker) == cfg.mercdave_hover,
		"%s, %s" % [_name_of(UiSfx.click_library(marker)), _name_of(UiSfx.hover_library(marker))])
	marker.queue_free()
	heard.clear()
	tile.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing a menu tile plays a big button click on UI, not the plain click",
		heard.only(cfg.big_button_click, UI_BUS) and heard.hits(cfg.click) == 0, heard.text())
	tile.queue_free()
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var bazaar: GridMenuButton = hud.button_of(&"bazaar")
	TestFixtures.check(res, "the HUD's bazaar tile clicks with big_button_click",
		bazaar != null and UiSfx.click_library(bazaar) == cfg.big_button_click,
		"tile %s, %s" % [str(bazaar), _name_of(UiSfx.click_library(bazaar)) if bazaar != null else "-"])
	heard.clear()
	UiSfx.note_pointer()
	if bazaar != null:
		bazaar.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a HUD tile hovers with the default hover once the pointer moves",
		heard.only(cfg.hover, UI_BUS), heard.text())
	hud.queue_free()
	await _stale_pointer(host)
	heard.clear()


static func _case_overrides(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var button := Button.new()
	host.add_child(button)
	UiSfx.override_click(button, cfg.money)
	heard.clear()
	button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a click override plays its own library on UI",
		UiSfx.click_library(button) == cfg.money and heard.only(cfg.money, UI_BUS), heard.text())
	UiSfx.override_click(button, null)
	heard.clear()
	button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a null click override silences the button",
		UiSfx.click_library(button) == null and heard.size() == 0, heard.text())
	UiSfx.clear_overrides(button)
	heard.clear()
	button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "clear_overrides restores the default click",
		UiSfx.click_library(button) == cfg.click and heard.only(cfg.click, UI_BUS), heard.text())
	var probe := SfxProbe.new()
	probe.click_sfx = cfg.permit
	host.add_child(probe)
	heard.clear()
	probe.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a button's own click_sfx property plays in place of the default",
		UiSfx.click_library(probe) == cfg.permit and heard.only(cfg.permit, UI_BUS), heard.text())
	probe.click_sfx = null
	TestFixtures.check(res, "a null click_sfx property falls back to the default click",
		UiSfx.click_library(probe) == cfg.click, _name_of(UiSfx.click_library(probe)))
	probe.click_sfx = cfg.permit
	UiSfx.override_click(probe, cfg.reject)
	TestFixtures.check(res, "an override wins over the click_sfx property",
		UiSfx.click_library(probe) == cfg.reject, _name_of(UiSfx.click_library(probe)))
	host.remove_child(probe)
	TestFixtures.check(res, "an override is dropped when its button leaves the tree",
		UiSfx.click_library(probe) == cfg.permit, _name_of(UiSfx.click_library(probe)))
	probe.free()
	var bevel: BevelButton = (load(BEVEL_SCENE) as PackedScene).instantiate() as BevelButton
	host.add_child(bevel)
	var plain: bool = UiSfx.click_library(bevel) == cfg.click and UiSfx.hover_library(bevel) == cfg.hover
	bevel.click_sfx = cfg.equip
	bevel.hover_sfx = cfg.unequip
	heard.clear()
	bevel.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a BevelButton clicks the default until its click_sfx and hover_sfx are set",
		plain and UiSfx.hover_library(bevel) == cfg.unequip and heard.only(cfg.equip, UI_BUS),
		"default %s, heard %s" % [plain, heard.text()])
	button.queue_free()
	bevel.queue_free()


static func _case_hover_gate(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var button := Button.new()
	host.add_child(button)
	await _stale_pointer(host)
	heard.clear()
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a hover under a still pointer stays silent", heard.size() == 0, heard.text())
	UiSfx.note_pointer()
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a hover right after pointer motion plays a hover cue on UI between 0.95 and 1.05",
		heard.only(cfg.hover, UI_BUS) and heard.pitches[0] >= UiSfx.HOVER_PITCH_LOW
		and heard.pitches[0] <= UiSfx.HOVER_PITCH_HIGH, heard.text())
	await _stale_pointer(host)
	heard.clear()
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the pointer counts as still again after HOVER_FRAMES frames", heard.size() == 0,
		heard.text())
	button.disabled = true
	UiSfx.note_pointer()
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a disabled button never plays the default hover", heard.hits(cfg.hover) == 0,
		heard.text())
	button.disabled = false
	heard.clear()
	UiSfx.override_hover(button, cfg.permit)
	UiSfx.note_pointer()
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a hover override replaces the default hover", heard.only(cfg.permit, UI_BUS),
		heard.text())
	UiSfx.override_hover(button, null)
	heard.clear()
	UiSfx.note_pointer()
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a null hover override silences the hover",
		UiSfx.hover_library(button) == null and heard.size() == 0, heard.text())
	UiSfx.clear_overrides(button)
	await _stale_pointer(host)
	heard.clear()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1270.0, 710.0)
	host.get_viewport().push_input(motion)
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a mouse motion event through the viewport opens the hover gate",
		heard.only(cfg.hover, UI_BUS), heard.text())
	button.queue_free()
	await _stale_pointer(host)
	heard.clear()


#A left mouse button event, down or up.
static func _left_press(down: bool) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	return click


#A point local to control, in the canvas space UiSfx._input reads event positions in.
static func _point_in(control: Control, local: Vector2) -> Vector2:
	return control.get_global_transform_with_canvas() * local


#One pointer step as push_input reports it: the exit of from, the enter of to, then a motion event at the given point.
static func _cross(from: Control, to: Control, at: Vector2) -> void:
	UiSfx.note_pointer()
	if from != null:
		from.mouse_exited.emit()
	if to != null:
		to.mouse_entered.emit()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	UiSfx._input(motion)


#A hooked button with a hooked child button inside its rect: crossing the child and back replays no parent hover.
static func _case_hover_replay(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var layer := CanvasLayer.new()
	layer.layer = 128
	host.add_child(layer)
	var outer := Button.new()
	outer.position = Vector2(400.0, 300.0)
	outer.size = Vector2(120.0, 60.0)
	layer.add_child(outer)
	var inner := Button.new()
	inner.position = Vector2(80.0, 12.0)
	inner.size = Vector2(30.0, 30.0)
	outer.add_child(inner)
	UiSfx.override_hover(inner, cfg.permit)
	await _stale_pointer(host)
	heard.clear()
	var face: Vector2 = _point_in(outer, Vector2(10.0, outer.size.y * 0.5))
	var away: Vector2 = _point_in(outer, Vector2(-60.0, -60.0))
	_cross(null, outer, face)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the pointer entering a hooked button from outside plays its hover once",
		heard.only(cfg.hover, UI_BUS), heard.text())
	heard.clear()
	_cross(outer, inner, _point_in(inner, inner.size * 0.5))
	await host.get_tree().process_frame
	TestFixtures.check(res, "moving onto a hooked child button plays only the child's hover",
		heard.only(cfg.permit, UI_BUS), heard.text())
	heard.clear()
	_cross(inner, outer, face)
	await host.get_tree().process_frame
	TestFixtures.check(res, "coming back off the child inside the parent's rect replays no parent hover",
		heard.size() == 0, heard.text())
	_cross(outer, null, away)
	await host.get_tree().process_frame
	heard.clear()
	_cross(null, outer, face)
	await host.get_tree().process_frame
	TestFixtures.check(res, "leaving the parent's rect and coming back plays the parent's hover again",
		heard.only(cfg.hover, UI_BUS), heard.text())
	UiSfx.clear_overrides(inner)
	layer.queue_free()
	await _stale_pointer(host)
	heard.clear()


#A real unread NotificationItem, built the way GuiNotifyTests._bell does: its mark-read X is the inner button.
static func _case_notice_replay(res: Dictionary, host: Node, heard: PlayLog) -> void:
	const NOTICE_BELL: String = "res://Scenes/GUI/Notifications/NotificationBell.tscn"
	var cfg: SfxConfig = UiSfx.config
	NotificationCenter.reset()
	var bell: NotificationBell = (load(NOTICE_BELL) as PackedScene).instantiate() as NotificationBell
	host.add_child(bell)
	await host.get_tree().process_frame
	var row: NotificationData = NotificationCenter.push(NotificationData.TYPE_CONTRACT_COMPLETED, 11,
		{"name": "Replay Probe", "difficulty": 3.5, "reward": 1250})
	bell.open_panel()
	await _drain(host, heard)
	await _stale_pointer(host)
	heard.clear()
	var panel: NotificationPanel = bell.panel()
	var card: NotificationItem = null
	if row != null and panel != null:
		card = panel.card_for(row.id)
	var mark: Button = card.mark_button() if card != null else null
	var walkable: bool = mark != null and mark.is_visible_in_tree() and not row.read
	var mark_at: Vector2 = _point_in(mark, mark.size * 0.5) if walkable else Vector2.ZERO
	if walkable:
		var mark_local: Vector2 = card.get_global_transform_with_canvas().affine_inverse() * mark_at
		walkable = Rect2(Vector2.ZERO, card.size).has_point(mark_local)
	TestFixtures.check(res, "an unread notice card shows its mark-read X inside its own rect", walkable,
		"row %s, card %s, mark %s, shown %s" % [row != null, card != null, mark != null,
		mark != null and mark.is_visible_in_tree()])
	if not walkable:
		bell.queue_free()
		NotificationCenter.reset()
		await _stale_pointer(host)
		heard.clear()
		return
	var face: Vector2 = _point_in(card, Vector2(12.0, card.size.y * 0.5))
	var away: Vector2 = _point_in(card, Vector2(-40.0, -40.0))
	_cross(null, card, face)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the pointer entering an unread notice card plays its hover once",
		heard.only(cfg.hover, UI_BUS), heard.text())
	heard.clear()
	_cross(card, mark, mark_at)
	await host.get_tree().process_frame
	TestFixtures.check(res, "moving onto the notice card's mark-read X plays only the X's hover",
		heard.only(cfg.hover, UI_BUS), heard.text())
	heard.clear()
	_cross(mark, card, face)
	await host.get_tree().process_frame
	TestFixtures.check(res, "coming back off the mark-read X onto its notice card replays no card hover",
		heard.size() == 0, heard.text())
	_cross(card, null, away)
	await host.get_tree().process_frame
	heard.clear()
	_cross(null, card, face)
	await host.get_tree().process_frame
	TestFixtures.check(res, "leaving the notice card and coming back plays its hover again",
		heard.only(cfg.hover, UI_BUS), heard.text())
	bell.queue_free()
	NotificationCenter.reset()
	await _stale_pointer(host)
	heard.clear()


#play_hover_cue: the default hover past a still pointer and past any hover override.
static func _case_hover_cue(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var probe := Button.new()
	host.add_child(probe)
	await _stale_pointer(host)
	heard.clear()
	UiSfx.play_hover_cue()
	await host.get_tree().process_frame
	TestFixtures.check(res, "play_hover_cue under a still pointer plays one default hover on UI between 0.95 and 1.05",
		heard.only(cfg.hover, UI_BUS) and heard.pitches[0] >= UiSfx.HOVER_PITCH_LOW
		and heard.pitches[0] <= UiSfx.HOVER_PITCH_HIGH, heard.text())
	heard.clear()
	UiSfx.play_hover_cue(1.2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "play_hover_cue(1.2) plays the default hover at pitch 1.2",
		heard.only(cfg.hover, UI_BUS) and heard.pitch_is(1.2), heard.text())
	UiSfx.override_hover(probe, null)
	heard.clear()
	UiSfx.note_pointer()
	probe.mouse_entered.emit()
	UiSfx.play_hover_cue()
	await host.get_tree().process_frame
	TestFixtures.check(res, "play_hover_cue plays the default hover while a null override silences the hovered control",
		heard.only(cfg.hover, UI_BUS), heard.text())
	UiSfx.override_hover(probe, cfg.permit)
	heard.clear()
	UiSfx.note_pointer()
	probe.mouse_entered.emit()
	UiSfx.play_hover_cue()
	await host.get_tree().process_frame
	TestFixtures.check(res, "play_hover_cue plays the default hover beside a hover override, never the override library",
		heard.size() == 2 and _heard_from(heard, cfg.hover, UI_BUS) == 1
		and _heard_from(heard, cfg.permit, UI_BUS) == 1, heard.text())
	UiSfx.clear_overrides(probe)
	probe.queue_free()
	await _stale_pointer(host)
	heard.clear()


static func _case_generic_hook(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var probe := HookProbe.new()
	host.add_child(probe)
	TestFixtures.check(res, "a Control with a no-arg pressed signal is hooked",
		probe.get_meta(UiSfx.HOOK_META, 0) == probe.get_instance_id(), str(probe.get_meta(UiSfx.HOOK_META, 0)))
	heard.clear()
	probe.press()
	await host.get_tree().process_frame
	TestFixtures.check(res, "its pressed signal plays the default click on UI", heard.only(cfg.click, UI_BUS),
		heard.text())
	heard.clear()
	UiSfx.note_pointer()
	probe.hover()
	await host.get_tree().process_frame
	TestFixtures.check(res, "its sfx_hovered signal plays the hover on UI", heard.only(cfg.hover, UI_BUS),
		heard.text())
	heard.clear()
	UiSfx.note_pointer()
	probe.mouse_entered.emit()
	await host.get_tree().process_frame
	var hover: Callable = UiSfx.play_hover.bind(probe)
	TestFixtures.check(res, "sfx_hovered takes the place of mouse_entered as its hover",
		probe.sfx_hovered.is_connected(hover) and not probe.mouse_entered.is_connected(hover) and heard.size() == 0,
		heard.text())
	var arg := ArgProbe.new()
	host.add_child(arg)
	heard.clear()
	arg.press(3)
	UiSfx.note_pointer()
	arg.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a pressed signal with an argument leaves the Control unhooked",
		arg.get_meta(UiSfx.HOOK_META, 0) == 0 and heard.size() == 0, heard.text())
	probe.queue_free()
	arg.queue_free()
	await _stale_pointer(host)
	heard.clear()


static func _case_disabled_press(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var button := Button.new()
	button.disabled = true
	host.add_child(button)
	heard.clear()
	button.gui_input.emit(_left_press(true))
	await host.get_tree().process_frame
	TestFixtures.check(res, "a left press on a disabled button plays click_disabled on the UI bus",
		heard.only(cfg.click_disabled, UI_BUS), heard.text())
	var kept: SoundLibrary = cfg.click_disabled
	cfg.click_disabled = null
	heard.clear()
	button.gui_input.emit(_left_press(true))
	await host.get_tree().process_frame
	cfg.click_disabled = kept
	TestFixtures.check(res, "a disabled press with click_disabled null falls back to the reject cue on the event bus",
		heard.only(cfg.reject, EVENT_BUS), heard.text())
	heard.clear()
	var right: InputEventMouseButton = _left_press(true)
	right.button_index = MOUSE_BUTTON_RIGHT
	button.gui_input.emit(right)
	button.gui_input.emit(_left_press(false))
	await host.get_tree().process_frame
	TestFixtures.check(res, "a right press or a left release on a disabled button stays silent", heard.size() == 0,
		heard.text())
	button.disabled = false
	heard.clear()
	button.gui_input.emit(_left_press(true))
	await host.get_tree().process_frame
	TestFixtures.check(res, "a left press on an enabled button plays neither click_disabled nor reject",
		heard.size() == 0, heard.text())
	button.queue_free()


#Unverified headless: a real press pushed through the viewport onto a disabled button on the top canvas layer.
static func _case_disabled_push(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var layer := CanvasLayer.new()
	layer.layer = 128
	host.add_child(layer)
	var button := Button.new()
	button.disabled = true
	button.position = Vector2(40.0, 40.0)
	button.size = Vector2(120.0, 40.0)
	layer.add_child(button)
	await host.get_tree().process_frame
	heard.clear()
	var at: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var down: InputEventMouseButton = _left_press(true)
	down.position = at
	down.global_position = at
	host.get_viewport().push_input(down, true)
	var up: InputEventMouseButton = _left_press(false)
	up.position = at
	up.global_position = at
	host.get_viewport().push_input(up, true)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a real left press pushed onto a disabled button plays click_disabled on the UI bus",
		heard.only(cfg.click_disabled, UI_BUS), heard.text())
	layer.queue_free()
	await _stale_pointer(host)
	heard.clear()


static func _case_hover_pitch(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var button := Button.new()
	host.add_child(button)
	heard.clear()
	for _i: int in 20:
		UiSfx.note_pointer()
		button.mouse_entered.emit()
		await host.get_tree().process_frame
	var inside: bool = heard.size() == 20 and heard.hits(cfg.hover) == 20
	var varied: bool = false
	for pitch: float in heard.pitches:
		inside = inside and pitch >= UiSfx.HOVER_PITCH_LOW and pitch <= UiSfx.HOVER_PITCH_HIGH
		varied = varied or not is_equal_approx(pitch, 1.0)
	TestFixtures.check(res, "twenty hovers land between 0.95 and 1.05 and do not all sit at 1.0", inside and varied,
		heard.text())
	button.queue_free()
	await _stale_pointer(host)
	heard.clear()


static func _case_hover_set(res: Dictionary, _host: Node, _heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var held: int = cfg.hover_disabled.sounds.size() if cfg.hover_disabled != null else 0
	TestFixtures.check(res, "the hover_disabled slot holds one stream", held == 1,
		"%s with %d streams" % [_name_of(cfg.hover_disabled), held])
	var hover: SoundLibrary = load(LIBRARY_DIR + "hover.tres") as SoundLibrary
	var names: PackedStringArray = PackedStringArray()
	if hover != null:
		for stream: AudioStream in hover.sounds:
			names.append("null" if stream == null else stream.resource_path.get_file())
	var joined: String = ", ".join(names)
	TestFixtures.check(res, "the hover library holds four streams without Inventory_Placement_3 or Switch_Wooden_2",
		names.size() == 4 and not joined.contains("Inventory_Placement_3") and not joined.contains("Switch_Wooden_2"),
		joined)


static func _case_disabled_hover(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var button := Button.new()
	button.disabled = true
	host.add_child(button)
	heard.clear()
	UiSfx.note_pointer()
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a disabled button plays hover_disabled once on the UI bus",
		heard.only(cfg.hover_disabled, UI_BUS), heard.text())
	UiSfx.override_hover(button, null)
	heard.clear()
	UiSfx.note_pointer()
	button.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a null hover override keeps a disabled button silent", heard.size() == 0, heard.text())
	button.queue_free()
	await _stale_pointer(host)
	heard.clear()


static func _case_step_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var button := Button.new()
	host.add_child(button)
	UiSfx.override_click(button, null)
	heard.clear()
	UiSfx.play_step(button)
	await host.get_tree().process_frame
	TestFixtures.check(res, "play_step plays the default click even when an override silences the button",
		heard.only(cfg.click, UI_BUS), heard.text())
	UiSfx.clear_overrides(button)
	heard.clear()
	UiSfx.play_click(button)
	UiSfx.reject_press(button)
	await host.get_tree().process_frame
	TestFixtures.check(res, "reject_press after the click drops the click and plays the reject cue",
		heard.only(cfg.reject, EVENT_BUS), heard.text())
	heard.clear()
	UiSfx.reject_press(button)
	UiSfx.play_click(button)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a click after reject_press in the same frame stays dropped",
		heard.only(cfg.reject, EVENT_BUS), heard.text())
	heard.clear()
	UiSfx.play_click(button)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the next frame clicks again", heard.only(cfg.click, UI_BUS), heard.text())
	heard.clear()
	button.pressed.emit()
	UiSfx.reject_press()
	await host.get_tree().process_frame
	TestFixtures.check(res, "reject_press with no control drops the default click",
		heard.only(cfg.reject, EVENT_BUS), heard.text())
	button.queue_free()


static func _case_custom_hooks(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var missed: Array[String] = []
	var nodes: Array[Control] = []
	for path: String in HOOK_SCENES:
		var node: Control = (load(path) as PackedScene).instantiate() as Control
		host.add_child(node)
		nodes.append(node)
		if node.get_meta(UiSfx.HOOK_META, 0) != node.get_instance_id():
			missed.append(path.get_file())
	TestFixtures.check(res, "the custom clickable controls carry the UiSfx hook", missed.is_empty(),
		TestFixtures.detail(missed, HOOK_SCENES.size(), "scenes"))
	var slot: Control = nodes[0]
	var picker: Control = nodes[1]
	await _stale_pointer(host)
	heard.clear()
	UiSfx.note_pointer()
	slot.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a team slot hovers through sfx_hovered outside a drag", heard.only(cfg.hover, UI_BUS),
		heard.text())
	heard.clear()
	UiSfx.note_pointer()
	picker.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the star picker never hovers", UiSfx.hover_library(picker) == null and heard.size() == 0,
		heard.text())
	for node: Control in nodes:
		node.queue_free()
	await _stale_pointer(host)
	heard.clear()


#The picker x of the left or the right half of a star, two pixels in from the star edge.
static func _star_half_x(picker: StarRangePicker, row: int, star: int, right_half: bool) -> float:
	var left: float = picker._stars_x(row) + float(star - 1) * (picker._star_px() + picker._star_gap())
	return left + (picker._star_px() - 2.0 if right_half else 2.0)


static func _star_motion_at(x: float) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(x, 4.0)
	return motion


static func _case_star_hover(res: Dictionary, host: Node, heard: PlayLog) -> void:
	const SCENE: String = "res://Scenes/GUI/Shared/StarRangePicker.tscn"
	var cfg: SfxConfig = UiSfx.config
	var picker: StarRangePicker = (load(SCENE) as PackedScene).instantiate() as StarRangePicker
	host.add_child(picker)
	await _drain(host, heard)
	await _stale_pointer(host)
	var min_row: int = StarRangePicker.ROW_MIN
	var max_row: int = StarRangePicker.ROW_MAX
	picker._gui_input(_star_motion_at(_star_half_x(picker, min_row, 1, false)))
	await host.get_tree().process_frame
	TestFixtures.check(res, "pointer motion onto a star plays one hover cue on the UI bus with a stale pointer",
		heard.only(cfg.hover, UI_BUS), heard.text())
	TestFixtures.check(res, "the star hover cue pitch sits between HOVER_PITCH_LOW and HOVER_PITCH_HIGH",
		heard.size() == 1 and heard.pitches[0] >= UiSfx.HOVER_PITCH_LOW
			and heard.pitches[0] <= UiSfx.HOVER_PITCH_HIGH, heard.text())
	heard.clear()
	picker._gui_input(_star_motion_at(_star_half_x(picker, min_row, 1, true)))
	await host.get_tree().process_frame
	TestFixtures.check(res, "motion to the other half of the same star plays nothing",
		heard.size() == 0, heard.text())
	picker._gui_input(_star_motion_at(_star_half_x(picker, min_row, 1, false)))
	await host.get_tree().process_frame
	TestFixtures.check(res, "motion back to the first half of the same star plays nothing",
		heard.size() == 0, heard.text())
	picker._gui_input(_star_motion_at(_star_half_x(picker, min_row, 2, false)))
	await host.get_tree().process_frame
	TestFixtures.check(res, "motion onto the next star plays one hover cue on the UI bus",
		heard.only(cfg.hover, UI_BUS), heard.text())
	heard.clear()
	picker._gui_input(_star_motion_at(picker._stars_x(min_row) * 0.5))
	await host.get_tree().process_frame
	TestFixtures.check(res, "motion onto the row label plays nothing", heard.size() == 0, heard.text())
	picker._gui_input(_star_motion_at(_star_half_x(picker, min_row, 2, true)))
	await host.get_tree().process_frame
	TestFixtures.check(res, "motion from the row label back onto a star plays one hover cue",
		heard.only(cfg.hover, UI_BUS), heard.text())
	heard.clear()
	picker._gui_input(_star_motion_at(_star_half_x(picker, max_row, 2, false)))
	await host.get_tree().process_frame
	TestFixtures.check(res, "the same star number on the other row plays one hover cue",
		heard.only(cfg.hover, UI_BUS), heard.text())
	heard.clear()
	picker.notification(Control.NOTIFICATION_MOUSE_EXIT)
	picker._gui_input(_star_motion_at(_star_half_x(picker, max_row, 2, true)))
	await host.get_tree().process_frame
	TestFixtures.check(res, "leaving the picker resets the star so the next entry plays one hover cue",
		heard.only(cfg.hover, UI_BUS), heard.text())
	picker.queue_free()
	await _drain(host, heard)


static func _case_block_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var scene: PackedScene = load(MODULE_SCENE) as PackedScene
	var dim: CustomizeBlock = scene.instantiate() as CustomizeBlock
	var base: CustomizeBlock = scene.instantiate() as CustomizeBlock
	host.add_child(dim)
	host.add_child(base)
	var id: String = ""
	for key: String in TreeLayout.block_ids():
		if key != CustomizeBlock.BASE_ID:
			id = key
			break
	dim.setup(id)
	dim.refresh({}, false)
	base.setup(CustomizeBlock.BASE_ID)
	base.refresh({}, true)
	var caught: Array[String] = []
	dim.pressed_block.connect(func(pressed_id: String) -> void: caught.append(pressed_id))
	heard.clear()
	dim.press()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a dimmed module press plays the Bad Click cue on the UI bus",
		heard.only(cfg.click_disabled, UI_BUS), heard.text())
	TestFixtures.check(res, "a dimmed module press opens nothing and leaves the event bus silent",
		not dim.is_usable() and caught.is_empty() and heard.buses.count(EVENT_BUS) == 0 and heard.hits(cfg.reject) == 0,
		"opened %s, heard %s" % [caught, heard.text()])
	heard.clear()
	base.press()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a press on the Base module stays silent", heard.size() == 0, heard.text())
	heard.clear()
	UiSfx.note_pointer()
	dim.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a dimmed module hover plays the Bad Hover cue on the UI bus",
		heard.only(cfg.hover_disabled, UI_BUS), heard.text())
	heard.clear()
	UiSfx.note_pointer()
	base.mouse_entered.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a base module hover stays silent", heard.size() == 0, heard.text())
	dim.queue_free()
	base.queue_free()


static func _case_pitch(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	TestFixtures.check(res, "pitch_for runs 0.75 at 0, 1.0 at half and 1.25 at 1",
		is_equal_approx(UiSfx.pitch_for(0.0), 0.75) and is_equal_approx(UiSfx.pitch_for(0.5), 1.0)
		and is_equal_approx(UiSfx.pitch_for(1.0), 1.25),
		"%.3f, %.3f, %.3f" % [UiSfx.pitch_for(0.0), UiSfx.pitch_for(0.5), UiSfx.pitch_for(1.0)])
	TestFixtures.check(res, "pitch_for clamps a ratio outside 0 to 1",
		is_equal_approx(UiSfx.pitch_for(-2.0), UiSfx.PITCH_LOW) and is_equal_approx(UiSfx.pitch_for(3.0),
		UiSfx.PITCH_HIGH), "%.3f, %.3f" % [UiSfx.pitch_for(-2.0), UiSfx.pitch_for(3.0)])
	heard.clear()
	UiSfx.play_slider(0.25)
	await host.get_tree().process_frame
	TestFixtures.check(res, "play_slider plays the slider on UI at its ratio's pitch",
		heard.only(cfg.slider, UI_BUS) and heard.pitch_is(0.875), heard.text())
	heard.clear()
	UiSfx.play_upgrade(1.0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "play_upgrade plays the upgrade click on UI at its ratio's pitch",
		heard.only(cfg.upgrade_click, UI_BUS) and heard.pitch_is(1.25), heard.text())
	var slider := PixelSlider.new()
	slider.max_value = 10.0
	host.add_child(slider)
	heard.clear()
	slider._apply(10.0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a PixelSlider moved to its top plays the slider at 1.25",
		heard.only(cfg.slider, UI_BUS) and heard.pitch_is(1.25), heard.text())
	heard.clear()
	slider._apply(10.0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a PixelSlider move that keeps its value plays nothing", heard.size() == 0,
		heard.text())
	var dual := DualSlider.new()
	dual.max_value = 10.0
	host.add_child(dual)
	dual.set_range_silent(2.0, 10.0)
	dual._active = DualSlider.Thumb.HIGH
	heard.clear()
	dual._apply(6.0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a DualSlider high thumb moved to 6 of 10 plays the slider at pitch_for(0.6)",
		is_equal_approx(dual.high, 6.0) and heard.only(cfg.slider, UI_BUS) and heard.pitch_is(UiSfx.pitch_for(0.6)),
		"high %.1f, heard %s" % [dual.high, heard.text()])
	dual._active = -1
	heard.clear()
	dual._apply(3.0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a DualSlider with no thumb held stays silent", heard.size() == 0, heard.text())
	slider.queue_free()
	dual.queue_free()


static func _case_upgrade_dialog(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	var dlg: UpgradeTierDialog = (load(TIER_SCENE) as PackedScene).instantiate() as UpgradeTierDialog
	host.add_child(dlg)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the tier dialog's plus and minus buttons are silenced",
		UiSfx.click_library(dlg._plus) == null and UiSfx.click_library(dlg._minus) == null,
		"plus %s, minus %s" % [_name_of(UiSfx.click_library(dlg._plus)), _name_of(UiSfx.click_library(dlg._minus))])
	var id: String = UpgradeDefs.ORDER[0]
	heard.clear()
	dlg.open_for(id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening the hidden tier dialog plays summon_window on UI",
		dlg.is_open() and heard.only(cfg.summon_window, UI_BUS), heard.text())
	heard.clear()
	dlg.open_for(id, Vector2(300.0, 120.0))
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening it again while visible plays nothing", heard.size() == 0, heard.text())
	var ratio: float = dlg.upgrade_ratio()
	TestFixtures.check(res, "upgrade_ratio is the tier over the max tier, inside 0 to 1",
		is_equal_approx(ratio, float(dlg.tier()) / float(maxi(1, dlg.max_tier()))) and ratio >= 0.0 and ratio <= 1.0,
		"%.3f at tier %d of %d" % [ratio, dlg.tier(), dlg.max_tier()])
	heard.clear()
	dlg._plus.button_down.emit()
	dlg._plus.pressed.emit()
	dlg._plus.button_up.emit()
	await host.get_tree().process_frame
	var plus_text: String = heard.text()
	var plus_ok: bool = heard.hits(cfg.upgrade_click) + heard.hits(cfg.reject) >= 1
	var clicks: int = heard.hits(cfg.click)
	heard.clear()
	dlg._minus.button_down.emit()
	dlg._minus.pressed.emit()
	dlg._minus.button_up.emit()
	await host.get_tree().process_frame
	var minus_ok: bool = heard.hits(cfg.upgrade_click) + heard.hits(cfg.reject) >= 1
	clicks += heard.hits(cfg.click)
	TestFixtures.check(res, "pressing plus or minus never plays the default click", clicks == 0,
		"plus %s; minus %s" % [plus_text, heard.text()])
	TestFixtures.check(res, "each plus or minus press answers with the upgrade click or the reject",
		plus_ok and minus_ok, "plus %s; minus %s" % [plus_text, heard.text()])
	ratio = dlg.upgrade_ratio()
	heard.clear()
	UiSfx.play_upgrade(ratio)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the upgrade cue at the dialog's ratio plays on UI at pitch_for(ratio)",
		heard.only(cfg.upgrade_click, UI_BUS) and heard.pitch_is(UiSfx.pitch_for(ratio)),
		"ratio %.3f, heard %s" % [ratio, heard.text()])
	heard.clear()
	dlg.close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the open tier dialog plays dismiss_window on UI",
		not dlg.is_open() and heard.only(cfg.dismiss_window, UI_BUS), heard.text())
	heard.clear()
	dlg.close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing it again while hidden plays nothing", heard.size() == 0, heard.text())
	dlg.queue_free()
	GuiFrameStack.clear()


#QuantityStepper: one click per real move and none on release, the reject alone at a bound, silence at reject_seconds 0.
static func _case_stepper_steps(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var stepper: QuantityStepper = (load(STEPPER_SCENE) as PackedScene).instantiate() as QuantityStepper
	host.add_child(stepper)
	await host.get_tree().process_frame
	var sides: Array[int] = []
	var moves: Array[int] = []
	stepper.rejected.connect(func(side: int) -> void: sides.append(side))
	stepper.value_changed.connect(func(v: int) -> void: moves.append(v))
	var minus_lib: SoundLibrary = UiSfx.click_library(stepper.minus_button)
	var plus_lib: SoundLibrary = UiSfx.click_library(stepper.plus_button)
	TestFixtures.check(res, "a quantity stepper rejects for REJECT_SECONDS by default and silences both buttons",
		is_equal_approx(stepper.reject_seconds, QuantityStepper.REJECT_SECONDS) and minus_lib == null and plus_lib == null,
		"reject_seconds %.2f, minus %s, plus %s" % [stepper.reject_seconds, _name_of(minus_lib), _name_of(plus_lib)])
	stepper.max_value = 5
	stepper.set_value_silent(3)
	await _drain(host, heard)
	stepper.press_plus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "press_plus from 3 moves to 4 and plays one click on UI",
		stepper.value == 4 and heard.only(cfg.click, UI_BUS), "value %d, heard %s" % [stepper.value, heard.text()])
	heard.clear()
	stepper.plus_button.button_down.emit()
	stepper.plus_button.pressed.emit()
	stepper.plus_button.button_up.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a full plus click moves one step and its release adds no second click",
		stepper.value == 5 and heard.only(cfg.click, UI_BUS), "value %d, heard %s" % [stepper.value, heard.text()])
	heard.clear()
	sides.clear()
	stepper.plus_button.button_down.emit()
	var shaking: bool = stepper.is_rejecting() and stepper.rejected_side() == 1
	stepper.step_hold(1.0)
	stepper.plus_button.pressed.emit()
	stepper.plus_button.button_up.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "plus at the ceiling shakes, arms no hold and plays only the reject on the event bus",
		stepper.value == 5 and shaking and sides.size() == 1 and sides[0] == 1 and heard.only(cfg.reject, EVENT_BUS),
		"value %d, shaking %s, sides %s, heard %s" % [stepper.value, shaking, sides, heard.text()])
	stepper.end_reject()
	stepper.step = 2
	stepper.set_value_silent(4)
	sides.clear()
	await _drain(host, heard)
	stepper.press_plus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a step 2 press from 4 under a ceiling of 5 lands on 5 and plays only the reject",
		stepper.value == 5 and sides.size() == 1 and sides[0] == 1 and heard.only(cfg.reject, EVENT_BUS),
		"value %d, sides %s, heard %s" % [stepper.value, sides, heard.text()])
	stepper.step = 1
	stepper.end_reject()
	stepper.max_value = 100
	stepper.set_value_silent(0)
	sides.clear()
	await _drain(host, heard)
	moves.clear()
	stepper.hold_start(1)
	stepper.set_process(false)
	var clicks: int = 0
	var stray: int = 0
	var most: int = 0
	for _i: int in 60:
		var was: int = moves.size()
		stepper.step_hold(1.0 / 60.0)
		most = maxi(most, moves.size() - was)
		await host.get_tree().process_frame
		clicks += _heard_from(heard, cfg.click, UI_BUS)
		stray += heard.size() - heard.hits(cfg.click)
		heard.clear()
	TestFixtures.check(res, "one second of hold steps at least 8 times, at most once a slice, with one click per step",
		moves.size() >= 8 and most <= 1 and clicks == moves.size() and stray == 0 and sides.is_empty(),
		"%d moves, most %d in a slice, %d clicks, %d other plays, sides %s" % [moves.size(), most, clicks, stray, sides])
	stepper.max_value = stepper.value + 2
	var top: int = stepper.max_value
	clicks = 0
	var rejects: int = 0
	var guard: int = 30
	while not stepper.is_rejecting() and guard > 0:
		guard -= 1
		stepper.step_hold(1.0 / 60.0)
		await host.get_tree().process_frame
		clicks += _heard_from(heard, cfg.click, UI_BUS)
		rejects += _heard_from(heard, cfg.reject, EVENT_BUS)
		heard.clear()
	#A hold that did not stop would step into the ceiling again here and report a second reject.
	stepper.step_hold(1.0)
	TestFixtures.check(res, "a hold run into the ceiling clicks twice more, then plays one reject and stops",
		stepper.value == top and clicks == 2 and rejects == 1 and sides.size() == 1 and sides[0] == 1,
		"value %d of %d, %d clicks, %d rejects, sides %s" % [stepper.value, top, clicks, rejects, sides])
	stepper.end_reject()
	stepper.reject_seconds = 0.0
	sides.clear()
	await _drain(host, heard)
	stepper.press_plus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "at reject_seconds 0 a press at the ceiling plays nothing and reports no reject",
		stepper.value == top and heard.size() == 0 and sides.is_empty() and not stepper.is_rejecting(),
		"value %d, sides %s, heard %s" % [stepper.value, sides, heard.text()])
	stepper.queue_free()
	await _drain(host, heard)


#PayrollStepper: silent release clicks on all four buttons, one click per tick, the reject alone at the max and
#click_disabled alone on a disabled button.
static func _case_payroll_steps(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var pay: PayrollStepper = (load(PAYROLL_STEPPER_SCENE) as PackedScene).instantiate() as PayrollStepper
	host.add_child(pay)
	await host.get_tree().process_frame
	var sides: Array[int] = []
	pay.rejected.connect(func(side: int) -> void: sides.append(side))
	var buttons: Array[Button] = [pay.minus_button, pay.plus_button, pay.minus_small, pay.plus_small]
	var loud: PackedStringArray = PackedStringArray()
	for button: Button in buttons:
		if UiSfx.click_library(button) != null:
			loud.append(String(button.name))
	TestFixtures.check(res, "the payroll stepper silences the release click of all four buttons",
		loud.is_empty(), "still clicking: %s" % ", ".join(loud))
	pay.max_value = 10
	pay.set_value_silent(5)
	await _drain(host, heard)
	pay.plus_button.button_down.emit()
	pay.plus_button.pressed.emit()
	pay.plus_button.button_up.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a full payroll plus click ticks 5 to 6 and plays one click on UI",
		pay.value == 6 and heard.only(cfg.click, UI_BUS), "value %d, heard %s" % [pay.value, heard.text()])
	pay.set_value_silent(10)
	heard.clear()
	sides.clear()
	pay.press_plus()
	var shaking: bool = pay.is_rejecting() and pay.rejected_side() == 1
	await host.get_tree().process_frame
	TestFixtures.check(res, "payroll plus at the max shakes and plays only the reject on the event bus",
		pay.value == 10 and shaking and sides.size() == 1 and sides[0] == 1 and heard.only(cfg.reject, EVENT_BUS),
		"value %d, shaking %s, sides %s, heard %s" % [pay.value, shaking, sides, heard.text()])
	pay.step = 2
	pay.set_value_silent(9)
	sides.clear()
	await _drain(host, heard)
	pay.press_plus()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a step 2 payroll press from 9 under a max of 10 lands on 10 and plays only the reject",
		pay.value == 10 and sides.size() == 1 and sides[0] == 1 and heard.only(cfg.reject, EVENT_BUS),
		"value %d, sides %s, heard %s" % [pay.value, sides, heard.text()])
	pay.disabled = true
	await _drain(host, heard)
	var on_plus: InputEventMouseButton = _left_press(true)
	on_plus.position = pay.get_global_transform().affine_inverse() * pay.plus_button.get_global_rect().get_center()
	pay._gui_input(on_plus)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a left press on a disabled payroll stepper's plus button plays only click_disabled",
		pay.value == 10 and heard.only(cfg.click_disabled, UI_BUS), "value %d, heard %s" % [pay.value, heard.text()])
	heard.clear()
	var on_box: InputEventMouseButton = _left_press(true)
	on_box.position = pay.get_global_transform().affine_inverse() * pay.middle.get_global_rect().get_center()
	pay._gui_input(on_box)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a left press on a disabled payroll stepper's value box plays nothing",
		heard.size() == 0, heard.text())
	pay.queue_free()
	await _drain(host, heard)


#UpgradeTierDialog hold-repeat, walked down from the top tier: a raise also needs budget a fresh game may lack.
static func _case_tier_hold(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	SubscriptionManager.max_out()
	var id: String = ""
	for each: String in UpgradeDefs.ORDER:
		if each != "seats" and each != "contracts" and UpgradeDefs.tier_count(each) >= 4:
			id = each
			break
	var dlg: UpgradeTierDialog = (load(TIER_SCENE) as PackedScene).instantiate() as UpgradeTierDialog
	host.add_child(dlg)
	await host.get_tree().process_frame
	dlg.open_for(id)
	await _drain(host, heard)
	var top: int = dlg.max_tier()
	dlg._minus.button_down.emit()
	dlg._minus.pressed.emit()
	dlg._minus.button_up.emit()
	var press_tier: int = dlg.tier()
	var left_armed: bool = dlg.is_holding() or dlg.is_processing()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a full minus click drops one tier, plays only the upgrade cue on UI and leaves no hold",
		id != "" and top >= 4 and press_tier == top - 1 and not left_armed and heard.only(cfg.upgrade_click, UI_BUS),
		"id '%s', tier %d of %d, armed %s, heard %s" % [id, press_tier, top, left_armed, heard.text()])
	SubscriptionManager.max_out()
	await _drain(host, heard)
	dlg.hold_begin(-1)
	var armed: bool = dlg.is_holding() and dlg.is_processing()
	dlg.set_process(false)
	var first_tier: int = dlg.tier()
	await host.get_tree().process_frame
	var pitches: Array[float] = _heard_pitches(heard, cfg.upgrade_click)
	TestFixtures.check(res, "hold_begin(-1) steps once right away, plays one upgrade cue and arms the repeat",
		first_tier == top - 1 and armed and heard.only(cfg.upgrade_click, UI_BUS),
		"tier %d of %d, armed %s, heard %s" % [first_tier, top, armed, heard.text()])
	heard.clear()
	dlg.step_hold(UpgradeTierDialog.HOLD_DELAY)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a held minus steps nothing and plays nothing until HOLD_DELAY has passed",
		dlg.tier() == top - 1 and dlg.is_holding() and heard.size() == 0,
		"tier %d, holding %s, heard %s" % [dlg.tier(), dlg.is_holding(), heard.text()])
	var per_slice: Array[int] = []
	for _i: int in 3:
		heard.clear()
		dlg.step_hold(TIER_SLICE)
		await host.get_tree().process_frame
		per_slice.append(_heard_from(heard, cfg.upgrade_click, UI_BUS))
		pitches.append_array(_heard_pitches(heard, cfg.upgrade_click))
	var falling: bool = pitches.size() == 4
	for i: int in range(1, pitches.size()):
		falling = falling and pitches[i] < pitches[i - 1]
	var last_ok: bool = (not pitches.is_empty()
		and is_equal_approx(pitches[pitches.size() - 1], UiSfx.pitch_for(dlg.upgrade_ratio())))
	TestFixtures.check(res, "three repeat slices step one tier each, one upgrade cue apiece at a falling pitch",
		dlg.tier() == top - 4 and per_slice.size() == 3 and per_slice.count(1) == 3 and falling and last_ok,
		"tier %d of %d, cues per slice %s, pitches %s" % [dlg.tier(), top, per_slice, pitches])
	var more: int = 0
	var rejects: int = 0
	var stray: int = 0
	var kind: String = ""
	var guard: int = top + 2
	heard.clear()
	while dlg.is_holding() and guard > 0:
		guard -= 1
		dlg.step_hold(TIER_SLICE)
		if not dlg.is_holding():
			kind = dlg.reject_kind()
		await host.get_tree().process_frame
		more += _heard_from(heard, cfg.upgrade_click, UI_BUS)
		rejects += _heard_from(heard, cfg.reject, EVENT_BUS)
		stray += heard.size() - heard.hits(cfg.upgrade_click) - heard.hits(cfg.reject)
		heard.clear()
	TestFixtures.check(res, "the hold walks down to tier 0, then the refused step plays one reject and ends the hold",
		dlg.tier() == 0 and more == top - 4 and rejects == 1 and stray == 0 and kind == "down"
			and not dlg.is_holding() and not dlg.is_processing(),
		"tier %d, %d more cues, %d rejects, %d other plays, kind '%s', holding %s" % [dlg.tier(), more, rejects,
			stray, kind, dlg.is_holding()])
	dlg.step_hold(1.0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a slice after the refusal steps nothing and plays nothing",
		dlg.tier() == 0 and heard.size() == 0, "tier %d, heard %s" % [dlg.tier(), heard.text()])
	SubscriptionManager.max_out()
	await _drain(host, heard)
	dlg.hold_begin(1)
	var up_armed: bool = dlg.is_holding() or dlg.is_processing()
	var up_kind: String = dlg.reject_kind()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hold_begin(1) at the top tier plays only the reject and arms nothing",
		dlg.tier() == top and not up_armed and up_kind == "up" and heard.only(cfg.reject, EVENT_BUS),
		"tier %d of %d, armed %s, kind '%s', heard %s" % [dlg.tier(), top, up_armed, up_kind, heard.text()])
	dlg.hold_begin(-1)
	var was_holding: bool = dlg.is_holding()
	dlg.close()
	TestFixtures.check(res, "closing the dialog mid hold ends the hold and its processing",
		was_holding and not dlg.is_holding() and not dlg.is_processing(),
		"holding before %s, after %s, processing %s" % [was_holding, dlg.is_holding(), dlg.is_processing()])
	dlg.queue_free()
	GuiFrameStack.clear()
	SubscriptionManager.max_out()
	await _drain(host, heard)


static func _case_summon_dismiss(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate() as SubWindow
	host.add_child(win)
	await host.get_tree().process_frame
	heard.clear()
	win.present()
	await host.get_tree().process_frame
	TestFixtures.check(res, "presenting a hidden window plays summon_window on UI",
		win.is_open() and heard.only(cfg.summon_window, UI_BUS), heard.text())
	heard.clear()
	win.present()
	await host.get_tree().process_frame
	TestFixtures.check(res, "presenting an open window again plays nothing", heard.size() == 0, heard.text())
	heard.clear()
	win.close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing an open window plays dismiss_window on UI",
		not win.is_open() and heard.only(cfg.dismiss_window, UI_BUS), heard.text())
	heard.clear()
	win.close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing a hidden window plays nothing", heard.size() == 0, heard.text())
	heard.clear()
	win.summon_sfx = cfg.equip
	win.dismiss_sfx = cfg.unequip
	win.present()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a window's summon_sfx replaces summon_window", heard.only(cfg.equip, UI_BUS),
		heard.text())
	heard.clear()
	win.close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a window's dismiss_sfx replaces dismiss_window", heard.only(cfg.unequip, UI_BUS),
		heard.text())
	heard.clear()
	UiSfx.play_summon()
	UiSfx.play_dismiss(cfg.permit)
	await host.get_tree().process_frame
	TestFixtures.check(res, "play_summon with no library plays summon_window; play_dismiss plays the one given",
		heard.size() == 2 and heard.hits(cfg.summon_window) == 1 and heard.hits(cfg.permit) == 1,
		heard.text())
	win.queue_free()
	GuiFrameStack.clear()


static func _case_dispatched(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var trip := ActiveRun.new()
	trip.travel_mode = "foot"
	heard.clear()
	GameState.dispatched.emit(trip)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a dispatch on foot plays dispatch_foot on Sound Effects",
		heard.only(cfg.dispatch_foot, EVENT_BUS), heard.text())
	var own: Dictionary = _own_dispatch(cfg)
	for key: String in own:
		trip.travel_mode = key
		heard.clear()
		GameState.dispatched.emit(trip)
		await host.get_tree().process_frame
		TestFixtures.check(res, "a dispatch by %s plays dispatch_%s on Sound Effects" % [key, key],
			heard.only(own[key] as SoundLibrary, EVENT_BUS), heard.text())
	trip.travel_mode = "horse"
	heard.clear()
	GameState.dispatched.emit(trip)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a dispatch by horse falls back to dispatch_foot",
		heard.only(cfg.dispatch_foot, EVENT_BUS), heard.text())
	heard.clear()
	GameSfx.play_dispatch("horse")
	GameSfx.play_dispatch("nonsense")
	await host.get_tree().process_frame
	TestFixtures.check(res, "two fallback dispatches in one frame play dispatch_foot once",
		heard.only(cfg.dispatch_foot, EVENT_BUS), heard.text())


static func _case_results(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var won: ContractResultData = _result(false, [ResultMemberData.Fate.ALIVE, ResultMemberData.Fate.DEAD])
	var lost: ContractResultData = _result(true, [ResultMemberData.Fate.CAPTURED])
	var clean: ContractResultData = _result(false, [ResultMemberData.Fate.ALIVE])
	var grim: ContractResultData = _result(true, [ResultMemberData.Fate.CAPTURED, ResultMemberData.Fate.DEAD])
	var want_won: Array[SoundLibrary] = [cfg.contract_success, cfg.dead]
	var want_lost: Array[SoundLibrary] = [cfg.contract_failure, cfg.captured]
	var want_clean: Array[SoundLibrary] = [cfg.contract_success]
	var want_grim: Array[SoundLibrary] = [cfg.contract_failure, cfg.dead, cfg.captured]
	TestFixtures.check(res, "a success with a dead member cues success then dead",
		GameSfx.result_libraries(won) == want_won, _names(GameSfx.result_libraries(won)))
	TestFixtures.check(res, "a failure with a captured member cues failure then captured",
		GameSfx.result_libraries(lost) == want_lost, _names(GameSfx.result_libraries(lost)))
	TestFixtures.check(res, "a success where everyone lived cues success alone",
		GameSfx.result_libraries(clean) == want_clean, _names(GameSfx.result_libraries(clean)))
	TestFixtures.check(res, "a failure with both fates cues failure, dead, captured",
		GameSfx.result_libraries(grim) == want_grim, _names(GameSfx.result_libraries(grim)))
	heard.clear()
	GameSfx.play_result(won)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a settled contract plays its outcome cue at once and alone",
		heard.only(cfg.contract_success, EVENT_BUS), heard.text())
	await host.get_tree().create_timer(GameSfx.RESULT_FOLLOW_SECONDS + 0.2).timeout
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "the dead cue follows RESULT_FOLLOW_SECONDS later on Sound Effects",
		heard.size() == 2 and heard.hits(cfg.dead) == 1 and cfg.dead.sounds.has(heard.streams[1])
		and heard.buses[1] == EVENT_BUS, heard.text())
	heard.clear()
	GameSfx.play_result(grim)
	await host.get_tree().process_frame
	var first: String = heard.text()
	var first_ok: bool = heard.only(cfg.contract_failure, EVENT_BUS)
	await host.get_tree().create_timer(GameSfx.RESULT_FOLLOW_SECONDS + 0.2).timeout
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a failure with both fates plays failure, then dead and captured together",
		first_ok and heard.size() == 3 and heard.hits(cfg.dead) == 1 and heard.hits(cfg.captured) == 1,
		"first %s; all %s" % [first, heard.text()])
	heard.clear()


static func _case_notices(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var info: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_LOAN_OFFER,
		NotificationData.Urgency.INFORMATIONAL))
	TestFixtures.check(res, "an informational notice plays message_basic", info == cfg.message_basic,
		_name_of(info))
	var important: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_LOAN_OFFER,
		NotificationData.Urgency.IMPORTANT))
	TestFixtures.check(res, "an important notice plays alert_neutral", important == cfg.alert_neutral,
		_name_of(important))
	var urgent: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_LOAN_OFFER,
		NotificationData.Urgency.URGENT))
	TestFixtures.check(res, "an urgent notice plays alert_bad", urgent == cfg.alert_bad, _name_of(urgent))
	var settled: Array[String] = []
	for urgency: int in [NotificationData.Urgency.INFORMATIONAL, NotificationData.Urgency.URGENT]:
		var won: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_CONTRACT_COMPLETED, urgency))
		var lost: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_CONTRACT_FAILED, urgency))
		if won != cfg.alert_neutral:
			settled.append("completed at %d plays %s" % [urgency, _name_of(won)])
		if lost != cfg.alert_neutral:
			settled.append("failed at %d plays %s" % [urgency, _name_of(lost)])
	TestFixtures.check(res, "a completed or failed contract notice plays alert_neutral at any urgency",
		settled.is_empty(), TestFixtures.detail(settled, 4, "rows"))
	var up: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_STOCK_MOVE,
		NotificationData.Urgency.INFORMATIONAL, _stock_snap(4.2)))
	var down: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_STOCK_MOVE,
		NotificationData.Urgency.INFORMATIONAL, _stock_snap(-4.2)))
	TestFixtures.check(res, "a rising stock move plays alert_positive and a falling one message_basic",
		up == cfg.alert_positive and down == cfg.message_basic, "%s, %s" % [_name_of(up), _name_of(down)])
	heard.clear()
	NotificationCenter.push(NotificationData.TYPE_LOAN_OFFER, 1, {}, NotificationData.Urgency.URGENT)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an urgent push plays alert_bad on Sound Effects",
		heard.only(cfg.alert_bad, EVENT_BUS), heard.text())
	heard.clear()
	NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, 0, _stock_snap(2.5),
		NotificationData.Urgency.INFORMATIONAL)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a rising stock move push plays alert_positive", heard.only(cfg.alert_positive, EVENT_BUS),
		heard.text())
	heard.clear()
	NotificationCenter.push(NotificationData.TYPE_CONTRACT_COMPLETED, 2, {}, NotificationData.Urgency.IMPORTANT)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a contract completed push plays alert_neutral on Sound Effects",
		heard.only(cfg.alert_neutral, EVENT_BUS), heard.text())
	NotificationCenter.reset()
	await host.get_tree().process_frame
	heard.clear()


static func _case_events(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	heard.clear()
	GameState.money_moved.emit(10, "test")
	await host.get_tree().process_frame
	TestFixtures.check(res, "money coming in plays money on Sound Effects", heard.only(cfg.money, EVENT_BUS),
		heard.text())
	heard.clear()
	GameState.money_moved.emit(-25, "test")
	await host.get_tree().process_frame
	TestFixtures.check(res, "money going out plays money too", heard.only(cfg.money, EVENT_BUS), heard.text())
	heard.clear()
	GameState.money_moved.emit(0, "test")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a zero money move plays nothing", heard.size() == 0, heard.text())
	heard.clear()
	GameState.contracts_posted.emit(2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "new postings emitted alone play no cue of their own", heard.size() == 0, heard.text())
	heard.clear()
	GameState.contract_rejected.emit(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a rejected contract plays reject", heard.only(cfg.reject, EVENT_BUS), heard.text())
	heard.clear()
	LegalManager.permit_granted.emit(1, &"test")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a granted permit plays permit", heard.only(cfg.permit, EVENT_BUS), heard.text())
	heard.clear()
	GameSfx.play_mercdave_text()
	await host.get_tree().process_frame
	TestFixtures.check(res, "play_mercdave_text queues mercdave_text on the Sound Effects bus",
		_heard_from(heard, cfg.mercdave_text, EVENT_BUS) == 1, heard.text())
	heard.clear()
	var spoke_hooked: bool = Mercdave.spoke.is_connected(GameSfx.play_mercdave_text)
	TestFixtures.check(res, "Mercdave.spoke reaches GameSfx.play_mercdave_text", spoke_hooked,
		"connected %s" % spoke_hooked)
	UiSfx.play_equip()
	await host.get_tree().process_frame
	var equip_ok: bool = heard.only(cfg.equip, UI_BUS)
	var equip_text: String = heard.text()
	heard.clear()
	UiSfx.play_unequip()
	await host.get_tree().process_frame
	TestFixtures.check(res, "equip and unequip play their own libraries on UI",
		equip_ok and heard.only(cfg.unequip, UI_BUS), "%s; %s" % [equip_text, heard.text()])
	heard.clear()
	GameState.money_moved.emit(5, "test")
	GameState.contracts_posted.emit(1)
	GameState.contract_rejected.emit(3)
	LegalManager.permit_granted.emit(2, &"test")
	GameState.money_moved.emit(7, "test")
	await host.get_tree().process_frame
	TestFixtures.check(res, "five event signals in one frame play money, reject and permit once each and no posting cue",
		heard.size() == 3 and heard.hits(cfg.money) == 1 and heard.hits(cfg.new_contract) == 0
		and heard.hits(cfg.reject) == 1 and heard.hits(cfg.permit) == 1, heard.text())
	heard.clear()


static func _case_graph(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var chart: LineChart = (load(CHART_SCENE) as PackedScene).instantiate() as LineChart
	chart.tween_seconds = 0.4
	chart.custom_minimum_size = Vector2(480.0, 240.0)
	host.add_child(chart)
	await host.get_tree().process_frame
	heard.clear()
	chart.set_series(_series(["cash"], 4))
	await host.get_tree().process_frame
	var drawing: AudioStreamPlayer = GameSfx.graph_player()
	TestFixtures.check(res, "a chart drawing in a fresh metric set plays graph_draw on Sound Effects at GRAPH_DB",
		heard.only(cfg.graph_draw, EVENT_BUS) and is_equal_approx(heard.volumes[0], GameSfx.GRAPH_DB),
		"%s; volumes %s" % [heard.text(), str(heard.volumes)])
	TestFixtures.check(res, "the draw cue fades out with the reveal", drawing != null and AudioManager.fading(drawing),
		_player_text(drawing))
	heard.clear()
	chart.set_series(_series(["cash"], 6))
	await host.get_tree().process_frame
	TestFixtures.check(res, "new points for the same metrics redraw without a sound", heard.size() == 0,
		heard.text())
	heard.clear()
	var second: LineChart = (load(CHART_SCENE) as PackedScene).instantiate() as LineChart
	second.tween_seconds = 0.4
	host.add_child(second)
	await host.get_tree().process_frame
	heard.clear()
	second.set_series(_series(["cash"], 4))
	await host.get_tree().process_frame
	TestFixtures.check(res, "a second chart revealing while a draw cue plays stays silent", heard.size() == 0,
		heard.text())
	second.queue_free()
	AudioManager.stop_all()
	var hidden: LineChart = (load(CHART_SCENE) as PackedScene).instantiate() as LineChart
	hidden.tween_seconds = 0.4
	hidden.visible = false
	host.add_child(hidden)
	await host.get_tree().process_frame
	heard.clear()
	hidden.set_series(_series(["cash"], 4))
	await host.get_tree().process_frame
	var silent_hidden: bool = heard.size() == 0
	hidden.visible = true
	await host.get_tree().process_frame
	TestFixtures.check(res, "a hidden chart holds its reveal and its draw cue until it shows",
		silent_hidden and heard.only(cfg.graph_draw, EVENT_BUS), heard.text())
	hidden.queue_free()
	AudioManager.stop_all()
	heard.clear()
	chart.set_series(_series(["cash", "fame"], 6))
	await host.get_tree().process_frame
	TestFixtures.check(res, "adding a metric draws the chart in again with graph_draw",
		heard.only(cfg.graph_draw, EVENT_BUS), heard.text())
	heard.clear()
	chart.set_series(_series(["gone"], 0))
	await host.get_tree().process_frame
	TestFixtures.check(res, "a chart with no points stays silent", heard.size() == 0, heard.text())
	var still: LineChart = (load(CHART_SCENE) as PackedScene).instantiate() as LineChart
	still.tween_seconds = 0.0
	host.add_child(still)
	await host.get_tree().process_frame
	heard.clear()
	still.set_series(_series(["cash"], 4))
	await host.get_tree().process_frame
	TestFixtures.check(res, "a chart with no reveal tween draws without a sound", heard.size() == 0,
		heard.text())
	chart.queue_free()
	still.queue_free()
	await host.get_tree().process_frame
	heard.clear()


#Money moved by the running clock stays silent; a direct spend or refund and every cued payout fly play money.
static func _case_money_gate(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	await _drain(host, heard)
	GameState._clock_depth = 1
	var moving: bool = GameState.clock_moving()
	GameState.money_moved.emit(-40, "test")
	GameState.money_moved.emit(60, "test")
	GameState._clock_depth = 0
	await host.get_tree().process_frame
	TestFixtures.check(res, "money moved while the clock runs plays nothing",
		moving and not GameState.clock_moving() and heard.size() == 0, heard.text())
	heard.clear()
	GameState.refund(25, "test")
	await host.get_tree().process_frame
	var refund_ok: bool = heard.only(cfg.money, EVENT_BUS)
	var refund_text: String = heard.text()
	heard.clear()
	var spent: bool = GameState.spend(25, "test")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a direct refund and a direct spend each play money on Sound Effects",
		refund_ok and spent and heard.only(cfg.money, EVENT_BUS), "%s; %s" % [refund_text, heard.text()])
	heard.clear()
	for _i: int in 20:
		GameSfx.play_money(10)
		await host.get_tree().process_frame
	var low: float = INF
	var high: float = -INF
	var off: Array[String] = []
	for pitch: float in heard.pitches:
		low = minf(low, pitch)
		high = maxf(high, pitch)
		if pitch < GameSfx.MONEY_PITCH_LOW or pitch > GameSfx.MONEY_PITCH_HIGH:
			off.append("%.3f" % pitch)
	TestFixtures.check(res, "twenty money cues land between 0.85 and 1.15 at more than one pitch",
		heard.size() == 20 and heard.hits(cfg.money) == 20 and off.is_empty() and high - low > 0.01,
		"%d heard from %.3f to %.3f; %s" % [heard.size(), low, high, TestFixtures.detail(off, 20, "pitches")])
	heard.clear()
	GameState.fly_money(50)
	await host.get_tree().process_frame
	var in_ok: bool = heard.only(cfg.money, EVENT_BUS)
	var in_text: String = heard.text()
	heard.clear()
	GameState.fly_money(-50)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a payout fly plays money coming in and going out",
		in_ok and heard.only(cfg.money, EVENT_BUS), "%s; %s" % [in_text, heard.text()])
	heard.clear()
	GameState._clock_depth = 1
	GameState.fly_money(30)
	GameState._clock_depth = 0
	await host.get_tree().process_frame
	TestFixtures.check(res, "a payout fly plays money even while the clock runs",
		heard.only(cfg.money, EVENT_BUS), heard.text())
	heard.clear()
	GameState.fly_money(0)
	GameSfx.play_money(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a zero fly or a zero money cue plays nothing", heard.size() == 0, heard.text())
	heard.clear()


#A money cue sharing a frame with a direct-action cue plays at -6 dB; the action cue keeps full volume.
static func _case_money_stack(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	await _drain(host, heard)
	GameSfx.play_dispatch("foot")
	GameSfx.play_money(-30)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a dispatch then money in one frame play together, money at -6 dB and the dispatch at 0",
		heard.size() == 2 and is_equal_approx(heard.volume_of(cfg.money), GameSfx.STACKED_MONEY_DB)
			and is_equal_approx(heard.volume_of(cfg.dispatch_foot), 0.0),
		"%s; volumes %s" % [heard.text(), str(heard.volumes)])
	heard.clear()
	GameState.money_moved.emit(-20, "test")
	LegalManager.permit_granted.emit(1, &"test")
	await host.get_tree().process_frame
	TestFixtures.check(res, "money then a permit in one frame drops the money to -6 dB and keeps the permit at 0",
		heard.size() == 2 and is_equal_approx(heard.volume_of(cfg.money), GameSfx.STACKED_MONEY_DB)
			and is_equal_approx(heard.volume_of(cfg.permit), 0.0),
		"%s; volumes %s" % [heard.text(), str(heard.volumes)])
	heard.clear()
	GameSfx.play_money(40)
	var pitch: float = GameSfx._money_pitch
	GameSfx.note_action_cue()
	await host.get_tree().process_frame
	TestFixtures.check(res, "an action cue after money in one frame keeps one money cue at -6 dB and its pitch",
		heard.only(cfg.money, EVENT_BUS) and heard.pitch_is(pitch)
			and is_equal_approx(heard.volumes[0], GameSfx.STACKED_MONEY_DB),
		"%s; volumes %s" % [heard.text(), str(heard.volumes)])
	heard.clear()
	GameSfx.note_action_cue()
	await host.get_tree().process_frame
	var lone: int = heard.size()
	GameSfx.play_money(15)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an action cue alone plays nothing and money a frame later plays at full volume",
		lone == 0 and heard.only(cfg.money, EVENT_BUS) and is_equal_approx(heard.volumes[0], 0.0),
		"%s; volumes %s" % [heard.text(), str(heard.volumes)])
	heard.clear()


#The volume rides through play, play_library and the frame queue; unqueue drops a cue still waiting.
static func _case_volume_queue(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var stream: AudioStream = cfg.click.sounds[0]
	await _drain(host, heard)
	AudioManager.stop_all()
	var player: AudioStreamPlayer = AudioManager.play(stream, UI_BUS, 1.0, -6.0)
	TestFixtures.check(res, "play sets the player volume and records it in last, last_volume_db and the callback",
		player != null and is_equal_approx(player.volume_db, -6.0)
			and is_equal_approx(float(AudioManager.last.get("volume_db", 0.0)), -6.0)
			and is_equal_approx(AudioManager.last_volume_db, -6.0)
			and heard.size() == 1 and is_equal_approx(heard.volumes[0], -6.0),
		"%s; volumes %s" % [_player_text(player), str(heard.volumes)])
	if player != null:
		player.stop()
	var again: AudioStreamPlayer = AudioManager.play(stream, UI_BUS)
	TestFixtures.check(res, "the next play on the same pool player is back at full volume",
		again != null and again == player and is_equal_approx(again.volume_db, 0.0)
			and is_equal_approx(AudioManager.last_volume_db, 0.0),
		"%s; last %.1f dB" % [_player_text(again), AudioManager.last_volume_db])
	heard.clear()
	AudioManager.play_library(cfg.click, UI_BUS, 1.0, -4.0)
	TestFixtures.check(res, "play_library passes the volume through",
		heard.only(cfg.click, UI_BUS) and is_equal_approx(heard.volumes[0], -4.0), str(heard.volumes))
	AudioManager.stop_all()
	heard.clear()
	AudioManager.queue(cfg.money, EVENT_BUS, 1.0, -3.0)
	AudioManager.queue(cfg.money, EVENT_BUS, 1.0, -9.0)
	AudioManager.flush()
	TestFixtures.check(res, "a repeat queue before the flush replaces the volume and plays once",
		heard.only(cfg.money, EVENT_BUS) and is_equal_approx(heard.volumes[0], -9.0), str(heard.volumes))
	heard.clear()
	AudioManager.queue(cfg.money)
	var dropped: bool = AudioManager.unqueue(cfg.money)
	var twice: bool = AudioManager.unqueue(cfg.money)
	var pending: int = AudioManager.pending_count()
	await host.get_tree().process_frame
	TestFixtures.check(res, "unqueue drops a waiting cue once, a null library drops nothing and nothing plays",
		dropped and not twice and not AudioManager.unqueue(null) and pending == 0 and heard.size() == 0,
		"dropped %s, again %s, pending %d, heard %s" % [dropped, twice, pending, heard.text()])
	heard.clear()
	AudioManager.queue(cfg.money)
	AudioManager.queue(cfg.permit)
	AudioManager.unqueue(cfg.money)
	await host.get_tree().process_frame
	TestFixtures.check(res, "unqueue leaves the other waiting libraries alone",
		heard.only(cfg.permit, EVENT_BUS), heard.text())
	AudioManager.stop_all()
	heard.clear()


#A notice cue fires once per arrival: a row pushed already alerted stays silent, every raise and read re-fire
#alerts except the first raise of a seeded trigger, and a new game opens without a notice cue.
static func _case_alerted(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var probe := &"soundDeadline"
	var saved: Dictionary = NotificationCenter.rules.duplicate()
	NotificationCenter.rules.clear()
	NotificationCenter.reset()
	await _drain(host, heard)
	var pushes: Array[int] = []
	var on_push: Callable = func(pushed_row: NotificationData) -> void: pushes.append(pushed_row.id)
	NotificationCenter.pushed.connect(on_push)
	var quiet: NotificationData = NotificationCenter.push(NotificationData.TYPE_LOAN_OFFER, 1, {},
		NotificationData.Urgency.URGENT, "", true)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a push that arrives already alerted plays nothing yet still reaches pushed",
		heard.size() == 0 and quiet.alerted and pushes.size() == 1 and pushes[0] == quiet.id,
		"%s; %d pushes" % [heard.text(), pushes.size()])
	NotificationCenter.pushed.disconnect(on_push)
	var hours: Dictionary = {7: 10.0}
	var open_fn: Callable = func() -> Array: return hours.keys()
	var hours_fn: Callable = func(trigger: int) -> float: return float(hours.get(trigger, 200.0))
	NotificationCenter.add_rule(probe, {"open": open_fn, "hours_left": hours_fn, "kind": "Finance"})
	var now: int = CampaignClock.now()
	var refire: int = now + NotificationCenter.REFIRE_MINUTES
	heard.clear()
	NotificationCenter.escalate(now)
	await host.get_tree().process_frame
	var raised: NotificationData = NotificationCenter.latest(probe, 7)
	TestFixtures.check(res, "a deadline going urgent plays alert_bad once",
		raised != null and raised.alerted and heard.only(cfg.alert_bad, EVENT_BUS), heard.text())
	heard.clear()
	NotificationCenter.escalate(refire)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unread urgent row stays silent at the re-fire mark", heard.size() == 0, heard.text())
	if raised != null:
		NotificationCenter.mark_read(raised.id)
	heard.clear()
	NotificationCenter.escalate(refire)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a read urgent row re-fires eight hours on with alert_bad",
		heard.only(cfg.alert_bad, EVENT_BUS) and NotificationCenter.latest(probe, 7) != raised, heard.text())
	hours[9] = 10.0
	NotificationCenter.mark_seeded(probe, 9)
	heard.clear()
	NotificationCenter.escalate(now)
	await host.get_tree().process_frame
	var seeded: NotificationData = NotificationCenter.latest(probe, 9)
	TestFixtures.check(res, "the first raise of a seeded trigger is silent and arrives alerted",
		seeded != null and seeded.alerted and seeded.urgency == NotificationData.Urgency.URGENT
			and heard.size() == 0, heard.text())
	if seeded != null:
		NotificationCenter.mark_read(seeded.id)
	heard.clear()
	NotificationCenter.escalate(refire)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the next re-fire of the seeded trigger plays alert_bad",
		heard.only(cfg.alert_bad, EVENT_BUS), heard.text())
	NotificationCenter.remove_rule(probe)
	for key: Variant in saved.keys():
		NotificationCenter.add_rule(StringName(key), saved[key])
	FinanceManager._register_rule()
	heard.clear()
	_fresh()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var offer_rows: int = _offer_rows()
	var notice_hits: int = (heard.hits(cfg.message_basic) + heard.hits(cfg.alert_neutral)
		+ heard.hits(cfg.alert_bad) + heard.hits(cfg.alert_positive))
	TestFixtures.check(res, "a new game opens without a notice cue and holds no loan offer or offer row",
		notice_hits == 0 and offer_rows == 0 and FinanceManager.offers.is_empty(),
		"%d offer rows, %d offers; %s" % [offer_rows, FinanceManager.offers.size(), heard.text()])
	heard.clear()
	NotificationCenter.escalate(CampaignClock.now())
	await host.get_tree().process_frame
	TestFixtures.check(res, "the first escalate of a new game raises no offer row and plays no cue",
		_offer_rows() == 0 and heard.size() == 0, "%d offer rows; %s" % [_offer_rows(), heard.text()])
	heard.clear()


#How many bell rows carry a loan offer.
static func _offer_rows() -> int:
	var count: int = 0
	for row: NotificationData in NotificationCenter.items:
		if row.type == NotificationData.TYPE_LOAN_OFFER:
			count += 1
	return count


#Good news chimes alert_positive at any urgency; a failed contract notice stays silent.
static func _case_positive(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var approved_snap: Dictionary = {"approved": true}
	var refused_snap: Dictionary = {"approved": false}
	var approved: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_LOAN_OFFER,
		NotificationData.Urgency.INFORMATIONAL, approved_snap))
	var refused: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_LOAN_OFFER,
		NotificationData.Urgency.INFORMATIONAL, refused_snap))
	TestFixtures.check(res, "an approved loan offer plays alert_positive and a refused one message_basic",
		approved == cfg.alert_positive and refused == cfg.message_basic,
		"%s, %s" % [_name_of(approved), _name_of(refused)])
	var important: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_LOAN_OFFER,
		NotificationData.Urgency.IMPORTANT, approved_snap))
	var urgent: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_LOAN_OFFER,
		NotificationData.Urgency.URGENT, approved_snap))
	TestFixtures.check(res, "an important or urgent approved offer plays alert_positive",
		important == cfg.alert_positive and urgent == cfg.alert_positive,
		"%s, %s" % [_name_of(important), _name_of(urgent)])
	var wrong: Array[String] = []
	for offer_row: Dictionary in GuiLoanTests.FIXTURE_OFFERS:
		var library: SoundLibrary = GameSfx.notice_library(_notice(NotificationData.TYPE_LOAN_OFFER,
			NotificationData.Urgency.INFORMATIONAL, offer_row))
		var want: SoundLibrary = cfg.alert_positive if bool(offer_row["approved"]) else cfg.message_basic
		if library != want:
			wrong.append("%s (%s) plays %s" % [offer_row["lender"], offer_row["outcome"], _name_of(library)])
	TestFixtures.check(res, "each fixture offer plays alert_positive when approved and message_basic when not",
		wrong.is_empty(), TestFixtures.detail(wrong, GuiLoanTests.FIXTURE_OFFERS.size(), "offers"))
	await _drain(host, heard)
	NotificationCenter.push(NotificationData.TYPE_CONTRACT_FAILED, 903, {}, NotificationData.Urgency.IMPORTANT)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a contract failed push plays alert_neutral",
		heard.only(cfg.alert_neutral, EVENT_BUS), heard.text())
	heard.clear()
	NotificationCenter.push(NotificationData.TYPE_LOAN_OFFER, 901, approved_snap,
		NotificationData.Urgency.INFORMATIONAL)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an approved loan offer push plays alert_positive on Sound Effects",
		heard.only(cfg.alert_positive, EVENT_BUS), heard.text())
	NotificationCenter.reset()
	FinanceManager.reset()
	await _drain(host, heard)


#A dispatch window over the first open board posting, widened to five slots by the contract suite helper.
static func _dispatch_window(host: Node) -> DispatchWindow:
	for view: ContractView in GameState.contracts:
		if view.status == GuiTypes.ContractStatus.AVAILABLE:
			return await GuiContractTests._wide_window(view, host)
	return null


#A merc landing in a dispatch slot plays equip, slots that only empty play unequip, and an opening window is silent.
static func _case_slot_equip(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	_fresh()
	TestFixtures.add_mercs(SLOT_ROSTER - GameState.mercs.size())
	await _drain(host, heard)
	var window: DispatchWindow = await _dispatch_window(host)
	var usable: bool = window != null and window.slot_count() == 5 and window.candidates.size() >= 5
	TestFixtures.check(res, "a dispatch window opens with five slots and at least five mercs to place", usable,
		"slots %d mercs %d" % [window.slot_count() if window != null else -1,
		window.candidates.size() if window != null else -1])
	if not usable:
		if window != null:
			window.queue_free()
		GuiFrameStack.clear()
		return
	TestFixtures.check(res, "opening a dispatch window plays no equip or unequip",
		heard.hits(cfg.equip) == 0 and heard.hits(cfg.unequip) == 0, heard.text())
	var uids: Array[int] = []
	for view: MercView in window.candidates:
		uids.append(view.uid)
	heard.clear()
	window.place(uids[0], 0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "placing a merc in an empty slot plays equip on UI", heard.only(cfg.equip, UI_BUS),
		heard.text())
	heard.clear()
	window.place(uids[1], 1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "placing a second merc plays equip again", heard.only(cfg.equip, UI_BUS),
		heard.text())
	heard.clear()
	window.place(uids[0], 2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "moving a placed merc to another slot plays equip and no unequip",
		heard.only(cfg.equip, UI_BUS), heard.text())
	heard.clear()
	window.swap_slots(1, 2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "swapping two filled slots plays equip and no unequip",
		heard.only(cfg.equip, UI_BUS), heard.text())
	heard.clear()
	window.swap_slots(2, 3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "swapping a filled slot with an empty one plays equip and no unequip",
		heard.only(cfg.equip, UI_BUS), heard.text())
	heard.clear()
	window.remove_slot(3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "emptying a slot plays unequip on UI", heard.only(cfg.unequip, UI_BUS),
		heard.text())
	heard.clear()
	window.remove_slot(3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "emptying an empty slot plays nothing",
		heard.hits(cfg.equip) == 0 and heard.hits(cfg.unequip) == 0, heard.text())
	var placed_row: DispatchRosterItem = GuiContractTests._roster_row(window.roster_panel(), uids[0])
	var placed_found: bool = placed_row != null
	heard.clear()
	if placed_found:
		placed_row.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing the roster row of a placed merc frees the slot and plays unequip",
		placed_found and window.filled_count() == 0 and heard.hits(cfg.unequip) == 1
		and heard.hits(cfg.equip) == 0, "filled %d, %s" % [window.filled_count(), heard.text()])
	for slot: int in 3:
		window.place(uids[2 + slot], slot)
	await host.get_tree().process_frame
	heard.clear()
	window.clear_team()
	await host.get_tree().process_frame
	TestFixtures.check(res, "clearing a team of three plays unequip once", heard.only(cfg.unequip, UI_BUS),
		heard.text())
	heard.clear()
	window.clear_team()
	await host.get_tree().process_frame
	TestFixtures.check(res, "clearing an empty team plays nothing",
		heard.hits(cfg.equip) == 0 and heard.hits(cfg.unequip) == 0, heard.text())
	heard.clear()
	window.optimize()
	await host.get_tree().process_frame
	TestFixtures.check(res, "optimize over an empty team plays equip once",
		window.filled_count() >= 2 and heard.only(cfg.equip, UI_BUS),
		"filled %d, %s" % [window.filled_count(), heard.text()])
	window.queue_free()
	GuiFrameStack.clear()
	await host.get_tree().process_frame
	heard.clear()
	var reopened: DispatchWindow = await _dispatch_window(host)
	TestFixtures.check(res, "a window opened after a team was built plays no equip or unequip",
		reopened != null and heard.hits(cfg.equip) == 0 and heard.hits(cfg.unequip) == 0, heard.text())
	if reopened != null:
		reopened.queue_free()
	GuiFrameStack.clear()


#A roster press over a full team and a refused dispatch play reject; a press that lands and a dispatch that goes do not.
static func _case_dispatch_refusals(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	_fresh()
	TestFixtures.add_mercs(REFUSAL_ROSTER - GameState.mercs.size())
	await _drain(host, heard)
	var window: DispatchWindow = await _dispatch_window(host)
	var usable: bool = window != null and window.slot_count() == 5 and window.candidates.size() >= 6
	TestFixtures.check(res, "a dispatch window opens with five slots and at least six mercs to pick from", usable,
		"slots %d mercs %d" % [window.slot_count() if window != null else -1,
		window.candidates.size() if window != null else -1])
	if not usable:
		if window != null:
			window.queue_free()
		GuiFrameStack.clear()
		return
	for slot: int in window.slot_count():
		window.place(window.candidates[slot].uid, slot)
	await host.get_tree().process_frame
	heard.clear()
	var spare: DispatchRosterItem = window.roster_panel().first_free_row()
	if spare != null:
		spare.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a roster press over a full team plays reject on Sound Effects and no click",
		spare != null and window.filled_count() == 5 and heard.only(cfg.reject, EVENT_BUS), heard.text())
	window.remove_slot(4)
	await host.get_tree().process_frame
	heard.clear()
	var open_row: DispatchRosterItem = window.roster_panel().first_free_row()
	var open_found: bool = open_row != null
	if open_found:
		open_row.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a roster press with a free slot places the merc and plays equip, not reject",
		open_found and window.filled_count() == 5 and heard.hits(cfg.equip) == 1
		and heard.hits(cfg.reject) == 0, "filled %d, %s" % [window.filled_count(), heard.text()])
	window.clear_team()
	await host.get_tree().process_frame
	heard.clear()
	var refused: bool = not window.commit()
	await host.get_tree().process_frame
	var on_events: bool = false
	for i: int in heard.size():
		if cfg.reject.sounds.has(heard.streams[i]) and heard.buses[i] == EVENT_BUS:
			on_events = true
	TestFixtures.check(res, "a dispatch the board refuses plays reject once on Sound Effects",
		refused and on_events and heard.hits(cfg.reject) == 1
		and window.confirm().title == "Dispatch failed", heard.text())
	window.queue_free()
	GuiFrameStack.clear()
	await host.get_tree().process_frame
	var sender: DispatchWindow = await _dispatch_window(host)
	var went: bool = false
	if sender != null:
		await GuiContractTests._ready_team(sender, host)
		heard.clear()
		went = sender.commit()
		await host.get_tree().process_frame
	TestFixtures.check(res, "a dispatch the board takes plays no reject",
		sender != null and went and heard.hits(cfg.reject) == 0, heard.text())
	if sender != null:
		sender.queue_free()
	GuiFrameStack.clear()


#HireOfferDialog: the salary stepper at its ceiling and a blocked offer press each answer with the reject alone.
static func _case_hire_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	var parts: Array = await GuiHiringTests._open_offer(host)
	var page: HiringTab = parts[0] as HiringTab
	var dialog: HireOfferDialog = parts[2] as HireOfferDialog
	var built: bool = page != null and dialog != null and dialog.is_open() and dialog.stepper() != null
	TestFixtures.check(res, "the hiring page opens an offer dialog with its salary stepper", built,
		"page %s, dialog %s" % [page != null, dialog != null])
	if not built:
		if page != null:
			await GuiHiringTests._shut(host, page)
		GuiFrameStack.clear()
		_fresh()
		await _drain(host, heard)
		return
	var stepper: QuantityStepper = dialog.stepper()
	dialog.set_amount(stepper.max_value)
	await _drain(host, heard)
	stepper.press_plus()
	var shaking: bool = stepper.is_rejecting() and stepper.rejected_side() == 1
	await host.get_tree().process_frame
	TestFixtures.check(res, "the offer stepper at its ceiling shakes and plays only the reject on the event bus",
		stepper.value == stepper.max_value and shaking and heard.only(cfg.reject, EVENT_BUS),
		"value %d of %d, shaking %s, heard %s" % [stepper.value, stepper.max_value, shaking, heard.text()])
	var sent: Array[int] = []
	dialog.hire_requested.connect(func(id: int, _salary: int) -> void: sent.append(id))
	dialog.counter_sent.connect(func(id: int, _offer: int) -> void: sent.append(id))
	GameState.bank_notes = 0
	await _drain(host, heard)
	var reason: String = dialog.block_reason()
	dialog.action_button().pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a blocked offer press plays only the reject, sends nothing and keeps the dialog open",
		reason != "" and sent.is_empty() and dialog.is_open() and heard.only(cfg.reject, EVENT_BUS),
		"reason '%s', sent %s, open %s, heard %s" % [reason, sent, dialog.is_open(), heard.text()])
	await GuiHiringTests._shut(host, page)
	GuiFrameStack.clear()
	_fresh()
	await _drain(host, heard)


#CheckoutDialog: a Place Order press the bank stopped covering after open() plays the reject and stays open.
static func _case_checkout_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	BazaarManager.reset()
	var stock: BazaarItemData = null
	for found: BazaarItemData in BazaarManager.catalog:
		if BazaarManager.available(found) and found.price > 0:
			stock = found
			break
	var dialog: CheckoutDialog = (load(CHECKOUT_SCENE) as PackedScene).instantiate() as CheckoutDialog
	host.add_child(dialog)
	await host.get_tree().process_frame
	var filled: bool = stock != null and BazaarManager.set_qty(stock.id, 1)
	GameState.bank_notes = BazaarManager.cart_total()
	dialog.open()
	var shown: bool = filled and dialog.is_open() and not dialog.confirm_button.disabled
	GameState.bank_notes = BazaarManager.cart_total() - 1
	await _drain(host, heard)
	dialog.confirm_button.pressed.emit()
	await host.get_tree().process_frame
	var click: SoundLibrary = UiSfx.click_library(dialog.confirm_button)
	TestFixtures.check(res, "a Place Order press the bank stopped covering plays only the reject and keeps checkout open",
		shown and click != null and heard.hits(click) == 0 and _heard_from(heard, cfg.reject, EVENT_BUS) == 1
		and heard.hits(cfg.reject) == 1 and dialog.is_open() and BazaarManager.orders.is_empty()
		and dialog.confirm_button.disabled,
		"shown %s, open %s, %d orders, shut %s, heard %s" % [shown, dialog.is_open(),
		BazaarManager.orders.size(), dialog.confirm_button.disabled, heard.text()])
	dialog.close()
	dialog.queue_free()
	BazaarManager.reset()
	GuiFrameStack.clear()
	_fresh()
	await _drain(host, heard)


#LoanOfferDialog: an Accept press on an offer withdrawn after open plays the reject alone; Decline keeps click plus reject.
static func _case_loan_accept_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	FinanceManager.reset()
	_lay_offers()
	var standing: Array[Dictionary] = FinanceManager.open_offers()
	var target: int = int(standing[0]["id"]) if not standing.is_empty() else -1
	for row: Dictionary in standing:
		if int(row["id"]) != target:
			FinanceManager.reject_offer(int(row["id"]))
	var dialog: LoanOfferDialog = (load(LoanOfferDialog.SCENE_PATH) as PackedScene).instantiate() as LoanOfferDialog
	host.add_child(dialog)
	await host.get_tree().process_frame
	dialog.open_for(target)
	var lone: bool = target >= 0 and dialog.is_open() and not dialog.needs_confirm()
	FinanceManager.reject_offer(target)
	var loans_before: int = FinanceManager.loans.size()
	var taken: Array[int] = []
	dialog.accepted.connect(func(id: int) -> void: taken.append(id))
	var click: SoundLibrary = UiSfx.click_library(dialog.confirm_button)
	await _drain(host, heard)
	dialog.confirm_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "an Accept press on an offer withdrawn after open plays only the reject and stays open",
		lone and click != null and heard.hits(click) == 0 and _heard_from(heard, cfg.reject, EVENT_BUS) == 1
		and heard.hits(cfg.reject) == 1 and dialog.is_open() and taken.is_empty()
		and FinanceManager.loans.size() == loans_before,
		"lone %s, open %s, taken %s, %d loans, heard %s" % [lone, dialog.is_open(), taken,
		FinanceManager.loans.size(), heard.text()])
	dialog.close()
	FinanceManager.reset()
	_lay_offers()
	var again: Array[Dictionary] = FinanceManager.open_offers()
	var other: int = int(again[0]["id"]) if not again.is_empty() else -1
	dialog.open_for(other)
	var reopened: bool = other >= 0 and dialog.is_open()
	var decline_click: SoundLibrary = UiSfx.click_library(dialog.cancel_button)
	await _drain(host, heard)
	dialog.cancel_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a Decline press is a player choice, so it keeps its click beside the reject",
		reopened and decline_click != null and heard.hits(decline_click) == 1
		and _heard_from(heard, cfg.reject, EVENT_BUS) == 1 and not dialog.is_open()
		and FinanceManager.offer(other).is_empty(),
		"reopened %s, open %s, heard %s" % [reopened, dialog.is_open(), heard.text()])
	dialog.queue_free()
	FinanceManager.reset()
	GuiFrameStack.clear()
	_fresh()
	await _drain(host, heard)


#InvestTradeConfirm: a Confirm press on a buy the bank stopped covering plays the reject without its click, then closes.
static func _case_trade_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	StockMarket.reset()
	var dialog: InvestTradeConfirm = InvestTab.CONFIRM_SCENE.instantiate() as InvestTradeConfirm
	host.add_child(dialog)
	await host.get_tree().process_frame
	var k: int = GuiInvestTests.FREE_K
	var saved_bank: int = GameState.bank_notes
	dialog.open_for(k, InvestTradePanel.SIDE_BUY, 1)
	var shown: bool = dialog.is_open() and dialog.side() == InvestTradePanel.SIDE_BUY
	GameState.bank_notes = 0
	var click: SoundLibrary = UiSfx.click_library(dialog.confirm_button)
	await _drain(host, heard)
	dialog.confirm_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a trade Confirm press the bank cannot cover plays the reject and no click, then closes",
		shown and click != null and heard.hits(click) == 0 and _heard_from(heard, cfg.reject, EVENT_BUS) == 1
		and heard.hits(cfg.reject) == 1 and not dialog.last_result() and not dialog.is_open()
		and StockMarket.holding(k).is_empty(),
		"shown %s, result %s, open %s, heard %s" % [shown, dialog.last_result(), dialog.is_open(),
		heard.text()])
	GameState.bank_notes = saved_bank
	dialog.queue_free()
	StockMarket.reset()
	GuiFrameStack.clear()
	_fresh()
	await _drain(host, heard)


#A dispatch cue starts at full volume and fades to silence over DISPATCH_FADE_SECONDS. A fade is linear in linear
#volume, a repeat queue replaces it, and a player that the pool hands out again or that stop_all stops drops it.
static func _case_dispatch_fade(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	await _drain(host, heard)
	AudioManager.stop_all()
	GameSfx.play_dispatch("foot")
	AudioManager.flush()
	var player: AudioStreamPlayer = AudioManager.last.get("player") as AudioStreamPlayer
	var fade: Tween = AudioManager.fade_of(player)
	var fade_seconds: float = float(AudioManager.last.get("fade", 0.0))
	TestFixtures.check(res, "a dispatch cue plays dispatch_foot at full volume and starts its fade at once",
		heard.only(cfg.dispatch_foot, EVENT_BUS) and is_equal_approx(heard.volumes[0], 0.0)
			and AudioManager.fading(player) and fade != null
			and is_equal_approx(fade_seconds, GameSfx.DISPATCH_FADE_SECONDS),
		"%s; %s; fade %.2f s" % [heard.text(), _player_text(player), fade_seconds])
	if fade != null:
		fade.custom_step(GameSfx.DISPATCH_FADE_SECONDS + 0.1)
	var linear: float = player.volume_linear if player != null else -1.0
	TestFixtures.check(res, "stepping the dispatch fade 2.1 s leaves its player silent and stopped",
		player != null and fade != null and linear >= 0.0 and linear <= 0.0001 and not player.playing
			and not AudioManager.fading(player),
		"linear %.4f; %s" % [linear, _player_text(player)])
	AudioManager.stop_all()
	var stream: AudioStream = cfg.dispatch_foot.sounds[0]
	var half: AudioStreamPlayer = AudioManager.play(stream, EVENT_BUS, 1.0, 0.0, 2.0)
	var half_fade: Tween = AudioManager.fade_of(half)
	if half_fade != null:
		half_fade.custom_step(1.0)
	var mid: float = half.volume_linear if half != null else -1.0
	TestFixtures.check(res, "a fade is linear in linear volume and reads 0.5 halfway through",
		half_fade != null and absf(mid - 0.5) < 0.01 and half.playing, "linear %.3f; %s" % [mid, _player_text(half)])
	if half != null:
		half.stop()
	var reused: AudioStreamPlayer = AudioManager.play(stream, EVENT_BUS, 1.0, -3.0)
	TestFixtures.check(res, "a stopped player the pool hands out again drops its old fade and keeps the new volume",
		reused != null and reused == half and not AudioManager.fading(reused) and is_equal_approx(reused.volume_db, -3.0)
			and half_fade != null and not half_fade.is_running(),
		_player_text(reused))
	AudioManager.stop_all()
	heard.clear()
	AudioManager.queue(cfg.money, EVENT_BUS, 1.0, 0.0, 1.5)
	AudioManager.queue(cfg.money, EVENT_BUS, 1.0, 0.0, 0.0)
	AudioManager.flush()
	var plain: AudioStreamPlayer = AudioManager.last.get("player") as AudioStreamPlayer
	var plain_fade: float = float(AudioManager.last.get("fade", -1.0))
	AudioManager.queue(cfg.money, EVENT_BUS, 1.0, 0.0, 0.0)
	AudioManager.queue(cfg.money, EVENT_BUS, 1.0, 0.0, 1.5)
	AudioManager.flush()
	var faded: AudioStreamPlayer = AudioManager.last.get("player") as AudioStreamPlayer
	var faded_fade: float = float(AudioManager.last.get("fade", -1.0))
	TestFixtures.check(res, "a repeat queue before the flush replaces the fade",
		heard.size() == 2 and heard.hits(cfg.money) == 2 and is_zero_approx(plain_fade) and not AudioManager.fading(plain)
			and is_equal_approx(faded_fade, 1.5) and AudioManager.fading(faded),
		"fades %.2f then %.2f; %s" % [plain_fade, faded_fade, heard.text()])
	AudioManager.stop_all()
	TestFixtures.check(res, "stop_all stops a fading player and drops its fade, and a null player never fades",
		faded != null and not faded.playing and not AudioManager.fading(faded) and not AudioManager.fading(null)
			and AudioManager.fade_of(null) == null,
		_player_text(faded))
	heard.clear()


#Every notification cue plays at NOTICE_DB, about 75 percent linear volume; a postings row chimes once per day.
static func _case_notice_level(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	NotificationCenter.reset()
	await _drain(host, heard)
	GameSfx.play_notice(_notice(NotificationData.TYPE_LOAN_OFFER, NotificationData.Urgency.INFORMATIONAL))
	await host.get_tree().process_frame
	TestFixtures.check(res, "an informational notice plays message_basic at -2.5 dB",
		heard.only(cfg.message_basic, EVENT_BUS) and is_equal_approx(heard.volume_of(cfg.message_basic), -2.5)
			and is_equal_approx(AudioManager.last_volume_db, GameSfx.NOTICE_DB),
		"%s; volumes %s" % [heard.text(), str(heard.volumes)])
	heard.clear()
	GameSfx.play_notice(_notice(NotificationData.TYPE_LOAN_OFFER, NotificationData.Urgency.IMPORTANT))
	GameSfx.play_notice(_notice(NotificationData.TYPE_LOAN_OFFER, NotificationData.Urgency.URGENT))
	GameSfx.play_notice(_notice(NotificationData.TYPE_STOCK_MOVE, NotificationData.Urgency.INFORMATIONAL,
		_stock_snap(4.2)))
	await host.get_tree().process_frame
	var loud: Array[String] = []
	for i: int in heard.size():
		if not is_equal_approx(heard.volumes[i], GameSfx.NOTICE_DB):
			loud.append("%s at %.1f dB" % [heard.streams[i].resource_path.get_file(), heard.volumes[i]])
	TestFixtures.check(res, "alert_neutral, alert_bad and alert_positive notices all play at NOTICE_DB",
		heard.size() == 3 and heard.hits(cfg.alert_neutral) == 1 and heard.hits(cfg.alert_bad) == 1
			and heard.hits(cfg.alert_positive) == 1 and loud.is_empty(),
		"%s; %s" % [heard.text(), TestFixtures.detail(loud, 3, "cues")])
	heard.clear()
	var day: int = TrynnCalendar.day_index(CampaignClock.now())
	var row: NotificationData = NotificationCenter.add_postings(day, 2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a new postings row chimes message_basic at NOTICE_DB and never new_contract",
		row != null and heard.only(cfg.message_basic, EVENT_BUS) and is_equal_approx(heard.volumes[0], GameSfx.NOTICE_DB)
			and heard.hits(cfg.new_contract) == 0,
		"%s; volumes %s" % [heard.text(), str(heard.volumes)])
	heard.clear()
	var same: NotificationData = NotificationCenter.add_postings(day, 3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a second posting the same day raises the row's count without a second chime",
		row != null and same == row and int(row.snap.get("count", 0)) == 5 and heard.size() == 0,
		"count %s; %s" % [str(row.snap.get("count", "none")) if row != null else "no row", heard.text()])
	NotificationCenter.reset()
	await _drain(host, heard)


#The kind of news decides before the urgency: urgent good news still chimes alert_positive.
static func _case_notice_order(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var urgent: int = NotificationData.Urgency.URGENT
	var stock: StringName = NotificationData.TYPE_STOCK_MOVE
	var loan: StringName = NotificationData.TYPE_LOAN_OFFER
	var rising: SoundLibrary = GameSfx.notice_library(_notice(stock, urgent, _stock_snap(6.0)))
	var offer: SoundLibrary = GameSfx.notice_library(_notice(loan, urgent))
	TestFixtures.check(res, "an urgent rising stock move plays alert_positive and an urgent loan offer alert_bad",
		rising == cfg.alert_positive and offer == cfg.alert_bad, "%s, %s" % [_name_of(rising), _name_of(offer)])
	var falling: SoundLibrary = GameSfx.notice_library(_notice(stock, urgent, _stock_snap(-6.0)))
	var refused: SoundLibrary = GameSfx.notice_library(_notice(loan, urgent, {"approved": false}))
	var lifted: SoundLibrary = GameSfx.notice_library(_notice(stock, NotificationData.Urgency.IMPORTANT, _stock_snap(3.0)))
	TestFixtures.check(res, "urgent bad news plays alert_bad and important good news alert_positive",
		falling == cfg.alert_bad and refused == cfg.alert_bad and lifted == cfg.alert_positive,
		"%s, %s, %s" % [_name_of(falling), _name_of(refused), _name_of(lifted)])
	NotificationCenter.reset()
	await _drain(host, heard)
	NotificationCenter.push(stock, 0, _stock_snap(5.0), urgent)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an urgent rising stock push plays alert_positive on Sound Effects",
		heard.only(cfg.alert_positive, EVENT_BUS), heard.text())
	NotificationCenter.reset()
	await _drain(host, heard)


#A fly with its cue off still asks the HUD to fly the notes but stays silent; only money_fly_cued plays money.
static func _case_fly_cue(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	await _drain(host, heard)
	var flights: Array[int] = []
	var on_fly: Callable = func(amount: int) -> void: flights.append(amount)
	GameState.money_fly_requested.connect(on_fly)
	GameState.fly_money(50, false)
	await host.get_tree().process_frame
	var quiet_size: int = heard.size()
	var quiet_text: String = heard.text()
	heard.clear()
	GameState.fly_money(50)
	await host.get_tree().process_frame
	GameState.money_fly_requested.disconnect(on_fly)
	TestFixtures.check(res, "a fly with the cue off plays nothing and a cued fly plays money, and both still fly",
		quiet_size == 0 and heard.only(cfg.money, EVENT_BUS) and flights.size() == 2 and flights[0] == 50
			and flights[1] == 50,
		"%s; %s; flights %s" % [quiet_text, heard.text(), str(flights)])
	heard.clear()
	GameState.money_fly_requested.emit(40)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a bare money_fly_requested without money_fly_cued plays nothing", heard.size() == 0,
		heard.text())
	heard.clear()


#One graph_draw texture follows the pointer: the pitch bends on the live player, graph_scrub_end or the idle timer
#fades it out, a pick that runs out hands over to a new pick, and an empty library keeps it silent.
static func _case_graph_scrub(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	await _drain(host, heard)
	AudioManager.stop_all()
	GameSfx.graph_scrub(0.0)
	var player: AudioStreamPlayer = GameSfx.scrub_player()
	TestFixtures.check(res, "a scrub at the left edge starts one graph_draw on Sound Effects at pitch 0.95",
		heard.only(cfg.graph_draw, EVENT_BUS) and heard.pitch_is(GameSfx.SCRUB_PITCH_LOW) and player != null
			and is_equal_approx(player.pitch_scale, 0.95),
		"%s; %s" % [heard.text(), _player_text(player)])
	GameSfx.graph_scrub(1.0)
	var same: AudioStreamPlayer = GameSfx.scrub_player()
	TestFixtures.check(res, "a scrub at the right edge bends the same player to 1.05 without a second start",
		heard.size() == 1 and player != null and same == player and is_equal_approx(same.pitch_scale, 1.05),
		"%s; %s" % [heard.text(), _player_text(same)])
	GameSfx.graph_scrub(0.5)
	var mid: float = player.pitch_scale if player != null else 0.0
	GameSfx.graph_scrub(-3.0)
	var under: float = player.pitch_scale if player != null else 0.0
	GameSfx.graph_scrub(7.0)
	var over: float = player.pitch_scale if player != null else 0.0
	TestFixtures.check(res, "the scrub pitch runs linearly across the plot and clamps outside it",
		is_equal_approx(mid, 1.0) and is_equal_approx(under, 0.95) and is_equal_approx(over, 1.05)
			and heard.size() == 1 and GameSfx.scrub_player() == player,
		"%.3f, %.3f, %.3f; %s" % [mid, under, over, heard.text()])
	GameSfx.graph_scrub_end()
	var was_fading: bool = AudioManager.fading(player)
	var forgot: bool = GameSfx.scrub_player() == null
	var fade: Tween = AudioManager.fade_of(player)
	if fade != null:
		fade.custom_step(0.2)
	TestFixtures.check(res, "graph_scrub_end fades the scrub, custom_step(0.2) stops it and scrub_player() is null",
		was_fading and forgot and fade != null and player != null and not player.playing
			and GameSfx.scrub_player() == null,
		"fading %s; %s" % [was_fading, _player_text(player)])
	await _drain(host, heard)
	GameSfx.graph_scrub(0.25)
	var idle: AudioStreamPlayer = GameSfx.scrub_player()
	await host.get_tree().create_timer(GameSfx.SCRUB_IDLE_SECONDS + 0.1).timeout
	TestFixtures.check(res, "a scrub that gets no new point for SCRUB_IDLE_SECONDS ends on its own",
		idle != null and GameSfx.scrub_player() == null and (AudioManager.fading(idle) or not idle.playing)
			and heard.only(cfg.graph_draw, EVENT_BUS),
		"%s; %s" % [_player_text(idle), heard.text()])
	AudioManager.stop_all()
	await _drain(host, heard)
	GameSfx.graph_scrub(0.5)
	var first: AudioStreamPlayer = GameSfx.scrub_player()
	if first != null:
		first.stop()
		first.finished.emit()
	var next: AudioStreamPlayer = GameSfx.scrub_player()
	TestFixtures.check(res, "a scrub pick that runs out hands over to a new graph_draw pick at the same pitch",
		first != null and next != null and next.playing and is_equal_approx(next.pitch_scale, 1.0)
			and heard.size() == 2 and heard.hits(cfg.graph_draw) == 2,
		"%s; %s" % [_player_text(next), heard.text()])
	GameSfx.graph_scrub_end()
	AudioManager.stop_all()
	await _drain(host, heard)
	var saved: SoundLibrary = GameSfx.config.graph_draw
	GameSfx.config.graph_draw = SoundLibrary.new()
	GameSfx.graph_scrub(0.5)
	var empty_player: AudioStreamPlayer = GameSfx.scrub_player()
	GameSfx.config.graph_draw = null
	GameSfx.graph_scrub(0.5)
	var null_player: AudioStreamPlayer = GameSfx.scrub_player()
	GameSfx.config.graph_draw = saved
	await host.get_tree().process_frame
	TestFixtures.check(res, "a scrub with an empty or missing graph_draw library plays nothing",
		empty_player == null and null_player == null and heard.size() == 0, heard.text())
	GameSfx.graph_scrub_end()
	heard.clear()


#Hovering across a chart drives the scrub: the left of the plot reads low and the right high, moves inside one
#point's bucket leave it alone, and hide_tip or the pointer leaving ends it.
static func _case_chart_scrub(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	var chart: LineChart = (load(CHART_SCENE) as PackedScene).instantiate() as LineChart
	chart.tween_seconds = 0.0
	chart.custom_minimum_size = Vector2(400.0, 200.0)
	host.add_child(chart)
	chart.size = Vector2(400.0, 200.0)
	await host.get_tree().process_frame
	chart.set_series(_series(["cash"], 2))
	AudioManager.stop_all()
	await _drain(host, heard)
	var plot: Rect2 = chart.plot_rect()
	var mid_y: float = plot.get_center().y
	chart.hover_at(Vector2(plot.position.x + 4.0, mid_y))
	var left: AudioStreamPlayer = GameSfx.scrub_player()
	var low: float = left.pitch_scale if left != null else 0.0
	chart.hover_at(Vector2(plot.position.x + 40.0, mid_y))
	var inside: float = left.pitch_scale if left != null else 0.0
	chart.hover_at(Vector2(plot.end.x - 4.0, mid_y))
	var right: AudioStreamPlayer = GameSfx.scrub_player()
	var high: float = right.pitch_scale if right != null else 0.0
	TestFixtures.check(res, "hovering a chart from the left of the plot to the right raises the scrub pitch",
		left != null and right == left and low < 0.97 and high > 1.03 and heard.only(cfg.graph_draw, EVENT_BUS),
		"%.3f to %.3f; %s" % [low, high, heard.text()])
	TestFixtures.check(res, "pointer moves inside one point's bucket leave the scrub pitch alone",
		left != null and is_equal_approx(inside, low), "%.3f then %.3f" % [low, inside])
	chart.hide_tip()
	TestFixtures.check(res, "hide_tip on a hovered chart fades the scrub out",
		left != null and AudioManager.fading(left) and GameSfx.scrub_player() == null and chart.hovered_index() == -1,
		_player_text(left))
	chart.hover_at(Vector2(plot.position.x + 4.0, mid_y))
	var again: AudioStreamPlayer = GameSfx.scrub_player()
	chart.notification(Control.NOTIFICATION_MOUSE_EXIT)
	TestFixtures.check(res, "the pointer leaving a hovered chart ends the scrub",
		again != null and AudioManager.fading(again) and GameSfx.scrub_player() == null and chart.hovered_index() == -1,
		_player_text(again))
	chart.queue_free()
	await host.get_tree().process_frame
	AudioManager.stop_all()
	heard.clear()


#HiringTab: a Hire confirm press the bank stopped covering after the ask plays only the reject and hires nobody.
static func _case_hire_confirm_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	var parts: Array = await GuiHiringTests._open_offer(host)
	var page: HiringTab = parts[0] as HiringTab
	var one: ApplicantData = parts[1] as ApplicantData
	var dialog: HireOfferDialog = parts[2] as HireOfferDialog
	if dialog != null and one != null:
		dialog.press_action()
	await host.get_tree().process_frame
	var ask: ConfirmDialog = page.confirm_dialog() if page != null else null
	var asked: bool = one != null and ask != null and ask.is_open() and ask.confirm_button != null
	var roster: int = GameState.mercs.size()
	GameState.bank_notes = 0
	var click: SoundLibrary = UiSfx.click_library(ask.confirm_button) if asked else null
	await _drain(host, heard)
	if asked:
		ask.confirm_button.pressed.emit()
	await host.get_tree().process_frame
	var kept: bool = asked and PromotionsManager.applicant_of(one.id) != null and GameState.mercs.size() == roster
	var flashed: bool = asked and page.notice().showing() and page.notice().color().is_equal_approx(GuiColors.RAMP_RED)
	TestFixtures.check(res, "a Hire confirm press the bank stopped covering plays only the reject and hires nobody",
		asked and click != null and heard.hits(click) == 0 and _heard_from(heard, cfg.reject, EVENT_BUS) == 1
		and heard.hits(cfg.reject) == 1 and kept and flashed,
		"asked %s, kept %s, flashed %s, heard %s" % [asked, kept, flashed, heard.text()])
	if page != null:
		await GuiHiringTests._shut(host, page)
	GuiFrameStack.clear()
	_fresh()
	await _drain(host, heard)


#LoansTab: a Pay Off press the bank stopped covering after the ask plays only the reject and keeps the loan.
static func _case_payoff_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	GuiLoanTests._fresh_seeded()
	var tab: LoansTab = (load(LoansTab.SCENE_PATH) as PackedScene).instantiate() as LoansTab
	host.add_child(tab)
	await host.get_tree().process_frame
	var loan_id: int = GuiLoanViewTests.LOAN_2
	tab.ask_payoff(loan_id)
	await host.get_tree().process_frame
	var ask: ConfirmDialog = tab.payoff_dialog()
	var asked: bool = ask != null and ask.is_open() and tab.payoff_id() == loan_id and ask.confirm_button != null
	var under: int = FinanceManager.payoff_amount(loan_id) - 1
	GameState.bank_notes = under
	var click: SoundLibrary = UiSfx.click_library(ask.confirm_button) if asked else null
	await _drain(host, heard)
	if asked:
		ask.confirm_button.pressed.emit()
	await host.get_tree().process_frame
	var kept: bool = FinanceManager.loan_by_id(loan_id) != null and GameState.bank_notes == under
	TestFixtures.check(res, "a Pay Off press the bank stopped covering plays only the reject and keeps the loan",
		asked and click != null and heard.hits(click) == 0 and _heard_from(heard, cfg.reject, EVENT_BUS) == 1
		and heard.hits(cfg.reject) == 1 and kept and tab.payoff_id() == -1,
		"asked %s, kept %s, %d notes, asking %d, heard %s" % [asked, kept, GameState.bank_notes, tab.payoff_id(),
		heard.text()])
	tab.queue_free()
	FinanceManager.reset()
	GuiFrameStack.clear()
	_fresh()
	await _drain(host, heard)


#CampaignBuilder: a Launch press the bank stopped covering after open plays only the reject and keeps the builder open.
static func _case_launch_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	GuiAdsTests._fresh(GuiAdsTests._full_ent())
	var viewer: PromotionsViewer = GuiAdsTests.VIEWER.instantiate() as PromotionsViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	viewer.open_tab(PromotionsViewer.JOB_KEY)
	viewer.press_new()
	var builder: CampaignBuilder = viewer.builder()
	var armed: bool = (builder != null and builder.is_open() and builder.launch_enabled()
		and builder.launch_button != null and not builder.launch_button.disabled)
	var before: int = PromotionsManager.campaigns.size()
	GameState.bank_notes = 0
	var click: SoundLibrary = UiSfx.click_library(builder.launch_button) if armed else null
	await _drain(host, heard)
	if armed:
		builder.launch_button.pressed.emit()
	await host.get_tree().process_frame
	var held: bool = armed and builder.is_open() and PromotionsManager.campaigns.size() == before
	var why: String = builder.reason_text() if builder != null else ""
	TestFixtures.check(res, "a Launch press the bank stopped covering plays only the reject and keeps the builder open",
		armed and click != null and heard.hits(click) == 0 and _heard_from(heard, cfg.reject, EVENT_BUS) == 1
		and heard.hits(cfg.reject) == 1 and held,
		"armed %s, held %s, reason '%s', heard %s" % [armed, held, why, heard.text()])
	viewer.queue_free()
	GuiFrameStack.clear()
	_fresh()
	await _drain(host, heard)


#PlanSwitchDialog: a switch the bank stopped covering after open plays only the reject and keeps the dialog open.
static func _case_plan_switch_reject(res: Dictionary, host: Node, heard: PlayLog) -> void:
	var cfg: SfxConfig = UiSfx.config
	GuiFrameStack.clear()
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	var first: int = SubscriptionManager.plan()
	var scene: PackedScene = load(GuiFrameTests.PLAN_SWITCH_SCENE) as PackedScene
	var dialog: PlanSwitchDialog = scene.instantiate() as PlanSwitchDialog
	host.add_child(dialog)
	await host.get_tree().process_frame
	var pro: int = SubscriptionManager.Plan.PRO
	GameState.bank_notes = SubscriptionManager.service_fee(pro)
	dialog.open_for(pro)
	var live: bool = (dialog.is_open() and dialog.can_afford() and dialog.fee() > 0
		and SubscriptionManager.can_switch(pro) and dialog.confirm_button != null)
	GameState.bank_notes = dialog.fee() - 1
	var switched: Array[int] = []
	dialog.confirmed.connect(func() -> void: switched.append(dialog.target_plan()))
	var click: SoundLibrary = UiSfx.click_library(dialog.confirm_button) if live else null
	await _drain(host, heard)
	if live:
		dialog.confirm_button.pressed.emit()
	await host.get_tree().process_frame
	var held: bool = dialog.is_open() and switched.is_empty() and SubscriptionManager.plan() == first
	TestFixtures.check(res, "a plan switch press the bank stopped covering plays only the reject and keeps the dialog open",
		live and click != null and heard.hits(click) == 0 and _heard_from(heard, cfg.reject, EVENT_BUS) == 1
		and heard.hits(cfg.reject) == 1 and held,
		"live %s, held %s, plan %d, heard %s" % [live, held, SubscriptionManager.plan(), heard.text()])
	dialog.close()
	dialog.queue_free()
	GuiFrameStack.clear()
	_fresh()
	await _drain(host, heard)
