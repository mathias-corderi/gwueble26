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
## True = only spawns once the player is piloting the Mech, and then as an
## extra batch on top of the normal one (existing enemies keep their rate).
@export var requires_mech: bool = false

@export_group("Ranged")
## > 0 turns the enemy into a kiter: it backs away when the player is closer
## than this and closes in when further, instead of charging.
@export var preferred_distance: float = 0.0
## Seconds between shots. 0 = melee only (the default for every basic enemy).
@export var shot_interval: float = 0.0
@export var shot_speed: float = 230.0
@export var shot_radius: float = 14.0
@export var shot_damage: float = 8.0
## Optional projectile sprite; falls back to a colored circle.
@export var shot_sprite: Texture2D
## Tint for the shot sprite/circle and its glow. Alpha 0 (the default) means
## "derive from the enemy's base color"; set it to give shots their own color.
@export var shot_color: Color = Color(0, 0, 0, 0)

@export_group("Presentation")
## Optional sprite; falls back to a colored placeholder circle when unset.
@export var sprite: Texture2D
