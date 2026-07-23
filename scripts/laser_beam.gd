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
##  - Mass/inertia: the straight beam is marched in segments whose heading eases
##    (capped curvature) toward a smoothed, time-lagged history of recent aim
##    samples, so the near end tracks the cursor and the far end trails — a
##    water-jet wave instead of a rigid laser pointer or a jerky "rope".
##  - Homing settles gradually (slow exit turn + wide curve radius), weaving S
##    curves between enemies on alternating sides rather than snapping.
##  - Grow-in/out: the beam thickness animates from a hairline up to full width
##    when it starts and back down before it frees.
##  - Impact VFX: while the beam touches enemies it continuously sprays sparks in
##    a cone opposite to the beam's travel and lights nearby objects in its color.
##  - HDR glow: the core color is pushed past 1.0 so it blooms under the
##    WorldEnvironment glow set up in main.gd.
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
## Low on purpose: the exit heading eases in so the beam feels like it has mass.
const AIM_TURN_RATE := 4.0
## How far off-axis an enemy can be and still bend a homing beam.
const CAPTURE_RADIUS := 180.0
## Homing curve: the path is marched in short steps, turning toward the target
## with at most this radius of curvature — wide radius = gentle, S-shaped bends.
const CURVE_STEP := 16.0
const CURVE_RADIUS := 170.0
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
const BRANCH_SPREAD := 0.66 # ~38 degrees off the beam
const BRANCH_WIDTH_FACTOR := 0.7
## Inertia: the straight beam is marched in SEGMENTS steps; segment i reads the
## aim from `i/(SEGMENTS-1) * HISTORY_SPAN` frames ago (slerp-interpolated), so a
## cursor turn ripples outward like a hose. A shorter span + capped per-segment
## turn keeps the wave "controlled" instead of coiling into a rope.
const SEGMENTS := 32
const HISTORY_SPAN := 24
## Smallest curve radius the straight beam may bend through: caps how sharply the
## marched heading can turn per segment, smoothing kinks into a flowing wave.
const BEAM_CURVE_RADIUS := 115.0
## Cap on how fast the beam's base aim may rotate while firing (rad/second). Kept
## low so a fast cursor spin can't sweep more than ~half a turn within HISTORY_SPAN
## and coil the beam onto itself — the ray steers with weight instead of snapping.
const STEER_TURN_RATE := 6.0
## Fake-glow halo width relative to the beam core (layered under the HDR bloom).
const GLOW_WIDTH_FACTOR := 2.6
## Thickness animation: how fast _width_scale eases toward its target (1/seconds).
## Low = a longer, more visible grow-in / shrink-out (~0.25 s each way).
const WIDTH_ANIM_SPEED := 4.0
## Burst mode starts fading out this long before it ends, so it fully thins out
## at the slower WIDTH_ANIM_SPEED before it self-frees.
const BURST_FADE_LEAD := 0.35
## Impact VFX pool cap: at most this many spark/light pairs at once.
const MAX_IMPACT_VFX := 8
const SPARK_SPREAD := 35.0
const SPARK_AMOUNT := 18
const SPARK_LIFETIME := 0.35
## PointLight2D energy at full width; scaled down by _width_scale as it grows/fades.
const LIGHT_ENERGY := 1.3
const LIGHT_TEXTURE_SCALE := 2.5
## Core is tinted toward white then multiplied past 1.0 so it blooms (needs the
## HDR 2D + WorldEnvironment glow from project.godot / main.gd).
const CORE_HDR_GAIN := 1.3
const GLOW_HDR_GAIN := 1.6

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
## Rate-limited aim actually driving the beam: caps how fast the whole ray can
## swing so a quick flick can't kink it (see STEER_TURN_RATE).
var _steer_dir := Vector2.ZERO
## Recent aim directions, newest first, driving the straight beam's inertia.
var _aim_history: Array[Vector2] = []
## Split branches for this frame: each entry is [start, end] in world space.
var _branch_segments: Array = []
var _branch_lines: Array[Line2D] = []
## Autonomous burst mode (Atomic Throne's charge_laser): the beam drives itself
## for a fixed time instead of being steered by the player, then frees itself.
var _burst_time := 0.0
var _burst_duration := 0.0
var _burst_dir := Vector2.ZERO
var _burst_tick := 0.0
var _burst_levels := {}
## Optional node the burst beam rides along with (the Throne chair), so a driven
## chair drags its laser instead of leaving it anchored where it fired.
var _burst_follow: Node2D = null
## HDR core color, reused by the core line and the split branches.
var _core_color := Color.WHITE
## Grow-in/shrink-out thickness envelope (0 = hairline/invisible, 1 = full).
var _width_scale := 0.0
var _width_target := 1.0
var _fading_out := false
## Pooled continuous impact VFX, grown on demand and reused frame to frame.
var _spark_emitters: Array[CPUParticles2D] = []
var _lights: Array[PointLight2D] = []

