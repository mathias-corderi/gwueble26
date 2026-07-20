class_name Combat
extends RefCounted
## Shared combat helpers used by chair breaks, secondary attacks, etc.

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
