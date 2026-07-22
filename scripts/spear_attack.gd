class_name SpearAttack
extends Area2D
## The Spiked Chair's melee lunge: a wide, long hitbox that stabs out in a
## direction, damaging and shoving every enemy it catches once. Sprite-ready —
## drop a texture into `sprite` and it draws that instead of the placeholder.

const LENGTH := 190.0
const WIDTH := 64.0
const DURATION := 0.22
const KNOCKBACK_FORCE := 560.0
const KNOCKBACK_STUN := 0.3

var damage := 30.0
var color := Color(0.8, 0.8, 0.85)
var sprite: Texture2D

var _age := 0.0
var _dir := Vector2.RIGHT
var _hit := {}

## Must be called before the attack is added to the tree.
func setup(direction: Vector2, spear_damage: float, spear_color: Color, spear_sprite: Texture2D = null) -> void:
	_dir = direction
	damage = spear_damage
	color = spear_color
	sprite = spear_sprite

func _ready() -> void:
	rotation = _dir.angle()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(LENGTH, WIDTH)
	var collision: CollisionShape2D = $CollisionShape2D
	collision.shape = shape
	collision.position = Vector2(LENGTH * 0.5, 0.0) # extends forward from the chair
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age > DURATION:
		queue_free()
		return
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body is Enemy and body not in _hit:
		_hit[body] = true
		body.take_damage(damage)
		body.apply_knockback(_dir * KNOCKBACK_FORCE, KNOCKBACK_STUN)

func _draw() -> void:
	var fade := 1.0 - _age / DURATION
	if sprite:
		var tint := Color(color.r, color.g, color.b, fade)
		# Drawn in local space (already rotated): fit along the forward axis.
		var tex_size := sprite.get_size()
		var scale := WIDTH / tex_size.y
		var draw_len := tex_size.x * scale
		draw_texture_rect(sprite, Rect2(0, -WIDTH * 0.5, draw_len, WIDTH), false, tint)
		return
	var body_color := Color(color.r, color.g, color.b, 0.7 * fade)
	# A tapered spike: wide at the base, pointed at the tip.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -WIDTH * 0.5), Vector2(LENGTH * 0.8, -WIDTH * 0.2),
		Vector2(LENGTH, 0), Vector2(LENGTH * 0.8, WIDTH * 0.2), Vector2(0, WIDTH * 0.5),
	]), body_color)
