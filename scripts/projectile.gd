class_name Projectile
extends Area2D
## A single shot from a weapon. Passive levels are baked in at spawn time, so
## any weapon automatically benefits from every burning passive. Fragments (from
## the split passive and the shatter break) reuse this same node via
## init_fragment(), which leaves every passive level at 0 so they don't recurse.

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
## Split passive: each hit spawns (1 + level) smaller, weaker fragments.
const SPLIT_DAMAGE_FACTOR := 0.5
const SPLIT_SPEED := 420.0
const SPLIT_LIFETIME := 0.6
const SPLIT_RADIUS_FACTOR := 0.6
## Knockback passive: constant shove on every bullet hit.
const KNOCKBACK_FORCE := 280.0
const KNOCKBACK_STUN := 0.2
## Trailing-streak render (Shotgun pellet): the chain stretches with speed but is
## clamped, so the pieces only ever separate a little. Each piece behind the head
## is darkened by TRAIL_DARKEN^i.
const TRAIL_LAG := 0.02
const TRAIL_GAP_MIN := 8.0
const TRAIL_GAP_MAX := 22.0
const TRAIL_DARKEN := 0.6
## Poison passive: fraction of max HP per second, +5% per extra level.
const POISON_PCT_BASE := 0.10
const POISON_PCT_PER_LEVEL := 0.05
const POISON_DURATION := 3.0
## Sonic passive: small AoE that damages and slows.
const SONIC_BASE_RADIUS := 70.0
const SONIC_RADIUS_PER_LEVEL := 25.0
const SONIC_DAMAGE_FACTOR := 0.5
const SONIC_SLOW_FACTOR := 0.5
const SONIC_SLOW_DURATION := 1.5
const SONIC_COLOR := Color(0.85, 0.5, 1.0)

var damage := 10.0
var radius := 6.0
var color := Color.WHITE
var sprite: Texture2D
## > 1 renders a lagging trail of this many sprite copies (see WeaponData).
var trail_pieces := 0
var homing := false
var burn_level := 0
var poison_level := 0
var explosive_level := 0
var sonic_level := 0
var arc_level := 0
var split_level := 0
var knockback_level := 0
var pierce_left := 0
var bounce_left := 0
## Pierce bullets and the laser ricochet off walls; plain bullets off enemies.
var bounces_off_walls := false
var velocity := Vector2.ZERO
var lifetime := 2.5

var _age := 0.0

## The projectile scene, loaded lazily at runtime. Loading it here rather than
## as a `const preload` avoids a self-referential dependency (this script is the
## scene's script), which otherwise leaves instantiate() returning a scriptless
## node under some load orders and crashes the split/shatter fragments.
static var _frag_scene: PackedScene

static func fragment_scene() -> PackedScene:
	if _frag_scene == null:
		_frag_scene = load("res://scenes/projectile.tscn")
	return _frag_scene

## Must be called before the projectile is added to the tree.
func configure(weapon: WeaponData, direction: Vector2, passive_levels: Dictionary) -> void:
	damage = weapon.damage
	radius = weapon.projectile_radius
	color = weapon.projectile_color
	sprite = weapon.projectile_sprite
	trail_pieces = weapon.projectile_trail_pieces
	velocity = direction * weapon.projectile_speed
	lifetime = weapon.projectile_lifetime
	homing = int(passive_levels.get(&"homing", 0)) > 0
	burn_level = int(passive_levels.get(&"burn", 0))
	poison_level = int(passive_levels.get(&"poison", 0))
	explosive_level = int(passive_levels.get(&"explosive", 0))
	sonic_level = int(passive_levels.get(&"sonic", 0))
	arc_level = int(passive_levels.get(&"arc", 0))
	split_level = int(passive_levels.get(&"split", 0))
	knockback_level = int(passive_levels.get(&"knockback", 0))
	pierce_left = PIERCE_PER_LEVEL * int(passive_levels.get(&"pierce", 0))
	bounce_left = int(passive_levels.get(&"bounce", 0))
	bounces_off_walls = pierce_left > 0

## Lightweight bullet with no passives, used by the split passive and the
## shatter break effect. Leaves every *_level at 0 so it never recurses.
func init_fragment(frag_damage: float, direction: Vector2, frag_radius: float, frag_color: Color) -> void:
	damage = frag_damage
	radius = frag_radius
	color = frag_color
	velocity = direction * SPLIT_SPEED
	lifetime = SPLIT_LIFETIME

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
	if bounces_off_walls and bounce_left > 0:
		_bounce_off_camera()
	rotation = velocity.angle()

func _draw() -> void:
	if sprite == null:
		draw_circle(Vector2.ZERO, radius, color)
	elif trail_pieces > 1:
		_draw_trail()
	else:
		SpriteFit.draw(self, sprite, Vector2.ONE * radius * 2.5, color)

