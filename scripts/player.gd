class_name Player
extends CharacterBody2D
## The player. Standing slowly drains HP; sitting on a chair regenerates and
## unlocks the chair's passive preview and secondary attack. Weapons provide
## the primary attack and can be fired in any state, always aiming at the mouse.

signal hp_changed(hp: float, max_hp: float)
signal died
signal seated_on(chair: Chair)
signal stood_up
signal near_chair_changed(chair: Chair)
signal weapons_changed
signal pickup_rejected

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const MAX_HP := 100.0
const MOVE_SPEED := 320.0
## HP lost per second while standing — the "slow burn" pressure to find a chair.
const STANDING_DRAIN := 5.0
const SEATED_REGEN := 3.0
## Minimum fan width when a passive turns a single shot into a volley.
const MIN_FAN_SPREAD_DEG := 24.0
const MAX_WEAPONS := 3

enum State { STANDING, SEATED }

var hp := MAX_HP
var state := State.STANDING
var current_chair: Chair
## Carried weapons: [{data: WeaponData, ammo: int}]. Mouse wheel cycles them.
var weapons: Array[Dictionary] = []
var current_weapon_index := 0
## Seconds since the last shot; the animator uses it for the shoot state.
var time_since_fire := 999.0

var _nearby_chair: Chair
var _dead := false
var _fire_cooldown := 0.0

@onready var interact_area: Area2D = $InteractArea
@onready var body_sprite: AnimatedSprite2D = $BodySprite

func _ready() -> void:
	add_to_group("player")
	var camera: Camera2D = $Camera2D
	camera.limit_left = int(RunState.ARENA.position.x)
	camera.limit_top = int(RunState.ARENA.position.y)
	camera.limit_right = int(RunState.ARENA.end.x)
	camera.limit_bottom = int(RunState.ARENA.end.y)

func _process(_delta: float) -> void:
	queue_redraw() # the placeholder weapon stub follows the mouse

func _draw() -> void:
	if body_sprite.sprite_frames == null:
		draw_rect(Rect2(-13, -13, 26, 26), Color(0.4, 0.8, 1.0))
		draw_rect(Rect2(-13, -13, 26, 26), Color(0.12, 0.28, 0.4), false, 2.0)
	var weapon := current_weapon()
	if not weapon.is_empty() and weapon.data.weapon_frames == null:
		var aim := global_position.direction_to(get_global_mouse_position())
		draw_line(aim * 8.0, aim * 26.0, weapon.data.color, 4.0)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	time_since_fire += delta
	_fire_cooldown -= delta
	if state == State.STANDING:
		_standing_process(delta)
	else:
		_seated_process(delta)
	if Input.is_action_pressed("fire") and _fire_cooldown <= 0.0 and not weapons.is_empty():
		_fire()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_next"):
		cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		cycle_weapon(-1)

func _standing_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * MOVE_SPEED
	move_and_slide()
	_change_hp(-STANDING_DRAIN * delta)
	_update_nearby_chair()
	if Input.is_action_just_pressed("interact") and _nearby_chair:
		_sit(_nearby_chair)

func _seated_process(delta: float) -> void:
	if current_chair:
		global_position = current_chair.global_position # ride the chair (mounts move)
	_change_hp(SEATED_REGEN * delta)
	if Input.is_action_just_pressed("secondary_fire") and current_chair:
		current_chair.try_secondary()
	if Input.is_action_just_pressed("interact") and current_chair:
		current_chair.break_chair() # standing up voluntarily sacrifices the chair

func take_damage(amount: float) -> void:
	_change_hp(-amount)
	modulate = Color(2.0, 1.2, 1.2)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

## Called by the chair whenever it breaks under us (voluntary stand-up included).
func on_chair_broken() -> void:
	state = State.STANDING
	current_chair = null
	stood_up.emit()
	MusicManager.stop_music()

## Called by weapon pickups; returns false when the inventory is full.
func try_pickup(weapon_data: WeaponData) -> bool:
	if weapons.size() >= MAX_WEAPONS:
		pickup_rejected.emit()
		return false
	weapons.append({data = weapon_data, ammo = weapon_data.max_ammo})
	current_weapon_index = weapons.size() - 1
	weapons_changed.emit()
	return true

func current_weapon() -> Dictionary:
	return {} if weapons.is_empty() else weapons[current_weapon_index]

func cycle_weapon(step: int) -> void:
	if weapons.size() < 2:
		return
	current_weapon_index = wrapi(current_weapon_index + step, 0, weapons.size())
	weapons_changed.emit()

func _sit(chair: Chair) -> void:
	state = State.SEATED
	current_chair = chair
	chair.occupy(self)
	global_position = chair.global_position
	velocity = Vector2.ZERO
	_set_nearby_chair(null)
	seated_on.emit(chair)
	MusicManager.play_track(chair.data.music)

func _fire() -> void:
	var weapon := current_weapon()
	var weapon_data: WeaponData = weapon.data
	_fire_cooldown = 1.0 / maxf(weapon_data.fire_rate, 0.1)
	time_since_fire = 0.0
	var chair_passive: StringName = current_chair.data.passive_id if current_chair else &""
	var levels := RunState.effective_passive_levels(chair_passive)
	var count: int = weapon_data.projectile_count + 2 * int(levels.get(&"triple_shot", 0))
	var aim := global_position.direction_to(get_global_mouse_position())
	var base_spread := deg_to_rad(weapon_data.spread_degrees)
	var container := get_tree().get_first_node_in_group("projectile_container")
	for i in count:
		var angle_offset := randf_range(-base_spread * 0.5, base_spread * 0.5)
		if count > 1:
			var fan := maxf(base_spread, deg_to_rad(MIN_FAN_SPREAD_DEG))
			angle_offset = lerpf(-fan * 0.5, fan * 0.5, float(i) / float(count - 1))
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		projectile.configure(weapon_data, aim.rotated(angle_offset), levels)
		projectile.position = global_position
		container.add_child(projectile)
	weapon.ammo -= 1
	if weapon.ammo <= 0:
		weapons.remove_at(current_weapon_index)
		current_weapon_index = clampi(current_weapon_index, 0, maxi(weapons.size() - 1, 0))
	weapons_changed.emit()

func _change_hp(delta_hp: float) -> void:
	if _dead:
		return
	hp = clampf(hp + delta_hp, 0.0, MAX_HP)
	hp_changed.emit(hp, MAX_HP)
	if hp <= 0.0:
		_dead = true
		died.emit()

func _update_nearby_chair() -> void:
	var best: Chair = null
	var best_dist := INF
	for body in interact_area.get_overlapping_bodies():
		if body is Chair and not body.occupied:
			var dist := global_position.distance_squared_to(body.global_position)
			if dist < best_dist:
				best_dist = dist
				best = body
	_set_nearby_chair(best)

func _set_nearby_chair(chair: Chair) -> void:
	if chair == _nearby_chair:
		return
	_nearby_chair = chair
	near_chair_changed.emit(chair)
