extends Node
## Background music + one-shot chair sounds.
##
## Music: a looping level theme that starts with the run and is swapped for the
## mech theme when the player boards the Mech. Two players alternate so tracks
## can overlap during the 0.5s crossfade; streams loop by replaying on finish.
## Both music players route to the "Music" bus.
##
## Chair sounds: a single dedicated player fires the chair's `sit_sound` once
## (no loop) when the player sits, layered on top of the music. It routes to the
## "SFX" bus. The Music/SFX buses live in res://default_bus_layout.tres and their
## volumes are driven by SettingsManager.

## Looping background themes. Placeholders in res://audio/music/ — replace the
## files to give the level its music; the paths stay stable.
const LEVEL_MUSIC: AudioStream = preload("res://audio/music/level_theme.wav")
const MECH_MUSIC: AudioStream = preload("res://audio/music/mech_theme.wav")

const FADE_TIME := 0.5
const MUSIC_DB := -8.0
const SILENT_DB := -60.0

var _players: Array[AudioStreamPlayer] = []
var _active := -1
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		add_child(player)
		player.finished.connect(_on_player_finished.bind(player))
		_players.append(player)
	# One-shot chair sounds: never reconnects finished -> play, so it plays once.
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = &"SFX"
	add_child(_sfx_player)

## Starts (or keeps) the looping level theme — call when a run begins.
func play_level_music() -> void:
	play_track(LEVEL_MUSIC)

## Crossfades the looping music over to the mech theme — call on boarding.
func play_mech_music() -> void:
	play_track(MECH_MUSIC)

## Fires a chair's sit sound once, over the current music. Null = no sound.
func play_chair_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()

func play_track(stream: AudioStream) -> void:
	if stream == null:
		stop_music()
		return
	if _active >= 0 and _players[_active].stream == stream and _players[_active].playing:
		return
	var next: int = 0 if _active < 0 else (_active + 1) % 2
	var previous := _active
	_active = next
	var player := _players[next]
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()
	_fade(player, MUSIC_DB)
	if previous >= 0 and previous != next:
		_fade_out(_players[previous])

func stop_music() -> void:
	if _active >= 0:
		_fade_out(_players[_active])
		_active = -1

func _fade(player: AudioStreamPlayer, to_db: float) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, FADE_TIME)

func _fade_out(player: AudioStreamPlayer) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, FADE_TIME)
	tween.tween_callback(player.stop)

func _on_player_finished(player: AudioStreamPlayer) -> void:
	if _active >= 0 and _players[_active] == player:
		player.play()
