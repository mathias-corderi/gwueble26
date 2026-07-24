class_name Chair
extends CharacterBody2D
## A sittable chair. Fills its meter while occupied; a full meter grants (or
## refreshes/levels) its burning passive, then the chair burns out. Any break
## knocks enemies back. While occupied the chair faces the cursor; chairs with
## move_speed > 0 are mounts driven with the move keys.

signal broke
signal hp_changed(hp: float, max_hp: float)
signal meter_changed(value: float, max_value: float)
signal meter_filled(passive_id: StringName)
signal secondary_changed(cooldown_left: float, uses_left: int)

const KNOCKBACK_RADIUS := 280.0
const KNOCKBACK_FORCE := 800.0
const KNOCKBACK_STUN := 0.6
## Seconds the chair survives after its meter is filled.
const BURNOUT_TIME := 3.0
const SHOCKWAVE_RADIUS := 240.0
const SHOCKWAVE_FORCE := 600.0
const SHOCKWAVE_STUN := 0.4
const SHOCKWAVE_DAMAGE := 10.0
const ELECTRIC_BURST_RADIUS := 360.0
const ELECTRIC_BURST_DAMAGE := 35.0
## Bolts fired outward from the chair when an electric_burst goes off.
const ELECTRIC_BURST_BOLTS := 7
const ELECTRIC_BURST_COLOR := Color(0.6, 0.85, 1.0)
## Unoccupied chairs are recycled after this long, but only off-camera so one
## never vanishes in front of the player.
const IDLE_DESPAWN_TIME := 120.0
const IDLE_DESPAWN_MARGIN := 120.0
## z_index values around the player's (6): behind normally, in front while the
## occupant aims up so the backrest covers the body.
const Z_BEHIND_PLAYER := 2
const Z_IN_FRONT_OF_PLAYER := 7

