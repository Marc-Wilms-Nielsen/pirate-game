class_name FloatingLoot
extends Area2D
## Tønde eller vraggods der flyder i vandet. Sejl hen over den (eller svøm) for at samle op.

var loot_table: String = "floating_barrel"
var lifetime: float = -1.0 ## -1 = forsvinder ikke af sig selv
var _time: float = 0.0
var _picked := false


func _ready() -> void:
	add_to_group("floating_loot")
	collision_layer = 0
	collision_mask = 4 | 2 # skibe og kaptajnen
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_time = randf() * 10.0
	rotation = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
	position += Vector2(sin(_time * 0.4), cos(_time * 0.3)) * 2.0 * delta # driver langsomt
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _picked:
		return
	if body.is_in_group("player_ship") or body.is_in_group("player_character") or body.is_in_group("escorts"):
		_picked = true
		if body is EscortShip:
			Game.log_line("%s fished up some flotsam:" % (body as EscortShip).captain().get("name", "Your captain"), Color(0.7, 1.0, 0.75), "captain")
		Sfx.play_at("splash", global_position, -12.0)
		Game.give_loot(loot_table, global_position)
		queue_free()


func _draw() -> void:
	var bob := sin(_time * 2.0) * 0.6
	draw_arc(Vector2.ZERO, 10.0 + sin(_time * 1.5) * 1.5, 0.0, TAU, 24, Color(1, 1, 1, 0.3), 1.0, true)
	draw_rect(Rect2(-6 + 2, -4 + 3, 12, 8), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(-6, -4 + bob, 12, 8), Color(0.58, 0.38, 0.2))
	draw_rect(Rect2(-6, -4 + bob, 1.5, 8), Color(0.35, 0.25, 0.15))
	draw_rect(Rect2(-1, -4 + bob, 1.5, 8), Color(0.35, 0.25, 0.15))
	draw_rect(Rect2(4.5, -4 + bob, 1.5, 8), Color(0.35, 0.25, 0.15))
