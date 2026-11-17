extends CanvasLayer
## Lille HUD: status nederst, kontroller øverst. Skifter tekst efter om man sejler eller går.

var _hint: Label
var _status: Label
var _ship # utypet: vi kalder ship.gd-funktioner på den


func _ready() -> void:
	_hint = _make_label(Vector2(8, 6))
	_hint.modulate.a = 0.75
	_status = _make_label(Vector2(8, 340))


func _process(_delta: float) -> void:
	if _ship == null:
		_ship = get_tree().get_first_node_in_group("player_ship")
		return

	var player = get_tree().get_first_node_in_group("player_character")
	if player != null:
		_hint.text = "WASD: gå / svøm    F: gå om bord (tæt på skibet)"
		_status.text = "På land" if player.on_land else "Svømmer"
		return

	var hint := "W/S: sejl    A/D: ror    Mellemrum: anker"
	if _ship.can_disembark():
		hint += "    F: hop i vandet"
	_hint.text = hint
	_status.text = "Sejl: %s    Fart: %.1f knob    Anker: %s" % [
		_ship.get_sail_name(), _ship.speed / 10.0, "kastet" if _ship.anchored else "hævet"]


func _make_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label
