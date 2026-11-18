class_name PlayerCharacter
extends CharacterBody2D
## Kaptajnen til fods. Går på øerne og svømmer i vandet (langsommere og mere "flydende").
## F: åbn kiste / gå om bord · Mellemrum: sværdhug · 1-8: vælg våben · venstreklik: brug valgt våben mod musen.
## Tegnes med kode som en placeholder-figur.

signal board_requested
signal died

const MAX_HP := 100.0
const OUTLINE := Color(0.08, 0.06, 0.05, 0.75) ## mørk kontur, så figuren står skarpt
const ATTACK_RANGE := 20.0
const ATTACK_DAMAGE := 10.0
const ATTACK_COOLDOWN := 0.45

@export var walk_speed: float = 60.0
@export var swim_speed: float = 28.0
@export var walk_responsiveness: float = 10.0 ## Høj = stopper og starter hurtigt
@export var swim_responsiveness: float = 2.5 ## Lav = glider i vandet
@export var board_distance: float = 40.0

var on_land: bool = false
var hp: float = MAX_HP
var _attack_timer: float = 0.0
var _swing: float = 0.0
var _hurt_flash: float = 0.0
var _dead := false
var _since_hurt: float = 99.0
var _prev_pos := Vector2.ZERO
var _curr_pos := Vector2.ZERO
var _draw_offset := Vector2.ZERO ## glat tegning mellem fysik-skridt
var _gun_cooldown: float = 0.0
var _muzzle_flash: float = 0.0
var _wet_warning: float = 0.0
var _gather_target: ResourceNode = null
var _gather_progress: float = 0.0
const REGEN_DELAY := 4.0
const REGEN_PER_SECOND := 5.0

var _facing := Vector2.RIGHT
var _time: float = 0.0
var _input_cooldown: float = 0.3
var _splash: AudioStreamPlayer


func _ready() -> void:
	add_to_group("player_character")
	WorldSky.add_lantern(self, Vector2.ZERO, 70.0, Color(1.0, 0.85, 0.6), 0.7)
	($Camera2D as ZoomCamera).base_zoom = 2.0
	# On foot the view stays close and personal: you can zoom out much less than at sea
	($Camera2D as ZoomCamera).min_user_zoom = ZoomCamera.ON_FOOT_MIN_ZOOM
	($Camera2D as Camera2D).top_level = true
	_splash = AudioStreamPlayer.new()
	_splash.stream = load("res://assets/audio/sfx/splash.wav") as AudioStream
	_splash.volume_db = -6.0
	_splash.bus = "SFX"
	add_child(_splash)
	_prev_pos = global_position
	_curr_pos = global_position
	($Camera2D as Camera2D).global_position = global_position
	on_land = _check_land()
	if not on_land:
		_splash.play() # plask, når man hopper i vandet


