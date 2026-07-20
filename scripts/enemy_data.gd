class_name EnemyData
extends Resource
## Defines an enemy type. To add a new enemy, create a new .tres with this
## script in res://data/enemies/ — the spawner picks it up automatically.

@export var display_name: String = "Enemy"
@export var color: Color = Color.RED
@export var radius: float = 14.0
@export var speed: float = 120.0
@export var max_hp: float = 20.0
@export var contact_damage: float = 6.0
@export var attack_interval: float = 0.8
## Run time in seconds before this enemy type starts spawning.
@export var unlock_time: float = 0.0

@export_group("Presentation")
## Optional sprite; falls back to a colored placeholder circle when unset.
@export var sprite: Texture2D
