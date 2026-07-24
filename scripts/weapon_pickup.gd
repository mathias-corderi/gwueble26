class_name WeaponPickup
extends Area2D
## A weapon lying on the map. Auto-picked up on player contact (ignored when
## the player's inventory is full).

var data: WeaponData

var _time := 0.0

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
		Sfx.play(Sfx.AMMO_PICKUP, -4.0, 1.0, 0.05)
		queue_free()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	# Pulsing highlight halo so weapon pickups stand out on the map.
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	var glow := Color(data.color.r, data.color.g, data.color.b, 0.10 + 0.12 * pulse)
	var base_r := 20.0 + 3.0 * pulse
	draw_circle(Vector2.ZERO, base_r, glow)
	draw_circle(Vector2.ZERO, base_r * 0.7, glow)
	if data.sprite:
		SpriteFit.draw(self, data.sprite, Vector2(28, 28), Color(1.2, 1.2, 1.2))
	else:
		var points := PackedVector2Array([
			Vector2(0, -14), Vector2(14, 0), Vector2(0, 14), Vector2(-14, 0)
		])
		draw_colored_polygon(points, data.color)
		points.append(Vector2(0, -14))
		draw_polyline(points, Color(0, 0, 0, 0.4), 2.0)
