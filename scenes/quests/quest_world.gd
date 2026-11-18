class_name QuestWorld
extends Node2D
## The quest line's presence in the world (added by main.gd):
## - yellow "!" / "?" floating over harbors (see Quests.marker_at)
## - spawns the current quest's boss when you come near its spot, and the treasure chest
##   after the final boss; despawns the boss again if you sail far away (it waits for you)
## - a name tag over the boss

const SPAWN_RANGE := 1300.0
const DESPAWN_RANGE := 3200.0
const MARK_COLOR := Color(1.0, 0.85, 0.15)

var _boss: Node2D = null
var _boss_name := ""
var _boss_for := "" ## the quest id the boss belongs to
var _treasure: Chest = null
var _think := 0.0
var _time := 0.0
var _font: Font


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	_font = ThemeDB.fallback_font
	# Places are picked from the finished world (camps, castles and harbors must exist)
	Quests.resolve_spots.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	_think -= delta
	if _think <= 0.0:
		_think = 0.5
		_manage()
	queue_redraw()


## Where the player is: the captain on foot, or the ship.
func _focus() -> Vector2:
	var player := get_tree().get_first_node_in_group("player_character") as Node2D
	if player:
		return player.global_position
	var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
	return ship.global_position if ship else Vector2.ZERO


func _manage() -> void:
	var q := Quests.current()
	var focus := _focus()
	var wants_boss: bool = not q.is_empty() and q["type"] == "boss" and Quests.state == "active" and not Quests.boss_down
	if current_boss() == null:
		_boss = null # beaten (still sinking or fading out), or it belonged to an earlier quest
	elif focus.distance_to(_boss.global_position) > DESPAWN_RANGE:
		_boss.queue_free() # sailed away: it comes back at full strength when you return
		_boss = null
	if _boss == null and wants_boss:
		var target: Vector2 = Quests.spots.get(q["id"] + ".target", Vector2.INF)
		if target != Vector2.INF and focus.distance_to(target) < SPAWN_RANGE:
			_spawn_boss(q, target)
	# The final treasure: a chest appears on the island once the boss is beaten
	var wants_treasure: bool = not q.is_empty() and q.get("treasure", false) and Quests.boss_down and not Quests.treasure_found
	if wants_treasure and not is_instance_valid(_treasure):
		var dig: Vector2 = Quests.spots.get(q["id"] + ".dig", Vector2.INF)
		if dig != Vector2.INF and focus.distance_to(dig) < SPAWN_RANGE * 1.5:
			_treasure = Chest.new()
			_treasure.loot_table = "sun_treasure"
			_treasure.set_meta("quest_treasure", true)
			_treasure.global_position = dig
			Game.world_root.add_child(_treasure)


## The current quest's living boss, or null (a beaten boss can linger while it sinks).
func current_boss() -> Node2D:
	var q := Quests.current()
	if not is_instance_valid(_boss) or _boss.is_queued_for_deletion() or q.is_empty() or _boss_for != q["id"] or Quests.boss_down:
		return null
	return _boss


func _spawn_boss(q: Dictionary, target: Vector2) -> void:
	var b: Dictionary = q["boss"]
	_boss_for = q["id"]
	_boss_name = String(b["name"]).capitalize()
	match b["kind"]:
		"ship":
			var ship := EnemyShip.new()
			ship.setup("pirate", b["ship"])
			ship.ship_name = _boss_name
			ship.hp_mult = float(b["hp"])
			ship.boss_quest = q["id"]
			ship.crew += 6
			ship.global_position = target
			Game.world_root.add_child(ship)
			_boss = ship
		"beast":
			var beast := Beast.new()
			beast.kind = b["beast"]
			beast.home = _island_at(Quests.spots.get(q["id"] + ".island", target))
			beast.global_position = target
			beast.set_meta("quest_boss", q["id"])
			Game.world_root.add_child(beast) # runs _ready, which sets the normal stats
			var size := float(b["size"])
			beast.scale = Vector2.ONE * size
			beast.radius *= size
			beast.max_hp *= float(b["hp"])
			beast.hp = beast.max_hp
			var cfg: Dictionary = (beast.get("_cfg") as Dictionary).duplicate()
			cfg["damage"] = float(cfg["damage"]) * float(b["damage"])
			cfg["reach"] = float(cfg["reach"]) * size
			cfg["aggro"] = float(cfg["aggro"]) * 1.5
			beast.set("_cfg", cfg)
			_boss = beast
		"bandit":
			var home := _island_at(target)
			for i in int(b.get("guards", 0)):
				var guard := Bandit.new()
				guard.style = "gunner" if i % 2 == 0 else "melee"
				guard.home = home
				guard.camp_center = target
				guard.global_position = target + Vector2.from_angle(TAU * i / 3.0) * 30.0
				guard.add_to_group("bandits")
				Game.world_root.add_child(guard)
			var chief := Bandit.new()
			chief.style = "melee"
			chief.home = home
			chief.camp_center = target
			chief.global_position = target + Vector2(0, 12)
			chief.set_meta("quest_boss", q["id"])
			chief.add_to_group("bandits")
			Game.world_root.add_child(chief)
			chief.scale = Vector2.ONE * 1.5
			chief.radius *= 1.5
			chief.max_hp = float(b["hp"])
			chief.hp = chief.max_hp
			_boss = chief


func _island_at(pos: Vector2) -> Island:
	var best: Island = null
	var best_d := INF
	for island in Game.islands_near(pos):
		var d := (island as Island).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = island
	return best


func _draw() -> void:
	var vp := get_viewport()
	var view := (vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()).grow(200.0)
	var bob := sin(_time * 3.0) * 3.0
	for node in get_tree().get_nodes_in_group("harbors"):
		var harbor := node as Harbor
		var mark := Quests.marker_at(harbor.harbor_name)
		if mark == "":
			continue
		var p := harbor.to_global(Vector2(Harbor.PIER_LENGTH * 0.5, 0)) + Vector2(0, -64 + bob) # above the harbor name
		if view.has_point(p):
			_mark(p, mark, 30)
	var boss := current_boss()
	if boss and not boss is EnemyShip and view.has_point(boss.global_position): # ships show their own name
		_tag(boss.global_position + Vector2(0, -38), _boss_name)
	if is_instance_valid(_treasure) and not _treasure.opened:
		_mark(_treasure.global_position + Vector2(0, -20 + bob), "X", 16)


## A big yellow "!" or "?" with a dark outline (also used by the map).
func _mark(p: Vector2, text: String, font_size: int) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := p - Vector2(w * 0.5, 0)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.15, 0.1, 0.0, 0.9))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, MARK_COLOR)


func _tag(p: Vector2, text: String) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string_outline(_font, p - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color(0, 0, 0, 0.8))
	draw_string(_font, p - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.45, 0.35))
