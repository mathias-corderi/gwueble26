class_name WeaponPickup
extends Area2D
## A weapon lying on the map. Auto-picked up on player contact (ignored when
## the player's inventory is full).

var data: WeaponData

@onready var name_label: Label = $NameLabel

## Must be called before the pickup is added to the tree.
func setup(weapon_data: WeaponData) -> void:
	data = weapon_data

func _ready() -> void:
	add_to_group("weapon_pickups")
	body_entered.connect(_on_body_entered)
	name_label.text = "%s (%d)" % [data.display_name, data.max_ammo]
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is Player and body.try_pickup(data):
		queue_free()

func _draw() -> void:
	if data.sprite:
		SpriteFit.draw(self, data.sprite, Vector2(28, 28))
	else:
		var points := PackedVector2Array([
			Vector2(0, -14), Vector2(14, 0), Vector2(0, 14), Vector2(-14, 0)
		])
		draw_colored_polygon(points, data.color)
		points.append(Vector2(0, -14))
		draw_polyline(points, Color(0, 0, 0, 0.4), 2.0)
