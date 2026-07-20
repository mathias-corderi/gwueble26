extends Node
## Headless integration test for the weapons/chairs split, mounts, secondary
## attacks and burning passives. Run with:
##   godot --headless --path . res://test/smoke_test.tscn

const CHAIR_SCENE := preload("res://scenes/chair.tscn")

var _frame := 0
var _failures: Array[String] = []
var _player: Player
var _chairs: Node2D
var _projectiles: Node
var _gamer_chair: Chair
var _mount_start_x := 0.0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_player = main.get_node("Player")
	_chairs = main.get_node("Chairs")
	_projectiles = main.get_node("Projectiles")

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		10:
			var pistol: WeaponData = load("res://data/weapons/pistol.tres")
			var rifle: WeaponData = load("res://data/weapons/rifle.tres")
			_check(_player.try_pickup(pistol), "pistol picked up")
			_check(_player.try_pickup(rifle), "rifle picked up")
			_check(_player.current_weapon().data == rifle, "newest weapon auto-equipped")
			Input.action_press("fire")
		60:
			_check(_projectiles.get_child_count() > 0, "weapon fires while standing")
			_check(_player.current_weapon().ammo < _player.current_weapon().data.max_ammo,
				"ammo is consumed")
			Input.action_release("fire")
			_player.cycle_weapon(1)
			_check(_player.current_weapon().data.display_name == "Pistol", "wheel switch cycles weapons")
		70:
			_gamer_chair = CHAIR_SCENE.instantiate()
			_gamer_chair.setup(load("res://data/chairs/gamer_chair.tres"))
			_gamer_chair.position = _player.global_position + Vector2(40, 0)
			_chairs.add_child(_gamer_chair)
		75:
			_player._sit(_gamer_chair)
			_check(_player.state == Player.State.SEATED, "player seated")
			Input.action_press("secondary_fire")
		77:
			Input.action_release("secondary_fire")
		85:
			_check(_gamer_chair.secondary_uses_left == 2, "secondary consumed a use")
			_check(_gamer_chair.secondary_cooldown_left > 0.0, "secondary cooldown started")
			_mount_start_x = _player.global_position.x
			Input.action_press("move_right")
		115:
			Input.action_release("move_right")
			_check(_player.global_position.x > _mount_start_x + 50.0,
				"mount chair drives with move keys")
			_gamer_chair.meter = _gamer_chair.data.meter_time - 0.05
		130:
			_check(RunState.passive_level(&"burn") == 1, "meter fill grants passive level 1")
			RunState.grant_passive(&"burn")
			_check(RunState.passive_level(&"burn") == 2, "second grant levels the passive up")
			_check(RunState.passives[&"burn"].time_left > 13.0, "grant refreshes the burn timer")
			RunState.passives[&"burn"].time_left = 0.05
		145:
			_check(RunState.passive_level(&"burn") == 0, "passive expires when its bar burns out")
			_player.current_weapon().ammo = 1
			Input.action_press("fire")
		165:
			Input.action_release("fire")
			_check(_player.weapons.size() == 1, "empty weapon is discarded")
			_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_failures.append(label)
		print("FAIL: %s" % label)

func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE TEST OK")
	else:
		print("SMOKE TEST FAILED: %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
