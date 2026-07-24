class_name Enemy
extends CharacterBody2D
## Chases the player and deals contact damage on an interval to whatever its
## hitbox overlaps (the player, and the chair the player is sitting on).

var data: EnemyData
var hp := 0.0

var _burn_time := 0.0
var _burn_dps := 0.0
## Poison is a burn variant: a fraction of max HP per second, tinted green.
var _poison_time := 0.0
var _poison_pct := 0.0
## Slow multiplies movement speed (< 1) while active.
var _slow_time := 0.0
var _slow_factor := 1.0
var _stun_time := 0.0
var _knockback := Vector2.ZERO
var _attack_cooldown := 0.0
var _shot_cooldown := 0.0
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
	if _poison_time > 0.0:
		_poison_time -= delta
		take_damage(data.max_hp * _poison_pct * delta, false)
		if _poison_time <= 0.0:
			queue_redraw()
	var speed := data.speed
	if _slow_time > 0.0:
		_slow_time -= delta
		speed *= _slow_factor
	if _stun_time > 0.0:
		_stun_time -= delta
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	elif is_instance_valid(_player):
		velocity = _desired_direction() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0:
		_try_attack()
	if data.shot_interval > 0.0 and is_instance_valid(_player):
		_shot_cooldown -= delta
		if _shot_cooldown <= 0.0:
			_shot_cooldown = data.shot_interval
			_shoot()

## Chargers head straight for the player; kiters hold preferred_distance.
func _desired_direction() -> Vector2:
	var to_player := global_position.direction_to(_player.global_position)
	if data.preferred_distance <= 0.0:
		return to_player
	var distance := global_position.distance_to(_player.global_position)
	# A dead band around the ideal range stops it from jittering in place.
	if distance < data.preferred_distance * 0.9:
		return -to_player
	if distance > data.preferred_distance * 1.1:
		return to_player
	return Vector2.ZERO

func _shoot() -> void:
	Sfx.play(Sfx.PISTOL, -14.0, 0.75, 0.08) # muffled pistol: reads as enemy fire
	var shot: EnemyProjectile = preload("res://scenes/enemy_projectile.tscn").instantiate()
	shot.configure(data, global_position.direction_to(_player.global_position))
	shot.global_position = global_position
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		container = get_parent()
	container.add_child(shot)

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

## Poison: loses `pct` of its max HP per second (green), for `duration` seconds.
func apply_poison(pct: float, duration: float) -> void:
	_poison_pct = pct
	_poison_time = duration
	queue_redraw()

func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = factor
	_slow_time = duration

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
		var tint := Color.WHITE
		if _poison_time > 0.0:
			tint = Color(0.7, 1.5, 0.7)
		elif _burn_time > 0.0:
			tint = Color(1.6, 1.15, 0.7)
		SpriteFit.draw(self, data.sprite, Vector2.ONE * data.radius * 2.0, tint)
	else:
		var body_color := data.color
		if _poison_time > 0.0:
			body_color = body_color.lerp(Color(0.3, 0.9, 0.2), 0.6)
		elif _burn_time > 0.0:
			body_color = body_color.lerp(Color.ORANGE, 0.6)
		draw_circle(Vector2.ZERO, data.radius, body_color)
