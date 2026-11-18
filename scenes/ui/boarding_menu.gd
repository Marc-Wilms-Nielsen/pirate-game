extends CanvasLayer
## Entring: et kampskærmbillede hvor din besætning kæmper mod fjendens.
## Hver runde er et terningkast vægtet efter antal folk. Pirater kæmper hårdere end handelsfolk.
## Vinder du, kan du plyndre skibet eller tage det som prise.

signal closed

const PIRATE_STRENGTH := 1.15
const MERCHANT_STRENGTH := 0.7
const PRIZE_CREW := 2 ## sømænd der sejler et erobret skib i havn
const MORALE_BREAK_CHANCE := 0.25 ## chance pr. runde for at give op, når over halvdelen er faldet

var enemy: EnemyShip
var _their_crew: int = 0
var _their_start: int = 0
var _our_start: int = 0
var _over := false
var defending := false ## true når piraterne entrer dig
# Kopier af fjendens data, så menuen virker selv hvis skibet forsvinder imens
var _faction: String = "merchant"
var _type_name: String = "" ## skibets navn, f.eks. "The Black Gull"
var _class_name: String = "" ## skibstypen, f.eks. "Brig"
var _config: Dictionary = {}
var _last_pos := Vector2.ZERO

var _root: Control
var _title: Label
var _chance: Label
var _crew_view: CrewView
var _log: VBoxContainer
var _buttons: HBoxContainer


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func open(target: EnemyShip, is_defending := false) -> void:
	enemy = target
	defending = is_defending
	_faction = target.faction
	_type_name = target.ship_name if target.ship_name != "" else target.type_name()
	_class_name = target.type_name()
	_config = target.config.duplicate(true)
	_last_pos = target.global_position
	_their_crew = target.crew
	_their_start = target.crew
	_our_start = Game.crew
	_over = false
	visible = true
	get_tree().paused = true
	UiTheme.clear(_log)
	var who := "pirates" if _faction == "pirate" else "merchant sailors"
	if defending:
		_add_log("Grappling hooks! %d pirates storm your deck – your %d men fight back." % [_their_crew, Game.crew], UiTheme.BAD)
		_title.text = "You are being boarded by %s! (%s)" % [_type_name, _class_name]
	else:
		_add_log("The grappling hooks bite! Your %d men charge %d %s." % [Game.crew, _their_crew, who], UiTheme.ACCENT)
		_title.text = "Boarding: %s (%s %s)" % [_type_name, "pirate" if _faction == "pirate" else "merchant", _class_name.to_lower()]
	_show_fight_buttons()
	_update()
	Sfx.play("swing", -2.0)


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _strength() -> float:
	return PIRATE_STRENGTH if _faction == "pirate" else MERCHANT_STRENGTH


func _enemy_ok() -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion()


func _set_enemy_state(new_state: String) -> void:
	if _enemy_ok():
		enemy.state = new_state


func _remove_enemy() -> void:
	if _enemy_ok():
		_last_pos = enemy.global_position
		enemy.queue_free()


## Én kamprunde. Returnerer [vores tab, deres tab].
## Styrken er antal folk ganget med et terningkast – så flere folk hjælper meget, men intet er sikkert.
static func fight_round(ours: int, theirs: int, their_strength: float) -> Array[int]:
	var a := ours * randf_range(0.2, 1.8)
	var b := theirs * their_strength * randf_range(0.2, 1.8)
	var our_loss := 0
	var their_loss := 0
	if a >= b:
		their_loss = maxi(1, roundi(randf_range(0.1, 0.25) * theirs))
		our_loss = 1 if randf() < 0.3 else 0
	else:
		our_loss = maxi(1, roundi(randf_range(0.1, 0.25) * ours))
		their_loss = 1 if randf() < 0.3 else 0
	return [mini(our_loss, ours), mini(their_loss, theirs)]


## Har en side mistet over halvdelen, kan den miste modet og give op.
static func loses_heart(current: int, start: int) -> bool:
	return current > 0 and current < start * 0.5 and randf() < MORALE_BREAK_CHANCE


## Anslået chance for at vinde (simulerer kampen mange gange).
static func win_chance(ours: int, theirs: int, their_strength: float, runs := 300) -> float:
	if theirs <= 0:
		return 1.0
	if ours <= 0:
		return 0.0
	var wins := 0
	for r in runs:
		var o := ours
		var t := theirs
		while true:
			var losses := fight_round(o, t, their_strength)
			o -= losses[0]
			t -= losses[1]
			if t <= 0 or loses_heart(t, theirs):
				wins += 1
				break
			if o <= 0 or loses_heart(o, ours):
				break
	return float(wins) / runs


