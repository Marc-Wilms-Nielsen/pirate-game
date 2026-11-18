extends Node2D
## Hovedscenen. Bygger verdenen (øer, havne, kister, dyr), holder liv i havet
## (fjendeskibe, hajer, vraggods) og styrer skiftet mellem skib, kaptajn og havnemenu.

const OCEAN_SOUND := "res://assets/audio/ambience/ocean_loop.wav"
const PlayerScene := preload("res://scenes/player/player.tscn")
const IslandScene := preload("res://scenes/world/island.tscn")

@export var world_seed: int = 7 ## Samme seed = samme verden hver gang
@export var island_count: int = 300 ## Hav-shaderen får kun de øer, der er tæt på kameraet
@export var mainland_count: int = 6 ## Kæmpe fastlande: 3 med kongeriger, 3 vilde med skov, bjerge og store dyr
@export var world_radius: float = 44300.0 ## ca. 10x arealet af den første verden (14000)
@export var village_count: int = 45 ## fiskerlandsbyer på de øde øer
const PLACE_CELL := 4500.0
const HOME_RADIUS := 360.0 ## hjemøen er stor nok til en hel lille by

@export_group("Life at sea")
@export var max_enemies: int = 6
@export var max_sharks: int = 4
@export var max_barrels: int = 5
@export var max_shoals: int = 6
@export var camp_count: int = 40 ## piratlejre på land
@export var pirate_chance: float = 0.45
@export var enemy_grace_time: float = 25.0 ## Sekunder uden fjender i starten

@onready var _world: Node2D = $World
@onready var _ship: PlayerShip = $Ship
@onready var _pause: CanvasLayer = $PauseMenu
@onready var _harbor_menu: CanvasLayer = $HarborMenu
@onready var _boarding_menu: CanvasLayer = $BoardingMenu
@onready var _home_menu: CanvasLayer = $HomeMenu
var _duel_menu: CanvasLayer
var _escort_sync_pending := false
var _castle_spots: Array[Vector2] = [] ## ingen træer eller kister lige ved slottene
var _streamer: WorldStreamer
var _seabed: Seabed
var _quest_dialog: QuestDialog
var _place_grid: Dictionary = {} ## bruges kun mens øerne placeres
var _player: PlayerCharacter = null
var _spawn_timer: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	Game.world_root = _world
	var sky := WorldSky.new()
	sky.name = "Sky"
	add_child(sky)
	move_child(sky, $HUD.get_index()) # regn og tåge tegnes under HUD'en
	var music := MusicDirector.new()
	music.name = "Music"
	add_child(music)
	var ocean := AudioStreamPlayer.new()
	ocean.stream = load(OCEAN_SOUND) as AudioStream
	ocean.volume_db = -6.0
	ocean.bus = "Ambience"
	add_child(ocean)
	ocean.finished.connect(ocean.play)
	ocean.play()

	_duel_menu = CanvasLayer.new()
	_duel_menu.set_script(load("res://scenes/ui/duel_menu.gd"))
	_duel_menu.name = "DuelMenu"
	add_child(_duel_menu)
	_generate_world()
	_seabed = Seabed.new()
	_seabed.name = "Seabed"
	_seabed.world_seed = world_seed
	_seabed.world_radius = world_radius
	add_child(_seabed)
	# WaterLayers draws the seabed into a small off-screen image for the ocean shader and,
	# with Settings.render_scale < 1, draws the ocean itself at reduced resolution.
	var layers := WaterLayers.new()
	layers.name = "WaterLayers"
	add_child(layers)
	move_child(layers, $Ocean.get_index())
	layers.setup($Ocean as ColorRect, _seabed)
	# Main quest line: marks over harbors, bosses, and the chat window with the quest givers
	var quest_world := QuestWorld.new()
	quest_world.name = "QuestWorld"
	add_child(quest_world)
	_quest_dialog = QuestDialog.new()
	_quest_dialog.name = "QuestDialog"
	add_child(_quest_dialog)
	if Settings.needs_auto_quality:
		var auto := AutoQuality.new()
		auto.name = "AutoQuality"
		add_child(auto)

	_ship.disembark_requested.connect(_on_disembark_requested)
	_ship.dock_requested.connect(_on_dock_requested)
	_harbor_menu.closed.connect(_on_harbor_closed)
	_ship.boarding_requested.connect(_on_boarding_requested)
	_boarding_menu.closed.connect(_on_boarding_closed)
	_home_menu.closed.connect(_on_harbor_closed)
	Game.pirate_boarding.connect(_on_pirate_boarding)
	Game.duel_requested.connect(_on_duel_requested)
	Game.changed.connect(func() -> void:
		if not _escort_sync_pending:
			_escort_sync_pending = true
			_sync_escorts.call_deferred())
	_duel_menu.connect("closed", _on_duel_closed)
	var tow := TowTrain.new()
	add_child(tow)
	move_child(tow, _ship.get_index()) # tegnes under spillerens skib
	var autosave := Timer.new()
	autosave.wait_time = 60.0
	autosave.autostart = true
	autosave.timeout.connect(Game.save_game)
	add_child(autosave)
	Game.player_ship_sunk.connect(_on_ship_sunk)
	_sync_escorts.call_deferred()

	# Start ved kajen i den første havn – eller hvor man slap, hvis der er et gemt spil
	var start: Harbor = null
	for h in get_tree().get_nodes_in_group("harbors"):
		if (h as Harbor).kind != "home":
			start = h
			break
	for h in get_tree().get_nodes_in_group("harbors"):
		if (h as Harbor).harbor_name == Game.saved_harbor_name:
			start = h
	if start:
		Game.last_harbor = start
		_ship.place_at(start.dock_position(), start.dock_rotation())
	# Verdenen kan have ændret sig siden sidst (nye øer) – start i havn, hvis skibet ville stå på land
	if Game.saved_ship_position != null and not Game.is_land(Game.saved_ship_position):
		_ship.place_at(Game.saved_ship_position, Game.saved_ship_rotation)
		Game.notify("Welcome back, captain!", UiTheme.ACCENT)
	else:
		Game.notify("Welcome to %s! Press M for the map." % (start.harbor_name if start else "the islands"), UiTheme.ACCENT)
	_streamer.update_now.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_game()


