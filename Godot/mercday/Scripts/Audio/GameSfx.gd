extends Node

#Event sounds. The autoload signals for a dispatch, a settled contract, money, a rejection, a permit,
#every alerted notification and every delivered mail each queue one cue on the event bus. New postings play no cue of their own.
#Money moved while the clock runs stays silent; a money cue sharing a frame with an action cue plays at half volume.
#graph_scrub() drives one graph_draw texture while the pointer crosses chart points.

const RESULT_FOLLOW_SECONDS: float = 0.6
const MONEY_PITCH_LOW: float = 0.85
const MONEY_PITCH_HIGH: float = 1.15
const STACKED_MONEY_DB: float = -6.0
const DISPATCH_FADE_SECONDS: float = 2.0
#About 75 percent linear volume for every notification cue.
const NOTICE_DB: float = -2.5
const SCRUB_PITCH_LOW: float = 0.95
const SCRUB_PITCH_HIGH: float = 1.05
const SCRUB_IDLE_SECONDS: float = 0.3
const SCRUB_FADE_SECONDS: float = 0.15
#The graph_draw textures run 3.5 to 28 seconds; a draw cue fades out with the reveal and every chart cue sits at GRAPH_DB.
const GRAPH_DB: float = -12.0
const GRAPH_TAIL_SECONDS: float = 0.2

var config: SfxConfig

#Process frames of the last money cue and the last action cue, and the pitch that money cue drew.
var _money_frame: int = -1
var _money_pitch: float = 1.0
var _action_frame: int = -1
#The graph_draw player a scrub drives, the stream it started, the pitch the pointer last set and the idle timer.
var _scrub_player: AudioStreamPlayer
var _scrub_stream: AudioStream
var _scrub_pitch: float = 1.0
var _scrub_timer: Timer
#The live draw-in cue player and the stream it started.
var _graph_player: AudioStreamPlayer
var _graph_stream: AudioStream


func _ready() -> void:
	config = load(UiSfx.CONFIG_PATH) as SfxConfig
	GameState.dispatched.connect(_on_dispatched)
	GameState.money_moved.connect(_on_money_moved)
	GameState.money_fly_cued.connect(play_money)
	GameState.contract_rejected.connect(_on_contract_rejected)
	LegalManager.permit_granted.connect(_on_permit_granted)
	NotificationCenter.alerted.connect(play_notice)
	MailCenter.delivered.connect(_on_mail_delivered)
	#Mercdave is the autoload after GameSfx, so the connect waits one deferred step.
	call_deferred(&"_hook_mercdave")
	_scrub_timer = Timer.new()
	_scrub_timer.one_shot = true
	_scrub_timer.wait_time = SCRUB_IDLE_SECONDS
	_scrub_timer.timeout.connect(graph_scrub_end)
	add_child(_scrub_timer)


#The travel cue fades to silence over DISPATCH_FADE_SECONDS.
func play_dispatch(travel_mode: String) -> void:
	note_action_cue()
	_queue(config.dispatch_library(travel_mode), 1.0, 0.0, DISPATCH_FADE_SECONDS)


#The outcome cue, then dead when a member died and captured when one was taken.
func result_libraries(result: ContractResultData) -> Array[SoundLibrary]:
	var out: Array[SoundLibrary] = [config.contract_failure if result.failed else config.contract_success]
	if _any_fate(result, ResultMemberData.Fate.DEAD):
		out.append(config.dead)
	if _any_fate(result, ResultMemberData.Fate.CAPTURED):
		out.append(config.captured)
	return out


#Call when the results screen's verdict stamp slams in, not when the contract settles, so the
#outcome is never spoiled before the player opens the screen. The outcome cue plays at once; the
#fate cues follow RESULT_FOLLOW_SECONDS later so they do not mask it.
func play_result(result: ContractResultData) -> void:
	var libraries: Array[SoundLibrary] = result_libraries(result)
	_queue(libraries.pop_front())
	if libraries.is_empty():
		return
	await get_tree().create_timer(RESULT_FOLLOW_SECONDS).timeout
	for library: SoundLibrary in libraries:
		_queue(library)


#A settled contract's bell stays neutral either way; the win/lose cue plays separately when the
#results screen reveals the verdict, not here. The posting expiry notices stay silent.
#The kind of news decides before the urgency: an urgent rising stock still chimes alert_positive.
func notice_library(row: NotificationData) -> SoundLibrary:
	if row.type == NotificationData.TYPE_CONTRACT_COMPLETED or row.type == NotificationData.TYPE_CONTRACT_FAILED:
		return config.alert_neutral
	if row.type == NotificationData.TYPE_EXPIRY_WARNING or row.type == NotificationData.TYPE_EXPIRED:
		return null
	if _good_news(row):
		return config.alert_positive
	if row.urgency == NotificationData.Urgency.URGENT:
		return config.alert_bad
	if row.urgency == NotificationData.Urgency.IMPORTANT:
		return config.alert_neutral
	return config.message_basic


func play_notice(row: NotificationData) -> void:
	_queue(notice_library(row), 1.0, NOTICE_DB)


#Pitch drawn from MONEY_PITCH_LOW to MONEY_PITCH_HIGH; half volume when an action cue shares the frame.
func play_money(delta: int) -> void:
	if delta == 0:
		return
	_money_frame = Engine.get_process_frames()
	_money_pitch = randf_range(MONEY_PITCH_LOW, MONEY_PITCH_HIGH)
	var volume_db: float = STACKED_MONEY_DB if _action_frame == _money_frame else 0.0
	_queue(config.money, _money_pitch, volume_db)


