class_name PlayerAnimator
extends Node
## Drives the decoupled body/weapon AnimatedSprite2Ds: 8-direction facing from
## the cursor (twin-stick — movement never changes facing), state from input,
## horizontal mirroring, and weapon-behind-body ordering when aiming up.
## Naming convention and authoring rules: docs/ANIMATION_GUIDE.md.

## How long the shoot animation lingers after the last shot.
const SHOOT_ANIM_TIME := 0.25
const WEAPON_Z_FRONT := 1
const WEAPON_Z_BEHIND := -1

@onready var player: Player = get_parent()
@onready var body: AnimatedSprite2D = player.get_node("BodySprite")
@onready var weapon_sprite: AnimatedSprite2D = player.get_node("WeaponSprite")

func _process(_delta: float) -> void:
	var aim := player.global_position.direction_to(player.get_global_mouse_position())
	var facing := Facing.from_vector(aim)
	var state := _current_state()
	var candidates := _anim_candidates(state, facing.dir)
	Facing.play_anim(body, candidates, facing.flip_h)
	_update_weapon_sprite(candidates, facing)

func _current_state() -> String:
	var shooting := player.time_since_fire < SHOOT_ANIM_TIME
	if player.state == Player.State.SEATED:
		return "sit_shoot" if shooting else "sit"
	if shooting:
		return "shoot"
	if player.velocity.length() > 5.0:
		return "walk"
	return "idle"

func _anim_candidates(state: String, dir: StringName) -> Array:
	var candidates: Array = []
	var weapon := player.current_weapon()
	# Optional two-handed variants take priority when present in the frames.
	if not weapon.is_empty() and weapon.data.handedness == WeaponData.Handedness.TWO_HANDED:
		candidates.append("%s_2h_%s" % [state, dir])
	candidates.append("%s_%s" % [state, dir])
	if state == "sit_shoot":
		candidates.append("sit_%s" % dir)
	if state == "shoot":
		candidates.append("idle_%s" % dir)
	candidates.append("idle_%s" % dir)
	candidates.append("idle_down")
	return candidates

func _update_weapon_sprite(candidates: Array, facing: Dictionary) -> void:
	var weapon := player.current_weapon()
	if weapon.is_empty():
		weapon_sprite.visible = false
		return
	weapon_sprite.visible = true
	if weapon_sprite.sprite_frames != weapon.data.weapon_frames:
		weapon_sprite.sprite_frames = weapon.data.weapon_frames
	Facing.play_anim(weapon_sprite, candidates, facing.flip_h)
	var behind: bool = facing.dir == Facing.DIR_UP or facing.dir == Facing.DIR_UP_SIDE
	weapon_sprite.z_index = WEAPON_Z_BEHIND if behind else WEAPON_Z_FRONT
