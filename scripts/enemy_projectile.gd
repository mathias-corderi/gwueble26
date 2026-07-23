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
	color = data.shot_color if data.shot_color.a > 0.0 else data.color.lerp(Color.WHITE, 0.35)
	sprite = data.shot_sprite
	velocity = direction * data.shot_speed

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	# Additive blend fakes an intense glow under the GL Compatibility renderer.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
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
	# Soft additive halo behind the shot for the glow read.
	var glow := Color(color.r, color.g, color.b, 0.16)
	draw_circle(Vector2.ZERO, radius * 2.3, glow)
	draw_circle(Vector2.ZERO, radius * 1.6, glow)
	if sprite:
		SpriteFit.draw(self, sprite, Vector2.ONE * radius * 2.2, color)
		return
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color.lightened(0.5), 2.0)
