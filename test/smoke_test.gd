extends Node
## Temporary headless integration test: exercises sit -> fire -> passive ->
## break-chair -> re-sit with a permanent passive. Run with:
##   godot --headless --path . res://test/smoke_test.tscn

var _frame := 0
var _failures: Array[String] = []
var _player: Player
var _chairs: Node2D
var _projectiles: Node

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
			_check(_chairs.get_child_count() > 0, "chairs spawned")
			if _chairs.get_child_count() > 0:
				_player._sit(_chairs.get_child(0))
				_check(_player.state == Player.State.SEATED, "player seated")
			Input.action_press("fire") # firing is manual, so hold the button down
		70:
			_check(_projectiles.get_child_count() > 0, "projectiles fired while seated")
			if _player.current_chair:
				_check(_player.current_chair.meter > 0.0, "seat meter filling")
				_player.current_chair.break_chair()
			_check(_player.state == Player.State.STANDING, "player forced to stand on chair break")
		80:
			RunState.add_passive(&"triple_shot")
			_check(&"triple_shot" in RunState.permanent_passives, "permanent passive stored")
			for projectile in _projectiles.get_children():
				projectile.free()
		130:
			_check(_chairs.get_child_count() > 0, "replacement chairs spawned")
			if _chairs.get_child_count() > 0:
				_player._sit(_chairs.get_child(0))
		200:
			_check(_projectiles.get_child_count() >= 3, "triple shot volley from second chair")
			_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_failures.append(label)
		print("FAIL: %s" % label)

func _finish() -> void:
	Input.action_release("fire")
	if _failures.is_empty():
		print("SMOKE TEST OK")
	else:
		print("SMOKE TEST FAILED: %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)
