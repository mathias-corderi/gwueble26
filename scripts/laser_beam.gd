class_name LaserBeam
extends Node2D
## One continuous beam channeled by the player (WeaponData.AttackType.BEAM).
## The visual ray extends past the screen edge for an "endless" feel, but only
## enemies inside the camera view are hit. It innately pierces everything it
## crosses. With homing, the beam always leaves along the aim direction and
## then curves smoothly (capped turn radius) through nearby enemies in a chain
## (Isaac-style), continuing straight in its last direction afterwards.
## The player updates the path every physics frame and calls tick_damage() at
## the weapon's fire_rate; passive levels are re-read live, so passives
## expiring or leveling mid-beam take effect immediately.

## Long enough to cross any reasonable window from corner to corner.
const VISUAL_LENGTH := 2600.0
## How fast the beam's exit direction settles onto a new aim (radians/second).
## The slight lag makes the ray sweep instead of snapping to the cursor.
const AIM_TURN_RATE := 10.0
## How far off-axis an enemy can be and still bend a homing beam.
const CAPTURE_RADIUS := 180.0
## Homing curve: the path is marched in short steps, turning toward the target
## with at most this radius of curvature — small radius = tighter curls.
const CURVE_STEP := 16.0
const CURVE_RADIUS := 90.0
const MAX_CHAINED := 8
const MAX_CURVE_STEPS := 160
## A chased target counts as passed once the head gets this close (or leaves it behind).
const REACH_DISTANCE := 12.0
const WALL_MASK := 16
## Extra beam half-width per Pierce level (the laser pierces innately).
const PIERCE_WIDTH_FACTOR := 0.5
## Slack around the camera rect so edge-of-screen hits don't feel robbed.
const CAMERA_MARGIN := 40.0
## Explosive passive: periodic mini-explosions on the enemies being hit.
const EXPLOSION_INTERVAL := 0.8
const EXPLOSION_BASE_RADIUS := 45.0
const EXPLOSION_RADIUS_PER_LEVEL := 15.0
const EXPLOSION_DAMAGE_FACTOR := 0.4
## Electric Arc passive: the cooldown is tracked per hit enemy, not globally,
## so a beam touching several enemies throws several independent arcs.
const ARC_INTERVAL := 0.5
const ARC_DAMAGE_FACTOR := 1.5

var damage := 4.0
var base_half_width := 5.0
var half_width := 5.0
var color := Color.WHITE
var texture: Texture2D
var burn_level := 0
var explosive_level := 0
var arc_level := 0

var _points := PackedVector2Array()
var _explosion_cooldown := 0.0
## enemy -> seconds until it can throw another arc.
var _arc_cooldowns := {}
## Smoothed exit direction; ZERO until the first update snaps it to the aim.
var _aim_dir := Vector2.ZERO

@onready var _line: Line2D = $Line2D

## Must be called before the beam is added to the tree.
func configure(weapon: WeaponData) -> void:
	damage = weapon.damage
	base_half_width = weapon.projectile_radius
	half_width = base_half_width
	color = weapon.projectile_color
	texture = weapon.projectile_sprite

func _ready() -> void:
	_line.default_color = color
	_line.width = half_width * 2.0
	if texture:
		_line.texture = texture
		_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	# Local settings so the pixel strip tiles crisply without touching the
	# project-wide texture defaults.
	_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _physics_process(delta: float) -> void:
	_explosion_cooldown -= delta
	for enemy in _arc_cooldowns.keys():
		if not is_instance_valid(enemy):
			_arc_cooldowns.erase(enemy)
			continue
		_arc_cooldowns[enemy] -= delta

