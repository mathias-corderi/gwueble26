class_name LightningVfx
extends Node2D
## Procedural electric bolt drawn along a chain of points. Each segment is
## subdivided and jittered sideways, and the jitter is re-rolled several times
## per second so the bolt crackles instead of sitting still — that flicker is
## what sells the "electric" read.
##
## Art is optional: with no texture it draws flat colored lines (which already
## look like lightning thanks to the jitter). Drop a horizontally-tileable
## grayscale strip at BOLT_TEXTURE_PATH and every arc picks it up automatically
## — see CONTRIBUTING.md.

const BOLT_TEXTURE_PATH := "res://art/fx/lightning_bolt.png"
const DURATION := 0.3
## How often the zig-zag is re-rolled.
const FLICKER_INTERVAL := 0.04
## Subdivisions per chain segment; more = finer, twitchier zig-zag.
const STEPS_PER_SEGMENT := 6
## Sideways jitter as a fraction of the segment length.
const JITTER_RATIO := 0.12
const MAX_JITTER := 26.0
const CORE_WIDTH := 3.0
const GLOW_WIDTH := 9.0

## Cached across every bolt: null until the artist drops the file in.
static var _texture: Texture2D
static var _texture_checked := false

var color := Color(0.6, 0.85, 1.0)

var _chain := PackedVector2Array()
var _age := 0.0
var _flicker_timer := 0.0

@onready var _glow: Line2D = $Glow
@onready var _core: Line2D = $Core

## Spawns a bolt through `points` (world space). Needs at least 2 points.
static func spawn(parent: Node, points: PackedVector2Array, bolt_color: Color) -> void:
	if parent == null or points.size() < 2:
		return
	var vfx: LightningVfx = preload("res://scenes/lightning_vfx.tscn").instantiate()
	vfx.color = bolt_color
	vfx._chain = points
	parent.add_child(vfx)

static func _bolt_texture() -> Texture2D:
	if not _texture_checked:
		_texture_checked = true
		if ResourceLoader.exists(BOLT_TEXTURE_PATH):
			_texture = load(BOLT_TEXTURE_PATH)
	return _texture

func _ready() -> void:
	var texture := _bolt_texture()
	for line in [_glow, _core]:
		line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		if texture:
			line.texture = texture
			line.texture_mode = Line2D.LINE_TEXTURE_TILE
	_glow.width = GLOW_WIDTH
	_glow.default_color = Color(color.r, color.g, color.b, 0.3)
	_core.width = CORE_WIDTH
	_core.default_color = color.lerp(Color.WHITE, 0.5)
	_rebuild()

func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = FLICKER_INTERVAL
		_rebuild()
	modulate.a = 1.0 - _age / DURATION

## Re-rolls the zig-zag between every pair of chain points.
func _rebuild() -> void:
	var points := PackedVector2Array()
	for i in _chain.size() - 1:
		var from := _chain[i]
		var to := _chain[i + 1]
		var segment := to - from
		var normal := segment.orthogonal().normalized()
		var jitter := minf(segment.length() * JITTER_RATIO, MAX_JITTER)
		points.append(to_local(from))
		for step in range(1, STEPS_PER_SEGMENT):
			var along := from.lerp(to, float(step) / STEPS_PER_SEGMENT)
			points.append(to_local(along + normal * randf_range(-jitter, jitter)))
	points.append(to_local(_chain[-1]))
	_glow.points = points
	_core.points = points
