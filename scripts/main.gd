extends Node2D
## Root of the game scene: resets run state and handles game over.

func _ready() -> void:
	_setup_glow_environment()
	RunState.reset()
	Sfx.stop_all_loops() # a restart mid-channel must not leave a loop playing
	MusicManager.play_level_music()
	# Built here (like the environment) so main.tscn and sandbox.tscn share it.
	add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())
	($Player as Player).died.connect(_on_player_died)

## Adds a WorldEnvironment with additive HDR glow so laser beams (whose colors
## are pushed past 1.0, see laser_beam.gd) bloom like a bright HDR highlight.
## The ~1.0 threshold means only HDR pixels bloom, so normal sprites and the HUD
## stay crisp. Requires the Forward+/Mobile renderer and rendering/viewport/hdr_2d,
## both set in project.godot. Built in code so main.tscn and sandbox.tscn (which
## share this script) both get it without versioning the node twice.
func _setup_glow_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.85
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 1.0
	env.set_glow_level(2, 1.0) # level 3
	env.set_glow_level(3, 1.0) # level 4
	env.set_glow_level(4, 1.0) # level 5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# Let SettingsManager reach this code-built environment (brightness/HDR).
	world_env.add_to_group(SettingsManager.ENV_GROUP)
	SettingsManager.apply_environment()

func _on_player_died() -> void:
	RunState.game_over = true
	MusicManager.stop_music()
	get_tree().paused = true
