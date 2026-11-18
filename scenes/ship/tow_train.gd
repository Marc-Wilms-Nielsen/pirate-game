class_name TowTrain
extends Node2D
## Tegner de erobrede skibe, der slæbes efter spillerens skib, med et reb imellem.
## Skibene følger efter hinanden som perler på en snor. Data ligger i Game.towed.

const ROPE_GAP := 26.0

var _visuals: Array[ShipVisual] = []
var _ropes: Array[Line2D] = []
var _positions: Array[Vector2] = []
var _rotations: Array[float] = []
var _count_key := ""


func _process(delta: float) -> void:
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	if ship == null:
		return
	var key := str(Game.towed.size()) + ":" + ",".join(PackedStringArray(Game.towed.map(func(c: Dictionary) -> String: return c["type"])))
	if key != _count_key:
		_rebuild(ship)
		_count_key = key
	var leader_pos := ship.visual.global_position
	var leader_rot := ship.visual.global_rotation
	var leader_len: float = Catalog.SHIPS[Game.active_ship()["type"]]["look"]["length"]
	for i in _visuals.size():
		var my_len: float = Catalog.SHIPS[Game.towed[i]["type"]]["look"]["length"]
		var stern := leader_pos - Vector2.from_angle(leader_rot) * leader_len * 0.5
		var away := _positions[i] - stern
		if away.length() < 1.0:
			away = -Vector2.from_angle(leader_rot)
		var center := stern + away.normalized() * (ROPE_GAP + my_len * 0.5)
		_positions[i] = center
		var target_rot := (stern - center).angle()
		_rotations[i] = lerp_angle(_rotations[i], target_rot, 1.0 - exp(-6.0 * delta))
		_visuals[i].global_position = center
		_visuals[i].global_rotation = _rotations[i]
		_visuals[i].update_motion(ship.speed, 0.0, 0.0, delta)
		var bow := center + Vector2.from_angle(_rotations[i]) * my_len * 0.5
		_ropes[i].points = PackedVector2Array([stern, bow])
		leader_pos = center
		leader_rot = _rotations[i]
		leader_len = my_len


func _rebuild(ship: PlayerShip) -> void:
	for v in _visuals:
		v.queue_free()
	for r in _ropes:
		r.queue_free()
	_visuals.clear()
	_ropes.clear()
	var old_positions := _positions.duplicate()
	_positions.clear()
	_rotations.clear()
	var behind := ship.global_position
	for i in Game.towed.size():
		var rope := Line2D.new()
		rope.width = 1.3
		rope.default_color = Color(0.35, 0.25, 0.15, 0.85)
		rope.antialiased = true
		add_child(rope)
		_ropes.append(rope)
		var v := ShipVisual.new()
		add_child(v)
		v.apply_config(Game.towed[i])
		_visuals.append(v)
		behind -= Vector2.from_angle(ship.rotation) * 70.0
		_positions.append(old_positions[i] if i < old_positions.size() else behind)
		_rotations.append(ship.rotation)