func _process(delta: float) -> void:
	_elapsed += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 2.0
		_maintain_life()


# --- Verden ---------------------------------------------------------------------

func _generate_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	_streamer = WorldStreamer.new()
	_streamer.name = "Streamer"
	add_child(_streamer)
	var placed: Array[Dictionary] = []
	_place_grid.clear()
	# Første ø (med starthavnen Sunhaven) ligger i midten
	_place(placed, {"pos": Vector2.ZERO, "radius": 150.0, "lagoon": 5.5, "detail": 0.0})
	# Fastlande: 3 kongeriger og 3 vilde fastlande skiftevis rundt om midten
	var base_angle := rng.randf() * TAU
	var kingdom_lands: Array[int] = []
	for i in mainland_count:
		var is_kingdom := i % 2 == 0 and kingdom_lands.size() < Catalog.KINGDOMS.size()
		for attempt in 80:
			var r := rng.randf_range(1450.0, 1850.0) if is_kingdom else rng.randf_range(1100.0, 1600.0)
			var angle := base_angle + TAU * i / mainland_count + rng.randf_range(-0.25, 0.25)
			var dist := rng.randf_range(0.5, 0.66) if is_kingdom else rng.randf_range(0.3, 0.8)
			var candidate := {"pos": Vector2.from_angle(angle) * world_radius * dist, "radius": r, "lagoon": rng.randf_range(1.35, 1.5), "detail": 1.0}
			if _fits(candidate):
				_place(placed, candidate)
				if is_kingdom:
					kingdom_lands.append(placed.size() - 1)
				break
	# Hjemøen: en stor, rund ø tæt på starthavnen med plads til at bygge
	var home_index := -1
	for attempt in 300:
		var pos := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1500.0, 2800.0)
		var candidate := {"pos": pos, "radius": HOME_RADIUS, "lagoon": 2.6, "detail": 0.0, "home": true, "shape_calm": true}
		if _fits(candidate):
			_place(placed, candidate)
			home_index = placed.size() - 1
			break
	var tries := 0
	while placed.size() < island_count and tries < island_count * 120:
		tries += 1
		var r := rng.randf_range(80.0, 280.0) * (1.0 if rng.randf() < 0.7 else 1.4)
		var pos := Vector2.from_angle(rng.randf() * TAU) * world_radius * sqrt(rng.randf())
		# Store øer får en relativt smallere lagune, så lavvandet ikke bliver uendeligt
		var lagoon := lerpf(6.0, 3.2, clampf((r - 80.0) / 300.0, 0.0, 1.0)) + rng.randf_range(-0.4, 0.4)
		var candidate := {"pos": pos, "radius": r, "lagoon": lagoon, "detail": 0.3 if r > 250.0 else 0.0}
		if _fits(candidate):
			_place(placed, candidate)

	var harbor_factions := _assign_harbors(placed, home_index, kingdom_lands)
	# Landsbyer og piratlejre på nogle af de øvrige øer
	var free_islands: Array[int] = []
	for i in placed.size():
		if i != home_index and not harbor_factions.has(i) and not kingdom_lands.has(i):
			free_islands.append(i)
	var shuffled := free_islands.duplicate()
	var shuffle_rng := RandomNumberGenerator.new()
	shuffle_rng.seed = world_seed + 99
	for i in range(shuffled.size() - 1, 0, -1):
		var j := shuffle_rng.randi_range(0, i)
		var tmp: int = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var villages: Dictionary = {}
	var camps: Dictionary = {}
	for i in shuffled:
		if placed[i]["radius"] >= 110.0 and villages.size() < village_count:
			villages[i] = villages.size()
		elif camps.size() < camp_count:
			camps[i] = true

	var name_index := 0
	var kingdom_index := 0
	for i in placed.size():
		var island := IslandScene.instantiate() as Island
		island.position = placed[i]["pos"]
		island.radius = placed[i]["radius"]
		island.seed_value = rng.randi()
		island.palm_count = 0 if i == home_index else mini(int(placed[i]["radius"] / 30.0) + rng.randi_range(0, 3), 70)
		island.gull_count = rng.randi_range(1, 3) + (2 if placed[i]["detail"] > 0.0 else 0)
		island.lagoon_size = placed[i]["lagoon"]
		island.coast_detail = placed[i]["detail"]
		if harbor_factions.has(i):
			var info: Array = harbor_factions[i]
			island.harbor_name = info[1]
			island.harbor_kind = Catalog.FACTIONS[info[0]]["kind"]
			island.island_name = info[1]
			island.harbor_angle = PI if i == 0 else rng.randf() * TAU
		elif i == home_index:
			island.harbor_name = "Home Island"
			island.harbor_kind = "home"
			island.island_name = "Home Island"
			island.harbor_angle = (-placed[i]["pos"]).angle() # molen vender mod starthavnen
		elif kingdom_lands.has(i):
			island.island_name = (Catalog.KINGDOMS[kingdom_lands.find(i)]["name"] as String).replace("Kingdom of ", "")
		elif villages.has(i):
			island.island_name = _village_name(villages[i])
		else:
			var names := Catalog.ISLAND_NAMES
			island.island_name = names[name_index % names.size()] + ("" if name_index < names.size() else " " + ["II", "III", "IV", "V", "VI", "VII", "VIII"][mini(name_index / names.size() - 1, 6)])
			name_index += 1
		_world.add_child(island)
		var castle_index := -1
		if kingdom_lands.has(i):
			castle_index = kingdom_lands.find(i)
			_add_castle(island, castle_index, rng)
			kingdom_index += 1
		var has_harbor := harbor_factions.has(i) or i == home_index
		if i == home_index:
			# Hjemøen bygges med det samme (byggefeltet skal findes fra start)
			_populate_island(island, true)
			_add_home_rim(island, rng)
			_streamer.add_wide(island, island.radius * 1.5 * island.lagoon_size)
		else:
			# Landsbyer og lejre findes fra start (de står på kortet), resten af øens indhold
			# (træer, kister, dyr) bygges først når man kommer i nærheden
			if villages.has(i):
				_add_village(island, villages[i])
			if camps.has(i):
				_add_camp(island)
			_streamer.add_wide(island, island.radius * 1.5 * island.lagoon_size, func() -> void:
				_populate_island(island, has_harbor)
				_add_resources(island))
	# Havbunden bygges også bid for bid
	_streamer.add_cell_builder(func(cell: Vector2i, rect: Rect2) -> void:
		if _seabed:
			_seabed.populate_cell(cell, rect))


