class_name ImpactBurst
extends CPUParticles2D
## A small one-shot particle burst spawned when a bullet or beam hits an enemy,
## tinted to the projectile's color. Self-frees once the burst finishes. Uses
## CPUParticles2D (not GPU) so it renders under the GL Compatibility renderer.

const LIFETIME := 0.35

## Spawns a burst at `pos` (world space) in `burst_color`.
static func spawn(parent: Node, pos: Vector2, burst_color: Color, amount := 8) -> void:
	if parent == null:
		return
	var burst := ImpactBurst.new()
	burst._configure(burst_color, amount)
	# Position BEFORE add_child: _ready() flips emitting on (the one-shot burst
	# fires immediately), so the node must already sit at the impact — otherwise
	# every particle spawns at the origin (the centre of the map).
	burst.position = pos
	parent.add_child(burst)

func _configure(burst_color: Color, particle_count: int) -> void:
	emitting = false # started in _ready so every particle spawns inside the tree
	one_shot = true
	explosiveness = 1.0
	amount = maxi(particle_count, 1)
	lifetime = LIFETIME
	local_coords = false # particles keep flying even after the node is freed-safe
	direction = Vector2.RIGHT
	spread = 180.0 # full circle
	gravity = Vector2.ZERO
	initial_velocity_min = 45.0
	initial_velocity_max = 145.0
	damping_min = 120.0
	damping_max = 220.0
	scale_amount_min = 1.5
	scale_amount_max = 3.0
	color = burst_color
	# Fade the alpha to 0 over the particle's life so the sparks dissolve.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(burst_color.r, burst_color.g, burst_color.b, 1.0))
	ramp.set_color(1, Color(burst_color.r, burst_color.g, burst_color.b, 0.0))
	color_ramp = ramp

func _ready() -> void:
	z_index = 6
	emitting = true
	get_tree().create_timer(LIFETIME + 0.1).timeout.connect(queue_free)
