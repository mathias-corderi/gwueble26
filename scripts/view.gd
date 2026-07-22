class_name View
extends RefCounted
## Shared viewport helpers. Used to keep effects and cleanup camera-aware:
## the laser only damages what is on screen, and idle chairs only despawn
## while the player can't see them.

## The world-space rectangle currently visible through the camera.
static func world_rect(node: Node) -> Rect2:
	var viewport := node.get_viewport()
	if viewport == null:
		return Rect2()
	var canvas_xform := viewport.get_canvas_transform()
	return Rect2(canvas_xform.affine_inverse().origin,
		viewport.get_visible_rect().size / canvas_xform.get_scale())
