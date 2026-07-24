extends Node2D
## Crosshair that replaces the OS cursor. Dimmed while standing (you cannot
## shoot), tinted to the chair's color while seated.

const STANDING_COLOR := Color(0.8, 0.85, 0.9, 0.45)

var _color := STANDING_COLOR

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	add_to_group("crosshair") # so the pause menu can hide it while open
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var player: Player = get_tree().get_first_node_in_group("player")
	player.seated_on.connect(_on_seated)
	player.stood_up.connect(_on_stood_up)

func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()

func _on_seated(chair: Chair) -> void:
	_color = Color(chair.data.color, 1.0)
	queue_redraw()

func _on_stood_up() -> void:
	_color = STANDING_COLOR
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, _color, 2.0)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2.from_angle(angle)
		draw_line(direction * 6.0, direction * 16.0, _color, 2.0)
	draw_circle(Vector2.ZERO, 1.5, _color)
