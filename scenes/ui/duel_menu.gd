extends CanvasLayer
## Duel mod et kongerige: din besætning og du stormer mod slottets garnison.
## Kampen vises som en lille animeret slagmark. Hver runde er et terningkast (som ved entring),
## men du vælger en taktik mellem runderne, og dit eget udstyr giver en bonus.

signal closed

const MORALE_BREAK_CHANCE := 0.22
const RALLY_USES := 2
const ROUND_TIME := 1.7 ## sekunder pr. animeret runde
const TACTICS := {
	"storm": {"name": "Charge", "desc": "All-out attack: better odds, but more losses", "roll": 1.3, "our_loss": 1.5, "their_loss": 1.25},
	"hold": {"name": "Hold the line", "desc": "Careful: fewer losses on both sides", "roll": 0.95, "our_loss": 0.5, "their_loss": 0.7},
	"rally": {"name": "Captain's rally", "desc": "Raises morale: +20 % for 3 rounds, and nobody flees", "roll": 0.85, "our_loss": 1.0, "their_loss": 0.8},
}

var castle: Castle
var _kingdom: Dictionary = {}
var _kingdom_index: int = 0
var _theirs: int = 0
var _their_start: int = 0
var _our_start: int = 0
var _ours: int = 0 ## dine folk i duellen: din egen besætning + eskorteskibenes
var _pools: Array = [] ## [skibskonfiguration, folk ved start] for hvert eskorteskib
var _over := false
var _won := false
var _busy := false ## en runde er ved at blive animeret
var _auto := false ## "kæmp til enden"
var _rally_left: int = RALLY_USES
var _rally_rounds: int = 0
var _pending_tactic: String = ""
var _round_time: float = 0.0
var _round_applied := false
var _gate_pos := Vector2.ZERO

var _root: Control
var _title: Label
var _chance: Label
var _arena: Arena
var _log: VBoxContainer
var _buttons: HBoxContainer


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func open(target: Castle) -> void:
	castle = target
	_kingdom_index = target.kingdom_index
	_kingdom = target.kingdom()
	_gate_pos = target.gate_position()
	_theirs = Game.kingdom_garrison(_kingdom_index)
	_their_start = _theirs
	_pools = []
	_ours = Game.crew
	for cfg in Game.escort_configs():
		var n := int(cfg.get("crew", 0))
		if n > 0:
			_pools.append([cfg, n])
			_ours += n
	_our_start = _ours
	_over = false
	_won = false
	_busy = false
	_auto = false
	_rally_left = RALLY_USES
	_rally_rounds = 0
	visible = true
	get_tree().paused = true
	UiTheme.clear(_log)
	_title.text = "Duel against the %s" % _kingdom["name"]
	_arena.setup(_our_start, _their_start, _kingdom)
	_add_log("%s sends %d soldiers into the courtyard. Your %d men draw their sabers." % [_kingdom["king"], _theirs, _ours], UiTheme.ACCENT)
	if not _pools.is_empty():
		_add_log("%d of them come from your escort ships." % (_ours - Game.crew), UiTheme.GOOD)
	if _ours < 4:
		_add_log("You have very few men – consider hiring more in a harbor first.", UiTheme.BAD)
	_show_tactic_buttons()
	_update()
	Sfx.play("swing", -2.0)


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


## Fordel de overlevende tilbage på dit skib og eskorteskibene (i forhold til hvor mange hvert skib sendte).
func _settle_crew() -> void:
	var survivors := maxi(_ours, 0)
	var start := maxi(_our_start, 1)
	var given := 0
	for pool in _pools:
		var n := floori(float(pool[1]) * survivors / start)
		(pool[0] as Dictionary)["crew"] = n
		given += n
	Game.crew = maxi(survivors - given, 1)
	_pools = []
	_our_start = maxi(_ours, 1)
	Game.changed.emit()