func _village_name(index: int) -> String:
	var names := Catalog.VILLAGE_NAMES
	if index < names.size():
		return names[index]
	return "%s %s" % [["North", "South", "East", "West", "Old", "New"][(index / names.size() - 1) % 6], names[index % names.size()]]


## Vælger havne-øerne (spredt ud over verdenen) og giver dem en fraktion:
## hvert kongerige får havnene tættest på sit fastland, smuglerne de mest afsides,
## og de frie handlende resten (inkl. Sunhaven i midten). Returnerer ø-index -> [fraktion, navn].
func _assign_harbors(placed: Array[Dictionary], home_index: int, kingdom_lands: Array[int]) -> Dictionary:
	var total := 0
	for f in Catalog.FACTIONS:
		total += int(Catalog.FACTIONS[f]["harbors"])
	var chosen: Array[int] = [0]
	while chosen.size() < total and chosen.size() < placed.size() - 1:
		var best := -1
		var best_dist := -1.0
		for i in placed.size():
			if i in chosen or i == home_index:
				continue
			var nearest := INF
			for h in chosen:
				nearest = minf(nearest, placed[i]["pos"].distance_to(placed[h]["pos"]))
			if nearest > best_dist:
				best_dist = nearest
				best = i
		chosen.append(best)
	var result: Dictionary = {0: ["free", Catalog.HARBOR_NAMES["free"][0]]}
	var left: Array[int] = chosen.slice(1)
	# Kongerigerne: de nærmeste havne omkring deres fastland
	for k in mini(kingdom_lands.size(), Catalog.KINGDOMS.size()):
		var faction: String = Catalog.KINGDOMS[k]["id"]
		var center: Vector2 = placed[kingdom_lands[k]]["pos"]
		left.sort_custom(func(a: int, b: int) -> bool: return placed[a]["pos"].distance_to(center) < placed[b]["pos"].distance_to(center))
		var names: Array = Catalog.HARBOR_NAMES[faction]
		for n in mini(int(Catalog.FACTIONS[faction]["harbors"]), left.size()):
			result[left[0]] = [faction, names[n]]
			left.remove_at(0)
	# Smuglerne: de mest afsides havne (langt fra midten)
	left.sort_custom(func(a: int, b: int) -> bool: return placed[a]["pos"].length() > placed[b]["pos"].length())
	var smug: Array = Catalog.HARBOR_NAMES["smugglers"]
	for n in mini(smug.size(), left.size()):
		result[left[0]] = ["smugglers", smug[n]]
		left.remove_at(0)
	var free: Array = Catalog.HARBOR_NAMES["free"]
	for n in left.size():
		result[left[n]] = ["free", free[mini(n + 1, free.size() - 1)]]
	return result


