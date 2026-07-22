class_name MechStation
extends Area2D
## The assembly platform at the centre of the arena. Walking into it hands over
## every carried part; at RunState.MECH_PARTS_REQUIRED the Mech is assembled
## here and can be boarded.
##
## The station shows one build stage per delivered part. Drop the art into
## `build_stage_sprites` (10 entries, bare frame → finished robot) and the
## station upgrades itself; a partially filled array is fine, it just shows the
## highest stage authored so far. Until then it draws a placeholder silhouette
## that gains a piece per stage. See CONTRIBUTING.md.

const MECH_SCENE := preload("res://scenes/mech.tscn")
const PLATFORM_RADIUS := 90.0
## Footprint the stage art is fitted into; grows as the robot is assembled.
const ART_SIZE_MIN := Vector2(70, 70)
const ART_SIZE_MAX := Vector2(190, 210)
const THEME_COLOR := Color(0.6, 0.7, 0.85)

## One texture per build stage, in order. Element i is shown at i + 1 parts.
@export var build_stage_sprites: Array[Texture2D] = []
## Where the assembled Mech is parked, relative to the station.
@export var mech_offset := Vector2(0, 150)

var _mech_spawned := false

@onready var progress_label: Label = $ProgressLabel

func _ready() -> void:
	add_to_group("mech_station")
	body_entered.connect(_on_body_entered)
	RunState.parts_changed.connect(_refresh)
	_refresh()

## 0 = nothing delivered yet; otherwise the 1-based count of delivered parts.
func build_stage() -> int:
	return mini(RunState.deposited_parts.size(), RunState.MECH_PARTS_REQUIRED)

func _on_body_entered(body: Node) -> void:
	if body is Player and RunState.deposit_parts() > 0:
		_try_assemble()

func _try_assemble() -> void:
	if _mech_spawned or RunState.deposited_parts.size() < RunState.MECH_PARTS_REQUIRED:
		return
	_mech_spawned = true
	var mech: Mech = MECH_SCENE.instantiate()
	mech.setup(load("res://data/chairs/mech.tres"))
	mech.position = position + mech_offset
	get_parent().add_child(mech)

func _refresh() -> void:
	var stage := build_stage()
	progress_label.text = "MECH  %d / %d" % [stage, RunState.MECH_PARTS_REQUIRED]
	queue_redraw()

func _draw() -> void:
	var stage := build_stage()
	var ratio := float(stage) / RunState.MECH_PARTS_REQUIRED
	# Platform: a ring that fills up as parts arrive.
	draw_circle(Vector2.ZERO, PLATFORM_RADIUS, Color(0.16, 0.18, 0.22, 0.9))
	draw_arc(Vector2.ZERO, PLATFORM_RADIUS, 0.0, TAU, 48, THEME_COLOR.darkened(0.4), 3.0)
	if ratio > 0.0:
		draw_arc(Vector2.ZERO, PLATFORM_RADIUS - 8.0, -PI / 2.0, -PI / 2.0 + TAU * ratio,
			48, THEME_COLOR, 5.0)
	if stage == 0:
		return
	var texture := _stage_texture(stage)
	if texture:
		SpriteFit.draw(self, texture, ART_SIZE_MIN.lerp(ART_SIZE_MAX, ratio))
	else:
		_draw_placeholder_build(stage)

## Highest authored stage at or below the current one, so art can land one PNG
## at a time without holes.
func _stage_texture(stage: int) -> Texture2D:
	for i in range(mini(stage, build_stage_sprites.size()) - 1, -1, -1):
		if build_stage_sprites[i]:
			return build_stage_sprites[i]
	return null

## Placeholder robot that visibly gains a piece per delivered part.
func _draw_placeholder_build(stage: int) -> void:
	var color := THEME_COLOR
	var steel := color.darkened(0.35)
	if stage >= 1: # feet
		draw_rect(Rect2(-34, 44, 26, 16), steel)
		draw_rect(Rect2(8, 44, 26, 16), steel)
	if stage >= 2: # legs
		draw_rect(Rect2(-28, 4, 16, 42), color)
		draw_rect(Rect2(12, 4, 16, 42), color)
	if stage >= 3: # hips
		draw_rect(Rect2(-30, -8, 60, 16), steel)
	if stage >= 4: # torso
		draw_rect(Rect2(-32, -56, 64, 50), color)
	if stage >= 5: # chest core
		draw_circle(Vector2(0, -32), 10.0, Color(0.9, 0.85, 0.4))
	if stage >= 6: # left arm
		draw_rect(Rect2(-52, -54, 16, 46), steel)
	if stage >= 7: # right arm
		draw_rect(Rect2(36, -54, 16, 46), steel)
	if stage >= 8: # head
		draw_rect(Rect2(-18, -84, 36, 28), color)
	if stage >= 9: # optics
		draw_rect(Rect2(-12, -76, 24, 8), Color(1.0, 0.4, 0.35))
	if stage >= 10: # shoulder cannons — fully assembled
		draw_rect(Rect2(-62, -70, 20, 16), Color(0.85, 0.6, 0.3))
		draw_rect(Rect2(42, -70, 20, 16), Color(0.85, 0.6, 0.3))
