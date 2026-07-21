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

func _physics_process(_delta: float) -> void:
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

## Right-click ability; called by the seated player.
func try_secondary() -> void:
	if data.secondary_id == &"" or secondary_cooldown_left > 0.0 or secondary_uses_left == 0:
		return
	secondary_cooldown_left = data.secondary_cooldown
	if secondary_uses_left > 0:
		secondary_uses_left -= 1
	match data.secondary_id:
		&"shockwave":
			Combat.knockback_enemies(get_tree(), global_position, SHOCKWAVE_RADIUS,
				SHOCKWAVE_FORCE * data.secondary_power, SHOCKWAVE_STUN,
				SHOCKWAVE_DAMAGE * data.secondary_power)
			PulseVfx.spawn(get_tree().current_scene, global_position, SHOCKWAVE_RADIUS, data.color, 0.3)
		_:
			push_warning("Unknown secondary_id: %s" % data.secondary_id)
	secondary_changed.emit(secondary_cooldown_left, secondary_uses_left)

func take_damage(amount: float) -> void:
	if _breaking:
		return
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
		occupant.on_chair_broken()
	occupied = false
	Combat.knockback_enemies(get_tree(), global_position, KNOCKBACK_RADIUS, KNOCKBACK_FORCE, KNOCKBACK_STUN)
	PulseVfx.spawn(get_tree().current_scene, global_position, KNOCKBACK_RADIUS, data.color)
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