## Draws the lagging pellet chain: bright head at the origin, darker copies
## trailing behind along the travel axis (the node is rotated to velocity).
func _draw_trail() -> void:
	var box := Vector2.ONE * radius * 2.5
	var gap := clampf(velocity.length() * TRAIL_LAG, TRAIL_GAP_MIN, TRAIL_GAP_MAX)
	for i in range(trail_pieces - 1, -1, -1): # back-to-front so the head sits on top
		var f := pow(TRAIL_DARKEN, i)
		var tint := Color(color.r * f, color.g * f, color.b * f, color.a)
		_draw_sprite_fit(box, Vector2(-gap * i, 0.0), tint)

## SpriteFit.draw, but centered on `offset` instead of the node origin.
func _draw_sprite_fit(box_size: Vector2, offset: Vector2, tint: Color) -> void:
	var tex_size := sprite.get_size()
	var scale := minf(box_size.x / tex_size.x, box_size.y / tex_size.y)
	var draw_size := tex_size * scale
	draw_texture_rect(sprite, Rect2(offset - draw_size * 0.5, draw_size), false, tint)

func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		_hit_enemy(body)
	else:
		queue_free() # walls stop everything; bouncers already turned at the camera edge

func _hit_enemy(enemy: Enemy) -> void:
	enemy.take_damage(damage)
	ImpactBurst.spawn(get_tree().current_scene, global_position, color)
	if poison_level > 0:
		enemy.apply_poison(POISON_PCT_BASE + POISON_PCT_PER_LEVEL * (poison_level - 1), POISON_DURATION)
	if burn_level > 0:
		enemy.apply_burn(BURN_DPS_PER_LEVEL * burn_level, BURN_DURATION)
	if knockback_level > 0:
		enemy.apply_knockback(velocity.normalized() * KNOCKBACK_FORCE, KNOCKBACK_STUN)
	if explosive_level > 0:
		_explode(enemy)
	if sonic_level > 0:
		_sonic_burst()
	if arc_level > 0:
		_arc_from(enemy)
	if split_level > 0:
		_split()
	if pierce_left > 0:
		pierce_left -= 1
		return
	if bounce_left > 0 and not bounces_off_walls:
		_ricochet(enemy) # plain bullets bounce off the enemy toward the next one
		return
	queue_free()

## Plain bullet ricochet: redirect toward the nearest other enemy, reset life.
func _ricochet(hit_enemy: Enemy) -> void:
	bounce_left -= 1
	_age = 0.0
	var target := _nearest_enemy(hit_enemy)
	if target:
		velocity = global_position.direction_to(target.global_position) * velocity.length()
	else:
		velocity = -velocity

## Ricochet passive: pierce/laser-style bullets treat the camera edge as a wall,
## so they bounce inside the visible screen instead of off the far arena walls.
func _bounce_off_camera() -> void:
	var rect := View.world_rect(self)
	if not rect.has_area():
		return # headless / no camera: let it fly to the real wall
	var bounced := false
	if global_position.x <= rect.position.x or global_position.x >= rect.end.x:
		velocity.x = -velocity.x
		bounced = true
	if global_position.y <= rect.position.y or global_position.y >= rect.end.y:
		velocity.y = -velocity.y
		bounced = true
	if bounced:
		bounce_left -= 1
		_age = 0.0
		global_position = global_position.clamp(rect.position + Vector2.ONE * radius,
			rect.end - Vector2.ONE * radius)

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

## Sonic passive: a musical pop that damages and slows nearby enemies.
func _sonic_burst() -> void:
	var burst_radius := SONIC_BASE_RADIUS + SONIC_RADIUS_PER_LEVEL * (sonic_level - 1)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= burst_radius:
			enemy.take_damage(damage * SONIC_DAMAGE_FACTOR * sonic_level)
			enemy.apply_slow(SONIC_SLOW_FACTOR, SONIC_SLOW_DURATION)
	PulseVfx.spawn(get_tree().current_scene, global_position, burst_radius, SONIC_COLOR, 0.2)

## Split passive: scatter (1 + level) weaker fragments in random directions.
func _split() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	for i in split_level + 1:
		var frag: Projectile = fragment_scene().instantiate()
		if frag == null:
			continue
		frag.init_fragment(damage * SPLIT_DAMAGE_FACTOR, Vector2.from_angle(randf() * TAU),
			radius * SPLIT_RADIUS_FACTOR, color)
		frag.global_position = global_position
		container.add_child(frag)

## Electric Arc passive: the struck enemy zaps the chain around it. Each level
## adds one more jump.
func _arc_from(enemy: Enemy) -> void:
	var chain := Combat.chain_lightning(get_tree(), enemy.global_position, arc_level,
		damage * ARC_DAMAGE_FACTOR, [enemy])
	LightningVfx.spawn(get_tree().current_scene, chain, ARC_COLOR)

func _nearest_enemy(exclude: Node2D = null) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == exclude:
			continue
		var dist: float = global_position.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best
