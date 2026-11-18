class_name CaptainPreview
extends Control
## The Tailor's live model: the captain seen from above, big, slowly turning, with his portrait
## (head and shoulders) beside it. show_values() shows the options you are trying on.

var values: Dictionary = {}
var _portrait: Portrait
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = Portrait.new()
	add_child(_portrait)
	show_values(Game.captain_look)


func show_values(look_ids: Dictionary) -> void:
	values = look_ids
	if _portrait:
		_portrait.look = CaptainDrawer.portrait_look(CaptainDrawer.resolve(values, Game.equipped))
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.48, 0.3)) # a deck to stand on
	for y in range(0, int(size.y), 9):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.5, 0.37, 0.22, 0.7), 1.0)
	var psize := minf(size.x * 0.45, size.y * 0.5)
	_portrait.size = Vector2(psize, psize)
	_portrait.position = Vector2(size.x - psize - 6.0, 6.0)
	# The captain from above, turning slowly so you see the front, back and sides
	var s := CaptainDrawer.resolve(values, Game.equipped)
	var center := Vector2(size.x * 0.32, size.y * 0.55)
	var scale := minf(size.x, size.y) / 26.0
	var facing := Vector2.from_angle(_time * 0.6)
	draw_set_transform(center, 0.0, Vector2(scale, scale))
	CaptainDrawer.draw_body(self, s, facing, sin(_time * 5.0) * 0.3)
	CaptainDrawer.draw_head(self, s, facing, facing, 1.0, _time)
	draw_set_transform(Vector2.ZERO)
