class_name LaserBeam
extends Node2D
## One continuous beam channeled by the player (WeaponData.AttackType.BEAM).
## The visual ray extends past the screen edge for an "endless" feel, but only
## enemies inside the camera view are hit. It innately pierces everything it
## crosses. With homing, the beam always leaves along the aim direction and
## then curves smoothly (capped turn radius) through nearby enemies in a chain
## (Isaac-style), continuing straight in its last direction afterwards.
##
## Feel/passive extras:
##  - Inertia: the straight beam is marched in segments whose direction reads a
##    short history of recent aim samples, so the near end tracks the cursor and
##    the far end lags — a hose/rope wave instead of a rigid laser pointer.
##  - Ricochet passive: the camera edge acts as a wall, so the beam reflects
##    inside the visible screen (bounce_level reflections).
##  - Split passive: at every enemy the beam pierces it forks (1 + level)
##    branches that deal a fraction of the damage.
## The player updates the path every physics frame and calls tick_damage() at
## the weapon's fire_rate; passive levels are re-read live, so passives
## expiring or leveling mid-beam take effect immediately.

## Long enough to cross any reasonable window from corner to corner.
const VISUAL_LENGTH := 2600.0
## How fast the homing beam's exit direction settles onto a new aim (rad/second).
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
## Split passive: the beam forks (1 + level) branches at every enemy it pierces.
const SPLIT_DAMAGE_FACTOR := 0.5
const BRANCH_LENGTH := 340.0
const BRANCH_SPREAD := 0.66 # ~38 degrees off the beam
const BRANCH_WIDTH_FACTOR := 0.7
## Inertia: the straight beam is marched in SEGMENTS steps; farther segments read
## older aim samples, so a cursor turn ripples outward like a hose instead of the
## whole ray snapping. History spans SEGMENTS * SAMPLES_PER_SEGMENT frames.
const SEGMENTS := 26
const SAMPLES_PER_SEGMENT := 2

var damage := 4.0
var base_half_width := 5.0
var half_width := 5.0
var color := Color.WHITE
var texture: Texture2D
var burn_level := 0
var poison_level := 0
var explosive_level := 0
var arc_level := 0
## Ricochet passive: the beam reflects off this many camera edges.
var bounce_level := 0
## Split passive: forks this many extra branches per pierced enemy.
var split_level := 0

var _points := PackedVector2Array()
var _explosion_cooldown := 0.0
## enemy -> seconds until it can throw another arc.
var _arc_cooldowns := {}
## Smoothed exit direction used as the homing curve's starting heading.
var _aim_dir := Vector2.ZERO
## Recent aim directions, newest first, driving the straight beam's inertia.
var _aim_history: Array[Vector2] = []
## Split branches for this frame: each entry is [start, end] in world space.
var _branch_segments: Array = []
var _branch_lines: Array[Line2D] = []
## Autonomous burst mode (Atomic Throne's charge_laser): the beam drives itself
## for a fixed time instead of being steered by the player, then frees itself.
var _burst_time := 0.0
var _burst_dir := Vector2.ZERO
var _burst_tick := 0.0
var _burst_levels := {}

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
	if _burst_time > 0.0:
		_burst_time -= delta
		update_path(global_position, _burst_dir, _burst_levels)
		_burst_tick -= delta
		if _burst_tick <= 0.0:
			_burst_tick = 0.06
			tick_damage()
		if _burst_time <= 0.0:
			queue_free()

## Fires a self-driving beam in a fixed direction for `duration`, then frees
## itself. Set damage/width/color/texture on the node before calling.
func start_burst(direction: Vector2, duration: float, levels: Dictionary) -> void:
	_burst_dir = direction
	_burst_time = duration
	_burst_levels = levels

