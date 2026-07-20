class_name Enemy
extends CharacterBody2D
## Chases the player and deals contact damage on an interval to whatever its
## hitbox overlaps (the player, and the chair the player is sitting on).

var data: EnemyData
var hp := 0.0

var _burn_time := 0.0
var _burn_dps := 0.0
var _stun_time := 0.0
var _knockback := Vector2.ZERO
var _attack_cooldown := 0.0
var _player: Node2D

@onready var hitbox: Area2D = $Hitbox

## Must be called before the enemy is added to the tree.
func setup(enemy_data: EnemyData) -> void:
	data = enemy_data
	hp = data.max_hp

func _ready() -> void:
	add_to_group("enemies")
	var body_shape := CircleShape2D.new()
	body_shape.radius = data.radius
	$CollisionShape2D.shape = body_shape
	var hit_shape := CircleShape2D.new()
	hit_shape.radius = data.radius + 8.0
	$Hitbox/CollisionShape2D.shape = hit_shape
	_player = get_tree().get_first_node_in_group("player")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _burn_time > 0.0:
		_burn_time -= delta
		take_damage(_burn_dps * delta, false)
		if _burn_time <= 0.0:
			queue_redraw()
	if _stun_time > 0.0:
		_stun_time -= delta
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	elif is_instance_valid(_player):
		velocity = global_position.direction_to(_player.global_position) * data.speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0:
		_try_attack()

func take_damage(amount: float, flash := true) -> void:
	hp -= amount
	if hp <= 0.0:
		RunState.add_kill()
		queue_free()
		return
	if flash:
		modulate = Color(2.5, 2.5, 2.5)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func apply_burn(dps: float, duration: float) -> void:
	_burn_dps = dps
	_burn_time = duration
	queue_redraw()

func apply_knockback(impulse: Vector2, stun := 0.5) -> void:
	_knockback = impulse
	_stun_time = stun

func _try_attack() -> void:
	var attacked := false
	for body in hitbox.get_overlapping_bodies():
		if body is Player:
			body.take_damage(data.contact_damage)
			attacked = true
		elif body is Chair and body.occupied:
			# Unoccupied chairs are safe so the horde can't wipe the map's options.
			body.take_damage(data.contact_damage)
			attacked = true
	if attacked:
		_attack_cooldown = data.attack_interval

func _draw() -> void:
	if data.sprite:
		var tint := Color(1.6, 1.15, 0.7) if _burn_time > 0.0 else Color.WHITE
		SpriteFit.draw(self, data.sprite, Vector2.ONE * data.radius * 2.0, tint)
	else:
		var body_color := data.color
		if _burn_time > 0.0:
			body_color = body_color.lerp(Color.ORANGE, 0.6)
		draw_circle(Vector2.ZERO, data.radius, body_color)
