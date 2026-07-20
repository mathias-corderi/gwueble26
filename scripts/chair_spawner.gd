extends Node
## Keeps a fixed number of chairs alive on the map, spawning random types from
## every ChairData .tres found in res://data/chairs/.

const CHAIR_SCENE := preload("res://scenes/chair.tscn")
const CHAIRS_DIR := "res://data/chairs/"
const TARGET_ACTIVE := 4
const MIN_DIST_TO_PLAYER := 260.0
const MIN_DIST_TO_CHAIR := 320.0
const ARENA_MARGIN := 120.0
const RESPAWN_DELAY := 1.0

@export var container: Node2D

var _pool: Array[ChairData] = []
var _spawn_timer := 0.0

func _ready() -> void:
	for file in ResourceLoader.list_directory(CHAIRS_DIR):
		if file.ends_with(".tres"):
			var resource := load(CHAIRS_DIR + file)
			if resource is ChairData:
				_pool.append(resource)
	if _pool.is_empty():
		push_error("No ChairData resources found in %s" % CHAIRS_DIR)
	print("ChairSpawner: loaded %d chair types" % _pool.size())

func _process(delta: float) -> void:
	if _pool.is_empty():
		return
	if container.get_child_count() >= TARGET_ACTIVE:
		_spawn_timer = RESPAWN_DELAY
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_chair()
		_spawn_timer = RESPAWN_DELAY

func _spawn_chair() -> void:
	var chair: Chair = CHAIR_SCENE.instantiate()
	chair.setup(_pool.pick_random())
	chair.position = _find_position()
	container.add_child(chair)

func _find_position() -> Vector2:
	var arena := RunState.ARENA.grow(-ARENA_MARGIN)
	var player := get_tree().get_first_node_in_group("player")
	for attempt in 24:
		var pos := Vector2(
			randf_range(arena.position.x, arena.end.x),
			randf_range(arena.position.y, arena.end.y)
		)
		if player and pos.distance_to(player.global_position) < MIN_DIST_TO_PLAYER:
			continue
		var too_close := false
		for chair in container.get_children():
			if pos.distance_to(chair.position) < MIN_DIST_TO_CHAIR:
				too_close = true
				break
		if not too_close:
			return pos
	return Vector2(
		randf_range(arena.position.x, arena.end.x),
		randf_range(arena.position.y, arena.end.y)
	)