func _place(placed: Array[Dictionary], candidate: Dictionary) -> void:
	placed.append(candidate)
	var key := Vector2i(floori(candidate["pos"].x / PLACE_CELL), floori(candidate["pos"].y / PLACE_CELL))
	if not _place_grid.has(key):
		_place_grid[key] = []
	(_place_grid[key] as Array).append(candidate)


func _add_camp(isl: Island) -> void:
	var camp := Camp.new()
	camp.island = isl
	camp.global_position = _land_point(isl, 0.15, 0.5)
	_world.add_child(camp)
	_streamer.add(camp)


func _add_village(isl: Island, index: int) -> void:
	var village := FishingVillage.new()
	village.village_name = _village_name(index)
	village.seed_value = world_seed * 1000 + index
	var angle := randf() * TAU
	var shore := isl.shore_radius(angle)
	var inland := minf(110.0, shore * 0.45) # hytterne ligger lige oppe fra stranden
	village.global_position = isl.global_position + Vector2.from_angle(angle) * (shore - inland)
	village.rotation = angle
	village.pier_length = inland + 40.0
	_world.add_child(village)
	_streamer.add(village)


## Overlapper øen (inkl. dens lagune) med de øer, der allerede er placeret?
func _fits(candidate: Dictionary) -> bool:
	if candidate["pos"].length() > world_radius:
		return false
	var reach_a: float = candidate["radius"] * 1.4 * maxf(candidate["lagoon"] * 0.6, 1.6)
	var c := Vector2i(floori(candidate["pos"].x / PLACE_CELL), floori(candidate["pos"].y / PLACE_CELL))
	for x in range(c.x - 2, c.x + 3):
		for y in range(c.y - 2, c.y + 3):
			for other in _place_grid.get(Vector2i(x, y), []):
				var reach_b: float = other["radius"] * 1.4 * maxf(other["lagoon"] * 0.6, 1.6)
				if candidate["pos"].distance_to(other["pos"]) < reach_a + reach_b + 200.0:
					return false
	return true


