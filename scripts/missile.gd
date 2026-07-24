class_name Missile
extends Area2D
## A self-guided missile from the Smart Chair's secondary. It drifts erratically
## for a moment, then locks onto the nearest enemy and detonates on contact with
## a small explosion that damages and pushes.

const ERRATIC_TIME := 1.0
const SPEED := 340.0
const TURN_RATE := 9.0
const WANDER_RATE := 7.0
const LIFETIME := 4.0
const EXPLODE_RADIUS := 80.0
const EXPLODE_KNOCKBACK := 320.0
const EXPLODE_STUN := 0.2
const RADIUS := 7.0

var damage := 18.0
var color := Color(0.7, 0.9, 1.0)
var velocity := Vector2.ZERO

var _age := 0.0
var _target: Enemy

## Must be called before the missile is added to the tree.
func setup(missile_damage: float, start_dir: Vector2, missile_color: Color) -> void:
	damage = missile_damage
	color = missile_color
	velocity = start_dir * SPEED

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	$CollisionShape2D.shape = shape
	# The whole swarm shares one quiet refcounted flight loop as a bed...
	Sfx.loop_acquire(&"missiles", Sfx.MISSILE_LOOP, -14.0)
	# ...while each missile fires its own launch whoosh with a random delay and
	# pitch (throttle bypassed) so a volley sounds like many, not one.
	get_tree().create_timer(randf() * 0.22).timeout.connect(
		func() -> void: Sfx.play(Sfx.MISSILE_LAUNCH, -6.0, randf_range(0.85, 1.15), 0.0, 0))
	queue_redraw()

func _exit_tree() -> void:
	# Covers detonation, lifetime expiry and scene reloads alike.
	Sfx.loop_release(&"missiles")

func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	if _age < ERRATIC_TIME:
		velocity = velocity.rotated(randf_range(-WANDER_RATE, WANDER_RATE) * delta)
	else:
		if not is_instance_valid(_target) or _target.hp <= 0.0:
			_target = _nearest_enemy()
		if _target:
			var desired := global_position.direction_to(_target.global_position).angle()
			velocity = Vector2.from_angle(rotate_toward(velocity.angle(), desired, TURN_RATE * delta)) * SPEED
	global_position += velocity * delta
	rotation = velocity.angle()

func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		_detonate()

func _detonate() -> void:
	Sfx.play(Sfx.EXPLOSION, -5.0, 1.0, 0.1)
	Combat.knockback_enemies(get_tree(), global_position, EXPLODE_RADIUS,
		EXPLODE_KNOCKBACK, EXPLODE_STUN, damage)
	PulseVfx.spawn(get_tree().current_scene, global_position, EXPLODE_RADIUS, color, 0.2)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_line(Vector2(-RADIUS * 1.6, 0), Vector2(-RADIUS * 3.0, 0), color.lerp(Color.WHITE, 0.4), 3.0)

func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_dist := INF
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best