const MISSILE_SCENE := preload("res://scenes/missile.tscn")
const SPEAR_SCENE := preload("res://scenes/spear_attack.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const LASER_SCENE := preload("res://scenes/laser_beam.tscn")
const LASER_TEXTURE := preload("res://art/fx/laser_beam.png")

## musical_wave (Music): push + slow, distinct from shockwave by the slow.
const MUSICAL_WAVE_RADIUS := 260.0
const MUSICAL_WAVE_FORCE := 500.0
const MUSICAL_WAVE_STUN := 0.3
const MUSICAL_WAVE_SLOW := 0.4
const MUSICAL_WAVE_SLOW_TIME := 2.5
const MUSICAL_WAVE_DAMAGE := 8.0
const MUSICAL_WAVE_COLOR := Color(0.85, 0.5, 1.0)
## eye_burst (Eyed): 8 enlarged bullets mimicking the held weapon.
const EYE_BURST_COUNT := 8
const EYE_BURST_SIZE := 2.2
## dash (Wheelchair): the chair charges forward, invulnerable, passing through
## enemies (shoving each aside once) and scattering everyone when it ends.
const DASH_SPEED_MULT := 2.0
const DASH_DURATION := 1.05
const DASH_DAMAGE := 24.0
const DASH_KNOCKBACK := 520.0
const DASH_STUN := 0.35
const DASH_CONTACT_DIST := 34.0
const DASH_END_RADIUS := 420.0
const DASH_END_FORCE := 1100.0
## Knockback only moves an enemy while stunned (enemy.gd decays it at 1400/s),
## so the end push needs its own longer stun to actually throw them far.
const DASH_END_STUN := 0.55
## missiles (Smart): a swarm of self-guided missiles.
const MISSILE_COUNT := 10
const MISSILE_DAMAGE := 16.0
## charge_laser (Atomic): 1 s wind-up, then a giant self-driving beam.
const CHARGE_LASER_TIME := 1.0
const CHARGE_LASER_DURATION := 2
const CHARGE_LASER_DAMAGE := 22.0
const CHARGE_LASER_WIDTH := 22.0
## Wind-up particles: ring they spawn on and how long each mote lives.
const CHARGE_VFX_RADIUS := 100.0
const CHARGE_VFX_LIFETIME := 0.5
## spear (Spiked): a wide short lunge.
const SPEAR_DAMAGE := 34.0
## shatter (Plastic break): fragments of the seat fly out dealing damage.
const SHATTER_FRAGMENTS := 10
const SHATTER_DAMAGE := 14.0
const SHATTER_RADIUS := 6.0
## blast (Atomic break): a wide damaging shove.
const BLAST_RADIUS := 340.0
const BLAST_FORCE := 700.0
const BLAST_STUN := 0.5
const BLAST_DAMAGE := 30.0

var data: ChairData
var hp := 0.0
var meter := 0.0
var occupied := false
var occupant: Player
var secondary_cooldown_left := 0.0
var secondary_uses_left := -1

var _meter_filled := false
var _burnout_timer := -1.0
var _breaking := false
var _unused_time := 0.0
## Wheelchair dash state.
var _dash_time := 0.0
var _dash_dir := Vector2.ZERO
var _dash_hit := {}
## Atomic Throne charge_laser wind-up.
var _charge_time := 0.0
var _charge_particles: CPUParticles2D

@onready var name_label: Label = $NameLabel
@onready var chair_sprite: AnimatedSprite2D = $ChairSprite

## Must be called before the chair is added to the tree.
func setup(chair_data: ChairData) -> void:
	data = chair_data
	hp = data.max_hp
	secondary_uses_left = data.secondary_uses

func _ready() -> void:
	add_to_group("chairs")
	name_label.text = data.display_name
	if data.chair_frames:
		chair_sprite.sprite_frames = data.chair_frames
	_update_facing()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_dir * data.move_speed * DASH_SPEED_MULT
		move_and_slide()
		_dash_damage_contacts()
		if _dash_time <= 0.0:
			_end_dash()
		return
	if occupied and data.move_speed > 0.0:
		velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * data.move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if occupied and not _meter_filled and data.meter_time > 0.0:
		meter = minf(meter + delta, data.meter_time)
		meter_changed.emit(meter, data.meter_time)
		if meter >= data.meter_time:
			_meter_filled = true
			_burnout_timer = BURNOUT_TIME
			RunState.grant_passive(data.passive_id)
			meter_filled.emit(data.passive_id)
	if occupied:
		_update_facing()
		queue_redraw()
	else:
		_unused_time += delta
		if can_idle_despawn() and _unused_time >= IDLE_DESPAWN_TIME and _is_off_camera():
			queue_free()
			return
	if secondary_cooldown_left > 0.0:
		secondary_cooldown_left = maxf(secondary_cooldown_left - delta, 0.0)
		if occupied:
			secondary_changed.emit(secondary_cooldown_left, secondary_uses_left)
	if _charge_time > 0.0:
		_charge_time -= delta
		if _charge_time <= 0.0:
			_fire_charge_laser()
	if _burnout_timer > 0.0:
		_burnout_timer -= delta
		_apply_burnout_flash()
		queue_redraw()
		if _burnout_timer <= 0.0:
			break_chair()

func occupy(player: Player) -> void:
	occupied = true
	occupant = player
	_unused_time = 0.0
	secondary_changed.emit(secondary_cooldown_left, secondary_uses_left)

## Sandbox testing helper (bound to E in the sandbox scene): instantly fills the
## meter — granting the passive and, because the meter filled, dropping a mech
## part — then breaks the chair, so parts can be farmed quickly.
func force_burnout() -> void:
	if not _meter_filled and not _breaking:
		meter = data.meter_time
		meter_changed.emit(meter, data.meter_time)
		_meter_filled = true
		RunState.grant_passive(data.passive_id)
		meter_filled.emit(data.passive_id)
	break_chair()

## Right-click ability; called by the seated player.
func try_secondary() -> void:
	if data.secondary_id == &"" or secondary_cooldown_left > 0.0 or secondary_uses_left == 0:
		return
	secondary_cooldown_left = data.secondary_cooldown
	if secondary_uses_left > 0:
		secondary_uses_left -= 1
	var power := data.secondary_power
	## secondary animation? (mech has a slam)
	match data.secondary_id:
		&"shockwave":
			Combat.knockback_enemies(get_tree(), global_position, SHOCKWAVE_RADIUS,
				SHOCKWAVE_FORCE * power, SHOCKWAVE_STUN, SHOCKWAVE_DAMAGE * power)
			PulseVfx.spawn(get_tree().current_scene, global_position, SHOCKWAVE_RADIUS, data.color, 0.3)
			Sfx.play(Sfx.SONIC_BOOM, -10.0, 1.1)
		&"musical_wave":
			Combat.knockback_enemies(get_tree(), global_position, MUSICAL_WAVE_RADIUS,
				MUSICAL_WAVE_FORCE * power, MUSICAL_WAVE_STUN, MUSICAL_WAVE_DAMAGE * power)
			Sfx.play(Sfx.SONIC_BOOM, -14.0, 1.35)
			for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(enemy.global_position) <= MUSICAL_WAVE_RADIUS:
					enemy.apply_slow(MUSICAL_WAVE_SLOW, MUSICAL_WAVE_SLOW_TIME)
			PulseVfx.spawn(get_tree().current_scene, global_position, MUSICAL_WAVE_RADIUS,
				MUSICAL_WAVE_COLOR, 0.3)
		&"eye_burst":
			if is_instance_valid(occupant):
				var dirs: Array[Vector2] = []
				for i in EYE_BURST_COUNT:
					dirs.append(Vector2.from_angle(TAU * float(i) / EYE_BURST_COUNT))
				occupant.fire_burst(dirs, EYE_BURST_SIZE)
		&"dash":
			_dash_time = DASH_DURATION
			_dash_dir = _aim_direction()
			_dash_hit.clear()
			# Stop colliding with enemies: the chair phases through the horde,
			# shoving them aside, until _end_dash() restores the mask.
			set_collision_mask_value(2, false)
			if is_instance_valid(occupant):
				occupant.set_invulnerable(true)
			PulseVfx.spawn(get_tree().current_scene, global_position, 60.0, data.color, 0.2)
			Sfx.play(Sfx.WHEEL_ACCEL, -3.0, 1.0, 0.05)
		&"missiles":
			var container := _projectile_container()
			for i in MISSILE_COUNT:
				var missile: Missile = MISSILE_SCENE.instantiate()
				missile.setup(MISSILE_DAMAGE * power, Vector2.from_angle(randf() * TAU), data.color)
				missile.global_position = global_position
				container.add_child(missile)
		&"charge_laser":
			_charge_time = CHARGE_LASER_TIME
			# Parented to the chair so both the ring and the converging motes
			# ride along while the mounted throne keeps driving.
			PulseVfx.spawn(self, global_position, 90.0, data.color, CHARGE_LASER_TIME)
			_start_charge_vfx()
			Sfx.play(Sfx.LASER_CHARGE, 0.0, 1.0, 0.0) # synced to the 1 s wind-up
		&"spear":
			_spawn_spear(_aim_direction(), power)
		_:
			push_warning("Unknown secondary_id: %s" % data.secondary_id)
	secondary_changed.emit(secondary_cooldown_left, secondary_uses_left)

func _aim_direction() -> Vector2:
	return global_position.direction_to(get_global_mouse_position())

func _projectile_container() -> Node:
	var container := get_tree().get_first_node_in_group("projectile_container")
	return container if container else get_parent()

## Damages and shoves aside enemies the chair phases through during a dash
## (once each). The push is mostly lateral so the horde parts around the chair
## instead of being herded along in front of it.
func _dash_damage_contacts() -> void:
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _dash_hit:
			continue
		if global_position.distance_to(enemy.global_position) <= DASH_CONTACT_DIST + enemy.data.radius:
			_dash_hit[enemy] = true
			enemy.take_damage(DASH_DAMAGE)
			var side := signf(_dash_dir.cross(enemy.global_position - global_position))
			if side == 0.0:
				side = 1.0
			var push := (Vector2(-_dash_dir.y, _dash_dir.x) * side * 0.8
				+ _dash_dir * 0.5).normalized()
			enemy.apply_knockback(push * DASH_KNOCKBACK, DASH_STUN)
			Sfx.play(Sfx.WHEEL_CRASH, -8.0, 1.0, 0.12)

func _end_dash() -> void:
	set_collision_mask_value(2, true) # solid against enemies again
	Combat.knockback_enemies(get_tree(), global_position, DASH_END_RADIUS, DASH_END_FORCE,
		DASH_END_STUN)
	PulseVfx.spawn(get_tree().current_scene, global_position, DASH_END_RADIUS, data.color, 0.25)
	Sfx.play(Sfx.SONIC_BOOM, -8.0)
	if is_instance_valid(occupant):
		occupant.set_invulnerable(false)

## Green motes streaming inward while the throne charges: emitted on a ring
## around the chair and pulled toward the center (the beam's muzzle) hard
## enough (-2R/t^2) that each mote dies exactly on arrival. local_coords makes
## the whole stream ride the moving chair.
func _start_charge_vfx() -> void:
	_charge_particles = CPUParticles2D.new()
	_charge_particles.amount = 40
	_charge_particles.lifetime = CHARGE_VFX_LIFETIME
	_charge_particles.local_coords = true
	_charge_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_charge_particles.emission_sphere_radius = CHARGE_VFX_RADIUS
	_charge_particles.gravity = Vector2.ZERO
	_charge_particles.initial_velocity_min = 0.0
	_charge_particles.initial_velocity_max = 0.0
	var pull := -2.0 * CHARGE_VFX_RADIUS / (CHARGE_VFX_LIFETIME * CHARGE_VFX_LIFETIME)
	_charge_particles.radial_accel_min = pull
	_charge_particles.radial_accel_max = pull
	# A slight swirl so the stream spirals in instead of collapsing in spokes.
	_charge_particles.tangential_accel_min = -60.0
	_charge_particles.tangential_accel_max = 60.0
	_charge_particles.scale_amount_min = 1.5
	_charge_particles.scale_amount_max = 3.0
	var hot := data.color.lerp(Color.WHITE, 0.4)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(data.color.r, data.color.g, data.color.b, 0.15))
	ramp.set_color(1, Color(hot.r * 1.5, hot.g * 1.5, hot.b * 1.5, 1.0)) # HDR: blooms
	_charge_particles.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_charge_particles.material = mat
	_charge_particles.z_index = 6
	add_child(_charge_particles)