## Rebuilds the polyline. Called every physics frame while channeling.
func update_path(origin: Vector2, aim_dir: Vector2, passive_levels: Dictionary) -> void:
	burn_level = int(passive_levels.get(&"burn", 0))
	explosive_level = int(passive_levels.get(&"explosive", 0))
	arc_level = int(passive_levels.get(&"arc", 0))
	half_width = base_half_width * (1.0 + PIERCE_WIDTH_FACTOR * int(passive_levels.get(&"pierce", 0)))
	_line.width = half_width * 2.0

	if _aim_dir == Vector2.ZERO:
		_aim_dir = aim_dir
	else:
		_aim_dir = Vector2.from_angle(rotate_toward(_aim_dir.angle(), aim_dir.angle(),
			AIM_TURN_RATE * get_physics_process_delta_time()))

	_points = PackedVector2Array([origin])
	var head := origin
	var direction := _aim_dir
	if int(passive_levels.get(&"homing", 0)) > 0:
		var visible_rect := View.world_rect(self).grow(CAMERA_MARGIN)
		var chained := {}
		var target: Enemy = null
		var max_turn := CURVE_STEP / CURVE_RADIUS
		for step in MAX_CURVE_STEPS:
			if target and (not is_instance_valid(target) or target.hp <= 0.0):
				target = null
			if target == null and chained.size() < MAX_CHAINED:
				target = _capture_target(head, direction, chained, visible_rect)
			if target == null:
				break # no one left to chase: finish with the straight run below
			var to_target := target.global_position - head
			if to_target.length() <= REACH_DISTANCE or to_target.dot(direction) <= 0.0:
				chained[target] = true # passed through it; look for the next one
				target = null
				continue
			direction = Vector2.from_angle(
				rotate_toward(direction.angle(), to_target.angle(), max_turn))
			head += direction * CURVE_STEP
			_points.append(head)
	_points.append(_raycast_walls(head, head + direction * VISUAL_LENGTH))

	var local_points := PackedVector2Array()
	for point in _points:
		local_points.append(to_local(point))
	_line.points = local_points

## Damages every enemy on the path once. Called by the player at fire_rate.
func tick_damage() -> void:
	var visible_rect := View.world_rect(self).grow(CAMERA_MARGIN)
	var hits: Array[Enemy] = []
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.hp <= 0.0 or not visible_rect.has_point(enemy.global_position):
			continue
		if _distance_to_path(enemy.global_position) <= half_width + enemy.data.radius:
			hits.append(enemy)
	var explode := explosive_level > 0 and _explosion_cooldown <= 0.0 and not hits.is_empty()
	var hit_positions := PackedVector2Array()
	for enemy in hits:
		hit_positions.append(enemy.global_position)
		enemy.take_damage(damage)
		if burn_level > 0:
			enemy.apply_burn(Projectile.BURN_DPS_PER_LEVEL * burn_level, Projectile.BURN_DURATION)
		if arc_level > 0 and float(_arc_cooldowns.get(enemy, 0.0)) <= 0.0:
			_arc_cooldowns[enemy] = ARC_INTERVAL
			var chain := Combat.chain_lightning(get_tree(), enemy.global_position, arc_level,
				damage * ARC_DAMAGE_FACTOR, [enemy])
			LightningVfx.spawn(get_tree().current_scene, chain, Projectile.ARC_COLOR)
	if explode:
		_explosion_cooldown = EXPLOSION_INTERVAL
		_explode_at(hit_positions)

func _explode_at(positions: PackedVector2Array) -> void:
	var explosion_radius := EXPLOSION_BASE_RADIUS + EXPLOSION_RADIUS_PER_LEVEL * (explosive_level - 1)
	for pos in positions:
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.hp > 0.0 and pos.distance_to(enemy.global_position) <= explosion_radius:
				enemy.take_damage(damage * EXPLOSION_DAMAGE_FACTOR)
		PulseVfx.spawn(get_tree().current_scene, pos, explosion_radius, Color(1.0, 0.6, 0.2), 0.2)

## First enemy the forward ray passes near, by distance along the ray.
func _capture_target(head: Vector2, direction: Vector2, chained: Dictionary,
		visible_rect: Rect2) -> Enemy:
	var best: Enemy = null
	var best_along := INF
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in chained or enemy.hp <= 0.0:
			continue
		if not visible_rect.has_point(enemy.global_position):
			continue
		var offset := enemy.global_position - head
		var along := offset.dot(direction)
		if along <= 0.0 or absf(offset.cross(direction)) > CAPTURE_RADIUS:
			continue
		if along < best_along:
			best_along = along
			best = enemy
	return best

func _raycast_walls(from: Vector2, to: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return result.position if result else to

func _distance_to_path(point: Vector2) -> float:
	var best := INF
	for i in _points.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(point, _points[i], _points[i + 1])
		best = minf(best, point.distance_to(closest))
	return best