func _fight_once() -> void:
	if _over:
		return
	var losses := fight_round(Game.crew, _their_crew, _strength())
	Game.crew -= losses[0]
	_their_crew -= losses[1]
	_crew_view.hit(losses[0] > 0, losses[1] > 0)
	if losses[1] > losses[0]:
		_add_log("Your men drive them back! The enemy loses %d men." % losses[1], UiTheme.GOOD)
	elif losses[0] > 0:
		_add_log("The enemy holds – you lose %d men." % losses[0], UiTheme.BAD)
	else:
		_add_log("Blades clash, but nobody falls.", UiTheme.MUTED)
	Sfx.play("swing", -4.0)
	if losses[0] > 0 or losses[1] > 0:
		Sfx.play("hurt", -8.0)
	if loses_heart(_their_crew, _their_start):
		_add_log("The enemy loses heart and throws down their weapons!", UiTheme.GOOD)
		_their_crew = 0
	elif loses_heart(Game.crew, _our_start):
		_add_log("Your men lose heart and flee back aboard!", UiTheme.BAD)
		_defeat(false)
	Game.changed.emit()
	_check_end()
	_update()


func _fight_to_end() -> void:
	var guard := 0
	while not _over and guard < 200:
		_fight_once()
		guard += 1


func _retreat() -> void:
	var lost := mini(randi_range(1, 2), maxi(Game.crew - 1, 0))
	Game.crew -= lost
	Game.changed.emit()
	Game.notify("You cut the grappling lines and pulled away (-%d men)" % lost, UiTheme.BAD)
	_set_enemy_state("attack" if _faction == "pirate" else "flee")
	close()


func _check_end() -> void:
	if _their_crew <= 0:
		_over = true
		_add_log("The enemy surrenders! The ship is yours.", UiTheme.ACCENT)
		_show_victory_buttons()
	elif Game.crew <= 0:
		_defeat(true)


func _defeat(wiped_out: bool) -> void:
	if _over:
		return
	_over = true
	if wiped_out:
		Game.crew = 1
	var lost_gold := 0
	if _faction == "pirate":
		lost_gold = int(Game.gold * 0.15)
		Game.gold -= lost_gold
	if defending:
		# Piraterne tager også en del af lasten
		for id in Game.cargo.keys():
			var lose := int(ceil(Game.cargo[id] * 0.25))
			if lose > 0:
				Game.remove_item(id, lose)
	Game.changed.emit()
	var text := "Your crew is beaten. Only you and one sailor make it back aboard." if wiped_out else "The fight is lost – you escape with %d men." % Game.crew
	if lost_gold > 0:
		text += " The pirates took %d gold." % lost_gold
	_add_log(text, UiTheme.BAD)
	_set_enemy_state("flee" if _faction == "merchant" else "wander")
	_buttons_set([UiTheme.button("Back to the ship", close)])


func _plunder() -> void:
	var table := "merchant_wreck" if _faction == "merchant" else "pirate_wreck"
	var pos := enemy.global_position if _enemy_ok() else _last_pos
	Game.give_loot(table, pos)
	Game.give_loot(table, pos + Vector2(0, -30))
	_maybe_recruit()
	if _enemy_ok():
		enemy.surrender()
	Game.notify("You plundered %s and let the crew sail on." % _type_name, UiTheme.GOOD)
	close()


func _take_in_tow() -> void:
	var prize := _config.duplicate(true)
	prize["name"] = _type_name
	prize["hp"] = Game.ship_stats(prize)["max_hp"] * 0.5
	Game.towed.append(prize)
	Game.changed.emit()
	_remove_enemy()
	Game.notify("%s is in tow – sell it at a shipyard for about %d gold." % [_type_name, Game.towed_sell_price(prize)], UiTheme.GOOD)
	Game.popup("In tow!", _last_pos, UiTheme.ACCENT)
	close()


func _take_prize() -> void:
	var prize := _config.duplicate(true)
	prize["name"] = _type_name
	prize["hp"] = Game.ship_stats(prize)["max_hp"] * 0.5
	prize["decorations"] = {}
	Game.owned_ships.append(prize)
	Game.crew -= mini(PRIZE_CREW, maxi(Game.crew - 1, 0))
	Game.changed.emit()
	_remove_enemy()
	Game.notify("%s is yours! A prize crew sails it to the shipyard – find it under 'Your ships'." % _type_name, UiTheme.GOOD)
	Game.popup("Captured!", _last_pos, UiTheme.ACCENT)
	close()


