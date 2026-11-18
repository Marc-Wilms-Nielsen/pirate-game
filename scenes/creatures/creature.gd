class_name Creature
extends Node2D
## Fælles base for dyr og væsner: liv, skade, død og loot.
## Underklasser implementerer _behave(delta) og _draw_body().

@export var max_hp: float = 10.0
@export var speed: float = 30.0
@export var loot_table: String = ""
@export var radius: float = 6.0

var hp: float
var home: Island ## øen dyret hører til (null for havdyr)
var facing := Vector2.RIGHT
var _hit_flash: float = 0.0
var _show_health: float = 0.0
var _time: float = 0.0
var _dead := false
var _stun: float = 0.0 ## blændet: står stille
var slow_factor: float = 1.0 ## < 1 når dyret er forgiftet
var _slow_timer: float = 0.0


func _ready() -> void:
	hp = max_hp
	# Bevidst ingen fysik-krop: at flytte mange fysik-områder hvert frame kostede ~18 ms.
	# Sværd og kanonkugler finder dyr via afstand i stedet.
	add_to_group("creatures")
	_time = randf() * 10.0


func _process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	_hit_flash = maxf(_hit_flash - delta * 4.0, 0.0)
	_show_health = maxf(_show_health - delta, 0.0)
	_slow_timer = maxf(_slow_timer - delta, 0.0)
	if _slow_timer <= 0.0:
		slow_factor = 1.0
	if _stun > 0.0:
		_stun -= delta
	else:
		_behave(delta * slow_factor)
	queue_redraw()


func _behave(_delta: float) -> void:
	pass


func take_damage(amount: float, from: Vector2) -> void:
	if _dead:
		return
	hp -= amount
	_hit_flash = 1.0
	_show_health = 3.0
	position += (global_position - from).normalized() * 6.0 # lille skub væk
	Sfx.play_at("hurt", global_position, -6.0)
	Game.popup("-%d" % int(amount), global_position + Vector2(0, -12), Color(1, 0.6, 0.5))
	_on_hurt(from)
	if hp <= 0.0:
		_die()


## Blændgranat: dyret står forvirret stille.
func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


## Gift: dyret bliver langsomt.
func slow(factor: float, seconds: float) -> void:
	slow_factor = minf(slow_factor, factor)
	_slow_timer = maxf(_slow_timer, seconds)


func _on_hurt(_from: Vector2) -> void:
	pass


func _die() -> void:
	_dead = true
	if loot_table != "":
		Game.give_loot(loot_table, global_position)
	# Quest bosses (set by QuestWorld) drop extra loot and complete their quest's goal
	if has_meta("quest_boss"):
		Game.give_loot("quest_boss", global_position + Vector2(0, -20))
		Quests.boss_defeated(get_meta("quest_boss"))
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func player_character() -> Node2D:
	return get_tree().get_first_node_in_group("player_character") as Node2D


func move_towards_point(target: Vector2, spd: float, delta: float) -> void:
	var dir := target - global_position
	if dir.length() < 1.0:
		return
	facing = facing.slerp(dir.normalized(), 1.0 - exp(-8.0 * delta))
	global_position += dir.normalized() * spd * delta


func _draw() -> void:
	_draw_body()
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius + 1.0, Color(1, 1, 1, 0.5 * _hit_flash), true, -1.0, true)
	if _stun > 0.0: # små stjerner over hovedet
		for i in 3:
			var a := _time * 4.0 + TAU * i / 3.0
			draw_circle(Vector2(cos(a) * 5.0, -radius - 4.0 + sin(a) * 1.5), 1.1, Color(1, 0.95, 0.5), true, -1.0, true)
	if slow_factor < 1.0:
		draw_circle(Vector2.ZERO, radius + 2.0, Color(0.5, 0.9, 0.3, 0.25), true, -1.0, true)
	if _show_health > 0.0 and hp < max_hp:
		var w := radius * 3.0
		draw_rect(Rect2(-w * 0.5, -radius - 8, w, 2.5), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-w * 0.5, -radius - 8, w * hp / max_hp, 2.5), Color(0.9, 0.3, 0.25))


func _draw_body() -> void:
	pass
