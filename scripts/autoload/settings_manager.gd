extends Node
## Persists and applies user settings — audio bus volumes and video options —
## to a ConfigFile at user://settings.cfg. Autoloaded and PROCESS_MODE_ALWAYS so
## the pause/options menu can drive it live while the game is paused. Every
## setter applies immediately and saves, so the menu never needs an "Apply".

const CONFIG_PATH := "user://settings.cfg"
const ENV_GROUP := &"world_environment"

## Windowed resolutions offered by the Video options (index maps to the
## OptionButton). Fullscreen ignores these and uses the native screen size.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

# Audio — linear 0..1 (0 mutes the bus).
var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0
# Video.
var fullscreen := false
var resolution := Vector2i(1280, 720)
var brightness := 1.0 ## 1.0 = neutral; drives Environment.adjustment_brightness.
var hdr := true
var vsync := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	apply_all()

# --- persistence ---

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return # first launch: keep defaults
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	resolution = cfg.get_value("video", "resolution", resolution)
	brightness = cfg.get_value("video", "brightness", brightness)
	hdr = cfg.get_value("video", "hdr", hdr)
	vsync = cfg.get_value("video", "vsync", vsync)

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "resolution", resolution)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("video", "hdr", hdr)
	cfg.set_value("video", "vsync", vsync)
	cfg.save(CONFIG_PATH)

# --- apply ---

func apply_all() -> void:
	_apply_bus(&"Master", master_volume)
	_apply_bus(&"Music", music_volume)
	_apply_bus(&"SFX", sfx_volume)
	apply_display()
	apply_environment()

func _apply_bus(bus_name: StringName, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, value <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(value, 0.0001, 1.0)))

func apply_display() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		DisplayServer.window_set_size(resolution)
		var screen := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(screen)
		var pos := DisplayServer.screen_get_position(screen) + (screen_size - resolution) / 2
		DisplayServer.window_set_position(pos)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

## Applies brightness + HDR to the code-built WorldEnvironment that main.gd
## registers in ENV_GROUP, plus the main viewport's HDR flag. A no-op for the
## environment part when no WorldEnvironment exists (e.g. other scenes).
func apply_environment() -> void:
	get_viewport().use_hdr_2d = hdr
	var world_env := get_tree().get_first_node_in_group(ENV_GROUP) as WorldEnvironment
	if world_env == null or world_env.environment == null:
		return
	var env := world_env.environment
	env.adjustment_enabled = true
	env.adjustment_brightness = brightness
	# The glow bloom relies on HDR headroom, so turning HDR off also drops glow.
	env.glow_enabled = hdr

# --- setters used by the options menu (apply immediately + persist) ---

func set_master_volume(value: float) -> void:
	master_volume = value
	_apply_bus(&"Master", value)
	save()

func set_music_volume(value: float) -> void:
	music_volume = value
	_apply_bus(&"Music", value)
	save()

func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	_apply_bus(&"SFX", value)
	save()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()
	save()

func set_resolution(res: Vector2i) -> void:
	resolution = res
	apply_display()
	save()

func set_brightness(value: float) -> void:
	brightness = value
	apply_environment()
	save()

func set_hdr(value: bool) -> void:
	hdr = value
	apply_environment()
	save()

func set_vsync(value: bool) -> void:
	vsync = value
	apply_display()
	save()
