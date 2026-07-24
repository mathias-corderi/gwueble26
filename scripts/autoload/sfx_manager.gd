extends Node
## Central gameplay SFX: a pool of one-shot players with per-call random pitch
## (so repeated sounds never play twice identically), plus refcounted looping
## sounds for continuous sources (channeled laser, missile swarm).
##
## Everything routes to the "SFX" bus, so the pause-menu volume slider governs
## it all; per-sound loudness is set with volume_db at the call site — bus
## volumes belong to SettingsManager. Unlike MusicManager this node keeps the
## default pause mode, so every one-shot and loop freezes under the pause menu.

## Streams not owned by a WeaponData resource (weapon fire sounds live in the
## weapon .tres files instead).
const IMPACTS: Array[AudioStream] = [
	preload("res://audio/sfx/impact_1.wav"),
	preload("res://audio/sfx/impact_2.wav"),
	preload("res://audio/sfx/impact_3.wav"),
]
const PISTOL := preload("res://audio/sfx/pistol_shot.wav")
const EXPLOSION := preload("res://audio/sfx/explosion.wav")
const SPARK := preload("res://audio/sfx/spark.wav")
const SONIC_BOOM := preload("res://audio/sfx/sonic_boom.wav")
const LASER_CHARGE := preload("res://audio/sfx/laser_charge.wav")
const MEGA_LASER := preload("res://audio/sfx/mega_laser.wav")
const LASER_BURST := preload("res://audio/sfx/laser_burst.wav")
const WHEEL_ACCEL := preload("res://audio/sfx/wheel_dash.wav")
const WHEEL_CRASH := preload("res://audio/sfx/wheel_crash.wav")
const SPEAR := preload("res://audio/sfx/spear_thrust.wav")
const AMMO_PICKUP := preload("res://audio/sfx/ammo_pickup.wav")
const MISSILE_LOOP := preload("res://audio/sfx/missile_loop.wav")
const MISSILE_LAUNCH := preload("res://audio/sfx/missile_launch.wav")

## Every SFX plays this much quieter, so the whole layer sits under the music
## (which is at -8 dB). Tune here to move the entire mix at once.
const MASTER_TRIM_DB := -6.0
const PLAYER_COUNT := 14
## The same stream asked for twice within this window plays once (shotgun
## pellets hitting together, the spear_burst's four simultaneous spears...).
const THROTTLE_MS := 40
## A one-shot younger than this is never stolen: it is the most audible one.
const STEAL_PROTECT_MS := 100
const LOOP_FADE := 0.2

var _pool: Array[AudioStreamPlayer] = []
var _started_ms: Array[int] = []
var _next := 0
## stream -> last start in ticks msec, for the throttle.
var _last_play_ms := {}
## key -> {player: AudioStreamPlayer, refs: int}
var _loops := {}

func _ready() -> void:
	for i in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)
		_started_ms.append(0)

## Fires a one-shot with random pitch variation. jitter 0.06 = +/-6%.
## throttle_ms 0 disables the per-stream dedupe (for deliberately overlapping
## same-stream sounds like the missile swarm's launches).
func play(stream: AudioStream, volume_db := 0.0, pitch := 1.0, jitter := 0.06,
		throttle_ms := THROTTLE_MS) -> void:
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if throttle_ms > 0 and now - int(_last_play_ms.get(stream, -throttle_ms)) < throttle_ms:
		return
	_last_play_ms[stream] = now
	var player := _grab_player(now)
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db + MASTER_TRIM_DB
	player.pitch_scale = maxf(0.01, pitch * randf_range(1.0 - jitter, 1.0 + jitter))
	player.play()

## Picks a random variant: round-robin-ish anti-monotony for frequent sounds.
func play_one_of(streams: Array, volume_db := 0.0, pitch := 1.0, jitter := 0.06) -> void:
	if streams.is_empty():
		return
	play(streams[randi() % streams.size()], volume_db, pitch, jitter)

## Starts (or joins) a looping sound shared by every holder of `key`. Each
## acquire must be paired with one loop_release. The stream must be loop-flagged
## in its import settings.
func loop_acquire(key: StringName, stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if stream == null:
		return
	if key in _loops:
		_loops[key].refs += 1
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.stream = stream
	player.volume_db = volume_db + MASTER_TRIM_DB
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	_loops[key] = {player = player, refs = 1}

func loop_release(key: StringName) -> void:
	if key not in _loops:
		return
	_loops[key].refs -= 1
	if _loops[key].refs > 0:
		return
	var player: AudioStreamPlayer = _loops[key].player
	_loops.erase(key)
	# Fade out briefly so the loop doesn't click off.
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -40.0, LOOP_FADE)
	tween.tween_callback(player.queue_free)

## Safety net for scene reloads that skip the normal release paths.
func stop_all_loops() -> void:
	for key in _loops:
		_loops[key].player.queue_free()
	_loops.clear()

## First idle player after the rotating index; otherwise the oldest one that
## isn't freshly started (dropping a sound beats cutting a fresh one).
func _grab_player(now: int) -> AudioStreamPlayer:
	var oldest := -1
	var oldest_ms := now + 1
	for offset in _pool.size():
		var i := (_next + offset) % _pool.size()
		if not _pool[i].playing:
			_next = i + 1
			_started_ms[i] = now
			return _pool[i]
		if _started_ms[i] < oldest_ms:
			oldest_ms = _started_ms[i]
			oldest = i
	if oldest < 0 or now - oldest_ms < STEAL_PROTECT_MS:
		return null
	_next = oldest + 1
	_started_ms[oldest] = now
	return _pool[oldest]
