extends Node
## The main quest line, "The Sun King's Crown" (autoload "Quests").
##
## One quest at a time, in the order of Catalog.QUESTS, with no timers:
##   "offer"  – the giver waits at a harbor; that harbor shows a yellow "!"
##   "active" – accepted; when the goal is met (is_ready), the hand-in harbor shows a "?"
## Docking at a harbor with a "!" or "?" opens the chat window (scenes/ui/quest_dialog.gd).
##
## Where things happen (harbors, camps, boss spots) is picked once from the generated world by
## resolve_spots() and saved, so the same world always gets the same places.

signal changed

var index: int = 0 ## current quest in Catalog.QUESTS; == size when the line is finished
var state: String = "offer"
var boss_down := false
var treasure_found := false
## Resolved places: "<quest id>.giver" / ".turn_in" -> harbor name,
## ".target" / ".island" / ".dig" -> world position (Vector2)
var spots: Dictionary = {}


func _ready() -> void:
	reset()
	Game.register_save_hooks(_save, _load)


func reset() -> void:
	index = 0
	state = "offer"
	boss_down = false
	treasure_found = false
	spots = {}
	changed.emit()


func current() -> Dictionary:
	return Catalog.QUESTS[index] if index < Catalog.QUESTS.size() else {}


func finished() -> bool:
	return index >= Catalog.QUESTS.size()


func giver_harbor(q: Dictionary) -> String:
	return spots.get(q["id"] + ".giver", "")


func turn_in_harbor(q: Dictionary) -> String:
	return spots.get(q["id"] + ".turn_in", giver_harbor(q))


func turn_in_person(q: Dictionary) -> String:
	return q.get("turn_in", q["giver"])


## True when the current quest's goal is met and it can be handed in.
func is_ready() -> bool:
	var q := current()
	if q.is_empty() or state != "active":
		return false
	match q["type"]:
		"gather":
			for id in q["items"]:
				if Game.cargo_count(id) < int(q["items"][id]):
					return false
			return true
		"delivery":
			return true
		"boss":
			return boss_down and (not q.get("treasure", false) or treasure_found)
	return false


## "!" where a quest waits, "?" where one can be handed in, "" elsewhere.
func marker_at(harbor_name: String) -> String:
	var q := current()
	if q.is_empty() or spots.is_empty():
		return ""
	if state == "offer" and harbor_name == giver_harbor(q):
		return "!"
	if is_ready() and harbor_name == turn_in_harbor(q):
		return "?"
	return ""


## What the chat window should show when docking at this harbor (empty = nothing to say).
func talk_at(harbor_name: String) -> Dictionary:
	var q := current()
	match marker_at(harbor_name):
		"!":
			var lines: Array = []
			for line in q["offer"]:
				lines.append((line as String) % turn_in_harbor(q) if "%s" in line else line)
			return {"mode": "offer", "person": q["giver"], "title": q["title"], "lines": lines, "goal": _goal_text(q)}
		"?":
			return {"mode": "turn_in", "person": turn_in_person(q), "title": q["title"], "lines": q["done"],
				"reward": reward_text(q)}
	return {}


func reward_text(q: Dictionary) -> String:
	var r: Dictionary = q["reward"]
	var faction := Game.faction_of(turn_in_harbor(q))
	return "Reward: %d gold, +%d reputation with the %s" % [int(r["gold"]), int(r["rep"]), Catalog.FACTIONS[faction]["short"]]


func accept() -> void:
	if state != "offer" or finished():
		return
	state = "active"
	boss_down = false
	treasure_found = false
	Game.notify("New quest: %s" % current()["title"], UiTheme.ACCENT)
	Sfx.play("click")
	changed.emit()


func complete() -> void:
	if not is_ready():
		return
	var q := current()
	if q["type"] == "gather":
		for id in q["items"]:
			Game.remove_item(id, int(q["items"][id]))
	var r: Dictionary = q["reward"]
	Game.add_gold(int(r["gold"]))
	Game.add_harbor_rep(turn_in_harbor(q), float(r["rep"]))
	Game.log_line("Quest complete: %s  (+%d gold)" % [q["title"], int(r["gold"])], UiTheme.ACCENT, "gold")
	Sfx.play("coin", 2.0)
	index += 1
	state = "offer"
	boss_down = false
	treasure_found = false
	if finished():
		Game.notify("You found the Crown of the Sun King. Your name is a legend on every sea!", UiTheme.ACCENT)
	else:
		Game.notify("Quest complete: %s. Next: talk to %s in %s" % [q["title"], person_name(current()["giver"]), giver_harbor(current())], UiTheme.ACCENT)
	changed.emit()
	Game.changed.emit()


