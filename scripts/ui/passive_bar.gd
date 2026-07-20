class_name PassiveBar
extends Control
## One burning passive: name + level, a bar that shrinks like a burning stick,
## and a FlameAnchor kept at the burn edge. When the flame art lands, replace
## FlameAnchor's placeholder child with an AnimatedSprite2D — the anchor's
## position is already driven by this script (see docs/ANIMATION_GUIDE.md).

var passive_id: StringName

@onready var name_label: Label = $NameLabel
@onready var bar: ProgressBar = $Bar
@onready var flame_anchor: Control = $FlameAnchor

func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.12, 0.1, 0.08, 0.8) # charred remains
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.72, 0.5) # unburnt stick
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

func _process(_delta: float) -> void:
	if passive_id not in RunState.passives:
		return
	var state: Dictionary = RunState.passives[passive_id]
	var config: Dictionary = RunState.PASSIVES[passive_id]
	var ratio: float = clampf(state.time_left / config.duration, 0.0, 1.0)
	bar.value = ratio * 100.0
	if config.max_level > 1:
		name_label.text = "%s Lv%d" % [config.name, state.level]
	else:
		name_label.text = config.name
	flame_anchor.position = bar.position + Vector2(bar.size.x * ratio, bar.size.y * 0.5)