## Shared soft radial texture for every beam's impact lights.
static var _light_texture: GradientTexture2D

@onready var _line: Line2D = $Line2D
@onready var _glow: Line2D = $Glow

## Must be called before the beam is added to the tree.
func configure(weapon: WeaponData) -> void:
	damage = weapon.damage
	base_half_width = weapon.projectile_radius
	half_width = base_half_width
	color = weapon.projectile_color
	texture = weapon.projectile_sprite

func _ready() -> void:
	# HDR core: tint toward white and push past 1.0 so it blooms.
	var hot := color.lerp(Color.WHITE, 0.5)
	_core_color = Color(hot.r * CORE_HDR_GAIN, hot.g * CORE_HDR_GAIN, hot.b * CORE_HDR_GAIN, 1.0)
	_line.default_color = _core_color
	if texture:
		_line.texture = texture
		_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	# Local settings so the pixel strip tiles crisply without touching the
	# project-wide texture defaults.
	_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Soft additive halo behind the core, textureless so it reads as a glow
	# rather than a second beam, and pushed to HDR so it feeds the bloom.
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = glow_mat
	_glow.default_color = Color(color.r * GLOW_HDR_GAIN, color.g * GLOW_HDR_GAIN, color.b * GLOW_HDR_GAIN, 0.5)
	# Taper the muzzle: a width curve that starts thin at the origin and widens
	# over a short distance, plus round caps, so the near end reads as a rounded
	# point (a "nozzle") instead of a blunt square.
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.15))
	taper.add_point(Vector2(0.03, 1.0))
	taper.add_point(Vector2(1.0, 1.0))
	_line.width_curve = taper
	_glow.width_curve = taper
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_apply_widths() # start at a hairline and grow in

func _process(delta: float) -> void:
	_width_scale = move_toward(_width_scale, _width_target, WIDTH_ANIM_SPEED * delta)
	_apply_widths()
	if _fading_out and _width_scale <= 0.001:
		queue_free()

func _physics_process(delta: float) -> void:
	_explosion_cooldown -= delta
	for enemy in _arc_cooldowns.keys():
		if not is_instance_valid(enemy):
			_arc_cooldowns.erase(enemy)
			continue
		_arc_cooldowns[enemy] -= delta
	if _burst_time > 0.0:
		_burst_time -= delta
		if is_instance_valid(_burst_follow):
			global_position = _burst_follow.global_position # ride along with the chair
		update_path(global_position, _burst_dir, _burst_levels)
		_burst_tick -= delta
		if _burst_tick <= 0.0:
			_burst_tick = 0.06
			tick_damage()
		# Short bursts (the Throne's 0.6 s zap) fade proportionally so they still
		# reach full width and hold it briefly instead of being all grow-and-shrink.
		if _burst_time <= minf(BURST_FADE_LEAD, _burst_duration * 0.4):
			begin_fade_out() # thin out before it self-frees

## Fires a self-driving beam in a fixed direction for `duration`, then frees
## itself. Set damage/width/color/texture on the node before calling.
func start_burst(direction: Vector2, duration: float, levels: Dictionary, follow: Node2D = null) -> void:
	_burst_dir = direction
	_burst_time = duration
	_burst_duration = duration
	_burst_levels = levels
	_burst_follow = follow

