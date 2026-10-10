extends Node

#The pool of AudioStreamPlayers every interface and event sound plays through. queue() collapses
#repeat requests for one library inside a frame into a single play when the deferred flush runs.
#fade_out() tweens a player's linear volume to silence and then stops it; a reused player loses its fade first.

signal played(stream: AudioStream, bus: String, pitch: float)

const DEFAULT_BUS: String = "Sound Effects"
const MASTER_BUS: String = "Master"
const MAX_PLAYERS: int = 24

#{"stream", "bus", "pitch", "volume_db", "fade" (fade-out seconds, 0.0 for none), "player"} of the last play.
var last: Dictionary = {}
var last_volume_db: float = 0.0
var play_count: int = 0

#Library instance id to {"library", "bus", "pitch", "volume_db", "fade"} waiting for flush().
var _queued: Dictionary = {}
#Player instance id to the Tween fading that player out; an entry leaves when its fade ends or is killed.
var _fades: Dictionary = {}


#A fade_out_seconds above zero fades the cue from volume_db to silence by that time, then stops it.
func play(stream: AudioStream, bus: String = DEFAULT_BUS, pitch: float = 1.0,
		volume_db: float = 0.0, fade_out_seconds: float = 0.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	var target: String = bus_or_master(bus)
	var player: AudioStreamPlayer = _free_player()
	_kill_fade(player)
	player.stream = stream
	player.bus = target
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
	if fade_out_seconds > 0.0:
		fade_out(player, fade_out_seconds)
	last = {"stream": stream, "bus": target, "pitch": pitch, "volume_db": volume_db, "fade": maxf(fade_out_seconds, 0.0),
		"player": player}
	last_volume_db = volume_db
	play_count += 1
	played.emit(stream, target, pitch)
	return player


func play_library(library: SoundLibrary, bus: String = DEFAULT_BUS, pitch: float = 1.0,
		volume_db: float = 0.0, fade_out_seconds: float = 0.0) -> AudioStreamPlayer:
	if library == null or library.is_empty():
		return null
	return play(library.pick(), bus, pitch, volume_db, fade_out_seconds)


#One play per library per frame; a repeat request before the flush replaces the bus, pitch, volume and fade.
func queue(library: SoundLibrary, bus: String = DEFAULT_BUS, pitch: float = 1.0,
		volume_db: float = 0.0, fade_out_seconds: float = 0.0) -> void:
	if library == null or library.is_empty():
		return
	if _queued.is_empty():
		flush.call_deferred()
	_queued[library.get_instance_id()] = {"library": library, "bus": bus, "pitch": pitch, "volume_db": volume_db,
		"fade": fade_out_seconds}


#Drops the library's cue before the flush plays it; true when one was waiting.
func unqueue(library: SoundLibrary) -> bool:
	if library == null:
		return false
	return _queued.erase(library.get_instance_id())


func flush() -> void:
	var waiting: Array = _queued.values()
	_queued.clear()
	for item: Dictionary in waiting:
		play_library(item["library"], item["bus"], item["pitch"], item["volume_db"], item["fade"])


func pending_count() -> int:
	return _queued.size()


func bus_or_master(bus: String) -> String:
	if AudioServer.get_bus_index(bus) >= 0:
		return bus
	return MASTER_BUS


#Fades the player from its current linear volume to 0.0 over the seconds, linear in linear volume, then stops it.
func fade_out(player: AudioStreamPlayer, seconds: float) -> void:
	if player == null:
		return
	_kill_fade(player)
	if seconds <= 0.0:
		player.stop()
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_linear", 0.0, seconds)
	tween.finished.connect(_end_fade.bind(player))
	_fades[player.get_instance_id()] = tween


func fading(player: AudioStreamPlayer) -> bool:
	return fade_of(player) != null


#The live Tween fading the player out, or null.
func fade_of(player: AudioStreamPlayer) -> Tween:
	if player == null:
		return null
	var tween: Tween = _fades.get(player.get_instance_id()) as Tween
	if tween == null or not tween.is_valid():
		return null
	return tween


func stop_all() -> void:
	_queued.clear()
	for tween: Tween in _fades.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_fades.clear()
	for child: Node in get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null:
			player.stop()


#An idle child, else a new one while the pool is below MAX_PLAYERS, else the first child is cut off.
func _free_player() -> AudioStreamPlayer:
	for child: Node in get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and not player.playing:
			return player
	if get_child_count() < MAX_PLAYERS:
		var fresh := AudioStreamPlayer.new()
		add_child(fresh)
		return fresh
	return get_child(0) as AudioStreamPlayer


func _end_fade(player: AudioStreamPlayer) -> void:
	_fades.erase(player.get_instance_id())
	player.stop()


func _kill_fade(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	var id: int = player.get_instance_id()
	var tween: Tween = _fades.get(id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_fades.erase(id)
