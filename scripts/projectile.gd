class_name Projectile
extends Area2D
## A single shot from a weapon. Passive levels are baked in at spawn time, so
## any weapon automatically benefits from every burning passive.

const HOMING_TURN_RATE := 5.0
const BURN_DPS_PER_LEVEL := 5.0
const BURN_DURATION := 2.5
const EXPLOSION_BASE_RADIUS := 90.0
const EXPLOSION_RADIUS_PER_LEVEL := 30.0
const EXPLOSION_DAMAGE_FACTOR := 0.7
const PIERCE_PER_LEVEL := 2
## Share of the bullet's damage carried by the electric arc it triggers.
const ARC_DAMAGE_FACTOR := 0.6
const ARC_COLOR := Color(0.6, 0.85, 1.0)

var damage := 10.0
var radius := 6.0
var color := Color.WHITE
var sprite: Texture2D
var homing := false
var burn_level := 0
var explosive_level := 0
var arc_level := 0
var pierce_left := 0
var velocity := Vector2.ZERO
var lifetime := 2.5

var _age := 0.0

## Must be called before the projectile is added to the tree.
func configure(weapon: WeaponData, direction: Vector2, passive_levels: Dictionary) -> void:
	damage = weapon.damage
	radius = weapon.projectile_radius
	color = weapon.projectile_color
	sprite = weapon.projectile_sprite
	velocity = direction * weapon.projectile_speed
	lifetime = weapon.projectile_lifetime
	homing = int(passive_levels.get(&"homing", 0)) > 0
	burn_level = int(passive_levels.get(&"burn", 0))
	explosive_level = int(passive_levels.get(&"explosive", 0))
	arc_level = int(passive_levels.get(&"arc", 0))
	pierce_left = PIERCE_PER_LEVEL * int(passive_levels.get(&"pierce", 0))

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		queue_free()
		return
	if homing:
		var target := _nearest_enemy()
		if target:
			var desired := (target.global_position - global_position).angle()
			var angle := rotate_toward(velocity.angle(), desired, HOMING_TURN_RATE * delta)
			velocity = Vector2.from_angle(angle) * velocity.length()
	global_position += velocity * delta
	rotation = velocity.angle()

func _draw() -> void:
	if sprite:
		SpriteFit.draw(self, sprite, Vector2.ONE * radius * 2.5)
	else:
		draw_circle(Vector2.ZERO, radius, color)

func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		_hit_enemy(body)
	else:
		queue_free() # walls stop everything, pierce included

func _hit_enemy(enemy: Enemy) -> void:
	enemy.take_damage(damage)
	if burn_level > 0:
		enemy.apply_burn(BURN_DPS_PER_LEVEL * burn_level, BURN_DURATION)
	if explosive_level > 0:
		_explode(enemy)
	if arc_level > 0:
		_arc_from(enemy)
	if pierce_left > 0:
		pierce_left -= 1
	else:
		queue_free()

func _explode(direct_target: Enemy) -> void:
	var explosion_radius := EXPLOSION_BASE_RADIUS + EXPLOSION_RADIUS_PER_LEVEL * (explosive_level - 1)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == direct_target:
			continue
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			enemy.take_damage(damage * EXPLOSION_DAMAGE_FACTOR)
			if burn_level > 0:
				enemy.apply_burn(BURN_DPS_PER_LEVEL * burn_level, BURN_DURATION)
	PulseVfx.spawn(get_tree().current_scene, global_position, explosion_radius, Color(1.0, 0.6, 0.2), 0.25)

## Electric Arc passive: the struck enemy zaps the chain around it. Each level
## adds one more jump.
func _arc_from(enemy: Enemy) -> void:
	var chain := Combat.chain_lightning(get_tree(), enemy.global_position, arc_level,
		damage * ARC_DAMAGE_FACTOR, [enemy])
	LightningVfx.spawn(get_tree().current_scene, chain, ARC_COLOR)

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist: float = global_position.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best
