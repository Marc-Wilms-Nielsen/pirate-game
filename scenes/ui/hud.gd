extends CanvasLayer
## HUD: guld og forsyninger øverst til højre, skibets liv og kanoner nederst til venstre,
## kontekst-hjælp øverst til venstre, prompt nederst i midten og beskeder i højre side.

var _stats: Label
var _stat_row: Control
var _status: Label
var _prompt: Label
var _log: LogPanel
var _bars: Bars
var _fps: Label
var _quest: Label ## the main quest's current goal, under the stats in the top right


func _ready() -> void:
	_quest = _label(Vector2(250, 22), 8)
	_quest.size = Vector2(382, 12)
	_quest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	process_mode = Node.PROCESS_MODE_ALWAYS # opdateres også når menuer er åbne
	# (Tastevejledningen er fjernet fra skærmen – den findes under Esc → Styring)
	_stats = _label(Vector2(0, 6), 10)
	_stats.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.position = Vector2(640 - 8 - 300, 6)
	_stats.size = Vector2(300, 14)
	_status = _label(Vector2(8, 344), 9)
	_prompt = _label(Vector2(120, 318), 11)
	_prompt.size = Vector2(400, 16)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", UiTheme.ACCENT)
	_log = LogPanel.new()
	_log.position = Vector2(6, 196)
	_log.size = Vector2(360, 124)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log)
	_bars = Bars.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bars)
	Game.notification.connect(func(text: String, color: Color) -> void: _log.add_line(text, color, ""))
	Game.logged.connect(func(text: String, color: Color, icon: String) -> void: _log.add_line(text, color, icon))
	_stat_row = StatRow.new()
	_stat_row.position = Vector2(300, 3)
	_stat_row.size = Vector2(332, 16)
	_stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stat_row)
	var icons := StatusIcons.new()
	icons.position = Vector2(4, 3)
	icons.size = Vector2(300, 16)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icons)
	_fps = _label(Vector2(8, 36), 8)
	_fps.modulate = Color(0.7, 1.0, 0.7)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_log"):
		_log.expanded = not _log.expanded


func _process(_delta: float) -> void:
	_fps.visible = Settings.show_fps
	if Settings.show_fps:
		_fps.text = "FPS %d" % Engine.get_frames_per_second()
	var q := Quests.current()
	var goal := Quests.objective_text()
	_quest.text = "" if goal == "" else ("%s – %s" % [q["title"], goal] if not q.is_empty() else goal)
	var ship := get_tree().get_first_node_in_group("player_ship") as PlayerShip
	var player := get_tree().get_first_node_in_group("player_character") as PlayerCharacter
	_bars.ship = ship
	_bars.player = player
	_stats.text = ""
	_stat_row.queue_redraw()
	if ship == null:
		return

	_prompt.text = ""
	if player != null:
		_status.text = "Captain – %s" % ("on land" if player.on_land else "swimming")
		var node := player.nearby_resource()
		var shoal := player.nearby_shoal()
		var castle := player.nearby_castle()
		var saloon := player.nearby_saloon()
		if player.nearby_shop():
			_prompt.text = "F: Step into the %s" % Catalog.CITY["shop"]
		elif saloon != "":
			_prompt.text = "%s – singing and a squeezebox from inside" % saloon
		elif castle:
			var wait := Game.kingdom_wait(castle.kingdom_index)
			if wait > 0.0:
				_prompt.text = "%s is gathering new troops (%d min)" % [castle.kingdom()["name"], ceili(wait / 60.0)]
			else:
				_prompt.text = "F: Challenge the %s to a duel (%d soldiers)" % [castle.kingdom()["name"], Game.kingdom_garrison(castle.kingdom_index)]
		elif player.nearby_chest():
			_prompt.text = "F: Open the chest"
		elif shoal:
			_prompt.text = shoal.status_text()
		elif node and player.gather_progress() < 0.0:
			var missing := node.missing_tool()
			_prompt.text = "F: %s" % node.info()["verb"] if missing == "" else "%s – requires %s" % [node.info()["name"], missing.to_lower()]
		elif player.can_board():
			_prompt.text = "F: Go aboard"
		return

	var food_warning := "    HUNGRY" if ship.is_hungry() else ""
	_status.text = "%s    Sails: %s    Speed: %.1f knots    Anchor: %s%s" % [
		Game.active_ship()["name"], ship.get_sail_name(), ship.speed / 10.0,
		"dropped" if ship.anchored else "raised", food_warning]
	var target := ship.boardable_enemy()
	var ship_shoal := ship.nearby_shoal()
	if target:
		var c := BoardingChance.estimate(Game.crew, target)
		_prompt.text = "F: Board %s (%d vs %d men – about %d %% chance)" % [target.ship_name, Game.crew, target.crew, roundi(c * 100.0)]
	elif ship_shoal:
		_prompt.text = ship_shoal.status_text()
	elif Game.current_harbor:
		if ship.can_dock():
			_prompt.text = "F: Dock in %s" % Game.current_harbor.harbor_name
		else:
			_prompt.text = "Slow down to dock in %s" % Game.current_harbor.harbor_name
	elif ship.can_disembark():
		_prompt.text = "F: Jump overboard"