## Kaptajnens bonus fra sværd og frakke (1.0 = startudstyr).
static func captain_bonus() -> float:
	var sword_damage := float(Game.sword().get("damage", 10.0))
	return 1.0 + maxf(sword_damage - 10.0, 0.0) / 60.0 + Game.gear_stat("armor") * 0.5


## Én runde. Returnerer [vores tab, deres tab].
static func duel_round(ours: int, theirs: int, their_strength: float, tactic: Dictionary, bonus: float) -> Array[int]:
	var a := (ours + 3.0) * bonus * float(tactic["roll"]) * randf_range(0.2, 1.8) # kaptajnen tæller som 3 mand
	var b := theirs * their_strength * randf_range(0.2, 1.8)
	var our_loss := 0
	var their_loss := 0
	if a >= b:
		their_loss = maxi(1, roundi(randf_range(0.1, 0.25) * theirs * float(tactic["their_loss"])))
		our_loss = 1 if randf() < 0.3 * float(tactic["our_loss"]) else 0
	else:
		our_loss = maxi(1, roundi(randf_range(0.1, 0.25) * ours * float(tactic["our_loss"])))
		their_loss = 1 if randf() < 0.3 * float(tactic["their_loss"]) else 0
	return [mini(our_loss, ours), mini(their_loss, theirs)]


## Anslået chance for at vinde med en bestemt taktik hele vejen.
static func win_chance(ours: int, theirs: int, their_strength: float, tactic: Dictionary, bonus: float, runs := 250) -> float:
	if theirs <= 0:
		return 1.0
	if ours <= 0:
		return 0.0
	var wins := 0
	for _r in runs:
		var o := ours
		var t := theirs
		for _guard in 200:
			var losses := duel_round(o, t, their_strength, tactic, bonus)
			o -= losses[0]
			t -= losses[1]
			if t <= 0 or (t < theirs * 0.5 and randf() < MORALE_BREAK_CHANCE):
				wins += 1
				break
			if o <= 0 or (o < ours * 0.5 and randf() < MORALE_BREAK_CHANCE):
				break
	return float(wins) / runs


func _process(delta: float) -> void:
	if not visible or not _busy:
		return
	var speed := 2.5 if _auto else 1.0
	_round_time += delta * speed
	_arena.round_progress = clampf(_round_time / ROUND_TIME, 0.0, 1.0)
	if not _round_applied and _round_time >= ROUND_TIME * 0.45:
		_round_applied = true
		_resolve_round()
	if _round_time >= ROUND_TIME:
		_busy = false
		_arena.round_progress = -1.0
		if _over:
			return
		if _auto:
			_start_round(_pending_tactic)
		else:
			_show_tactic_buttons()


func _start_round(tactic_id: String) -> void:
	if _over or _busy:
		return
	if tactic_id == "rally":
		if _rally_left <= 0:
			tactic_id = "hold"
		else:
			_rally_left -= 1
			_rally_rounds = 3
			_arena.shout()
			_add_log("\"For gold and glory!\" – your men roar back.", UiTheme.ACCENT)
	_pending_tactic = tactic_id
	_busy = true
	_round_time = 0.0
	_round_applied = false
	_arena.round_progress = 0.0
	_arena.tactic = tactic_id
	_buttons_set([UiTheme.button("Stop" if _auto else "The battle rages ...", func() -> void: _auto = false, _auto)])
	Sfx.play("swing", -4.0)