## Begins the shrink-out: the beam thins to a hairline, then frees itself. Called
## instead of queue_free() so the laser doesn't pop out of existence.
func begin_fade_out() -> void:
	if _fading_out:
		return
	_fading_out = true
	_width_target = 0.0
	for spark in _spark_emitters:
		spark.emitting = false

## Rebuilds the polyline. Called every physics frame while channeling.
func update_path(origin: Vector2, aim_dir: Vector2, passive_levels: Dictionary) -> void:
	burn_level = int(passive_levels.get(&"burn", 0))
	poison_level = int(passive_levels.get(&"poison", 0))
	explosive_level = int(passive_levels.get(&"explosive", 0))
	arc_level = int(passive_levels.get(&"arc", 0))
	bounce_level = int(passive_levels.get(&"bounce", 0))
	split_level = int(passive_levels.get(&"split", 0))
	half_width = base_half_width * (1.0 + PIERCE_WIDTH_FACTOR * int(passive_levels.get(&"pierce", 0)))
	_apply_widths()

	var dt := get_physics_process_delta_time()
	# Rate-limit the aim the whole beam follows, then feed that (not the raw
	# cursor) into the inertia history so a fast flick can't coil the ray.
	if _steer_dir == Vector2.ZERO:
		_steer_dir = aim_dir
	else:
		_steer_dir = Vector2.from_angle(rotate_toward(_steer_dir.angle(), aim_dir.angle(),
			STEER_TURN_RATE * dt))
	_push_aim(_steer_dir)
	if _aim_dir == Vector2.ZERO:
		_aim_dir = _steer_dir
	else:
		_aim_dir = Vector2.from_angle(rotate_toward(_aim_dir.angle(), _steer_dir.angle(),
			AIM_TURN_RATE * dt))

	var visible_rect := View.world_rect(self).grow(CAMERA_MARGIN)
	_points = PackedVector2Array([origin])
	if int(passive_levels.get(&"homing", 0)) > 0:
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
	_glow.points = local_points

	_build_branches()
	_update_impact_vfx(visible_rect)

## Damages every enemy on the path once. Called by the player at fire_rate.
func tick_damage() -> void:
	if _fading_out:
		return # shrinking out: no damage while it's disappearing
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
	var cap := HISTORY_SPAN + 2
	while _aim_history.size() > cap:
		_aim_history.pop_back()

## Smoothed aim direction feeding segment `i`: farther segments read older aim
## samples (slerp-interpolated between frames) so the beam trails the cursor as a
## continuous wave rather than snapping between discrete history entries.
func _history_dir(i: int) -> Vector2:
	if _aim_history.is_empty():
		return _aim_dir if _aim_dir != Vector2.ZERO else Vector2.RIGHT
	var age := float(i) / float(maxi(SEGMENTS - 1, 1)) * float(HISTORY_SPAN - 1)
	var lo := mini(int(age), _aim_history.size() - 1)
	var hi := mini(lo + 1, _aim_history.size() - 1)
	var frac := age - float(lo)
	return _aim_history[lo].slerp(_aim_history[hi], frac).normalized()

## Straight beam with inertia: the heading eases (capped curvature) toward a
## time-lagged, smoothed aim so a cursor sweep ripples outward like a water jet.
## Treats the camera edge as a wall when the Ricochet passive is active.
func _trace_inertia(origin: Vector2, length: float, bounces: int) -> void:
	var seg := length / float(SEGMENTS)
	var rect := View.world_rect(self)
	var can_bounce := bounces > 0 and rect.has_area()
	var pos := origin
	var flip := Vector2.ONE
	var used := 0
	var max_seg_turn := seg / BEAM_CURVE_RADIUS
	var heading := _history_dir(0)
	for i in SEGMENTS:
		var base := _history_dir(i)
		var target := Vector2(base.x * flip.x, base.y * flip.y)
		heading = Vector2.from_angle(rotate_toward(heading.angle(), target.angle(), max_seg_turn))
		if can_bounce and used < bounces:
			var exit := _rect_exit(pos, heading, rect)
			if exit.t >= 0.0 and exit.t <= seg:
				var hit: Vector2 = pos + heading * exit.t
				_points.append(hit)
				flip *= exit.flip
				heading = Vector2(heading.x * exit.flip.x, heading.y * exit.flip.y)
				used += 1
				pos = hit
				continue
		pos += heading * seg
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
					enemy.global_position + bdir * VISUAL_LENGTH])
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

