class_name Projectile
extends Area2D
## A single shot fired while seated. Passive flags are baked in at spawn time,
## so any chair attack automatically benefits from every active passive.

const LIFETIME := 2.5
const HOMING_TURN_RATE := 5.0
const BURN_DPS := 5.0
const BURN_DURATION := 2.5
const EXPLOSION_RADIUS := 90.0
const EXPLOSION_DAMAGE_FACTOR := 0.7
const PIERCE_COUNT := 2

var damage := 10.0
var radius := 6.0
var color := Color.WHITE
var homing := false
var burn := false
var explosive := false
var pierce_left := 0
var velocity := Vector2.ZERO

var _age := 0.0

## Must be called before the projectile is added to the tree.
func configure(data: ChairData, direction: Vector2, passives: Array[StringName]) -> void:
	damage = data.damage
	radius = data.projectile_radius
	color = data.projectile_color
	velocity = direction * data.projectile_speed
	homing = &"homing" in passives
	burn = &"burn" in passives
	explosive = &"explosive" in passives
	pierce_left = PIERCE_COUNT if &"pierce" in passives else 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	if homing:
		var target := _nearest_enemy()
		if target:
			var desired := (target.global_position - global_position).angle()
			var angle := rotate_toward(velocity.angle(), desired, HOMING_TURN_RATE * delta)
			velocity = Vector2.from_angle(angle) * velocity.length()
	global_position += velocity * delta

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)

func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		_hit_enemy(body)
	else:
		queue_free() # walls stop everything, pierce included

func _hit_enemy(enemy: Enemy) -> void:
	enemy.take_damage(damage)
	if burn:
		enemy.apply_burn(BURN_DPS, BURN_DURATION)
	if explosive:
		_explode(enemy)
	if pierce_left > 0:
		pierce_left -= 1
	else:
		queue_free()

func _explode(direct_target: Enemy) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == direct_target:
			continue
		if global_position.distance_to(enemy.global_position) <= EXPLOSION_RADIUS:
			enemy.take_damage(damage * EXPLOSION_DAMAGE_FACTOR)
			if burn:
				enemy.apply_burn(BURN_DPS, BURN_DURATION)
	PulseVfx.spawn(get_tree().current_scene, global_position, EXPLOSION_RADIUS, Color(1.0, 0.6, 0.2), 0.25)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist: float = global_position.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best
