class_name Mech
extends Chair
## The giant robot assembled at the MechStation. It is a Chair — so seating,
## mount driving, cursor facing, the shockwave secondary and the render order
## all come for free — but a permanent one: it has no meter, takes no damage,
## never breaks and is never recycled. Boarding it grants the passives of every
## chair that contributed a part, pinned so they never burn out, and swaps in
## the Mech's built-in weapons.

const LOADOUT_PATHS := [
	"res://data/weapons/mech_machinegun.tres",
	"res://data/weapons/mech_laser.tres",
]
const PLACEHOLDER_SIZE := Vector2(120, 130)

func occupy(player: Player) -> void:
	super(player)
	RunState.mech_active = true
	RunState.apply_mech_passives()
	var loadout: Array[WeaponData] = []
	for path in LOADOUT_PATHS:
		loadout.append(load(path))
	player.equip_loadout(loadout)
	# The Mech's much larger body becomes the pilot's only hitbox, so enemies
	# touching the robot connect without the small player shape double-dipping.
	player.set_hitbox_enabled(false)
	_clear_map()

## Chairs, weapons and loose parts are pointless once the Mech is running, and
## their spawners stop (see RunState.mech_active).
func _clear_map() -> void:
	for chair in get_tree().get_nodes_in_group("chairs"):
		if chair != self:
			chair.queue_free()
	for group in ["weapon_pickups", "mech_parts"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()

## The robot itself is indestructible, but the pilot inside is not: everything
## that hits the Mech is passed straight through to them.
func take_damage(amount: float) -> void:
	if occupied and is_instance_valid(occupant):
		occupant.take_damage(amount)

## Permanent: it never breaks, so pressing E while piloting does nothing.
func break_chair() -> void:
	pass

func can_idle_despawn() -> bool:
	return false

## Deliberately does not call super(): the Mech has neither an HP bar nor a
## meter bar to draw.
func _draw() -> void:
	if data.chair_frames:
		return # animated frames render through ChairSprite
	if data.sprite:
		SpriteFit.draw(self, data.sprite, PLACEHOLDER_SIZE)
		return
	# Placeholder mech: a scaled-up chair silhouette with a lit core.
	var color := data.color
	draw_rect(Rect2(-46, -20, 92, 76), color)
	draw_rect(Rect2(-46, -58, 92, 38), color.darkened(0.3))
	draw_rect(Rect2(-58, -14, 12, 52), color.darkened(0.45))
	draw_rect(Rect2(46, -14, 12, 52), color.darkened(0.45))
	draw_circle(Vector2(0, -4), 13.0, Color(0.95, 0.85, 0.35))