func _resolve_round() -> void:
	var tactic: Dictionary = TACTICS[_pending_tactic].duplicate()
	if _rally_rounds > 0:
		tactic["roll"] = float(tactic["roll"]) * 1.2
	var losses := duel_round(_ours, _theirs, float(_kingdom["strength"]), tactic, captain_bonus())
	_ours -= losses[0]
	_theirs -= losses[1]
	_arena.casualties(losses[0], losses[1], _ours, _theirs)
	Sfx.play("swing", -3.0)
	Sfx.play("wood_hit", -10.0)
	if losses[0] > 0 or losses[1] > 0:
		Sfx.play("hurt", -8.0)
	if losses[1] > losses[0]:
		_add_log("Your men break through! %d soldiers fall." % losses[1], UiTheme.GOOD)
	elif losses[0] > 0:
		_add_log("The garrison holds – you lose %d men." % losses[0], UiTheme.BAD)
	else:
		_add_log("Steel on steel, but nobody yields.", UiTheme.MUTED)
	var rallied := _rally_rounds > 0
	_rally_rounds = maxi(_rally_rounds - 1, 0)
	if _theirs > 0 and _theirs < _their_start * 0.5 and randf() < MORALE_BREAK_CHANCE:
		_add_log("The soldiers drop their spears and flee into the castle!", UiTheme.GOOD)
		_theirs = 0
		_arena.casualties(0, 0, _ours, 0)
	elif not rallied and _ours > 0 and _ours < _our_start * 0.5 and randf() < MORALE_BREAK_CHANCE:
		_add_log("Your men lose heart and fall back!", UiTheme.BAD)
		_defeat(false)
	Game.changed.emit()
	if _theirs <= 0:
		_victory()
	elif _ours <= 0:
		_defeat(true)
	_update()


func _victory() -> void:
	if _over:
		return
	_over = true
	_won = true
	_auto = false
	_arena.winner = 1
	var id: String = _kingdom["id"]
	Game.kingdom_wins[id] = int(Game.kingdom_wins.get(id, 0)) + 1
	Game.kingdom_cooldown(_kingdom_index)
	_settle_crew()
	_add_log("%s surrenders! The treasury is opened to you." % _kingdom["king"], UiTheme.ACCENT)
	_buttons_set([UiTheme.button("Take the treasury's loot", _take_loot)])
	Game.save_game()


func _take_loot() -> void:
	var rolls := int(_kingdom["loot_rolls"]) + floori(float(Game.kingdom_wins.get(_kingdom["id"], 1)) / 3.0)
	for i in rolls:
		Game.give_loot("kingdom_treasury", _gate_pos + Vector2(0, -16 * i))
	# Nogle soldater vil hellere sejle med en sejrrig kaptajn
	var volunteers := mini(randi_range(1, 4), Game.max_crew() - Game.crew)
	if volunteers > 0:
		Game.crew += volunteers
		Game.notify("%d of the king's soldiers join your crew" % volunteers, UiTheme.GOOD)
	Game.notify("You defeated the %s! They will gather new troops in %d minutes." % [_kingdom["name"], int(Catalog.DUEL_COOLDOWN_MIN)], UiTheme.ACCENT)
	Game.changed.emit()
	close()


func _defeat(wiped_out: bool) -> void:
	if _over:
		return
	_over = true
	_auto = false
	_arena.winner = -1
	if wiped_out:
		_ours = 0
	_settle_crew()
	var lost_gold := int(Game.gold * 0.1)
	Game.gold -= lost_gold
	# Et nederlag giver kongeriget en kortere pause
	Game.kingdom_ready_at[_kingdom["id"]] = Time.get_unix_time_from_system() + 5.0 * 60.0
	Game.changed.emit()
	var text := "Your crew is beaten. You and one sailor escape through the gate." if wiped_out else "The duel is lost – you retreat with %d men." % _ours
	if lost_gold > 0:
		text += " The crown demands a fine of %d gold." % lost_gold
	_add_log(text, UiTheme.BAD)
	_buttons_set([UiTheme.button("Leave the courtyard", close)])


func _surrender() -> void:
	var lost := mini(randi_range(1, 2), maxi(_ours - 1, 0))
	_ours -= lost
	_settle_crew()
	Game.changed.emit()
	Game.notify("You withdrew from the duel (-%d men)" % lost, UiTheme.BAD)
	close()


