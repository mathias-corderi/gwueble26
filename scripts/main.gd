extends Node2D
## Root of the game scene: resets run state and handles game over.

func _ready() -> void:
	RunState.reset()
	($Player as Player).died.connect(_on_player_died)

func _on_player_died() -> void:
	RunState.game_over = true
	MusicManager.stop_music()
	get_tree().paused = true
