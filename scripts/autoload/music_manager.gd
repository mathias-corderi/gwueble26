extends Node
## Crossfades between chair themes. Two players alternate so tracks can overlap
## during the fade; streams loop by replaying on finish.

const FADE_TIME := 0.5
const MUSIC_DB := -8.0
const SILENT_DB := -60.0

var _players: Array[AudioStreamPlayer] = []
var _active := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		add_child(player)
		player.finished.connect(_on_player_finished.bind(player))
		_players.append(player)

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