## Nogle af de overgivne sømænd vil gerne være pirater.
func _maybe_recruit() -> void:
	var room := Game.max_crew() - Game.crew
	var volunteers := mini(randi_range(0, 2), room)
	if volunteers > 0:
		Game.crew += volunteers
		Game.notify("%d of the enemy's men join your crew" % volunteers, UiTheme.GOOD)


func _update() -> void:
	_crew_view.ours = Game.crew
	_crew_view.theirs = _their_crew
	_crew_view.our_start = _our_start
	_crew_view.their_start = _their_start
	_crew_view.queue_redraw()
	if _over:
		_chance.text = ""
	else:
		var c := win_chance(Game.crew, _their_crew, _strength())
		_chance.text = "Chance of victory: about %d %%" % roundi(c * 100.0)
		_chance.add_theme_color_override("font_color", UiTheme.GOOD if c >= 0.6 else (UiTheme.ACCENT if c >= 0.35 else UiTheme.BAD))


func _add_log(text: String, color: Color) -> void:
	_log.add_child(UiTheme.label(text, 9, color))
	while _log.get_child_count() > 6:
		var first := _log.get_child(0)
		_log.remove_child(first)
		first.queue_free()


func _show_fight_buttons() -> void:
	_buttons_set([
		UiTheme.button("Fight (one round)" if defending else "Attack (one round)", _fight_once),
		UiTheme.button("Fight to the end", _fight_to_end),
		UiTheme.button("Cut the lines" if defending else "Retreat", _retreat),
	])


func _show_victory_buttons() -> void:
	var slots := Game.free_tow_slots()
	_buttons_set([
		UiTheme.button("Plunder the ship", _plunder),
		UiTheme.button("Take in tow (%d free)" % maxi(slots, 0) if slots > 0 else "No free tow slots", _take_in_tow, slots > 0),
		UiTheme.button("Take it as a prize", _take_prize),
	])


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
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(90, 40)
	panel.size = Vector2(460, 280)
	_root.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_title = UiTheme.label("", 14, UiTheme.ACCENT)
	vbox.add_child(_title)
	_crew_view = CrewView.new()
	_crew_view.custom_minimum_size = Vector2(440, 64)
	vbox.add_child(_crew_view)
	_chance = UiTheme.label("", 10)
	vbox.add_child(_chance)
	_log = VBoxContainer.new()
	_log.custom_minimum_size = Vector2(0, 80)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_log)
	_buttons = HBoxContainer.new()
	vbox.add_child(_buttons)


## Tegner besætningerne som prikker – du kan se styrkeforholdet med det samme.
class CrewView extends Control:
	var ours: int = 0
	var theirs: int = 0
	var our_start: int = 0
	var their_start: int = 0
	var _shake_ours: float = 0.0
	var _shake_theirs: float = 0.0

	func hit(our_hit: bool, their_hit: bool) -> void:
		if our_hit:
			_shake_ours = 1.0
		if their_hit:
			_shake_theirs = 1.0

	func _process(delta: float) -> void:
		_shake_ours = maxf(_shake_ours - delta * 3.0, 0.0)
		_shake_theirs = maxf(_shake_theirs - delta * 3.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var half := size.x * 0.5
		draw_string(font, Vector2(4, 12), "Your crew: %d" % ours, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.GOOD)
		draw_string(font, Vector2(half + 14, 12), "Enemy: %d" % theirs, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.BAD)
		draw_string(font, Vector2(half - 6, 40), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.ACCENT)
		_dots(Vector2(4, 22), half - 24, our_start, ours, Color(0.45, 0.85, 0.5), _shake_ours)
		_dots(Vector2(half + 14, 22), half - 24, their_start, theirs, Color(0.95, 0.4, 0.35), _shake_theirs)

	func _dots(origin: Vector2, width: float, total: int, alive: int, col: Color, shake: float) -> void:
		var per_row := maxi(1, int(width / 9.0))
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 2.0
		for i in total:
			var p := origin + Vector2((i % per_row) * 9.0 + 4.0, floorf(float(i) / per_row) * 9.0 + 4.0) + offset
			if i < alive:
				draw_circle(p, 3.2, col, true, -1.0, true)
			else:
				draw_circle(p, 3.2, Color(col, 0.18), true, -1.0, true)