func boss_defeated(quest_id: String) -> void:
	var q := current()
	if q.is_empty() or q["id"] != quest_id or state != "active" or boss_down:
		return
	boss_down = true
	if q.get("treasure", false):
		Game.notify("%s is sunk! Now go ashore and dig up the treasure." % q["boss"]["name"].capitalize(), UiTheme.ACCENT)
	else:
		Game.notify("%s is defeated! Return to %s in %s." % [q["boss"]["name"].capitalize(), person_name(turn_in_person(q)), turn_in_harbor(q)], UiTheme.ACCENT)
	changed.emit()


func treasure_opened() -> void:
	if current().get("treasure", false) and boss_down and not treasure_found:
		treasure_found = true
		Game.notify("The Crown of the Sun King! Bring it home to %s in %s." % [person_name(turn_in_person(current())), turn_in_harbor(current())], UiTheme.ACCENT)
		changed.emit()


func person_name(id: String) -> String:
	return Catalog.QUEST_PEOPLE[id]["name"]


## One line for the HUD: what to do right now.
func objective_text() -> String:
	var q := current()
	if q.is_empty():
		return "Quest line complete – you found the Sun King's Crown!"
	if spots.is_empty():
		return ""
	if state == "offer":
		return "Talk to %s in %s  (!)" % [person_name(q["giver"]), giver_harbor(q)]
	if is_ready():
		return "Return to %s in %s  (?)" % [person_name(turn_in_person(q)), turn_in_harbor(q)]
	return _goal_text(q)


func _goal_text(q: Dictionary) -> String:
	match q["type"]:
		"gather":
			var parts: Array[String] = []
			for id in q["items"]:
				parts.append("%s %d/%d" % [Game.item_name(id), mini(Game.cargo_count(id), int(q["items"][id])), int(q["items"][id])])
			return "Gather: " + ", ".join(parts)
		"delivery":
			return "Deliver to %s in %s" % [person_name(turn_in_person(q)), turn_in_harbor(q)]
		"boss":
			if boss_down and q.get("treasure", false):
				return "Dig up the treasure on the island (marked on your map)"
			return "Defeat %s (marked on your map)" % q["boss"]["name"]
	return ""


## Where the map should point right now (Vector2.INF = nowhere special).
func target_position() -> Vector2:
	var q := current()
	if q.is_empty() or state != "active":
		return Vector2.INF
	if is_ready() or q["type"] == "delivery":
		return harbor_position(turn_in_harbor(q))
	if q["type"] == "boss":
		if boss_down and q.get("treasure", false):
			return spots.get(q["id"] + ".dig", Vector2.INF)
		return spots.get(q["id"] + ".target", Vector2.INF)
	return Vector2.INF


func harbor_position(harbor_name: String) -> Vector2:
	var h := _harbor(harbor_name)
	return h.global_position if h else Vector2.INF


func _harbor(harbor_name: String) -> Harbor:
	for node in get_tree().get_nodes_in_group("harbors"):
		if (node as Harbor).harbor_name == harbor_name:
			return node as Harbor
	return null


# --- Picking places from the world --------------------------------------------

## Fills in any missing places for all quests. Called by QuestWorld once the world is built.
func resolve_spots() -> void:
	var before := spots.size()
	for q in Catalog.QUESTS:
		var id: String = q["id"]
		if not spots.has(id + ".giver"):
			spots[id + ".giver"] = _resolve_harbor(q["at"])
		if q.has("turn_in_at") and not spots.has(id + ".turn_in"):
			spots[id + ".turn_in"] = _resolve_harbor(q["turn_in_at"])
		if q.has("target") and not spots.has(id + ".target"):
			_resolve_target(id, q["target"])
	if spots.size() != before:
		changed.emit()


func _ref_pos(ref: String) -> Vector2:
	var harbor_name: String = Catalog.HARBOR_NAMES["free"][0] if ref == "start" else spots.get(ref, "")
	var p := harbor_position(harbor_name)
	return Vector2.ZERO if p == Vector2.INF else p