## Fired after the Atomic Throne's wind-up: a giant beam toward the cursor.
func _fire_charge_laser() -> void:
	if is_instance_valid(_charge_particles):
		# Stop emitting but let the in-flight motes finish feeding the beam.
		_charge_particles.emitting = false
		var tween := _charge_particles.create_tween()
		tween.tween_interval(CHARGE_VFX_LIFETIME)
		tween.tween_callback(_charge_particles.queue_free)
		_charge_particles = null
	Sfx.play(Sfx.MEGA_LASER, -4.0, 0.7, 0.03) # low pitch = a deeper, graver boom
	var beam: LaserBeam = LASER_SCENE.instantiate()
	beam.damage = CHARGE_LASER_DAMAGE
	beam.base_half_width = CHARGE_LASER_WIDTH
	beam.half_width = CHARGE_LASER_WIDTH
	beam.color = data.color
	beam.texture = LASER_TEXTURE
	beam.global_position = global_position
	_projectile_container().add_child(beam)
	beam.start_burst(_aim_direction(), CHARGE_LASER_DURATION, {}, self)

func _spawn_spear(direction: Vector2, power := 1.0) -> void:
	Sfx.play(Sfx.SPEAR, -4.0, 1.0, 0.08) # throttle dedups the spear_burst's four
	var spear: SpearAttack = SPEAR_SCENE.instantiate()
	spear.setup(direction, SPEAR_DAMAGE * power, data.color, data.sprite)
	spear.global_position = global_position
	_projectile_container().add_child(spear)