## Rebuilds the polyline. Called every physics frame while channeling.
func update_path(origin: Vector2, aim_dir: Vector2, passive_levels: Dictionary) -> void:
	burn_level = int(passive_levels.get(&"burn", 0))
	poison_level = int(passive_levels.get(&"poison", 0))
	explosive_level = int(passive_levels.get(&"explosive", 0))
	arc_level = int(passive_levels.get(&"arc", 0))
	bounce_level = int(passive_levels.get(&"bounce", 0))
	split_level = int(passive_levels.get(&"split", 0))
	half_width = base_half_width * (1.0 + PIERCE_WIDTH_FACTOR * int(passive_levels.get(&"pierce", 0)))
	_line.width = half_width * 2.0

	_push_aim(aim_dir)
	if _aim_dir == Vector2.ZERO:
		_aim_dir = aim_dir
	else:
		_aim_dir = Vector2.from_angle(rotate_toward(_aim_dir.angle(), aim_dir.angle(),
			AIM_TURN_RATE * get_physics_process_delta_time()))

	_points = PackedVector2Array([origin])
	if int(passive_levels.get(&"homing", 0)) > 0:
		var visible_rect := View.world_rect(self).grow(CAMERA_MARGIN)
		var head := origin
		var direction := _aim_dir
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
		_trace_camera(head, direction, VISUAL_LENGTH, bounce_level)
	else:
		_trace_inertia(origin, VISUAL_LENGTH, bounce_level)

	var local_points := PackedVector2Array()
	for point in _points:
		local_points.append(to_local(point))
	_line.points = local_points

	_build_branches()

## Damages every enemy on the path once. Called by the player at fire_rate.
func tick_damage() -> void:
	var visible_rect := View.world_rect(self).grow(CAMERA_MARGIN)
	var hits := _enemies_on_path(visible_rect)
	var explode := explosive_level > 0 and _explosion_cooldown <= 0.0 and not hits.is_empty()
	var hit_positions := PackedVector2Array()
	for enemy in hits:
		hit_positions.append(enemy.global_position)
		enemy.take_damage(damage)
		if poison_level > 0:
			enemy.apply_poison(Projectile.POISON_PCT_BASE
				+ Projectile.POISON_PCT_PER_LEVEL * (poison_level - 1), Projectile.POISON_DURATION)
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
	_damage_branches(hits, visible_rect)

## Every live, on-screen enemy whose body overlaps the beam polyline.
func _enemies_on_path(visible_rect: Rect2) -> Array[Enemy]:
	var hits: Array[Enemy] = []
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.hp <= 0.0 or not visible_rect.has_point(enemy.global_position):
			continue
		if _distance_to_path(enemy.global_position) <= half_width + enemy.data.radius:
			hits.append(enemy)
	return hits

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

## Records the newest aim direction for the inertia trace (newest at index 0).
func _push_aim(aim_dir: Vector2) -> void:
	_aim_history.push_front(aim_dir)
	var cap := SEGMENTS * SAMPLES_PER_SEGMENT + 1
	while _aim_history.size() > cap:
		_aim_history.pop_back()

## Aim direction for segment `i`: farther segments read older samples so the
## beam trails behind the cursor.
func _history_dir(i: int) -> Vector2:
	if _aim_history.is_empty():
		return _aim_dir if _aim_dir != Vector2.ZERO else Vector2.RIGHT
	return _aim_history[mini(i * SAMPLES_PER_SEGMENT, _aim_history.size() - 1)]

## Straight beam with inertia (older samples farther out) that treats the camera
## edge as a wall when the Ricochet passive is active.
func _trace_inertia(origin: Vector2, length: float, bounces: int) -> void:
	var seg := length / float(SEGMENTS)
	var rect := View.world_rect(self)
	var can_bounce := bounces > 0 and rect.has_area()
	var pos := origin
	var flip := Vector2.ONE
	var used := 0
	for i in SEGMENTS:
		var base := _history_dir(i)
		var dir := Vector2(base.x * flip.x, base.y * flip.y)
		if can_bounce and used < bounces:
			var exit := _rect_exit(pos, dir, rect)
			if exit.t >= 0.0 and exit.t <= seg:
				var hit: Vector2 = pos + dir * exit.t
				_points.append(hit)
				flip *= exit.flip
				used += 1
				pos = hit
				continue
		pos += dir * seg
		_points.append(pos)

## Straight ray from a fixed heading, reflecting off the camera rect. Used for
## the homing beam's tail after it finishes chaining.
func _trace_camera(from: Vector2, direction: Vector2, length: float, bounces: int) -> void:
	var rect := View.world_rect(self)
	var pos := from
	var dir := direction
	var remaining := length
	var used := 0
	while bounces > 0 and rect.has_area() and used < bounces and remaining > 0.0:
		var exit := _rect_exit(pos, dir, rect)
		if exit.t < 0.0 or exit.t >= remaining:
			break
		var hit: Vector2 = pos + dir * exit.t
		_points.append(hit)
		dir *= exit.flip
		remaining -= exit.t
		pos = hit
		used += 1
	_points.append(pos + dir * remaining)

