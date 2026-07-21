class_name WeaponData
extends Resource
## Defines a weapon. To add a new weapon, create a new .tres with this script
## in res://data/weapons/ — the spawner picks it up automatically.

enum Handedness { ONE_HANDED, TWO_HANDED }
## PROJECTILE fires bullets. BEAM channels a continuous laser while fire is
## held; the attack fields are reinterpreted (see below).
enum AttackType { PROJECTILE, BEAM }

@export var display_name: String = "Weapon"
@export var color: Color = Color.WHITE
## Drives optional animation variants (see docs/ANIMATION_GUIDE.md); no gameplay effect.
@export var handedness: Handedness = Handedness.ONE_HANDED
## The weapon is discarded when ammo reaches 0 (1 ammo per shot/volley).
@export var max_ammo: int = 60

@export_group("Attack")
## For BEAM weapons: fire_rate = damage ticks/s, damage = per tick, 1 ammo per
## tick, projectile_count/spread_degrees = fan of simultaneous beams,
## projectile_radius = beam half-width, projectile_color = beam tint.
@export var attack_type := AttackType.PROJECTILE
@export var fire_rate: float = 3.0
@export var damage: float = 10.0
@export var projectile_count: int = 1
## With a single projectile this is random jitter; with several it is the fan width.
@export var spread_degrees: float = 0.0
@export var projectile_speed: float = 600.0
@export var projectile_radius: float = 6.0
@export var projectile_color: Color = Color.WHITE
## Seconds a bullet lives before despawning — short values make short-range
## weapons like the Shotgun. PROJECTILE only.
@export var projectile_lifetime: float = 2.5

@export_group("Presentation")
## Pickup + held placeholder sprite (optional).
@export var sprite: Texture2D
## PROJECTILE: bullet sprite, authored pointing right (auto-rotated).
## BEAM: horizontally-tileable grayscale strip, tiled along the ray and tinted
## with projectile_color (empty = flat colored line).
@export var projectile_sprite: Texture2D
## 8-direction animation set for the held weapon (see docs/ANIMATION_GUIDE.md); optional.
@export var weapon_frames: SpriteFrames
