extends CanvasLayer
## Lille HUD: sejlstilling og fart nederst, kontroller øverst.

var _status: Label
var _ship # utypet: vi kalder ship.gd-funktioner på den


func _ready() -> void:
	var hint := _make_label(Vector2(8, 6))
	hint.text = "W/S: sejl op/ned    A/D: drej"
	hint.modulate.a = 0.7
	_status = _make_label(Vector2(8, 340))


func _process(_delta: float) -> void:
	if _ship == null:
		_ship = get_tree().get_first_node_in_group("player_ship")
		return
	_status.text = "Sejl: %s    Fart: %.1f knob" % [_ship.get_sail_name(), _ship.speed / 10.0]


func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label
