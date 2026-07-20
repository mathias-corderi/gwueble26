class_name PulseVfx
extends Node2D
## Expanding ring placeholder VFX, used for chair-break knockback and explosions.

var max_radius := 100.0
var color := Color.WHITE
var duration := 0.3

var _age := 0.0

static func spawn(parent: Node, pos: Vector2, radius: float, ring_color: Color, dur := 0.35) -> void:
	if parent == null:
		return
	var vfx := PulseVfx.new()
	vfx.max_radius = radius
	vfx.color = ring_color
	vfx.duration = dur
	parent.add_child(vfx)
	vfx.global_position = pos

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := _age / duration
	var ring_color := color
	ring_color.a = 1.0 - t
	draw_arc(Vector2.ZERO, max_radius * ease(t, 0.5), 0.0, TAU, 48, ring_color, 6.0)