func _physics_process(delta: float) -> void:
	_prev_pos = _curr_pos
	_input_cooldown = maxf(_input_cooldown - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_swing = maxf(_swing - delta * 4.0, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta * 3.0, 0.0)
	if _dead:
		return
	_since_hurt += delta
	if _since_hurt > REGEN_DELAY:
		hp = minf(hp + REGEN_PER_SECOND * delta, MAX_HP)

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_speed := walk_speed if on_land else swim_speed
	var responsiveness := walk_responsiveness if on_land else swim_responsiveness
	velocity = velocity.lerp(dir * target_speed, 1.0 - exp(-responsiveness * delta))
	move_and_slide()
	_curr_pos = global_position

	if dir.length() > 0.1:
		_facing = _facing.slerp(dir.normalized(), 1.0 - exp(-12.0 * delta))

	var now_on_land := _check_land()
	if now_on_land != on_land:
		on_land = now_on_land
		_splash.volume_db = -14.0
		_splash.pitch_scale = randf_range(1.1, 1.3)
		_splash.play()

	_update_gathering(delta, dir)
	if _input_cooldown <= 0.0 and Input.is_action_just_pressed("interact"):
		var chest := nearby_chest()
		var shoal := nearby_shoal()
		var node := nearby_resource()
		var castle := nearby_castle()
		if castle:
			Game.duel_requested.emit(castle)
		elif chest:
			chest.open()
		elif shoal:
			shoal.interact(self)
		elif node:
			_start_gathering(node)
		elif can_board():
			board_requested.emit()

	_gun_cooldown = maxf(_gun_cooldown - delta, 0.0)
	_muzzle_flash = maxf(_muzzle_flash - delta * 8.0, 0.0)
	_wet_warning = maxf(_wet_warning - delta, 0.0)
	for i in Catalog.WEAPON_ORDER.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			_select_weapon(Catalog.WEAPON_ORDER[i])
	if Input.is_action_just_pressed("attack"):
		_attack()
	if Input.is_action_just_pressed("attack_mouse"):
		_use_selected()


func _select_weapon(id: String) -> void:
	if not Game.has_weapon(id):
		var w: Dictionary = Catalog.WEAPONS[id]
		Game.notify("You have no %s – buy one at a harbor's weapon shop" % w["name"].to_lower(), UiTheme.BAD)
		return
	Game.selected_weapon = id
	Game.changed.emit()


func _aim() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	return to_mouse.normalized() if to_mouse.length() > 1.0 else _facing


func _use_selected() -> void:
	var id := Game.selected_weapon
	if not Game.has_weapon(id):
		id = "sword"
		Game.selected_weapon = id
	var w: Dictionary = Catalog.WEAPONS[id]
	match w["kind"]:
		"melee":
			_facing = _aim()
			_attack()
		"gun":
			_shoot(id, w)
		"grenade":
			_throw(id)


func _shoot(id: String, w: Dictionary) -> void:
	if _gun_cooldown > 0.0:
		return
	if not on_land:
		if _wet_warning <= 0.0:
			Game.notify("The powder gets wet – you can't shoot while swimming", UiTheme.BAD)
			_wet_warning = 2.0
		return
	if Game.shot < int(w["ammo"]):
		Game.notify("No powder and shot – buy more in a harbor", UiTheme.BAD)
		return
	Game.shot -= int(w["ammo"])
	Game.changed.emit()
	_gun_cooldown = w["reload"]
	var aim := _aim()
	_facing = aim
	for i in int(w["pellets"]):
		var bullet := Bullet.new()
		bullet.direction = aim.rotated(randf_range(-w["spread"], w["spread"]))
		bullet.damage = w["damage"]
		bullet.max_distance = w["range"] * randf_range(0.85, 1.0)
		bullet.global_position = global_position + aim * 9.0
		Game.world_root.add_child(bullet)
	_muzzle_flash = 1.0
	Sfx.play("gunshot", -3.0 if id != "pistol" else -6.0)


func _throw(id: String) -> void:
	if Game.grenades.get(id, 0) <= 0:
		return
	Game.grenades[id] -= 1
	Game.changed.emit()
	var to_mouse := get_global_mouse_position() - global_position
	var g := Grenade.new()
	g.weapon_id = id
	g.start = global_position
	g.target = global_position + to_mouse.limit_length(Catalog.GRENADE_THROW_RANGE)
	Game.world_root.add_child(g)
	_facing = _aim()
	Sfx.play("swing", -8.0)
	if Game.grenades[id] <= 0:
		Game.selected_weapon = "sword"
		Game.changed.emit()


func nearby_shoal() -> FishShoal:
	if not on_land:
		return null
	for s in get_tree().get_nodes_in_group("fish_shoals"):
		if (s as FishShoal).in_range(global_position, false):
			return s
	return null


func nearby_resource() -> ResourceNode:
	for n in get_tree().get_nodes_in_group("resources"):
		if (n as ResourceNode).can_gather(global_position):
			return n
	return null


## 0..1 mens kaptajnen samler (vises som en bjælke), ellers -1.
func gather_progress() -> float:
	if _gather_target == null:
		return -1.0
	return _gather_progress / float(_gather_target.info()["time"])


func _start_gathering(node: ResourceNode) -> void:
	var missing := node.missing_tool()
	if missing != "":
		Game.notify("You need a %s – buy one in a harbor" % missing.to_lower(), UiTheme.BAD)
		return
	_gather_target = node
	_gather_progress = 0.0
	_facing = (node.global_position - global_position).normalized()


func _update_gathering(delta: float, dir: Vector2) -> void:
	if _gather_target == null:
		return
	if dir.length() > 0.1 or not is_instance_valid(_gather_target) or not _gather_target.can_gather(global_position):
		_gather_target = null
		return
	_gather_progress += delta
	if _gather_progress >= float(_gather_target.info()["time"]):
		_gather_target.gather()
		_gather_target = null


func nearby_castle() -> Castle:
	if not on_land:
		return null
	for c in get_tree().get_nodes_in_group("castles"):
		if (c as Castle).can_challenge(global_position):
			return c
	return null


func nearby_chest() -> Chest:
	for c in get_tree().get_nodes_in_group("chests"):
		if (c as Chest).can_open(global_position):
			return c
	return null


func _attack() -> void:
	if _attack_timer > 0.0:
		return
	var sw := Game.sword()
	_attack_timer = sw["cooldown"]
	_swing = 1.0
	Sfx.play("swing", -4.0)
	for c in get_tree().get_nodes_in_group("creatures"):
		var creature := c as Creature
		var to := creature.global_position - global_position
		if to.length() < float(sw["reach"]) + creature.radius and to.normalized().dot(_facing) > 0.2:
			creature.take_damage(sw["damage"], global_position)


func take_damage(amount: float, from: Vector2) -> void:
	if _dead:
		return
	amount *= 1.0 - clampf(Game.gear_stat("armor"), 0.0, 0.6) # frakker beskytter
	hp = maxf(hp - amount, 0.0)
	_since_hurt = 0.0
	_hurt_flash = 1.0
	velocity += (global_position - from).normalized() * 60.0
	Sfx.play("hurt", -2.0)
	Game.popup("-%d" % int(amount), global_position + Vector2(0, -12), Color(1, 0.45, 0.4))
	if hp <= 0.0:
		_dead = true
		died.emit()


func can_board() -> bool:
	var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
	return ship != null and global_position.distance_to(ship.global_position) < board_distance


func _check_land() -> bool:
	return Game.is_land(global_position)


func _process(delta: float) -> void:
	_time += delta
	var smooth := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	_draw_offset = smooth - global_position
	($Camera2D as Camera2D).global_position = smooth
	queue_redraw()


func _draw() -> void:
	draw_set_transform(_draw_offset)
	var moving := clampf(velocity.length() / walk_speed, 0.0, 1.0)
	var angle := _facing.angle()

	# The captain's own look (Tailor) on top of the equipped hat and coat
	var look := CaptainDrawer.current()
	if on_land:
		var step := sin(_time * 14.0) * moving
		CaptainDrawer.draw_body(self, look, _facing, step)
		_draw_sword(angle)
		CaptainDrawer.draw_head(self, look, _facing * 1.0, _facing, 1.0, _time)
	else:
		# Ringe i vandet omkring svømmeren
		for i in 3:
			var r := fmod(_time * 6.0 + i * 5.0, 15.0) + 4.0
			var alpha := 0.35 * (1.0 - (r - 4.0) / 15.0)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1, 1, 1, alpha), 1.0, true)
		draw_circle(Vector2.ZERO, 6.0, Color(0.05, 0.25, 0.40, 0.35), true, -1.0, true) # krop under vand
		var bob := sin(_time * 3.0) * 0.4
		_draw_sword(angle)
		CaptainDrawer.draw_head(self, look, Vector2(0, bob), _facing, 0.9, _time)
	_draw_aim()
	var gp := gather_progress()
	if gp >= 0.0:
		draw_rect(Rect2(-10, -16, 20, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-10, -16, 20 * clampf(gp, 0.0, 1.0), 3), Color(0.6, 0.9, 0.5))
		# Lille hug-animation
		draw_line(_facing * 5.0, _facing * (9.0 + sin(gp * 25.0) * 2.0), Color(0.6, 0.45, 0.3), 1.5, true)
	if _hurt_flash > 0.0:
		draw_circle(Vector2.ZERO, 7.0, Color(1, 0.2, 0.2, 0.4 * _hurt_flash), true, -1.0, true)