## Træer, urter, klipper og (på fastlandene) malmårer.
func _add_resources(island: Island) -> void:
	var r := island.radius
	var big := r > 1000.0
	var counts := {"tree": mini(int(r / 35.0) + 2, 70 if big else 30), "herb": mini(int(r / 90.0) + 1, 18), "rock": mini(int(r / 80.0) + 1, 22),
		"ore": mini(int(r / 140.0), 12) if island.coast_detail > 0.0 else 0}
	var ranges := {"tree": [0.15, 0.6], "herb": [0.2, 0.75], "rock": [0.3, 0.88], "ore": [0.15, 0.55]}
	for kind in counts:
		for i in counts[kind]:
			var node := ResourceNode.new()
			node.kind = kind
			node.global_position = _land_point(island, ranges[kind][0], ranges[kind][1])
			_world.add_child(node)
			_streamer.add(node)


func _populate_island(island: Island, has_harbor: bool) -> void:
	var home := island.harbor_kind == "home" and island.harbor_name != ""
	var chest_count := 2 if home else 1 + mini(int(island.radius / 80.0), 14)
	for i in chest_count:
		var chest := Chest.new()
		chest.global_position = _land_point(island, 0.85 if home else 0.2, 0.92 if home else 0.85)
		_world.add_child(chest)
		_streamer.add(chest)
	for i in randi_range(2, mini(4 + int(island.radius / 60.0), 18)):
		var crab := Crab.new()
		crab.home = island
		crab.global_position = island.random_land_point(0.75, 0.93)
		_world.add_child(crab)
		_streamer.add(crab)
	if island.radius > 1000.0:
		_add_beasts(island)
	if not has_harbor:
		for i in randi_range(0, mini(1 + int(island.radius / 150.0), 8)):
			var snake := Snake.new()
			snake.home = island
			snake.global_position = island.random_land_point(0.1, 0.5)
			_world.add_child(snake)
			_streamer.add(snake)


## Hjemøen: kun palmer, træer og klipper helt ude ved kysten, så midten er fri til byggeri.
func _add_home_rim(island: Island, rng: RandomNumberGenerator) -> void:
	for i in 14:
		var node := ResourceNode.new()
		node.kind = ["tree", "tree", "tree", "rock", "herb"][i % 5]
		var a := rng.randf() * TAU
		if absf(angle_difference(a, island.harbor_angle)) < 0.5:
			a += 1.0
		node.global_position = island.global_position + Vector2.from_angle(a) * island.shore_radius(a) * rng.randf_range(0.86, 0.93)
		_world.add_child(node)
		_streamer.add(node)


## Store dyr og monstre på de kæmpe fastlande.
func _add_beasts(island: Island) -> void:
	var amounts := {"jaguar": 6, "boar": 7, "croc": 6, "golem": 3}
	for kind in amounts:
		for i in amounts[kind]:
			var beast := Beast.new()
			beast.kind = kind
			beast.home = island
			var zone: Array = Beast.KINDS[kind]["zone"]
			beast.global_position = _land_point(island, zone[0], zone[1])
			_world.add_child(beast)
			_streamer.add(beast)


## Et kongerige med slot på et kæmpe fastland. Slottet ligger inde i landet, med porten mod havet.
func _add_castle(island: Island, index: int, rng: RandomNumberGenerator) -> void:
	var angle := rng.randf() * TAU
	for i in 8:
		if island.harbor_name == "" or absf(angle_difference(angle, island.harbor_angle)) > 1.2:
			break
		angle = rng.randf() * TAU
	var pos := island.global_position + Vector2.from_angle(angle) * island.shore_radius(angle) * 0.7
	var town := KingdomTown.new()
	town.kingdom_index = index
	town.global_position = pos
	town.rotation = angle
	town.road_length = island.shore_radius(angle) * 0.3
	_world.add_child(town)
	_streamer.add(town)
	var castle := Castle.new()
	castle.kingdom_index = index
	castle.island = island
	castle.global_position = pos
	castle.rotation = angle
	castle.scale = Vector2(1.5, 1.5) # større slot
	_world.add_child(castle)
	_streamer.add(castle)
	_castle_spots.append(castle.global_position)


