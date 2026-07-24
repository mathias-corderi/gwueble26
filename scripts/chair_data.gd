class_name ChairData
extends Resource
## Defines a chair type. To add a new chair to the game, create a new .tres
## with this script in res://data/chairs/ — the spawner picks it up automatically.
## Chairs no longer provide the primary attack (weapons do); they provide the
## passive, an optional secondary attack, mobility, and survivability.

@export var display_name: String = "Chair"
@export var color: Color = Color.WHITE
## False keeps it out of the map spawner (e.g. the Mech, which is assembled).
@export var spawns_on_map: bool = true
@export var max_hp: float = 60.0
## Seconds the player must stay seated for the passive to be granted/refreshed.
@export var meter_time: float = 12.0
## 0 = static chair (movement locked while seated); > 0 = the chair is a mount
## driven with the move keys at this speed while seated.
@export var move_speed: float = 0.0

@export_group("Passive")
## One of the ids in RunState.PASSIVES (triple_shot, homing, burn, explosive, pierce).
@export var passive_id: StringName = &"triple_shot"

@export_group("Secondary Attack")
## Right-click ability while seated. Empty = none. Implemented: "shockwave".
@export var secondary_id: StringName = &""
@export var secondary_cooldown: float = 4.0
## -1 = unlimited uses (cooldown only).
@export var secondary_uses: int = -1
## Generic magnitude multiplier (shockwave: knockback force and damage).
@export var secondary_power: float = 1.0

@export_group("Break Effect")
## Fired whenever the chair breaks (enemy damage, burnout or standing up).
## Empty = none. Implemented: "electric_burst".
@export var break_effect_id: StringName = &""
## Generic magnitude multiplier (electric_burst: radius and damage).
@export var break_effect_power: float = 1.0

@export_group("Presentation")
## One-shot sound played once when the player sits on this chair; it does not
## loop and plays over the level music. The Mech additionally swaps the level
## music (see player._sit). Placeholder .wav per chair in res://audio/chairs/ —
## replace the file to give the chair its sound.
@export var sit_sound: AudioStream
## Static sprite fallback used when chair_frames is not set (optional).
@export var sprite: Texture2D
## 8-direction animation set (idle_<dir>, optional move_<dir> for mounts);
## see docs/ANIMATION_GUIDE.md. Optional — falls back to sprite, then placeholder.
@export var chair_frames: SpriteFrames
