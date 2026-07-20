class_name WeaponData
extends Resource
## Defines a weapon. To add a new weapon, create a new .tres with this script
## in res://data/weapons/ — the spawner picks it up automatically.

enum Handedness { ONE_HANDED, TWO_HANDED }

@export var display_name: String = "Weapon"
@export var color: Color = Color.WHITE
## Drives optional animation variants (see docs/ANIMATION_GUIDE.md); no gameplay effect.
@export var handedness: Handedness = Handedness.ONE_HANDED
## The weapon is discarded when ammo reaches 0 (1 ammo per shot/volley).
@export var max_ammo: int = 60

@export_group("Attack")
@export var fire_rate: float = 3.0
@export var damage: float = 10.0
@export var projectile_count: int = 1
## With a single projectile this is random jitter; with several it is the fan width.
@export var spread_degrees: float = 0.0
@export var projectile_speed: float = 600.0
@export var projectile_radius: float = 6.0
@export var projectile_color: Color = Color.WHITE

@export_group("Presentation")
## Pickup + held placeholder sprite (optional).
@export var sprite: Texture2D
@export var projectile_sprite: Texture2D
## 8-direction animation set for the held weapon (see docs/ANIMATION_GUIDE.md); optional.
@export var weapon_frames: SpriteFrames
