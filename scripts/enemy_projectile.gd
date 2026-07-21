class_name EnemyProjectile
extends Area2D
## A shot fired by a ranged enemy. It flies straight and passes through other
## enemies — its collision mask only covers the player and chairs — so a crowd
## never shields the player. It is destroyed on hitting the player (or the
## Mech, which forwards the damage to its pilot) or on leaving the arena.

var damage := 8.0
var radius := 14.0
var color := Color(1.0, 0.55, 0.9)
var sprite: Texture2D
var velocity := Vector2.ZERO

## Must be called before the projectile is added to the tree.
func configure(data: EnemyData, direction: Vector2) -> void:
	damage = data.shot_damage
	radius = data.shot_radius
	color = data.color.lerp(Color.WHITE, 0.35)
	sprite = data.shot_sprite
	velocity = direction * data.shot_speed

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	rotation = velocity.angle()
	if not RunState.ARENA.has_point(global_position):
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.take_damage(damage)
		queue_free()
	elif body is Mech:
		body.take_damage(damage) # forwarded to the pilot
		queue_free()

func _draw() -> void:
	if sprite:
		SpriteFit.draw(self, sprite, Vector2.ONE * radius * 2.2)
		return
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color.lightened(0.5), 2.0)