func take_damage(amount: float) -> void:
	if _breaking:
		return
	if _dash_time > 0.0:
		return # the dash is an all-in charge: the chair is invulnerable too
	hp -= amount
	hp_changed.emit(maxf(hp, 0.0), data.max_hp)
	queue_redraw()
	if hp <= 0.0:
		break_chair()

func break_chair() -> void:
	if _breaking:
		return
	_breaking = true
	if occupied and is_instance_valid(occupant):
		occupant.set_invulnerable(false) # never strand the dash's invulnerability
		occupant.on_chair_broken()
	occupied = false
	Combat.knockback_enemies(get_tree(), global_position, KNOCKBACK_RADIUS, KNOCKBACK_FORCE, KNOCKBACK_STUN)
	PulseVfx.spawn(get_tree().current_scene, global_position, KNOCKBACK_RADIUS, data.color)
	Sfx.play(Sfx.WHEEL_CRASH, -6.0, 0.8, 0.1) # generic break thud
	_apply_break_effect()
	if _meter_filled:
		_drop_mech_part() # only a chair that paid out its passive leaves a part
	broke.emit()
	queue_free()

## Overridden by the Mech, which is permanent and must never be recycled.
func can_idle_despawn() -> bool:
	return true

func _drop_mech_part() -> void:
	var part: MechPart = preload("res://scenes/mech_part.tscn").instantiate()
	part.setup(data)
	part.position = global_position
	get_parent().add_child(part)

