extends Node
## Headless integration test for the weapons/chairs split, mounts, secondary
## attacks and burning passives. Run with:
##   godot --headless --path . res://test/smoke_test.tscn

const CHAIR_SCENE := preload("res://scenes/chair.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var _frame := 0
var _failures: Array[String] = []
var _player: Player
var _chairs: Node2D
var _enemies: Node2D
var _projectiles: Node
var _weapon_spawner: Node
var _mount_chair: Chair
var _mount_start_x := 0.0
var _beam_enemy_a: Enemy
var _beam_enemy_b: Enemy
var _arc_near: Enemy
var _arc_far: Enemy
var _burst_enemy: Enemy
var _mech: Mech
var _hp_before := 0.0
var _poison_enemy: Enemy
var _poison_hp := 0.0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_player = main.get_node("Player")
	_chairs = main.get_node("Chairs")
	_enemies = main.get_node("Enemies")
	_projectiles = main.get_node("Projectiles")
	_weapon_spawner = main.get_node("WeaponSpawner")

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _frame:
		10:
			_check(_weapon_spawner._pool.size() >= 4,
				"spawner scanned all weapon types (pistol, assault rifle, shotgun, laser)")
			var pistol: WeaponData = load("res://data/weapons/pistol.tres")
			var rifle: WeaponData = load("res://data/weapons/assault_rifle.tres")
			_check(_player.try_pickup(pistol), "pistol picked up")
			_check(_player.try_pickup(rifle), "assault rifle picked up")
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
			_mount_chair = CHAIR_SCENE.instantiate()
			_mount_chair.setup(load("res://data/chairs/eyed_chair.tres"))
			_mount_chair.position = _player.global_position + Vector2(40, 0)
			_chairs.add_child(_mount_chair)
		75:
			_player._sit(_mount_chair)
			_check(_player.state == Player.State.SEATED, "player seated")
			Input.action_press("secondary_fire")
		77:
			Input.action_release("secondary_fire")
		85:
			_check(_mount_chair.secondary_uses_left == 2, "secondary consumed a use")
			_check(_mount_chair.secondary_cooldown_left > 0.0, "secondary cooldown started")
			_mount_start_x = _player.global_position.x
			Input.action_press("move_right")
		115:
			Input.action_release("move_right")
			_check(_player.global_position.x > _mount_start_x + 50.0,
				"mount chair drives with move keys")
			_mount_chair.meter = _mount_chair.data.meter_time - 0.05
		130:
			_check(RunState.passive_level(&"triple_shot") == 1, "meter fill grants passive level 1")
			RunState.grant_passive(&"triple_shot")
			_check(RunState.passive_level(&"triple_shot") == 2, "second grant levels the passive up")
			_check(RunState.passives[&"triple_shot"].time_left > 13.0, "grant refreshes the timer")
			RunState.passives[&"triple_shot"].time_left = 5.0 # seated: should re-pin to full
		140:
			_check(RunState.passives[&"triple_shot"].time_left > 30.0,
				"seated chair pins its own passive bar at full")
			_mount_chair.break_chair() # stand up so the bar can burn out
			RunState.passives[&"triple_shot"].time_left = 0.05
		150:
			_check(RunState.passive_level(&"triple_shot") == 0, "passive expires when its bar burns out")
			_player.current_weapon().ammo = 1
			Input.action_press("fire")
		170:
			Input.action_release("fire")
			_check(_player.weapons.size() == 1, "empty weapon is discarded")
			var laser: WeaponData = load("res://data/weapons/laser_gun.tres")
			_check(laser.attack_type == WeaponData.AttackType.BEAM, "laser gun is a BEAM weapon")
			_check(_player.try_pickup(laser), "laser gun picked up")
			var aim: Vector2 = _player.global_position.direction_to(_player.get_global_mouse_position())
			_beam_enemy_a = _spawn_brute(_player.global_position + aim * 180.0)
			_beam_enemy_b = _spawn_brute(_player.global_position + aim * 300.0)
			Input.action_press("fire")
		190:
			_check(_player._active_beams.size() == 1, "beam is channeled while holding fire")
			_check(_beam_enemy_a.hp < _beam_enemy_a.data.max_hp, "beam damages the first enemy")
			_check(_beam_enemy_b.hp < _beam_enemy_b.data.max_hp,
				"beam pierces through to the second enemy")
			_check(_player.current_weapon().ammo < _player.current_weapon().data.max_ammo,
				"beam ticks consume ammo")
			RunState.grant_passive(&"homing")
		200:
			_check(_player._active_beams[0]._points.size() > 2,
				"homing bends the beam through nearby enemies")
			Input.action_release("fire")
		204:
			# Laser split: the beam forks branches that damage enemies off its line.
			var split_beam: LaserBeam = load("res://scenes/laser_beam.tscn").instantiate()
			split_beam.configure(load("res://data/weapons/laser_gun.tres"))
			_projectiles.add_child(split_beam)
			var split_main := _spawn_brute(_player.global_position + Vector2.RIGHT * 150.0)
			# On the +spread branch of the beam, but well off its main (horizontal) line.
			var split_branch := _spawn_brute(_player.global_position + Vector2.RIGHT * 150.0
				+ Vector2.RIGHT.rotated(LaserBeam.BRANCH_SPREAD) * 130.0)
			split_beam.update_path(_player.global_position, Vector2.RIGHT, {&"split": 1})
			split_beam.tick_damage()
			_check(split_main.hp < split_main.data.max_hp, "the laser hits the enemy on its line")
			_check(split_branch.hp < split_branch.data.max_hp,
				"the split laser forks a branch onto a nearby enemy")
			split_beam.queue_free()
			split_main.queue_free() # clear these before the arc-chain test at 210
			split_branch.queue_free()
		205:
			_check(_player._active_beams.is_empty(), "beam clears when fire is released")
			var shotgun: WeaponData = load("res://data/weapons/shotgun.tres")
			_player.try_pickup(shotgun)
			_player.try_pickup(load("res://data/weapons/pistol.tres"))
			_check(_player.weapons.size() == 4, "a 4th distinct weapon fits (no inventory cap)")
			var entry := _weapon_entry(shotgun)
			entry.ammo = 1
			_check(_player.try_pickup(shotgun), "duplicate pickup is accepted")
			_check(_player.weapons.size() == 4 and _weapon_entry(shotgun).ammo > 1,
				"duplicate pickup restocks ammo instead of adding a weapon")
			_weapon_entry(shotgun).ammo = shotgun.max_ammo * Player.AMMO_STOCK_MULTIPLIER
			_check(not _player.try_pickup(shotgun), "restock is capped at 2x base ammo")
		210:
			# Electric Arc: the bullet hits _arc_near, the chain must reach the
			# enemy beside it but not one parked beyond Combat.ARC_RADIUS.
			RunState.grant_passive(&"arc")
			var arc_origin := _player.global_position + Vector2(0, -260)
			_arc_near = _spawn_brute(arc_origin)
			_spawn_brute(arc_origin + Vector2(90, 0))
			_spawn_brute(arc_origin + Vector2(180, 0)) # reachable on the 2nd jump
			_arc_far = _spawn_brute(arc_origin + Vector2(0, -(Combat.ARC_RADIUS + 400.0)))
			var chain := Combat.chain_lightning(get_tree(), _arc_near.global_position,
				RunState.passive_level(&"arc"), 20.0, [_arc_near])
			_check(chain.size() == 2, "arc Lv1 chains to exactly one nearby enemy")
			_check(_arc_far.hp == _arc_far.data.max_hp, "arc ignores enemies out of range")
			RunState.grant_passive(&"arc")
			var chain2 := Combat.chain_lightning(get_tree(), _arc_near.global_position,
				RunState.passive_level(&"arc"), 20.0, [_arc_near])
			_check(RunState.passive_level(&"arc") == 2 and chain2.size() == 3,
				"leveling the arc adds one more jump")
		215:
			var burst_chair: Chair = CHAIR_SCENE.instantiate()
			burst_chair.setup(load("res://data/chairs/electric_chair.tres"))
			burst_chair.position = _player.global_position + Vector2(0, 300)
			_chairs.add_child(burst_chair)
			_burst_enemy = _spawn_brute(burst_chair.position + Vector2(120, 0))
			burst_chair.break_chair()
			_check(_burst_enemy.hp < _burst_enemy.data.max_hp,
				"electric_burst damages enemies when the chair breaks")
		220:
			# Break both chairs far from the player so the drops aren't instantly
			# collected, then compare part counts.
			var unfilled := _spawn_chair_at(_player.global_position + Vector2(500, 0))
			var parts_before := _count_parts()
			unfilled.break_chair()
			_check(_count_parts() == parts_before, "an unfilled chair drops nothing")
			var filled := _spawn_chair_at(_player.global_position + Vector2(700, 0))
			filled._meter_filled = true # stand in for having sat through the meter
			filled.break_chair()
			_check(_count_parts() == parts_before + 1,
				"a meter-filled chair drops a mech part when it breaks")
			# Carrying is capped; extra parts stay on the map.
			var source: ChairData = load("res://data/chairs/eyed_chair.tres")
			for i in RunState.MAX_CARRIED_PARTS + 2:
				RunState.carry_part(source)
			_check(RunState.carried_parts.size() == RunState.MAX_CARRIED_PARTS,
				"carrying is capped at MAX_CARRIED_PARTS")
			_check(RunState.deposit_parts() == RunState.MAX_CARRIED_PARTS,
				"the station takes every carried part")
			_check(RunState.carried_parts.is_empty(), "hands are empty after depositing")
		225:
			var station: MechStation = get_tree().get_first_node_in_group("mech_station")
			_check(station.build_stage() == RunState.deposited_parts.size(),
				"the station reports one build stage per delivered part")
			_check(station._stage_texture(station.build_stage()) == null,
				"missing build-stage art falls back to the placeholder")
			# Fill the rest with the same chair type so the Mech stacks a passive.
			var stack_chair: ChairData = load("res://data/chairs/eyed_chair.tres")
			while RunState.deposited_parts.size() < RunState.MECH_PARTS_REQUIRED:
				RunState.carry_part(stack_chair)
				RunState.deposit_parts()
			_check(RunState.deposited_parts.size() == RunState.MECH_PARTS_REQUIRED,
				"the mech reaches its part requirement")
			station._try_assemble()
		230:
			_mech = _find_mech()
			_check(_mech != null, "the mech is assembled at the station")
			_check(_mech.data.spawns_on_map == false, "the mech never spawns as a random chair")
			_mech.break_chair()
			_check(is_instance_valid(_mech), "the mech cannot be broken")
			_check(not RunState.mech_active, "mech-gated content is asleep before boarding")
			_spawn_chair_at(_player.global_position + Vector2(600, 0)) # must be swept away
			_player.on_chair_broken() # leave the electric chair test state behind
			_player._sit(_mech)
			_check(_player.state == Player.State.SEATED, "player boards the mech")
			_check(RunState.mech_active, "boarding flips the mech_active gate")
			_check(RunState.passive_level(&"triple_shot") >= 2,
				"the mech stacks passives from repeated chair parts")
			_check(&"triple_shot" in RunState.pinned_passives, "mech passives are pinned")
			RunState.passives[&"triple_shot"].time_left = 0.05
		235:
			_check(RunState.passive_level(&"triple_shot") >= 2, "mech passives never burn out")
			_check(_chairs.get_children().all(func(n: Node) -> bool: return not (n is Chair)),
				"boarding clears the remaining chairs")
			_check(get_tree().get_nodes_in_group("weapon_pickups").is_empty(),
				"boarding clears the weapon pickups")
			_check(_player.collision_shape.disabled,
				"the pilot's own hitbox yields to the mech body")
			# Damage aimed at the mech must land on the pilot, not the robot.
			_hp_before = _player.hp
			_mech.take_damage(12.0)
			_check(is_instance_valid(_mech) and _player.hp == _hp_before - 12.0,
				"damage to the mech drains the pilot's HP")
		240:
			_check(_player.hp <= _hp_before - 12.0, "no regen within the mech's damage window")
			_check(_player.time_since_damage < Player.MECH_REGEN_DELAY, "the regen window is open")
			_player.time_since_damage = Player.MECH_REGEN_DELAY + 1.0
			_hp_before = _player.hp
		245:
			_check(_player.hp > _hp_before, "regen resumes once the damage window passes")
			var machinegun: WeaponData = _player.weapons[0].data
			_check(machinegun.max_ammo < 0, "the mech equips an infinite-ammo weapon")
			_player._spend_ammo(_player.weapons[0])
			_check(_player.weapons.size() == 2 and _player.weapons[0].ammo < 0,
				"infinite ammo is never spent nor discarded")
			# Mech laser energy: drains while firing, locks empty, only then refills.
			_player.current_weapon_index = 1
			var laser: Dictionary = _player.weapons[1]
			_check(laser.data.energy_seconds > 0.0, "the mech laser runs on energy")
			laser.energy = 5.0
			_player._tick_weapon_timers(1.0)
			_check(laser.energy == 5.0, "a partly used reserve does not recharge on its own")
			_player._channel_beam(1.0)
			_check(laser.energy < 5.0, "channelling drains the energy reserve")
			laser.energy = 0.2
			_player._channel_beam(0.5)
			_check(laser.energy_locked and _player._active_beams.is_empty(),
				"draining the reserve locks the laser")
		250:
			var laser: Dictionary = _player.weapons[1]
			_player._channel_beam(0.5)
			_check(_player._active_beams.is_empty(), "a locked laser refuses to fire")
			_player._tick_weapon_timers(1.0)
			_check(laser.energy > 0.0, "a locked laser recharges")
			laser.energy = laser.data.energy_seconds - 0.01
			_player._tick_weapon_timers(1.0)
			_check(not laser.energy_locked, "the laser unlocks at a full reserve")
			var spawner_pool: Array = _weapon_spawner._pool
			_check(not spawner_pool.any(func(w: WeaponData) -> bool: return not w.spawns_on_map),
				"mech-only weapons stay out of the map spawner")
		255:
			# The Sentry: mech-gated, kites away when crowded, shoots past allies.
			var sentry_data: EnemyData = load("res://data/enemies/sentry.tres")
			_check(sentry_data.requires_mech, "the sentry is gated behind the mech")
			_check(sentry_data.speed < _mech.data.move_speed,
				"the mech can always run a sentry down")
			var sentry: Enemy = ENEMY_SCENE.instantiate()
			sentry.setup(sentry_data)
			sentry.position = _player.global_position + Vector2(100, 0) # far too close
			_enemies.add_child(sentry)
			var away: Vector2 = sentry._desired_direction()
			_check(away.dot(Vector2.RIGHT) > 0.0, "a crowded sentry backs away from the player")
			sentry._shoot()
			var shot := _find_enemy_shot()
			_check(shot != null, "the sentry fires a projectile")
			_check(shot.collision_mask & 2 == 0, "enemy shots pass through other enemies")
			_hp_before = _player.hp
			shot._on_body_entered(_mech)
			_check(_player.hp < _hp_before, "an enemy shot on the mech hurts the pilot")
		257:
			for id in [&"split", &"knockback", &"poison", &"sonic", &"bounce"]:
				_check(id in RunState.PASSIVES, "passive '%s' is registered" % id)
			# Split scatters (1 + level) fragments on hit.
			var proj: Projectile = load("res://scenes/projectile.tscn").instantiate()
			_projectiles.add_child(proj)
			proj.split_level = 2
			var frags_before := _projectiles.get_child_count()
			proj._split()
			_check(_projectiles.get_child_count() == frags_before + 3,
				"split scatters (1 + level) fragments")
			proj.queue_free()
			# Pierce/laser bullets bounce off the camera edge; plain bullets off enemies.
			var pistol: WeaponData = load("res://data/weapons/pistol.tres")
			var wall_b: Projectile = load("res://scenes/projectile.tscn").instantiate()
			wall_b.configure(pistol, Vector2.RIGHT, {&"pierce": 1, &"bounce": 2})
			_check(wall_b.bounce_left == 2 and wall_b.bounces_off_walls,
				"pierce bullets bounce off the camera edge")
			wall_b.free()
			var enemy_b: Projectile = load("res://scenes/projectile.tscn").instantiate()
			enemy_b.configure(pistol, Vector2.RIGHT, {&"bounce": 1})
			_check(enemy_b.bounce_left == 1 and not enemy_b.bounces_off_walls,
				"plain bullets ricochet off enemies")
			enemy_b.free()
			# Poison drains a fraction of max HP over time.
			_poison_enemy = _spawn_brute(_player.global_position + Vector2(0, 640))
			_poison_enemy.apply_poison(0.5, 2.0)
			_poison_hp = _poison_enemy.hp
		258:
			# Every new secondary runs without error and starts its cooldown.
			for path in ["musical_chair", "eyed_chair", "wheelchair", "smart_chair", "throne", "spiked_chair"]:
				var c: Chair = CHAIR_SCENE.instantiate()
				c.setup(load("res://data/chairs/%s.tres" % path))
				c.position = _player.global_position + Vector2(0, 820)
				_chairs.add_child(c)
				c.occupied = true
				c.occupant = _player
				c.try_secondary()
				_check(c.secondary_cooldown_left > 0.0, "%s secondary fires and cools down" % path)
				if c.data.secondary_id == &"dash":
					_check(_player._invulnerable, "the wheelchair dash grants invulnerability")
					_player.set_invulnerable(false)
				c.occupied = false
				c.queue_free()
		259:
			_check(is_instance_valid(_poison_enemy) and _poison_enemy.hp < _poison_hp,
				"poison drains enemy HP over time")
			# Break effects: shatter scatters fragments, blast damages, spear_burst fires spears.
			var shatter_before := _projectiles.get_child_count()
			_detached_chair("plastic_chair", _player.global_position + Vector2(0, 900)).break_chair()
			_check(_projectiles.get_child_count() > shatter_before, "shatter break scatters fragments")
			var blast_enemy := _spawn_brute(_player.global_position + Vector2(0, 980))
			_detached_chair("throne", blast_enemy.global_position + Vector2(30, 0)).break_chair()
			_check(blast_enemy.hp < blast_enemy.data.max_hp, "blast break damages nearby enemies")
			_detached_chair("spiked_chair", _player.global_position + Vector2(0, 1040)).break_chair()
			var spears := _projectiles.get_children().filter(
				func(n: Node) -> bool: return n is SpearAttack).size()
			_check(spears >= 4, "spear_burst break fires spears in the 4 cardinal directions")
			# Sandbox helper: force_burnout fills the meter (granting the passive and
			# dropping a mech part) then breaks the chair, all in one call.
			var fb_parts_before := _count_parts()
			var fb_chair := _detached_chair("smart_chair", _player.global_position + Vector2(0, 1120))
			var fb_passive := fb_chair.data.passive_id
			fb_chair.force_burnout()
			_check(RunState.passive_level(fb_passive) >= 1, "force_burnout grants the chair's passive")
			_check(_count_parts() == fb_parts_before + 1, "force_burnout drops a mech part")
		260:
			# Guards the restart bug: reset() must announce the wipe so the HUD
			# drops passive bars built from the previous run.
			var announced := [false]
			RunState.passives_changed.connect(func() -> void: announced[0] = true, CONNECT_ONE_SHOT)
			RunState.reset()
			_check(announced[0], "reset() announces the cleared state to the HUD")
			_check(RunState.passives.is_empty() and not RunState.mech_active,
				"reset() clears passives and the mech gate")
			_finish()

func _spawn_chair_at(pos: Vector2) -> Chair:
	var chair: Chair = CHAIR_SCENE.instantiate()
	chair.setup(load("res://data/chairs/plastic_chair.tres"))
	chair.position = pos
	_chairs.add_child(chair)
	return chair

func _detached_chair(name: String, pos: Vector2) -> Chair:
	var chair: Chair = CHAIR_SCENE.instantiate()
	chair.setup(load("res://data/chairs/%s.tres" % name))
	chair.position = pos
	_chairs.add_child(chair)
	return chair

func _count_parts() -> int:
	return _chairs.get_children().filter(func(n: Node) -> bool: return n is MechPart).size()

func _find_enemy_shot() -> EnemyProjectile:
	for node in _projectiles.get_children():
		if node is EnemyProjectile:
			return node
	return null

func _find_mech() -> Mech:
	for node in _chairs.get_parent().get_children():
		if node is Mech:
			return node
	return null

func _weapon_entry(weapon_data: WeaponData) -> Dictionary:
	for entry in _player.weapons:
		if entry.data == weapon_data:
			return entry
	return {}

func _spawn_brute(pos: Vector2) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.setup(load("res://data/enemies/brute.tres"))
	enemy.position = pos
	_enemies.add_child(enemy)
	return enemy

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
