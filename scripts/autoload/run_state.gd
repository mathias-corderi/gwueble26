extends Node
## Global state for the current run: timer, kills and permanent passives.

signal passive_gained(passive_id: StringName)
signal kills_changed(kills: int)

var player_name: String = "Mathias"

const ARENA := Rect2(-1180, -680, 2360, 1360)

const PASSIVE_NAMES := {
	&"triple_shot": "Triple Shot",
	&"homing": "Homing",
	&"burn": "Burn",
	&"explosive": "Explosive",
	&"pierce": "Pierce",
}

var run_time := 0.0
var kills := 0
var permanent_passives: Array[StringName] = []
var game_over := false

func _process(delta: float) -> void:
	if not game_over:
		run_time += delta

func reset() -> void:
	run_time = 0.0
	kills = 0
	permanent_passives.clear()
	game_over = false

func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)

func add_passive(passive_id: StringName) -> void:
	if passive_id in permanent_passives:
		return
	permanent_passives.append(passive_id)
	passive_gained.emit(passive_id)

## Passives currently in effect: the permanent ones plus the seated chair's own.
func active_passives(chair_passive: StringName) -> Array[StringName]:
	var result := permanent_passives.duplicate()
	if chair_passive != &"" and chair_passive not in result:
		result.append(chair_passive)
	return result
