class_name Chair
extends StaticBody2D
## A sittable chair. Fills its meter while occupied; a full meter makes its
## passive permanent and burns the chair out. Any break knocks enemies back.

signal broke
signal hp_changed(hp: float, max_hp: float)
signal meter_changed(value: float, max_value: float)
signal meter_filled(passive_id: StringName)

const KNOCKBACK_RADIUS := 280.0
const KNOCKBACK_FORCE := 800.0
const KNOCKBACK_STUN := 0.6
## Seconds the chair survives after its meter is filled.
const BURNOUT_TIME := 3.0

var data: ChairData
var hp := 0.0
var meter := 0.0
var occupied := false
var occupant: Player

var _meter_filled := false
var _burnout_timer := -1.0
var _breaking := false

@onready var name_label: Label = $NameLabel

## Must be called before the chair is added to the tree.
func setup(chair_data: ChairData) -> void:
	data = chair_data
	hp = data.max_hp

func _ready() -> void:
	add_to_group("chairs")
	name_label.text = data.display_name
	queue_redraw()

func _process(delta: float) -> void:
	if occupied and not _meter_filled:
		meter = minf(meter + delta, data.meter_time)
		meter_changed.emit(meter, data.meter_time)
		if meter >= data.meter_time:
			_meter_filled = true
			_burnout_timer = BURNOUT_TIME
			RunState.add_passive(data.passive_id)
			meter_filled.emit(data.passive_id)
		queue_redraw()
	if _burnout_timer > 0.0:
		_burnout_timer -= delta
		queue_redraw()
		if _burnout_timer <= 0.0:
			break_chair()

func occupy(player: Player) -> void:
	occupied = true
	occupant = player

func take_damage(amount: float) -> void:
	if _breaking:
		return
	hp -= amount
	hp_changed.emit(maxf(hp, 0.0), data.max_hp)
	queue_redraw()
	if hp <= 0.0:
		break_chair()

func break_chair() -> void:
	if _breaking:
		return
	_breaking = true
	if occupied and is_instance_valid(occupant):
		occupant.on_chair_broken()
	occupied = false
	_knockback_enemies()
	PulseVfx.spawn(get_tree().current_scene, global_position, KNOCKBACK_RADIUS, data.color)
	broke.emit()
	queue_free()

func _knockback_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() > KNOCKBACK_RADIUS:
			continue
		var direction := offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT
		enemy.apply_knockback(direction * KNOCKBACK_FORCE, KNOCKBACK_STUN)

func _draw() -> void:
	var flashing := _burnout_timer > 0.0 and int(_burnout_timer * 8.0) % 2 == 0
	if data.sprite:
		SpriteFit.draw(self, data.sprite, Vector2(48, 56), Color(1.6, 1.6, 1.6) if flashing else Color.WHITE)
	else:
		var seat_color := data.color.lerp(Color.WHITE, 0.6) if flashing else data.color
		draw_rect(Rect2(-22, -22, 44, 44), seat_color)
		draw_rect(Rect2(-22, -34, 44, 12), seat_color.darkened(0.35))
	var hp_ratio := clampf(hp / data.max_hp, 0.0, 1.0)
	draw_rect(Rect2(-22, 28, 44, 5), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-22, 28, 44 * hp_ratio, 5), Color(0.9, 0.25, 0.25))
	var meter_ratio := clampf(meter / data.meter_time, 0.0, 1.0) if data.meter_time > 0.0 else 1.0
	draw_rect(Rect2(-22, 35, 44, 5), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-22, 35, 44 * meter_ratio, 5), Color(1.0, 0.85, 0.2))