#A direct-action cue (dispatch, permit, upgrade) this frame; a money cue still waiting drops to half volume.
func note_action_cue() -> void:
	_action_frame = Engine.get_process_frames()
	if _money_frame == _action_frame and AudioManager.unqueue(config.money):
		_queue(config.money, _money_pitch, STACKED_MONEY_DB)


func play_permit() -> void:
	note_action_cue()
	_queue(config.permit)


func play_mercdave_text() -> void:
	_queue(config.mercdave_text)


func play_reject() -> void:
	_queue(config.reject)


#One draw-in cue at a time: a chart that reveals while another cue still plays stays silent. The cue fades to silence
#over the reveal seconds plus GRAPH_TAIL_SECONDS.
func play_graph(seconds: float) -> void:
	if config == null or config.graph_draw == null or config.graph_draw.is_empty() or graph_player() != null:
		return
	var player: AudioStreamPlayer = AudioManager.play(config.graph_draw.pick(), String(config.event_bus), 1.0, GRAPH_DB,
		maxf(seconds, 0.0) + GRAPH_TAIL_SECONDS)
	_graph_player = player
	_graph_stream = player.stream if player != null else null


#The draw-in cue player while it still plays the stream it started, or null.
func graph_player() -> AudioStreamPlayer:
	if not is_instance_valid(_graph_player) or not _graph_player.playing or _graph_player.stream != _graph_stream:
		return null
	return _graph_player


#x_frac 0.0 to 1.0 across the plot sets the pitch from SCRUB_PITCH_LOW to SCRUB_PITCH_HIGH on one live graph_draw
#player; SCRUB_IDLE_SECONDS without a call ends it.
func graph_scrub(x_frac: float) -> void:
	if config == null or config.graph_draw == null or config.graph_draw.is_empty():
		return
	_scrub_pitch = lerpf(SCRUB_PITCH_LOW, SCRUB_PITCH_HIGH, clampf(x_frac, 0.0, 1.0))
	if _scrub_live():
		_scrub_player.pitch_scale = _scrub_pitch
	else:
		_start_scrub()
	_scrub_timer.start()


#Fades the live scrub out over SCRUB_FADE_SECONDS and forgets it.
func graph_scrub_end() -> void:
	_scrub_timer.stop()
	if _scrub_live():
		AudioManager.fade_out(_scrub_player, SCRUB_FADE_SECONDS)
	_drop_scrub()


#The graph_draw player a live scrub drives, or null.
func scrub_player() -> AudioStreamPlayer:
	return _scrub_player if _scrub_live() else null


func _on_dispatched(run: ActiveRun) -> void:
	play_dispatch(run.travel_mode)


#Clock deductions and settled rewards stay silent; the results screen's money fly carries the payout cue.
func _on_money_moved(delta: int, _reason: String) -> void:
	if GameState.clock_moving():
		return
	play_money(delta)


func _on_contract_rejected(_entry_id: int) -> void:
	play_reject()


func _on_permit_granted(_loc_id: int, _kind: StringName) -> void:
	play_permit()


func _hook_mercdave() -> void:
	Mercdave.spoke.connect(play_mercdave_text)


#Every delivered mail but spam chimes message_basic at the notice volume; mail never reaches NotificationCenter.
func _on_mail_delivered(mail: MailInstance) -> void:
	if mail.folder == &"spam":
		return
	_queue(config.message_basic, 1.0, NOTICE_DB)


#A rising stock move or an approved loan offer.
func _good_news(row: NotificationData) -> bool:
	if row.type == NotificationData.TYPE_STOCK_MOVE:
		return row.rising()
	if row.type == NotificationData.TYPE_LOAN_OFFER:
		return bool(row.snap.get("approved", false))
	return false


func _any_fate(result: ContractResultData, fate: int) -> bool:
	for member: ResultMemberData in result.members:
		if member != null and member.fate == fate:
			return true
	return false


func _queue(library: SoundLibrary, pitch: float = 1.0, volume_db: float = 0.0, fade_out_seconds: float = 0.0) -> void:
	AudioManager.queue(library, String(config.event_bus), pitch, volume_db, fade_out_seconds)


#A remembered player still playing the stream the scrub started, not cut off by the pool or fading out.
func _scrub_live() -> bool:
	if not is_instance_valid(_scrub_player) or AudioManager.fading(_scrub_player):
		return false
	return _scrub_player.playing and _scrub_player.stream == _scrub_stream


func _start_scrub() -> void:
	_drop_scrub()
	var player: AudioStreamPlayer = AudioManager.play(config.graph_draw.pick(), String(config.event_bus), _scrub_pitch,
		GRAPH_DB)
	if player == null:
		return
	_scrub_player = player
	_scrub_stream = player.stream
	player.finished.connect(_on_scrub_finished)


#A plain connection dropped by hand: a stopped player never emits finished, so a one-shot link would linger on it.
func _drop_scrub() -> void:
	if is_instance_valid(_scrub_player) and _scrub_player.finished.is_connected(_on_scrub_finished):
		_scrub_player.finished.disconnect(_on_scrub_finished)
	_scrub_player = null
	_scrub_stream = null


#The pick ran out while the pointer still crosses points, so the next pick carries the texture on.
func _on_scrub_finished() -> void:
	if is_instance_valid(_scrub_player) and _scrub_player.stream == _scrub_stream:
		_start_scrub()
	else:
		_drop_scrub()
