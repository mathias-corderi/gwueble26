class_name Player
extends CharacterBody2D
## The player. Standing slowly drains HP; sitting on a chair locks movement,
## regenerates a little and fires the chair's attack toward the mouse.

signal hp_changed(hp: float, max_hp: float)
signal died
signal seated_on(chair: Chair)
signal stood_up
signal near_chair_changed(chair: Chair)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const MAX_HP := 100.0
const MOVE_SPEED := 320.0
## HP lost per second while standing — the "slow burn" pressure to find a chair.
const STANDING_DRAIN := 5.0
const SEATED_REGEN := 3.0
## Minimum fan width when a passive turns a single shot into a volley.
const MIN_FAN_SPREAD_DEG := 24.0

enum State { STANDING, SEATED }

var hp := MAX_HP
var state := State.STANDING
var current_chair: Chair

var _nearby_chair: Chair
var _dead := false
var _fire_cooldown := 0.0

@onready var interact_area: Area2D = $InteractArea

func _ready() -> void:
	add_to_group("player")
	var camera: Camera2D = $Camera2D
	camera.limit_left = int(RunState.ARENA.position.x)
	camera.limit_top = int(RunState.ARENA.position.y)
	camera.limit_right = int(RunState.ARENA.end.x)
	camera.limit_bottom = int(RunState.ARENA.end.y)

func _draw() -> void:
	draw_rect(Rect2(-13, -13, 26, 26), Color(0.4, 0.8, 1.0))
	draw_rect(Rect2(-13, -13, 26, 26), Color(0.12, 0.28, 0.4), false, 2.0)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if state == State.STANDING:
		_standing_process(delta)
	else:
		_seated_process(delta)

func _standing_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * MOVE_SPEED
	move_and_slide()
	_change_hp(-STANDING_DRAIN * delta)
	_update_nearby_chair()
	if Input.is_action_just_pressed("interact") and _nearby_chair:
		_sit(_nearby_chair)

func _seated_process(delta: float) -> void:
	_change_hp(SEATED_REGEN * delta)
	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0 and current_chair and Input.is_action_pressed("fire"):
		_fire()
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

func _sit(chair: Chair) -> void:
	state = State.SEATED
	current_chair = chair
	chair.occupy(self)
	global_position = chair.global_position
	velocity = Vector2.ZERO
	_fire_cooldown = 0.2
	_set_nearby_chair(null)
	seated_on.emit(chair)
	MusicManager.play_track(chair.data.music)

func _fire() -> void:
	var data := current_chair.data
	_fire_cooldown = 1.0 / maxf(data.fire_rate, 0.1)
	var passives := RunState.active_passives(data.passive_id)
	var count := data.projectile_count
	if &"triple_shot" in passives:
		count += 2
	var aim := global_position.direction_to(get_global_mouse_position())
	var base_spread := deg_to_rad(data.spread_degrees)
	var container := get_tree().get_first_node_in_group("projectile_container")
	for i in count:
		var angle_offset := randf_range(-base_spread * 0.5, base_spread * 0.5)
		if count > 1:
			var fan := maxf(base_spread, deg_to_rad(MIN_FAN_SPREAD_DEG))
			angle_offset = lerpf(-fan * 0.5, fan * 0.5, float(i) / float(count - 1))
		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		projectile.configure(data, aim.rotated(angle_offset), passives)
		projectile.position = global_position
		container.add_child(projectile)

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
