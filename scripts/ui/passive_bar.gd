class_name PassiveBar
extends Control
## One burning passive: name + level, a bar that shrinks like a burning stick,
## and a FlameAnchor kept at the burn edge. wood_texture/charred_texture tile
## horizontally across the Bar rect (like the laser beam strip) rather than
## stretching, since they're authored as small repeating strips. With no
## textures assigned they fall back to flat colors.
##
## To add art (see docs/ANIMATION_GUIDE.md):
##  - Wood plank + charred remains: small horizontally-tileable PNGs, same
##    height as the Bar node (8 px), assigned to wood_texture/charred_texture
##    below.
##  - Flame: replace FlameAnchor's placeholder child with an AnimatedSprite2D —
##    the anchor's position is already driven by this script.

## Optional wood-grain strip for the remaining (unburnt) fill, tiled
## horizontally. Empty = flat placeholder color.
@export var wood_texture: Texture2D
## Optional charred-remains strip shown behind the fill as it burns away,
## tiled horizontally across the full bar.
@export var charred_texture: Texture2D

const WOOD_COLOR := Color(0.85, 0.72, 0.5)
const CHARRED_COLOR := Color(0.12, 0.1, 0.08, 0.8)

var passive_id: StringName
var _ratio := 1.0

@onready var name_label: Label = $NameLabel
@onready var bar: Control = $Bar
@onready var flame_anchor: Control = $FlameAnchor

func _ready() -> void:
	# Tile crisply (pixel art) instead of the default stretch/repeat-off look.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _process(_delta: float) -> void:
	if passive_id not in RunState.passives:
		return
	var state: Dictionary = RunState.passives[passive_id]
	var config: Dictionary = RunState.PASSIVES[passive_id]
	_ratio = clampf(state.time_left / config.duration, 0.0, 1.0)
	if config.max_level > 1:
		name_label.text = "%s Lv%d" % [config.name, state.level]
	else:
		name_label.text = config.name
	flame_anchor.position = bar.position + Vector2(bar.size.x * _ratio, bar.size.y * 0.5)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(bar.position, bar.size)
	_draw_tiled(rect, charred_texture, CHARRED_COLOR)
	var fill_rect := Rect2(rect.position, Vector2(rect.size.x * _ratio, rect.size.y))
	_draw_tiled(fill_rect, wood_texture, WOOD_COLOR)

func _draw_tiled(rect: Rect2, texture: Texture2D, fallback_color: Color) -> void:
	if rect.size.x <= 0.0:
		return
	if texture:
		draw_texture_rect(texture, rect, true)
	else:
		draw_rect(rect, fallback_color)