func _apply_break_effect() -> void:
	match data.break_effect_id:
		&"":
			pass
		&"electric_burst":
			Sfx.play(Sfx.SPARK, -2.0, 1.0, 0.1)
			var radius := ELECTRIC_BURST_RADIUS * data.break_effect_power
			for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(enemy.global_position) <= radius:
					enemy.take_damage(ELECTRIC_BURST_DAMAGE * data.break_effect_power)
			PulseVfx.spawn(get_tree().current_scene, global_position, radius,
				ELECTRIC_BURST_COLOR, 0.4)
			for i in ELECTRIC_BURST_BOLTS:
				var angle := TAU * float(i) / ELECTRIC_BURST_BOLTS + randf_range(-0.2, 0.2)
				var tip := global_position + Vector2.from_angle(angle) * radius
				LightningVfx.spawn(get_tree().current_scene,
					PackedVector2Array([global_position, tip]), ELECTRIC_BURST_COLOR)
		&"shatter":
			var container := _projectile_container()
			for i in SHATTER_FRAGMENTS:
				var frag: Projectile = PROJECTILE_SCENE.instantiate()
				if frag == null:
					continue
				frag.init_fragment(SHATTER_DAMAGE * data.break_effect_power,
					Vector2.from_angle(randf() * TAU), SHATTER_RADIUS, data.color)
				frag.global_position = global_position
				container.add_child(frag)
		&"blast":
			Sfx.play(Sfx.EXPLOSION, -8.0, 0.8, 0.08)
			Combat.knockback_enemies(get_tree(), global_position, BLAST_RADIUS * data.break_effect_power,
				BLAST_FORCE, BLAST_STUN, BLAST_DAMAGE * data.break_effect_power)
			PulseVfx.spawn(get_tree().current_scene, global_position,
				BLAST_RADIUS * data.break_effect_power, data.color, 0.4)
		&"spear_burst":
			for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				_spawn_spear(direction, data.break_effect_power)
		_:
			push_warning("Unknown break_effect_id: %s" % data.break_effect_id)

func _is_off_camera() -> bool:
	var view := View.world_rect(self).grow(IDLE_DESPAWN_MARGIN)
	return view.size != Vector2.ZERO and not view.has_point(global_position)

func _update_facing() -> void:
	var aim := Vector2.DOWN
	if occupied:
		aim = global_position.direction_to(get_global_mouse_position())
	var facing := Facing.from_vector(aim)
	var driving := occupied and data.move_speed > 0.0 and velocity.length() > 5.0
	var state := "move" if driving else "idle"
	Facing.play_anim(chair_sprite,
		["%s_%s" % [state, facing.dir], "idle_%s" % facing.dir, "idle_down"], facing.flip_h)
	var in_front: bool = occupied and (facing.dir == Facing.DIR_UP or facing.dir == Facing.DIR_UP_SIDE)
	z_index = Z_IN_FRONT_OF_PLAYER if in_front else Z_BEHIND_PLAYER

func _apply_burnout_flash() -> void:
	var flashing := int(_burnout_timer * 8.0) % 2 == 0
	chair_sprite.modulate = Color(1.6, 1.6, 1.6) if flashing else Color.WHITE

func _draw() -> void:
	var flashing := _burnout_timer > 0.0 and int(_burnout_timer * 8.0) % 2 == 0
	if data.chair_frames == null:
		if data.sprite:
			SpriteFit.draw(self, data.sprite, Vector2(48, 56),
				Color(1.6, 1.6, 1.6) if flashing else Color.WHITE)
		else:
			var seat_color := data.color.lerp(Color.WHITE, 0.6) if flashing else data.color
			draw_rect(Rect2(-22, -22, 44, 44), seat_color)
			draw_rect(Rect2(-22, -34, 44, 12), seat_color.darkened(0.35))
	var hp_ratio := clampf(hp / data.max_hp, 0.0, 1.0)
	draw_rect(Rect2(-22, 28, 44, 5), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-22, 28, 44 * hp_ratio, 5), Color(0.9, 0.25, 0.25))
	var meter_ratio := clampf(meter / data.meter_time, 0.0, 1.0) if data.meter_time > 0.0 else 1.0
	draw_rect(Rect2(-22, 35, 44, 5), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-22, 35, 44 * meter_ratio, 5), Color(1.0, 0.85, 0.2))
