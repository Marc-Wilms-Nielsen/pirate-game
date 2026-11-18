class_name Chest
extends Node2D
## Skattekiste på en ø. Gå hen til den og tryk F. Fyldes igen efter et stykke tid.

const OPEN_RANGE := 22.0
const RESPAWN_TIME := 300.0

var loot_table: String = "beach_chest"
var opened := false
var _respawn: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group("chests")
	rotation = randf_range(-0.4, 0.4)


func _process(delta: float) -> void:
	_time += delta
	if opened:
		_respawn -= delta
		if _respawn <= 0.0:
			opened = false
	queue_redraw()


func can_open(pos: Vector2) -> bool:
	return not opened and pos.distance_to(global_position) < OPEN_RANGE


func open() -> void:
	if opened:
		return
	opened = true
	_respawn = RESPAWN_TIME
	Sfx.play_at("chest", global_position)
	Game.give_loot(loot_table, global_position + Vector2(0, -10))
	if has_meta("quest_treasure"): # the Sun King's treasure: opens once, never refills
		_respawn = INF
		# The crown must never be lost to a full cargo hold: it squeezes in regardless
		if Game.cargo_count("sun_crown") == 0:
			Game.cargo["sun_crown"] = 1
			Game.changed.emit()
		Quests.treasure_opened()


func _draw() -> void:
	var wood := Color(0.55, 0.33, 0.16)
	var band := Color(0.85, 0.7, 0.25)
	draw_rect(Rect2(-6, -3, 14, 10), Color(0, 0, 0, 0.2)) # skygge
	draw_rect(Rect2(-7, -5, 14, 10), wood)
	if opened:
		draw_rect(Rect2(-6, -4, 12, 8), Color(0.2, 0.12, 0.06)) # tom indvendig
		draw_rect(Rect2(-7, -9, 14, 4), wood.lightened(0.1)) # åbent låg
	else:
		draw_rect(Rect2(-7, -5, 14, 4), wood.lightened(0.1))
		draw_rect(Rect2(-1.5, -2, 3, 3), band)
		# Glimt, så kisten er nem at få øje på
		var glint := (sin(_time * 2.5) * 0.5 + 0.5) * 0.6
		draw_circle(Vector2(5, -6), 1.3, Color(1, 1, 0.8, glint), true, -1.0, true)
	draw_rect(Rect2(-7, -5, 1.5, 10), band)
	draw_rect(Rect2(5.5, -5, 1.5, 10), band)