## Tilfældigt punkt på land, der ikke ligger oven i et slot.
func _land_point(island: Island, min_f: float, max_f: float) -> Vector2:
	var p := island.random_land_point(min_f, max_f)
	for attempt in 6:
		var clear := true
		for c in _castle_spots:
			if p.distance_to(c) < 360.0: # slot og by
				clear = false
				break
		if clear:
			return p
		p = island.random_land_point(min_f, max_f)
	return p


# --- Liv på havet ---------------------------------------------------------------

func _focus_position() -> Vector2:
	return _player.global_position if _player else _ship.global_position


func _maintain_life() -> void:
	var focus := _focus_position()
	_despawn_far("enemies", focus, 3800.0)
	_despawn_far("sharks", focus, 2600.0)
	_despawn_far("floating_loot", focus, 3200.0)
	_despawn_far("surrendered", focus, 2500.0)
	_despawn_far("fish_shoals", focus, 2600.0)
	if get_tree().get_nodes_in_group("fish_shoals").size() < max_shoals:
		# Fisk samles i lagunerne og langs kysterne
		var spot := _find_water_spot(focus, 250.0, 1500.0, 0.12)
		if spot != Vector2.INF and Game.water_depth(spot) < 0.95:
			var shoal := FishShoal.new()
			shoal.global_position = spot
			_world.add_child(shoal)

	if _elapsed > enemy_grace_time and get_tree().get_nodes_in_group("enemies").size() < max_enemies:
		var pos := _find_water_spot(focus, 1300.0, 2400.0, 0.85)
		if pos != Vector2.INF:
			var enemy := EnemyShip.new()
			# Om natten er der flere pirater og færre handelsskibe ude
			enemy.setup("pirate" if randf() < pirate_chance + 0.3 * Game.night else "merchant", "")
			enemy.global_position = pos
			enemy.rotation = randf() * TAU
			_world.add_child(enemy)

	if get_tree().get_nodes_in_group("sharks").size() < max_sharks:
		var pos := _find_water_spot(focus, 500.0, 1400.0, 0.6)
		if pos != Vector2.INF:
			var shark := Shark.new()
			shark.global_position = pos
			shark.add_to_group("sharks")
			_world.add_child(shark)

	if get_tree().get_nodes_in_group("floating_loot").size() < max_barrels:
		var pos := _find_water_spot(focus, 600.0, 1800.0, 0.15)
		if pos != Vector2.INF:
			var barrel := FloatingLoot.new()
			barrel.global_position = pos
			barrel.lifetime = 300.0
			_world.add_child(barrel)


func _find_water_spot(center: Vector2, min_r: float, max_r: float, min_depth: float) -> Vector2:
	for i in 12:
		var pos := center + Vector2.from_angle(randf() * TAU) * randf_range(min_r, max_r)
		if pos.length() < world_radius + 1500.0 and Game.water_depth(pos) >= min_depth:
			return pos
	return Vector2.INF


func _despawn_far(group: String, focus: Vector2, max_dist: float) -> void:
	for node in get_tree().get_nodes_in_group(group):
		var n := node as Node2D
		if n.global_position.distance_to(focus) > max_dist:
			if n is EnemyShip and (n as EnemyShip).state == "attack":
				continue
			n.queue_free()


# --- Skib, kaptajn og havne ------------------------------------------------------

func _on_disembark_requested() -> void:
	_player = PlayerScene.instantiate() as PlayerCharacter
	_player.position = _ship.global_position + Vector2.DOWN.rotated(_ship.rotation) * (22.0 * _ship.stats["size"])
	add_child(_player)
	_player.board_requested.connect(_on_board_requested)
	_player.died.connect(_on_player_died)
	_player.get_node("Camera2D").make_current()
	_ship.set_controlled(false)


func _on_board_requested() -> void:
	_remove_player()
	_ship.set_controlled(true)


func _on_player_died() -> void:
	var lost := int(Game.gold * 0.1)
	Game.gold -= lost
	Game.changed.emit()
	Game.notify("You passed out... the crew carried you back aboard (-%d gold)" % lost, UiTheme.BAD)
	_remove_player()
	_ship.set_controlled(true)


func _remove_player() -> void:
	if _player:
		_player.queue_free()
		_player = null


