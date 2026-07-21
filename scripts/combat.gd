class_name Combat
extends RefCounted
## Shared combat helpers used by chair breaks, secondary attacks, etc.

## How far an electric arc can reach for each jump.
const ARC_RADIUS := 420.0
## Damage kept on every extra jump down the chain.
const ARC_FALLOFF := 0.75

static func knockback_enemies(tree: SceneTree, center: Vector2, radius: float,
		force: float, stun: float, damage := 0.0) -> void:
	for enemy in tree.get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - center
		if offset.length() > radius:
			continue
		var direction := offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT
		enemy.apply_knockback(direction * force, stun)
		if damage > 0.0:
			enemy.take_damage(damage)

## Zaps a chain of enemies starting from `origin`, hopping to the nearest
## unvisited enemy within ARC_RADIUS up to `jumps` times. `exclude` holds
## enemies already accounted for (e.g. the one the bullet just hit).
## Returns the ordered point chain (origin first) so callers can draw the bolt;
## empty when nothing was in range.
static func chain_lightning(tree: SceneTree, origin: Vector2, jumps: int,
		damage: float, exclude: Array = []) -> PackedVector2Array:
	var points := PackedVector2Array()
	var visited := {}
	for enemy in exclude:
		visited[enemy] = true
	var head := origin
	var hop_damage := damage
	for jump in jumps:
		var target := _nearest_enemy(tree, head, visited)
		if target == null:
			break
		visited[target] = true
		target.take_damage(hop_damage)
		hop_damage *= ARC_FALLOFF
		head = target.global_position
		if points.is_empty():
			points.append(origin)
		points.append(head)
	return points

static func _nearest_enemy(tree: SceneTree, from: Vector2, visited: Dictionary) -> Enemy:
	var best: Enemy = null
	var best_dist := ARC_RADIUS * ARC_RADIUS
	for enemy: Enemy in tree.get_nodes_in_group("enemies"):
		if enemy in visited or enemy.hp <= 0.0:
			continue
		var dist := from.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best