## Distance along `dir` from `pos` to the nearest edge of `rect`, plus the axis
## sign flip to apply when reflecting there.
func _rect_exit(pos: Vector2, dir: Vector2, rect: Rect2) -> Dictionary:
	var tx := INF
	if dir.x > 0.0:
		tx = (rect.end.x - pos.x) / dir.x
	elif dir.x < 0.0:
		tx = (rect.position.x - pos.x) / dir.x
	var ty := INF
	if dir.y > 0.0:
		ty = (rect.end.y - pos.y) / dir.y
	elif dir.y < 0.0:
		ty = (rect.position.y - pos.y) / dir.y
	if tx <= ty:
		return {t = tx, flip = Vector2(-1.0, 1.0)}
	return {t = ty, flip = Vector2(1.0, -1.0)}

## Split passive: builds (1 + level) branch segments at every pierced enemy.
func _build_branches() -> void:
	_branch_segments.clear()
	if split_level > 0:
		var branches_per := split_level + 1
		var visible_rect := View.world_rect(self).grow(CAMERA_MARGIN)
		for enemy in _enemies_on_path(visible_rect):
			var base_dir := _path_direction_at(enemy.global_position)
			for b in branches_per:
				var frac := float(b) / float(maxi(branches_per - 1, 1))
				var bdir := base_dir.rotated(lerpf(-BRANCH_SPREAD, BRANCH_SPREAD, frac))
				_branch_segments.append([enemy.global_position,
					enemy.global_position + bdir * BRANCH_LENGTH])
	_render_branches()

## Split branches deal a fraction of the beam's damage to enemies they cross,
## skipping the enemies the main beam already hit so nothing is double-counted.
func _damage_branches(main_hits: Array[Enemy], visible_rect: Rect2) -> void:
	if _branch_segments.is_empty():
		return
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.hp <= 0.0 or enemy in main_hits or not visible_rect.has_point(enemy.global_position):
			continue
		for seg in _branch_segments:
			var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, seg[0], seg[1])
			if enemy.global_position.distance_to(closest) <= half_width + enemy.data.radius:
				enemy.take_damage(damage * SPLIT_DAMAGE_FACTOR)
				if poison_level > 0:
					enemy.apply_poison(Projectile.POISON_PCT_BASE
						+ Projectile.POISON_PCT_PER_LEVEL * (poison_level - 1), Projectile.POISON_DURATION)
				if burn_level > 0:
					enemy.apply_burn(Projectile.BURN_DPS_PER_LEVEL * burn_level, Projectile.BURN_DURATION)
				break

## Direction of the beam segment nearest to `point` (used to angle its branches).
func _path_direction_at(point: Vector2) -> Vector2:
	var best := INF
	var dir := Vector2.RIGHT
	for i in _points.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(point, _points[i], _points[i + 1])
		var d := point.distance_to(closest)
		if d < best:
			best = d
			var seg_dir := _points[i + 1] - _points[i]
			if seg_dir != Vector2.ZERO:
				dir = seg_dir.normalized()
	return dir

## Draws the current branch segments through a reused pool of Line2D children.
func _render_branches() -> void:
	while _branch_lines.size() < _branch_segments.size():
		var bl := Line2D.new()
		bl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bl.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		if texture:
			bl.texture = texture
			bl.texture_mode = Line2D.LINE_TEXTURE_TILE
		add_child(bl)
		_branch_lines.append(bl)
	for i in _branch_lines.size():
		var bl := _branch_lines[i]
		if i < _branch_segments.size():
			var seg = _branch_segments[i]
			bl.width = maxf(_line.width * BRANCH_WIDTH_FACTOR, 3.0)
			bl.default_color = color
			bl.points = PackedVector2Array([to_local(seg[0]), to_local(seg[1])])
			bl.visible = true
		else:
			bl.visible = false

func _distance_to_path(point: Vector2) -> float:
	var best := INF
	for i in _points.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(point, _points[i], _points[i + 1])
		best = minf(best, point.distance_to(closest))
	return best