func _on_dock_requested(harbor: Harbor) -> void:
	_ship.place_at(harbor.dock_position(), harbor.dock_rotation())
	_ship.set_controlled(false)
	_pause.set("harbor_menu_open", true)
	if harbor.kind == "home":
		_home_menu.call("open")
		return
	Game.last_harbor = harbor
	Game.save_game()
	# Quest givers talk first ("!" = new quest, "?" = hand in). Handing one in can lead
	# straight to the next offer at the same harbor; declining goes on to the harbor menu.
	var talk := Quests.talk_at(harbor.harbor_name)
	while not talk.is_empty():
		_quest_dialog.open(talk)
		var result: String = await _quest_dialog.closed
		Game.save_game()
		if result == "decline":
			break
		talk = Quests.talk_at(harbor.harbor_name)
	_harbor_menu.call("open", harbor)


func _on_harbor_closed() -> void:
	_pause.set("harbor_menu_open", false)
	_ship.set_controlled(true)


func _on_pirate_boarding(enemy: Node2D) -> void:
	if not _ship.controlled or get_tree().paused or _player != null:
		return
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	_on_boarding_requested(enemy as EnemyShip, true)


func _on_boarding_requested(enemy: EnemyShip, defending := false) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	_ship.set_controlled(false)
	_pause.set("harbor_menu_open", true)
	_boarding_menu.call("open", enemy, defending)


func _on_boarding_closed() -> void:
	_pause.set("harbor_menu_open", false)
	_ship.set_controlled(true)


func _on_duel_requested(castle: Node2D) -> void:
	if get_tree().paused or not is_instance_valid(castle):
		return
	var c := castle as Castle
	var wait := Game.kingdom_wait(c.kingdom_index)
	if wait > 0.0:
		Game.notify("%s is gathering new troops – come back in %d min." % [c.kingdom()["name"], ceili(wait / 60.0)], UiTheme.MUTED)
		return
	_pause.set("harbor_menu_open", true)
	_duel_menu.call("open", c)


func _on_duel_closed() -> void:
	_pause.set("harbor_menu_open", false)


## Sørger for at der sejler et eskorteskib for hvert af dine skibe med en kaptajn.
func _sync_escorts() -> void:
	_escort_sync_pending = false
	var wanted: Array = []
	for i in Game.owned_ships.size():
		var cfg: Dictionary = Game.owned_ships[i]
		if i != Game.active_ship_index and not Game.captain_by_id(int(cfg.get("captain", 0))).is_empty():
			wanted.append(cfg)
	var existing: Array = get_tree().get_nodes_in_group("escorts")
	for e in existing:
		var escort := e as EscortShip
		if not wanted.any(func(cfg: Dictionary) -> bool: return is_same(cfg, escort.config)):
			escort.queue_free()
	for slot in wanted.size():
		var cfg: Dictionary = wanted[slot]
		var found: EscortShip = null
		for e in existing:
			if is_same((e as EscortShip).config, cfg) and not (e as Node).is_queued_for_deletion():
				found = e
		if found:
			found.slot = slot
			found.refresh()
			continue
		var escort := EscortShip.new()
		escort.config = cfg
		escort.slot = slot
		if float(cfg["hp"]) <= 0.0:
			cfg["hp"] = Game.ship_stats(cfg)["max_hp"] * 0.4
		var spot := escort.formation_point(_ship)
		if Game.is_land(spot) or Game.water_depth(spot) < 0.05:
			spot = _ship.global_position - Vector2.from_angle(_ship.rotation) * 140.0
		escort.global_position = spot
		escort.rotation = _ship.rotation
		_world.add_child(escort)


func _on_ship_sunk() -> void:
	_remove_player()
	# Mist en del af lasten, men aldrig skibet eller opgraderingerne
	var lost_any := false
	for id in Game.cargo.keys():
		var lose := int(ceil(Game.cargo[id] * 0.3))
		if lose > 0:
			Game.remove_item(id, lose)
			lost_any = true
	var config := Game.active_ship()
	config["hp"] = Game.ship_stats(config)["max_hp"] * 0.5
	if not Game.towed.is_empty():
		Game.towed.clear()
		Game.notify("The ships in tow were lost", UiTheme.BAD)
	var harbor := Game.last_harbor as Harbor
	if harbor:
		_ship.place_at(harbor.dock_position(), harbor.dock_rotation())
	_ship.set_controlled(true)
	Game.changed.emit()
	Game.notify("You wake up in %s. %s" % [harbor.harbor_name if harbor else "the harbor", "Some of the cargo was lost." if lost_any else ""], UiTheme.BAD)
