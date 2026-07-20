class_name SpriteFit
extends RefCounted
## Shared helper for drawing an optional placeholder-replacement sprite,
## scaled to fit inside a box and centered on the owning CanvasItem.

static func draw(item: CanvasItem, texture: Texture2D, box_size: Vector2, tint := Color.WHITE) -> void:
	var tex_size := texture.get_size()
	var scale := minf(box_size.x / tex_size.x, box_size.y / tex_size.y)
	var draw_size := tex_size * scale
	item.draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, tint)
