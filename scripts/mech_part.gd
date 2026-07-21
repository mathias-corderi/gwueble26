class_name MechPart
extends Area2D
## A robotic part dropped by a chair that burned out after filling its meter.
## It flies out of the wreck, then waits on the map forever — parts never
## despawn, so the player can come back for them. Walking over one picks it up
## (up to RunState.MAX_CARRIED_PARTS); haul them to the MechStation to build
## the Mech. The source ChairData travels with the part, which is how the Mech
## knows which passives it was built from.

## Initial fly-out speed and how fast it bleeds off.
const EJECT_SPEED_MIN := 180.0
const EJECT_SPEED_MAX := 320.0
const DAMPING := 900.0
const RADIUS := 11.0

var source: ChairData

var _velocity := Vector2.ZERO

@onready var name_label: Label = $NameLabel

## Must be called before the part is added to the tree.
func setup(chair_data: ChairData) -> void:
	source = chair_data
	_velocity = Vector2.from_angle(randf() * TAU) * randf_range(EJECT_SPEED_MIN, EJECT_SPEED_MAX)

func _ready() -> void:
	add_to_group("mech_parts")
	body_entered.connect(_on_body_entered)
	name_label.text = "%s part" % source.display_name
	queue_redraw()

func _process(delta: float) -> void:
	if _velocity == Vector2.ZERO:
		return
	position += _velocity * delta
	_velocity = _velocity.move_toward(Vector2.ZERO, DAMPING * delta)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is Player:
		if RunState.carry_part(source):
			queue_free()
		else:
			body.pickup_rejected.emit() # hands full — the part stays put

func _draw() -> void:
	if source.sprite:
		SpriteFit.draw(self, source.sprite, Vector2.ONE * RADIUS * 2.4)
		return
	# Placeholder cog: a ring of teeth tinted with the chair it came from.
	var color := source.color
	draw_circle(Vector2.ZERO, RADIUS, color.darkened(0.25))
	draw_circle(Vector2.ZERO, RADIUS * 0.45, Color(0.1, 0.1, 0.12))
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var tooth := Vector2.from_angle(angle) * RADIUS
		draw_line(tooth * 0.8, tooth * 1.35, color, 4.0)
