extends Node
## Global state for the current run: timer, kills, and the burning passives.
## Passives are no longer permanent: each one has a decaying timer (a "burning
## cigarette"). Refreshing it via another chair of the same type resets the
## timer and levels the passive up (if its max_level allows).

signal passive_granted(passive_id: StringName, level: int)
signal passive_expired(passive_id: StringName)
signal passives_changed
signal kills_changed(kills: int)
signal parts_changed
signal mech_ready

var player_name: String = "Mathias"

const ARENA := Rect2(-1180, -680, 2360, 1360)

## Mech assembly: parts drop from burned-out chairs and are hauled to the
## station at the arena centre.
const MECH_PARTS_REQUIRED := 10
const MAX_CARRIED_PARTS := 3

## Central passive registry: display name, burn duration (seconds), max level.
const PASSIVES := {
	&"triple_shot": {name = "Triple Shot", duration = 36.0, max_level = 3},
	&"pierce": {name = "Pierce", duration = 36.0, max_level = 3},
	&"burn": {name = "Burn", duration = 42.0, max_level = 2},
	&"explosive": {name = "Explosive", duration = 42.0, max_level = 2},
	&"homing": {name = "Homing", duration = 30.0, max_level = 1},
	&"arc": {name = "Electric Arc", duration = 36.0, max_level = 3},
}

var run_time := 0.0
var kills := 0
## passive_id -> {level: int, time_left: float}
var passives := {}
## Passives held at full instead of burning down: the seated chair's own
## passive, and — permanently — every passive the Mech was built from.
var pinned_passives: Array[StringName] = []
## Parts in hand and parts already delivered. The ChairData itself records
## which chair each part came from, which is what the Mech reads to know its
## passives.
var carried_parts: Array[ChairData] = []
var deposited_parts: Array[ChairData] = []
## True once the player boards the Mech: clears the map of chairs and weapons,
## stops their spawners and wakes the mech-gated enemies.
var mech_active := false
var game_over := false

func _process(delta: float) -> void:
	if game_over:
		return
	run_time += delta
	var expired: Array[StringName] = []
	for id in passives:
		if id in pinned_passives:
			passives[id].time_left = PASSIVES[id].duration
			continue
		passives[id].time_left -= delta
		if passives[id].time_left <= 0.0:
			expired.append(id)
	for id in expired:
		passives.erase(id)
		passive_expired.emit(id)
	if not expired.is_empty():
		passives_changed.emit()

func reset() -> void:
	run_time = 0.0
	kills = 0
	passives.clear()
	pinned_passives.clear()
	carried_parts.clear()
	deposited_parts.clear()
	mech_active = false
	game_over = false
	# This autoload outlives the scene, and the HUD builds itself from the old
	# state before Main gets to call reset(). Re-announcing everything is what
	# stops dead passive bars from surviving a restart.
	passives_changed.emit()
	parts_changed.emit()
	kills_changed.emit(kills)

func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)

func grant_passive(passive_id: StringName) -> void:
	var config: Dictionary = PASSIVES.get(passive_id, {})
	if config.is_empty():
		push_warning("Unknown passive id: %s" % passive_id)
		return
	if passive_id in passives:
		passives[passive_id].time_left = config.duration
		if passives[passive_id].level < config.max_level:
			passives[passive_id].level += 1
	else:
		passives[passive_id] = {level = 1, time_left = config.duration}
	passive_granted.emit(passive_id, passives[passive_id].level)
	passives_changed.emit()

## 0 = not owned.
func passive_level(passive_id: StringName) -> int:
	return passives[passive_id].level if passive_id in passives else 0

func passive_name(passive_id: StringName) -> String:
	return PASSIVES.get(passive_id, {}).get("name", String(passive_id))

## Picks up a dropped part; false when both hands are full.
func carry_part(source: ChairData) -> bool:
	if carried_parts.size() >= MAX_CARRIED_PARTS:
		return false
	carried_parts.append(source)
	parts_changed.emit()
	return true

## Hands every carried part to the station. Returns how many were delivered.
func deposit_parts() -> int:
	if carried_parts.is_empty():
		return 0
	var delivered := carried_parts.size()
	deposited_parts.append_array(carried_parts)
	carried_parts.clear()
	parts_changed.emit()
	if deposited_parts.size() >= MECH_PARTS_REQUIRED:
		mech_ready.emit()
	return delivered

## Grants one passive level per contributing part and pins them all forever.
## grant_passive already levels up on repeat, so parts from the same chair type
## stack exactly like sitting on that chair again.
func apply_mech_passives() -> void:
	for part in deposited_parts:
		if part.passive_id != &"":
			grant_passive(part.passive_id)
			if part.passive_id not in pinned_passives:
				pinned_passives.append(part.passive_id)

## Levels in effect when firing: owned passives, plus the seated chair's own
## passive previewed at level >= 1.
func effective_passive_levels(chair_passive: StringName) -> Dictionary:
	var levels := {}
	for id in passives:
		levels[id] = passives[id].level
	if chair_passive != &"" and int(levels.get(chair_passive, 0)) == 0:
		levels[chair_passive] = 1
	return levels