func _resolve_harbor(sel: Variant) -> String:
	if sel is String:
		return Catalog.HARBOR_NAMES["free"][0] if sel == "start" else String(spots.get(sel, ""))
	var d: Dictionary = sel
	var from := _ref_pos(d["near"])
	var used: Array = spots.values()
	var best := ""
	var best_score := INF
	for node in get_tree().get_nodes_in_group("harbors"):
		var h := node as Harbor
		if h.kind == "home" or Game.faction_of(h.harbor_name) != d["faction"] or h.harbor_name in used:
			continue
		var score := absf(h.global_position.distance_to(from) - float(d["dist"]))
		if score < best_score:
			best_score = score
			best = h.harbor_name
	return best


func _resolve_target(id: String, sel: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	if sel.has("sea"):
		var from := _ref_pos(sel["sea"])
		spots[id + ".target"] = _open_water(from, float(sel["dist"]), rng)
	elif sel.has("camp"):
		var from := _ref_pos(sel["camp"])
		var best := Vector2.ZERO
		var best_score := INF
		for node in get_tree().get_nodes_in_group("camps"):
			var p := (node as Node2D).global_position
			var score := absf(p.distance_to(from) - float(sel["dist"]))
			if score < best_score:
				best_score = score
				best = p
		spots[id + ".target"] = best
	elif sel.has("wild_mainland"):
		var from := _ref_pos(sel["wild_mainland"])
		var island := _nearest_island(from, func(i: Island) -> bool: return i.radius > 1000.0 and not _has_castle(i))
		if island:
			var angle := (from - island.global_position).angle()
			spots[id + ".island"] = island.global_position
			# In the jaguars' zone: well inside the coast, but not in the middle of the jungle
			spots[id + ".target"] = island.global_position + Vector2.from_angle(angle) * island.shore_radius(angle) * 0.55
	elif sel.has("islet"):
		var from := _ref_pos(sel["islet"])
		var dist := float(sel["dist"])
		var island := _nearest_island(from, func(i: Island) -> bool: return i.harbor_name == "" and i.radius > 90.0 and i.radius < 400.0,
			func(i: Island) -> float: return absf(i.global_position.distance_to(from) - dist))
		if island:
			var angle := rng.randf() * TAU
			spots[id + ".island"] = island.global_position
			spots[id + ".dig"] = island.global_position + Vector2.from_angle(angle + 1.0) * island.radius * 0.3
			# The boss waits just outside the island's lagoon
			spots[id + ".target"] = _open_water(island.global_position, island.radius * island.lagoon_size * 1.05, rng)


func _open_water(from: Vector2, dist: float, rng: RandomNumberGenerator) -> Vector2:
	var start := rng.randf() * TAU
	for grow in [1.0, 1.25, 1.5, 2.0]:
		for i in 24:
			var p: Vector2 = from + Vector2.from_angle(start + TAU * i / 24.0) * dist * float(grow)
			if Game.water_depth(p) >= 0.99 and not Game.is_land(p):
				return p
	return from + Vector2.from_angle(start) * dist


func _has_castle(island: Island) -> bool:
	for c in get_tree().get_nodes_in_group("castles"):
		if (c as Node2D).global_position.distance_to(island.global_position) < island.radius * 1.2:
			return true
	return false


func _nearest_island(from: Vector2, ok: Callable, score := Callable()) -> Island:
	var best: Island = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("islands"):
		var island := node as Island
		if not ok.call(island):
			continue
		var s: float = score.call(island) if score.is_valid() else island.global_position.distance_to(from)
		if s < best_score:
			best_score = s
			best = island
	return best


# --- Saving -------------------------------------------------------------------

func _save(data: Dictionary) -> void:
	data["quests"] = {"index": index, "state": state, "boss_down": boss_down, "treasure_found": treasure_found, "spots": spots}


func _load(data: Dictionary) -> void:
	var d: Dictionary = data.get("quests", {})
	if d.is_empty():
		return
	index = int(d.get("index", 0))
	state = d.get("state", "offer")
	boss_down = d.get("boss_down", false)
	treasure_found = d.get("treasure_found", false)
	spots = d.get("spots", {})
	changed.emit()