## Closest point on the beam polyline to `point` (the visual impact spot).
func _closest_point_on_path(point: Vector2) -> Vector2:
	var best := INF
	var best_pt := point
	for i in _points.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(point, _points[i], _points[i + 1])
		var d := point.distance_squared_to(closest)
		if d < best:
			best = d
			best_pt = closest
	return best_pt

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
			bl.default_color = _core_color
			bl.points = PackedVector2Array([to_local(seg[0]), to_local(seg[1])])
			bl.visible = true
		else:
			bl.visible = false

## Applies the grow-in/shrink-out envelope to every thickness-driven visual.
func _apply_widths() -> void:
	var w := half_width * 2.0 * _width_scale
	_line.width = w
	_glow.width = w * GLOW_WIDTH_FACTOR
	for light in _lights:
		if light.visible:
			light.energy = LIGHT_ENERGY * _width_scale

## Continuous impact VFX: sparks sprayed in a cone opposite the beam's travel and
## colored lights on the objects the beam is touching. Repositioned every frame.
func _update_impact_vfx(visible_rect: Rect2) -> void:
	var hits: Array[Enemy] = []
	if not _fading_out and _width_scale > 0.05:
		hits = _enemies_on_path(visible_rect)
	_ensure_vfx_pool(hits.size())
	for i in _spark_emitters.size():
		var spark := _spark_emitters[i]
		var light := _lights[i]
		if i < hits.size():
			var impact := _closest_point_on_path(hits[i].global_position)
			var travel := _path_direction_at(hits[i].global_position)
			spark.position = to_local(impact)
			spark.direction = -travel # sparks fly back against the beam's advance
			spark.emitting = true
			light.position = to_local(impact)
			light.visible = true
			light.energy = LIGHT_ENERGY * _width_scale
		else:
			spark.emitting = false
			light.visible = false

## Grows the spark/light pool up to what this frame needs (capped, reused).
func _ensure_vfx_pool(count: int) -> void:
	var target := mini(count, MAX_IMPACT_VFX)
	while _spark_emitters.size() < target:
		_spark_emitters.append(_make_spark_emitter())
		_lights.append(_make_light())

func _make_spark_emitter() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = false
	p.local_coords = false # particles keep flying as the emitter is repositioned
	p.amount = SPARK_AMOUNT
	p.lifetime = SPARK_LIFETIME
	p.spread = SPARK_SPREAD
	p.gravity = Vector2.ZERO
	p.direction = Vector2.RIGHT
	# Fast so the sparks shoot clear of the beam's bright bloom, where they'd
	# otherwise be washed out and invisible.
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 300.0
	p.damping_min = 240.0
	p.damping_max = 420.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	# Born white-hot so they pop against the beam, then fade out to its color.
	var hot := color.lerp(Color.WHITE, 0.7)
	p.color = hot
	var ramp := Gradient.new()
	ramp.set_color(0, Color(hot.r, hot.g, hot.b, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.z_index = 6
	add_child(p)
	return p

func _make_light() -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _get_light_texture()
	light.color = color
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.texture_scale = LIGHT_TEXTURE_SCALE
	light.energy = 0.0
	light.visible = false
	add_child(light)
	return light

## Lazily builds the shared soft radial falloff used by every impact light.
static func _get_light_texture() -> GradientTexture2D:
	if _light_texture == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 128
		tex.height = 128
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		_light_texture = tex
	return _light_texture

func _distance_to_path(point: Vector2) -> float:
	var best := INF
	for i in _points.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(point, _points[i], _points[i + 1])
		best = minf(best, point.distance_to(closest))
	return best
