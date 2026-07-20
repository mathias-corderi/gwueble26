extends Node
## Keeps a fixed number of weapon pickups on the map, spawning random types
## from every WeaponData .tres found in res://data/weapons/.

const PICKUP_SCENE := preload("res://scenes/weapon_pickup.tscn")
const WEAPONS_DIR := "res://data/weapons/"
const TARGET_ACTIVE := 2
const MIN_DIST_TO_PLAYER := 200.0
const MIN_DIST_TO_PICKUP := 400.0
const ARENA_MARGIN := 120.0
const RESPAWN_DELAY := 4.0

@export var container: Node2D

var _pool: Array[WeaponData] = []
var _spawn_timer := 0.0

func _ready() -> void:
	for file in ResourceLoader.list_directory(WEAPONS_DIR):
		if file.ends_with(".tres"):
			var resource := load(WEAPONS_DIR + file)
			if resource is WeaponData:
				_pool.append(resource)
	if _pool.is_empty():
		push_error("No WeaponData resources found in %s" % WEAPONS_DIR)
	print("WeaponSpawner: loaded %d weapon types" % _pool.size())

func _process(delta: float) -> void:
	if _pool.is_empty():
		return
	if container.get_child_count() >= TARGET_ACTIVE:
		_spawn_timer = RESPAWN_DELAY
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_pickup()
		_spawn_timer = RESPAWN_DELAY

func _spawn_pickup() -> void:
	var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
	pickup.setup(_pool.pick_random())
	pickup.position = _find_position()
	container.add_child(pickup)

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
		for pickup in container.get_children():
			if pos.distance_to(pickup.position) < MIN_DIST_TO_PICKUP:
				too_close = true
				break
		if not too_close:
			return pos
	return Vector2(
		randf_range(arena.position.x, arena.end.x),
		randf_range(arena.position.y, arena.end.y)
	)