func _update() -> void:
	_arena.ours = _ours
	_arena.theirs = _theirs
	if _over:
		_chance.text = "Victory!" if _won else "Defeat"
		_chance.add_theme_color_override("font_color", UiTheme.GOOD if _won else UiTheme.BAD)
		return
	var bonus := captain_bonus()
	var c := win_chance(_ours, _theirs, float(_kingdom["strength"]), TACTICS["storm"], bonus, 150)
	var c2 := win_chance(_ours, _theirs, float(_kingdom["strength"]), TACTICS["hold"], bonus, 150)
	_chance.text = "Chance of victory: about %d %% (charge) / %d %% (careful)    Gear bonus: +%d %%" % [
		roundi(c * 100.0), roundi(c2 * 100.0), roundi((bonus - 1.0) * 100.0)]
	var best := maxf(c, c2)
	_chance.add_theme_color_override("font_color", UiTheme.GOOD if best >= 0.6 else (UiTheme.ACCENT if best >= 0.35 else UiTheme.BAD))


func _add_log(text: String, color: Color) -> void:
	_log.add_child(UiTheme.label(text, 8, color))
	while _log.get_child_count() > 4:
		var first := _log.get_child(0)
		_log.remove_child(first)
		first.queue_free()


func _show_tactic_buttons() -> void:
	var list: Array = []
	for id in ["storm", "hold", "rally"]:
		var t: Dictionary = TACTICS[id]
		var text: String = t["name"]
		var enabled := true
		if id == "rally":
			text += " (%d)" % _rally_left
			enabled = _rally_left > 0
		var b := UiTheme.button(text, _start_round.bind(id), enabled)
		b.tooltip_text = t["desc"]
		list.append(b)
	list.append(UiTheme.button("Fight to the end", func() -> void:
		_auto = true
		_start_round("storm")))
	list.append(UiTheme.button("Withdraw", _surrender))
	_buttons_set(list)


func _buttons_set(list: Array) -> void:
	UiTheme.clear(_buttons)
	for b in list:
		_buttons.add_child(b)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.make()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 14)
	panel.size = Vector2(560, 332)
	_root.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_title = UiTheme.label("", 14, UiTheme.ACCENT)
	vbox.add_child(_title)
	_arena = Arena.new()
	_arena.custom_minimum_size = Vector2(540, 180)
	vbox.add_child(_arena)
	_chance = UiTheme.label("", 9)
	vbox.add_child(_chance)
	_log = VBoxContainer.new()
	_log.custom_minimum_size = Vector2(0, 52)
	_log.add_theme_constant_override("separation", 0)
	vbox.add_child(_log)
	_buttons = HBoxContainer.new()
	vbox.add_child(_buttons)


