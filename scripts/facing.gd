class_name Facing
extends RefCounted
## Shared 8-direction facing convention (see docs/ANIMATION_GUIDE.md).
## Art is authored in 5 directions (side ones facing RIGHT); the 3 west
## directions are mirrored with flip_h.

const DIR_DOWN := &"down"
const DIR_DOWN_SIDE := &"down_side"
const DIR_SIDE := &"side"
const DIR_UP_SIDE := &"up_side"
const DIR_UP := &"up"

## Maps a world-space vector to {dir: StringName, flip_h: bool}.
static func from_vector(v: Vector2) -> Dictionary:
	if v == Vector2.ZERO:
		return {dir = DIR_DOWN, flip_h = false}
	# Octants: 0=E, 1=SE, 2=S, 3=SW, 4/-4=W, -3=NW, -2=N, -1=NE (y-down).
	var octant := wrapi(roundi(v.angle() / (PI / 4.0)), -4, 4)
	match octant:
		0: return {dir = DIR_SIDE, flip_h = false}
		1: return {dir = DIR_DOWN_SIDE, flip_h = false}
		2: return {dir = DIR_DOWN, flip_h = false}
		3: return {dir = DIR_DOWN_SIDE, flip_h = true}
		-1: return {dir = DIR_UP_SIDE, flip_h = false}
		-2: return {dir = DIR_UP, flip_h = false}
		-3: return {dir = DIR_UP_SIDE, flip_h = true}
		_: return {dir = DIR_SIDE, flip_h = true}

## Plays the first animation in `candidates` that exists in the sprite's
## frames. No-ops when no SpriteFrames is assigned (placeholder mode).
static func play_anim(sprite: AnimatedSprite2D, candidates: Array, flip: bool) -> void:
	if sprite.sprite_frames == null:
		return
	sprite.flip_h = flip
	for anim in candidates:
		if sprite.sprite_frames.has_animation(anim):
			if sprite.animation != StringName(anim) or not sprite.is_playing():
				sprite.play(anim)
			return