func _label(pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label


## Tegner livsbjælker og kanon-indikatorer.
class Bars extends Control:
	var ship: PlayerShip
	var player: PlayerCharacter

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		_draw_threat_arrows()
		if player != null:
			_bar(Vector2(8, 328), 120, player.hp / PlayerCharacter.MAX_HP, Color(0.85, 0.3, 0.3), "Health")
			_draw_weapon_bar()
			return
		if ship == null:
			return
		var ratio: float = ship.hp() / ship.stats["max_hp"]
		_bar(Vector2(8, 328), 140, ratio, Color(0.35, 0.75, 0.45), "Hull %d/%d" % [int(ship.hp()), int(ship.stats["max_hp"])])
		# Kanoner: Q (bagbord) og E (styrbord)
		var x := 160.0
		for side in ["left", "right"]:
			var key := "Q" if side == "left" else "E"
			var ready_ratio: float = 1.0 - ship.reload_left[side] / ship.stats["reload"]
			var col := Color(0.95, 0.8, 0.45) if ready_ratio >= 1.0 else Color(0.5, 0.5, 0.5)
			draw_rect(Rect2(x, 328, 34, 10), Color(0, 0, 0, 0.45))
			draw_rect(Rect2(x, 328, 34 * clampf(ready_ratio, 0.0, 1.0), 10), Color(col, 0.6))
			draw_string(font, Vector2(x + 3, 336.5), "%s x%d" % [key, ship.stats["cannons"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
			x += 38.0

	## Røde pile i skærmkanten peger mod pirater, der er uden for skærmen.
	func _draw_threat_arrows() -> void:
		var focus := player as Node2D if player != null else ship as Node2D
		if focus == null:
			return
		var to_screen := get_viewport().get_canvas_transform()
		var screen := Rect2(Vector2(14, 30), size - Vector2(28, 70))
		var center := screen.get_center()
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as EnemyShip
			if enemy.faction != "pirate" or enemy.global_position.distance_to(focus.global_position) > 1100.0:
				continue
			var p := to_screen * enemy.global_position
			if screen.has_point(p):
				continue
			var dir := (p - center).normalized()
			var t := minf(absf((screen.size.x * 0.5) / dir.x) if dir.x != 0.0 else INF,
				absf((screen.size.y * 0.5) / dir.y) if dir.y != 0.0 else INF)
			var edge := center + dir * t
			var side := dir.orthogonal()
			var alpha := 0.9 if enemy.state == "attack" else 0.5
			draw_colored_polygon(PackedVector2Array([edge + dir * 8.0, edge - dir * 4.0 + side * 6.0, edge - dir * 4.0 - side * 6.0]),
				Color(0.95, 0.25, 0.2, alpha))

	## Våbenbjælke nederst til højre: taster 1-8, valgt våben fremhævet, antal skud/granater.
	func _draw_weapon_bar() -> void:
		var font := ThemeDB.fallback_font
		var slot := Vector2(34, 22)
		var x0 := size.x - 8.0 - Catalog.WEAPON_ORDER.size() * (slot.x + 2.0)
		for i in Catalog.WEAPON_ORDER.size():
			var id: String = Catalog.WEAPON_ORDER[i]
			var w: Dictionary = Catalog.WEAPONS[id]
			var pos := Vector2(x0 + i * (slot.x + 2.0), size.y - slot.y - 8.0)
			var has := Game.has_weapon(id)
			var selected := Game.selected_weapon == id
			draw_rect(Rect2(pos, slot), Color(0.95, 0.8, 0.45, 0.85) if selected else Color(0, 0, 0, 0.45))
			var text_col := Color(0.1, 0.08, 0.05) if selected else (Color.WHITE if has else Color(1, 1, 1, 0.3))
			draw_string(font, pos + Vector2(2, 8), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, text_col)
			draw_string(font, pos + Vector2(2, 15), w["short"], HORIZONTAL_ALIGNMENT_LEFT, slot.x - 3.0, 7, text_col)
			var ammo := Game.weapon_ammo(id)
			if ammo >= 0 and (has or w["kind"] == "grenade"):
				draw_string(font, pos + Vector2(2, 21), "x%d" % ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, text_col)

	func _bar(pos: Vector2, width: float, ratio: float, color: Color, text: String) -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(pos, Vector2(width, 10)), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0.0, 1.0), 10)), color)
		draw_string(font, pos + Vector2(4, 8.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


## Hurtigt (og cachet) skøn over entringschancen til HUD-prompten.
class BoardingChance:
	static var _cache_key := ""
	static var _cache_value := 0.0

	static func estimate(ours: int, enemy: EnemyShip) -> float:
		var strength := 1.15 if enemy.faction == "pirate" else 0.7
		var key := "%d:%d:%s" % [ours, enemy.crew, enemy.faction]
		if key != _cache_key:
			_cache_key = key
			_cache_value = preload("res://scenes/ui/boarding_menu.gd").win_chance(ours, enemy.crew, strength, 150)
		return _cache_value


## Ur, vejr og et lille skjold, når du ligger i det fredelige strandvand.
class StatusIcons extends Control:
	var _safe_fade: float = 0.0

	func _process(delta: float) -> void:
		var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
		var safe := ship != null and Game.is_safe_water(ship.global_position) and get_tree().get_first_node_in_group("player_character") == null
		_safe_fade = move_toward(_safe_fade, 1.0 if safe else 0.0, delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var center := Vector2(12, 9)
		var day := 1.0 - Game.night
		if day > 0.5: # sol
			draw_circle(center, 4.0, Color(1.0, 0.85, 0.35), true, -1.0, true)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				draw_line(center + d * 5.5, center + d * 7.5, Color(1.0, 0.85, 0.35), 1.0, true)
		else: # måne
			draw_circle(center, 4.5, Color(0.9, 0.92, 1.0), true, -1.0, true)
			draw_circle(center + Vector2(2.2, -1.5), 4.0, Color(0.12, 0.15, 0.25), true, -1.0, true)
		var weather: Dictionary = WorldSky.WEATHERS.get(Game.weather, WorldSky.WEATHERS["clear"])
		var text := "%s  ·  %s" % [WorldSky.clock_text(Game.world_time), weather["name"]]
		draw_string(font, Vector2(24, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.95, 0.9, 0.9))
		if _safe_fade > 0.01:
			var a := _safe_fade
			var x := 24.0 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 14.0
			var s := Vector2(x, 9)
			var shield := PackedVector2Array([s + Vector2(-4, -4), s + Vector2(4, -4), s + Vector2(4, 0), s + Vector2(0, 5), s + Vector2(-4, 0)])
			draw_colored_polygon(shield, Color(0.45, 0.85, 0.75, a))
			draw_polyline(shield + PackedVector2Array([shield[0]]), Color(1, 1, 1, 0.8 * a), 0.8, true)
			draw_string(font, Vector2(x + 8, 13), "Peaceful shallows", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.95, 0.85, a))


## Guld, besætning, kugler, mad og last – med små ikoner, højrestillet.
class StatRow extends Control:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var entries := [
			["gold", _fmt(Game.gold)],
			["crew", "%d/%d" % [Game.crew, Game.max_crew()]],
			["cannonball", str(Game.cannonballs)],
			["food", str(Game.food)],
			["cargo", "%d/%d" % [Game.cargo_used(), Game.cargo_capacity()]],
		]
		var x := size.x
		for i in range(entries.size() - 1, -1, -1):
			var text: String = entries[i][1]
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			x -= w
			draw_string_outline(font, Vector2(x, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0, 0, 0, 0.5))
			draw_string(font, Vector2(x, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.97, 0.95, 0.9))
			x -= 14.0
			Icons.draw(self, entries[i][0], Vector2(x + 6.0, 8.0), 12.0)
			x -= 10.0

	static func _fmt(n: int) -> String:
		# 1000000 -> "1.000.000"
		var s := str(absi(n))
		var out := ""
		while s.length() > 3:
			out = "." + s.substr(s.length() - 3) + out
			s = s.substr(0, s.length() - 3)
		return ("-" if n < 0 else "") + s + out


## Loggen nederst til venstre: alt hvad du finder og hvad der sker, som et chatvindue.
## Linjerne falmer efter lidt tid. L viser hele loggen med baggrund.
class LogPanel extends Control:
	const MAX_LINES := 80
	const SHOW_TIME := 9.0
	const LINE_H := 11.0
	var expanded := false:
		set(value):
			expanded = value
			queue_redraw()
	var _lines: Array = [] ## [text, color, icon, time]
	var _time: float = 0.0

	func add_line(text: String, color: Color, icon: String) -> void:
		_lines.append([text, color, icon, _time])
		while _lines.size() > MAX_LINES:
			_lines.pop_front()
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		if not _lines.is_empty() and (expanded or _time - float(_lines[-1][3]) < SHOW_TIME + 2.0):
			queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var rows := int(size.y / LINE_H)
		if expanded:
			draw_rect(Rect2(Vector2(-2, -4), size + Vector2(4, 6)), Color(0.05, 0.08, 0.1, 0.55))
			draw_string(font, Vector2(2, -6), "Log (L)", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.MUTED)
		var count := mini(rows, _lines.size())
		for i in count:
			var line: Array = _lines[_lines.size() - count + i]
			var age: float = _time - float(line[3])
			var alpha := 1.0 if expanded else clampf(1.0 - (age - SHOW_TIME) / 2.0, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var y := size.y - (count - i - 1) * LINE_H - 2.0
			var x := 2.0
			if String(line[2]) != "":
				if alpha > 0.5:
					Icons.draw(self, line[2], Vector2(x + 5.0, y - 3.5), 9.0)
				x += 13.0
			var col: Color = line[1]
			col.a *= alpha
			var text: String = line[0]
			draw_string_outline(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - x, 8, 3, Color(0, 0, 0, 0.55 * alpha))
			draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - x, 8, col)