## Den animerede slagmark, set fra siden: slotsmur bagved, din besætning til venstre,
## garnisonen til højre. Hver runde stormer de mod midten, støder sammen og trækker sig.
class Arena extends Control:
	const MAX_FIGURES := 22
	const W := 540.0
	var _our_start: int = 1
	var _their_start: int = 1
	var ours: int = 0
	var theirs: int = 0
	var round_progress: float = -1.0 ## 0..1 under en runde, -1 mellem runder
	var tactic: String = "storm"
	var winner: int = 0 ## 1 = du vandt, -1 = du tabte
	var _kingdom: Dictionary = {}
	var _our_figs: Array = []
	var _their_figs: Array = []
	var _sparks: Array = [] ## [pos, vel, life]
	var _dust: Array = [] ## [pos, size, life]
	var _time: float = 0.0
	var _shout: float = 0.0
	var _our_colors := [Color(0.85, 0.85, 0.88), Color(0.75, 0.2, 0.2), Color(0.25, 0.35, 0.65), Color(0.85, 0.7, 0.35), Color(0.35, 0.55, 0.35)]

	func _ready() -> void:
		clip_contents = true

	func setup(our_men: int, their_men: int, kingdom: Dictionary) -> void:
		_kingdom = kingdom
		_our_start = maxi(our_men, 1)
		_their_start = maxi(their_men, 1)
		winner = 0
		round_progress = -1.0
		_sparks.clear()
		_dust.clear()
		_our_figs = _make_figures(our_men, true)
		_their_figs = _make_figures(their_men, false)

	func _make_figures(men: int, left: bool) -> Array:
		var figs: Array = []
		var count := clampi(men, 1, MAX_FIGURES)
		for i in count:
			var row := i % 3
			var col := floori(i / 3.0)
			var x := 70.0 + col * 17.0 + row * 6.0
			figs.append({
				"home": Vector2(x if left else W - x, 118.0 + row * 17.0),
				"alive": true, "fall": 0.0, "phase": randf() * TAU,
				"color": _our_colors[i % _our_colors.size()],
				"bandana": randf() < 0.5,
			})
		if left: # kaptajnen står forrest
			figs.insert(0, {"home": Vector2(52.0, 134.0), "alive": true, "fall": 0.0, "phase": 0.0, "captain": true})
		return figs

	func shout() -> void:
		_shout = 1.2

	## Fjern figurer så antallet passer til de overlevende.
	func casualties(our_loss: int, their_loss: int, our_left: int, their_left: int) -> void:
		_kill_to(_our_figs, our_left, _our_start)
		_kill_to(_their_figs, their_left, _their_start)
		var clash := Vector2(W * 0.5, 135.0)
		for i in 10 + (our_loss + their_loss) * 3:
			_sparks.append([clash + Vector2(randf_range(-40, 40), randf_range(-25, 20)), Vector2.from_angle(randf() * TAU) * randf_range(30, 90), randf_range(0.2, 0.5)])
		for i in 6:
			_dust.append([clash + Vector2(randf_range(-60, 60), randf_range(5, 35)), randf_range(5, 11), 1.0])

	func _kill_to(figs: Array, men_left: int, start_men: int) -> void:
		var soldiers: Array = figs.filter(func(f: Dictionary) -> bool: return not f.get("captain", false))
		var wanted := 0
		if men_left > 0:
			wanted = clampi(ceili(float(men_left) / float(start_men) * soldiers.size()), 1, soldiers.size())
		var alive: Array = soldiers.filter(func(f: Dictionary) -> bool: return f["alive"])
		alive.shuffle()
		for i in maxi(alive.size() - wanted, 0):
			alive[i]["alive"] = false

	func _process(delta: float) -> void:
		_time += delta
		_shout = maxf(_shout - delta, 0.0)
		for f in _our_figs + _their_figs:
			if not f["alive"]:
				f["fall"] = minf(f["fall"] + delta * 3.0, 1.0)
		for s in _sparks:
			s[0] += s[1] * delta
			s[1].y += 120.0 * delta
			s[2] -= delta
		_sparks = _sparks.filter(func(s: Array) -> bool: return s[2] > 0.0)
		for d in _dust:
			d[1] += delta * 8.0
			d[2] -= delta * 1.2
		_dust = _dust.filter(func(d: Array) -> bool: return d[2] > 0.0)
		queue_redraw()

	## Hvor langt figurerne er løbet frem mod midten (0 = hjemme, 1 = i kamp).
	func _advance() -> float:
		if round_progress < 0.0:
			return 0.0
		var p := round_progress
		if p < 0.35:
			return smoothstep(0.0, 0.35, p)
		if p < 0.7:
			return 1.0
		return 1.0 - smoothstep(0.7, 1.0, p)

	func _draw() -> void:
		var k_col: Color = _kingdom.get("color", Color(0.6, 0.2, 0.2))
		var k_acc: Color = _kingdom.get("accent", Color(0.95, 0.8, 0.3))
		# Himmel og slot
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.75, 0.9))
		draw_rect(Rect2(0, 60, size.x, 40), Color(0.68, 0.64, 0.56))
		for i in int(size.x / 14.0) + 1:
			draw_rect(Rect2(i * 14.0, 52, 8, 9), Color(0.68, 0.64, 0.56))
		for t in [70.0, size.x * 0.5, size.x - 70.0]:
			draw_rect(Rect2(t - 18, 38, 36, 62), Color(0.62, 0.58, 0.5))
			draw_colored_polygon(PackedVector2Array([Vector2(t - 22, 40), Vector2(t, 18), Vector2(t + 22, 40)]), k_col.darkened(0.2))
			var wave := sin(_time * 4.0 + t) * 2.0
			draw_line(Vector2(t, 18), Vector2(t, 4), Color(0.3, 0.2, 0.15), 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(t, 4), Vector2(t + 14, 6 + wave), Vector2(t, 10)]), k_col)
		# Porten
		var gx := size.x * 0.5
		draw_rect(Rect2(gx - 12, 70, 24, 30), Color(0.3, 0.22, 0.15))
		draw_circle(Vector2(gx, 70), 12.0, Color(0.3, 0.22, 0.15), true, -1.0, true)
		# Jord
		draw_rect(Rect2(0, 100, size.x, size.y - 100), Color(0.72, 0.62, 0.45))
		for i in 30:
			var p := Vector2(fmod(i * 97.3, size.x), 104.0 + fmod(i * 53.1, size.y - 108.0))
			draw_circle(p, 1.2, Color(0.62, 0.52, 0.38), true, -1.0, true)
		# Støv bag figurerne
		for d in _dust:
			draw_circle(d[0], d[1], Color(0.85, 0.78, 0.65, 0.5 * d[2]), true, -1.0, true)
		# Figurer – bagerste række først
		var adv := _advance()
		var all: Array = []
		for f in _our_figs:
			all.append([f, true])
		for f in _their_figs:
			all.append([f, false])
		all.sort_custom(func(a: Array, b: Array) -> bool: return a[0]["home"].y < b[0]["home"].y)
		for entry in all:
			_draw_figure(entry[0], entry[1], adv, k_col, k_acc)
		for s in _sparks:
			var pos: Vector2 = s[0]
			var vel: Vector2 = s[1]
			draw_line(pos, pos - vel.normalized() * 3.0, Color(1.0, 0.9, 0.45, clampf(s[2] * 3.0, 0.0, 1.0)), 1.2, true)
		if _shout > 0.0:
			var cap: Dictionary = _our_figs[0]
			draw_string(ThemeDB.fallback_font, cap["home"] + Vector2(-10, -34), "Hurrah!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.95, 0.6, minf(_shout, 1.0)))
		if winner != 0:
			var text := "VICTORY!" if winner > 0 else "DEFEAT"
			draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 40, 48), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiTheme.ACCENT if winner > 0 else UiTheme.BAD)

	func _draw_figure(f: Dictionary, left: bool, adv: float, k_col: Color, k_acc: Color) -> void:
		var dir := 1.0 if left else -1.0
		var home: Vector2 = f["home"]
		var front := W * 0.5 - dir * (12.0 + fmod(home.x, 23.0))
		var pos := home
		var fighting: bool = f["alive"] and adv > 0.0
		if fighting:
			var reach := adv
			if tactic == "hold" and left:
				reach *= 0.55
			pos.x = lerpf(home.x, front, reach)
		var bob := 0.0
		var swing := 0.0
		if f["alive"]:
			if adv > 0.0 and adv < 1.0:
				bob = absf(sin(_time * 14.0 + f["phase"])) * -2.0 # løber
			elif adv >= 1.0:
				swing = sin(_time * 12.0 + f["phase"]) # fægter
				pos.x += sin(_time * 7.0 + f["phase"]) * 1.5
			else:
				bob = sin(_time * 2.0 + f["phase"]) * 0.6
		var captain: bool = f.get("captain", false)
		var s := 1.35 if captain else 1.0
		# Faldne figurer ligger ned og falmer
		var fall: float = f["fall"]
		var alpha := 1.0 - fall * 0.55
		var base := pos + Vector2(0, bob)
		draw_set_transform(base, -dir * fall * PI * 0.5, Vector2(s, s))
		draw_circle(Vector2(0, 1), 5.0, Color(0, 0, 0, 0.15 * (1.0 - fall)), true, -1.0, true)
		# Ben
		var step := sin(_time * 14.0 + f["phase"]) * 3.0 if (adv > 0.0 and adv < 1.0 and f["alive"]) else 0.0
		var leg_col := Color(0.25, 0.2, 0.18, alpha)
		draw_line(Vector2(-1.5, -6), Vector2(-1.5 + step, 0), leg_col, 1.8, true)
		draw_line(Vector2(1.5, -6), Vector2(1.5 - step, 0), leg_col, 1.8, true)
		# Krop
		var body_col: Color
		var trim: Color
		if captain:
			var coat: Dictionary = Catalog.GEAR[Game.equipped.get("coat", "shirt")]["look"]
			body_col = coat["color"]
			trim = coat.get("accent", body_col.darkened(0.3))
		elif left:
			body_col = f["color"]
			trim = body_col.darkened(0.3)
		else:
			body_col = k_col
			trim = k_acc
		draw_rect(Rect2(-3.5, -14, 7, 9), Color(body_col, alpha))
		draw_line(Vector2(0, -14), Vector2(0, -5), Color(trim, alpha), 1.0)
		if left and not captain and (f["color"] as Color).r > 0.8 and (f["color"] as Color).g > 0.8:
			for y in [-12.0, -9.0, -6.5]: # stribet trøje
				draw_line(Vector2(-3.5, y), Vector2(3.5, y), Color(0.2, 0.3, 0.6, alpha), 1.0)
		# Hoved
		draw_circle(Vector2(0, -17), 3.2, Color(0.95, 0.78, 0.6, alpha), true, -1.0, true)
		if captain:
			var hat: Dictionary = Catalog.GEAR[Game.equipped.get("hat", "tricorn")]["look"]
			var hc: Color = hat["color"]
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -19), Vector2(0, -24), Vector2(6, -19), Vector2(0, -20)]), Color(hc, alpha))
			if hat.has("accent"):
				draw_line(Vector2(-2, -22), Vector2(-6 * dir, -27), Color(hat["accent"], alpha), 1.4, true)
		elif left:
			if f["bandana"]:
				draw_rect(Rect2(-3.3, -20.5, 6.6, 2.5), Color(0.8, 0.2, 0.2, alpha))
		else:
			draw_circle(Vector2(0, -18.5), 3.3, Color(0.78, 0.8, 0.85, alpha), true, -1.0, true) # hjelm
			draw_rect(Rect2(-4.2, -18, 8.4, 1.2), Color(0.6, 0.62, 0.68, alpha))
		draw_circle(Vector2(dir * 1.4, -17.3), 0.5, Color(0.1, 0.1, 0.1, alpha), true, -1.0, true)
		# Våben
		var arm := Vector2(dir * 3.5, -12)
		if left:
			var angle := -0.6 + swing * 1.1
			var wdir := Vector2(dir * cos(angle), sin(angle))
			if captain:
				WeaponArt.draw(self, Game.sword()["look"], arm, wdir, 0.9)
			else:
				var tip := arm + wdir * 9.0
				draw_line(arm, tip, Color(0.85, 0.87, 0.9, alpha), 1.3, true)
				draw_line(arm + Vector2(0, -1.5), arm + Vector2(0, 1.5), Color(0.6, 0.45, 0.2, alpha), 1.2)
		else:
			var thrust := swing * 3.0
			draw_line(Vector2(dir * 2.0 - dir * 6.0 + thrust * dir, -13), Vector2(dir * 14.0 + thrust * dir, -15), Color(0.5, 0.35, 0.2, alpha), 1.1, true) # spyd
			draw_colored_polygon(PackedVector2Array([Vector2(dir * 14.0 + thrust * dir, -16.5), Vector2(dir * 18.0 + thrust * dir, -15.2), Vector2(dir * 14.0 + thrust * dir, -13.8)]), Color(0.85, 0.87, 0.9, alpha))
			draw_circle(Vector2(-dir * 3.0, -10), 3.0, Color(k_acc, alpha), true, -1.0, true) # skjold
			draw_circle(Vector2(-dir * 3.0, -10), 1.4, Color(k_col.darkened(0.2), alpha), true, -1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
