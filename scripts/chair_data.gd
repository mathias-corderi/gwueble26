class_name ChairData
extends Resource
## Defines a chair type. To add a new chair to the game, create a new .tres
## with this script in res://data/chairs/ — the spawner picks it up automatically.

@export var display_name: String = "Chair"
@export var color: Color = Color.WHITE
@export var max_hp: float = 60.0
## Seconds the player must stay seated for the passive to become permanent.
@export var meter_time: float = 12.0

@export_group("Attack")
@export var fire_rate: float = 3.0
@export var damage: float = 10.0
@export var projectile_count: int = 1
## With a single projectile this is random jitter; with several it is the fan width.
@export var spread_degrees: float = 0.0
@export var projectile_speed: float = 600.0
@export var projectile_radius: float = 6.0
@export var projectile_color: Color = Color.WHITE

@export_group("Passive")
## One of the ids in RunState.PASSIVE_NAMES (triple_shot, homing, burn, explosive, pierce).
@export var passive_id: StringName = &"triple_shot"

@export_group("Presentation")
@export var music: AudioStream
## Optional sprite; falls back to a colored placeholder rectangle when unset.
@export var sprite: Texture2D
## Optional sprite for this chair's projectiles; falls back to a colored circle.
@export var projectile_sprite: Texture2D
## Optional replacement for the default projectile attack; unused by the prototype.
@export var custom_attack_scene: PackedScene
