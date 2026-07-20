extends Node
## Time-based difficulty director: spawns enemies around the player, shrinking
## the interval and growing the batch as the run goes on. Enemy types come from
## every EnemyData .tres found in res://data/enemies/.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENEMIES_DIR := "res://data/enemies/"
const START_INTERVAL := 2.2
const MIN_INTERVAL := 0.45
## Seconds of run time until the spawn interval reaches its minimum.
const RAMP_TIME := 300.0
## Every this many seconds the spawn batch grows by one enemy.
const BATCH_GROWTH_TIME := 45.0
const SPAWN_DISTANCE_MIN := 650.0
const SPAWN_DISTANCE_MAX := 900.0
const MIN_DIST_TO_PLAYER := 420.0

@export var container: Node2D

var _pool: Array[EnemyData] = []
var _timer := 1.0

func _ready() -> void:
	for file in ResourceLoader.list_directory(ENEMIES_DIR):
		if file.ends_with(".tres"):
			var resource := load(ENEMIES_DIR + file)
			if resource is EnemyData:
				_pool.append(resource)
	if _pool.is_empty():
		push_error("No EnemyData resources found in %s" % ENEMIES_DIR)
	print("EnemySpawner: loaded %d enemy types" % _pool.size())

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var run_time := RunState.run_time
	_timer = maxf(MIN_INTERVAL, START_INTERVAL - (START_INTERVAL - MIN_INTERVAL) * run_time / RAMP_TIME)
	var unlocked := _pool.filter(func(data: EnemyData) -> bool: return data.unlock_time <= run_time)
	if unlocked.is_empty():
		return
	var batch := 1 + int(run_time / BATCH_GROWTH_TIME)
	for i in batch:
		_spawn(unlocked.pick_random())

func _spawn(data: EnemyData) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var arena := RunState.ARENA.grow(-40.0)
	var pos: Vector2 = player.global_position + Vector2.RIGHT * SPAWN_DISTANCE_MAX
	for attempt in 16:
		var candidate: Vector2 = player.global_position \
			+ Vector2.from_angle(randf() * TAU) * randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
		candidate = candidate.clamp(arena.position, arena.end)
		pos = candidate
		if candidate.distance_to(player.global_position) >= MIN_DIST_TO_PLAYER:
			break
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.setup(data)
	enemy.position = pos
	container.add_child(enemy)