## Nærkampsvåbnet: hviler ved siden af kaptajnen og svinger i en bue ved angreb.
func _draw_sword(angle: float) -> void:
	var swing_angle := angle + 0.9 if _swing <= 0.0 else angle + lerpf(-1.3, 1.3, 1.0 - _swing)
	var dir := Vector2.from_angle(swing_angle)
	WeaponArt.draw(self, Game.sword()["look"], dir * 5.0, dir, 1.0)
	if _swing > 0.0:
		draw_arc(Vector2.ZERO, float(Game.sword()["reach"]), angle - 1.0, angle + 1.0, 16, Color(1, 1, 1, 0.35 * _swing), 1.5, true)


## Svag sigtelinje mod musen når et skydevåben eller en granat er valgt.
func _draw_aim() -> void:
	var w: Dictionary = Catalog.WEAPONS.get(Game.selected_weapon, {})
	if w.is_empty() or w["kind"] == "melee":
		return
	var aim := _aim()
	var reach: float = w["range"] if w["kind"] == "gun" else minf((get_global_mouse_position() - global_position).length(), Catalog.GRENADE_THROW_RANGE)
	var col := Color(1, 1, 1, 0.25)
	var d := 10.0
	while d < reach:
		draw_line(aim * d, aim * minf(d + 5.0, reach), col, 1.0, true)
		d += 10.0
	if w["kind"] == "grenade":
		draw_arc(aim * reach, w["radius"], 0.0, TAU, 32, Color(1, 0.8, 0.4, 0.3), 1.0, true)
	if _muzzle_flash > 0.0:
		draw_circle(aim * 10.0, 3.0 * _muzzle_flash, Color(1, 0.85, 0.4, _muzzle_flash), true, -1.0, true)
