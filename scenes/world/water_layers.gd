class_name WaterLayers
extends Node2D
## Owns how the ocean and the seabed reach the screen (added by main.gd).
##
## Seabed: the rocks and wrecks (the Seabed node) are drawn into a half-resolution off-screen
## image (a SubViewport). The ocean shader reads that image and blends it under the water.
## Before, the seabed was a second full-screen shader pass under the water; this is far cheaper.
##
## Render scale (Settings.render_scale < 1): the ocean is drawn into a smaller off-screen image
## and stretched to fill the screen. The water is the most expensive thing on screen, so at
## 0.5 it costs about a quarter. Ships, islands and UI are drawn as normal and stay sharp.
##
## Godot note: a SubViewport is a separate canvas with its own transform. Every frame, just
## before drawing (RenderingServer.frame_pre_draw), we copy the main view's canvas transform
## into it, so the off-screen images line up with the world pixel for pixel.

const SEABED_RES := 0.5 ## the seabed is under water and soft anyway

var ocean: ColorRect
var seabed: Seabed

var _seabed_view: SubViewport
var _water_view: SubViewport
var _water_sprite: Sprite2D
var _scale := 1.0


func setup(ocean_rect: ColorRect, seabed_node: Seabed) -> void:
	ocean = ocean_rect
	seabed = seabed_node
	_seabed_view = _make_view("SeabedView", true)
	add_child(_seabed_view)
	seabed.get_parent().remove_child(seabed)
	_seabed_view.add_child(seabed)
	var mat := ocean.material as ShaderMaterial
	mat.set_shader_parameter("seabed_tex", _seabed_view.get_texture())
	_apply_scale()
	Settings.changed.connect(_apply_scale)
	RenderingServer.frame_pre_draw.connect(_sync)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.disconnect(_sync)


func _make_view(view_name: String, transparent: bool) -> SubViewport:
	var v := SubViewport.new()
	v.name = view_name
	v.transparent_bg = transparent
	v.disable_3d = true
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	return v


## Moves the ocean into (or out of) the reduced-resolution view when the setting changes.
func _apply_scale() -> void:
	var s := clampf(Settings.render_scale, 0.25, 1.0)
	if is_equal_approx(s, _scale) and (s >= 1.0 or _water_view != null):
		return
	_scale = s
	var host := get_parent()
	if s >= 1.0:
		if _water_view:
			_water_view.remove_child(ocean)
			host.add_child(ocean)
			host.move_child(ocean, get_index())
			_water_view.queue_free()
			_water_sprite.queue_free()
			_water_view = null
			_water_sprite = null
		return
	if _water_view == null:
		_water_view = _make_view("WaterView", false)
		add_child(_water_view)
		_water_sprite = Sprite2D.new()
		_water_sprite.name = "WaterImage"
		_water_sprite.centered = false
		_water_sprite.texture = _water_view.get_texture()
		_water_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_water_sprite.z_index = ocean.z_index
		_water_sprite.z_as_relative = false
		add_child(_water_sprite)
		ocean.get_parent().remove_child(ocean)
		_water_view.add_child(ocean)


func _sync() -> void:
	if not is_inside_tree() or ocean == null:
		return
	var main_vp := get_viewport()
	var screen := main_vp.get_visible_rect().size
	var ct := main_vp.get_canvas_transform()
	var inv := ct.affine_inverse()
	# The ocean only has to cover what is on screen (plus a margin for the wave slope).
	var world_rect := inv * Rect2(Vector2.ZERO, screen)
	world_rect = world_rect.grow(64.0)
	ocean.position = world_rect.position
	ocean.size = world_rect.size
	# Seabed parallax: it sits slightly "deeper", so it moves a bit slower than the surface.
	var center := inv * (screen * 0.5)
	seabed.scale = Vector2.ONE * Seabed.DEPTH_PARALLAX
	seabed.position = center * (1.0 - Seabed.DEPTH_PARALLAX)
	var mat := ocean.material as ShaderMaterial
	mat.set_shader_parameter("floor_offset", seabed.position)
	mat.set_shader_parameter("floor_scale", Seabed.DEPTH_PARALLAX)
	# The game is laid out at 640 x 360 and Godot stretches it to the real window
	# ("canvas_items" stretch mode). The off-screen images must use real window pixels,
	# so include that stretch factor.
	var stretch := main_vp.get_final_transform().get_scale()
	_fit(_seabed_view, screen, stretch * SEABED_RES, ct)
	if _water_view:
		var s := stretch * _scale
		_fit(_water_view, screen, s, ct)
		# Stretch the small image back over the full screen, in world space so lights and
		# the day/night tint (CanvasModulate) still apply to it.
		_water_sprite.global_transform = inv * Transform2D(0.0, Vector2.ONE / s, 0.0, Vector2.ZERO)


func _fit(view: SubViewport, screen: Vector2, s: Vector2, ct: Transform2D) -> void:
	var px := screen * s
	var size := Vector2i(maxi(ceili(px.x), 2), maxi(ceili(px.y), 2))
	if view.size != size:
		view.size = size
	view.canvas_transform = Transform2D(0.0, s, 0.0, Vector2.ZERO) * ct
