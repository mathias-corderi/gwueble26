class_name SandboxRespawner
extends Node
## Godot-only test harness (run scenes/sandbox.tscn with F6): lays out one of
## every chair and every map weapon in a grid and respawns each in place 2 s
## after it is taken or broken. Enemies still spawn through the normal
## EnemySpawner. The Mech is assembled by hand at the MechStation (place E on a
## seated chair to fill its meter and drop a part fast — see Chair.force_burnout
## and the "sandbox" group this node registers). Respawning pauses once the Mech
## is boarded, so the map clears exactly like the real game.

const CHAIR_SCENE := preload("res://scenes/chair.tscn")
const PICKUP_SCENE := preload("res://scenes/weapon_pickup.tscn")
const CHAIRS_DIR := "res://data/chairs/"
const WEAPONS_DIR := "res://data/weapons/"
const RESPAWN_DELAY := 2.0
const COLS := 4
const SPACING := Vector2(260, 240)

@export var chairs_container: Node2D
@export var weapons_container: Node2D

## Each slot: {kind, res, pos, instance, timer}.
var _slots: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("sandbox") # RunState.sandbox_mode() keys off this
	var chairs := _load_dir(CHAIRS_DIR)
	var weapons := _load_dir(WEAPONS_DIR)
	var origin := Vector2(-float(COLS - 1) * SPACING.x * 0.5, -560.0)
	var index := 0
	for res in chairs:
		_add_slot("chair", res, origin + _grid_offset(index))
		index += 1
	for res in weapons:
		_add_slot("weapon", res, origin + _grid_offset(index))
		index += 1

func _process(delta: float) -> void:
	if RunState.mech_active:
		return # boarding clears the map for real; stop refilling it
	for slot in _slots:
		if is_instance_valid(slot.instance):
			continue
		slot.timer -= delta
		if slot.timer <= 0.0:
			_spawn(slot)

func _add_slot(kind: String, res: Resource, pos: Vector2) -> void:
	var slot := {kind = kind, res = res, pos = pos, instance = null, timer = 0.0}
	_slots.append(slot)
	_spawn(slot)

func _spawn(slot: Dictionary) -> void:
	slot.timer = RESPAWN_DELAY
	if slot.kind == "chair":
		var chair: Chair = CHAIR_SCENE.instantiate()
		chair.setup(slot.res)
		chair.position = slot.pos
		chairs_container.add_child(chair)
		slot.instance = chair
	else:
		var pickup: WeaponPickup = PICKUP_SCENE.instantiate()
		pickup.setup(slot.res)
		pickup.position = slot.pos
		weapons_container.add_child(pickup)
		slot.instance = pickup

func _grid_offset(index: int) -> Vector2:
	return Vector2((index % COLS) * SPACING.x, (index / COLS) * SPACING.y)

## Every ChairData/WeaponData in `dir` that opts into map spawning.
func _load_dir(dir: String) -> Array:
	var out: Array = []
	for file in ResourceLoader.list_directory(dir):
		if not file.ends_with(".tres"):
			continue
		var res := load(dir + file)
		if (res is ChairData or res is WeaponData) and res.spawns_on_map:
			out.append(res)
	return out
