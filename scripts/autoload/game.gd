extends Node
## Global spiltilstand (autoload "Game"): guld, last, forsyninger, skibe og hjælpefunktioner.
## UI lytter på signalet `changed` og opdaterer sig selv.

signal changed
signal notification(text: String, color: Color)
signal logged(text: String, color: Color, icon: String) ## én linje i loggen nederst til venstre (med ikon)
@warning_ignore("unused_signal") # udsendes af skibet
signal player_ship_sunk
@warning_ignore("unused_signal") # udsendes af fjendeskibe
signal pirate_boarding(enemy: Node2D) ## en pirat har lagt sig op ad og entrer dig
@warning_ignore("unused_signal") # udsendes af kaptajnen ved slotsporten
signal duel_requested(castle: Node2D) ## kaptajnen udfordrer et kongerige

var save_path := "user://save.dat" ## tests switch to their own file (use_test_files)
const SAVE_VERSION := 3 ## 2: opgraderinger har 100 trin. 3: 10x større verden

const START_GOLD := 0 ## a new voyage starts with empty pockets
const TEST_START_GOLD := 1000000 ## tests (use_test_files) start rich, so they can buy everything they check
var _test_mode := false
const START_CANNONBALLS := 30
const START_FOOD := 40

var gold: int = START_GOLD
var cannonballs: int = START_CANNONBALLS
var food: int = START_FOOD
var crew: int = 6 ## sømænd om bord på det aktive skib
var user_zoom: float = 1.0 ## spillerens egen zoom (scroll / + -)
var shot: int = 20 ## krudt og kugler til kaptajnens skydevåben
var owned_weapons: Dictionary = {} ## våben-id -> true
var grenades: Dictionary = {} ## granat-id -> antal
var selected_weapon: String = "sword"
var cargo: Dictionary = {} ## vare-id -> antal
var owned_ships: Array = [] ## liste af skibskonfigurationer (Dictionary)
var active_ship_index: int = 0
var unlocked_cosmetics: Dictionary = {} ## "sail:black" osv. -> true
var towed: Array = [] ## erobrede skibe på slæb (skibskonfigurationer)
var owned_gear: Dictionary = {} ## udstyrs-id -> true
var equipped: Dictionary = {} ## slot -> udstyrs-id
var tools: Dictionary = {} ## værktøj-id -> true (økse, hakke, fiskestang)
var repair_kits: int = 0
var captains: Array = [] ## ansatte kaptajner: {id, name, sailing, gunnery, courage}
var captain_slots: int = Catalog.CAPTAIN_START_SLOTS
var next_captain_id: int = 1
var boxes: Array = [] ## pakkede kasser i lastrummet: {"type": kasse-id, "contents": {vare-id: antal}}
var harbor_rep: Dictionary = {} ## fraktion -> samlet salg i guld (venskab). Gamle saves: havnenavn (flyttes ved load)
var kingdom_wins: Dictionary = {} ## kongerige-id -> antal vundne dueller
var kingdom_ready_at: Dictionary = {} ## kongerige-id -> unix-tid hvor det kan udfordres igen
var visited_harbors: Dictionary = {} ## harbor name -> true: where you have docked (fast travel goes there)
var captain_look: Dictionary = {} ## the captain's chosen look: part key -> option id (Catalog.CAPTAIN_STYLE_PARTS)
var world_time: float = 0.3 ## tid på døgnet 0..1 (0 = midnat, 0.5 = middag) – gemmes
var night: float = 0.0 ## 0 = dag, 1 = nat (sættes af Sky)
var weather: String = "clear" ## sættes af Sky
var wind := Vector2.ZERO ## skubber skibet i stormvejr (sættes af Sky)
var saved_ship_position = null ## Vector2 fra gemt spil (null = start i havn)
var saved_ship_rotation: float = 0.0
var saved_harbor_name: String = ""
var loaded_from_save := false

var world_root: Node2D ## sættes af main, bruges til popups
var last_harbor: Node2D ## hvor man vågner efter et forlis
var current_harbor: Node2D ## havnen man ligger ved lige nu (eller null)

var _price_cache: Dictionary = {}


func _ready() -> void:
	_ensure_input_actions()
	reset()
	load_game()


func reset() -> void:
	gold = TEST_START_GOLD if _test_mode else START_GOLD
	cannonballs = START_CANNONBALLS
	food = START_FOOD
	crew = Catalog.START_CREW
	shot = 20
	owned_weapons = {"sword": true, "pistol": true}
	grenades = {"grenade": 3, "firebomb": 1, "poison": 0, "flash": 1}
	selected_weapon = "sword"
	cargo = {}
	owned_ships = [new_ship_config("sloop")]
	active_ship_index = 0
	unlocked_cosmetics = {"sail:canvas": true, "hull:oak": true, "flag:black": true, "flagstyle:small": true}
	towed = []
	owned_gear = {"tricorn": true, "shirt": true, "cutlass": true}
	equipped = {"hat": "tricorn", "coat": "shirt", "sword": "cutlass"}
	tools = {"axe": true, "rod": true}
	repair_kits = 1
	harbor_rep = {}
	boxes = []
	captains = []
	captain_slots = Catalog.CAPTAIN_START_SLOTS
	next_captain_id = 1
	kingdom_wins = {}
	kingdom_ready_at = {}
	visited_harbors = {Catalog.HARBOR_NAMES["free"][0]: true} # the start harbor
	captain_look = {}
	world_time = 0.3
	saved_ship_position = null
	saved_harbor_name = ""
	loaded_from_save = false
	changed.emit()


# --- Skibe -------------------------------------------------------------------

func new_ship_config(type: String) -> Dictionary:
	var config := {
		"type": type,
		"name": Catalog.SHIPS[type]["name"],
		"upgrades": {},
		"cannons": 1,
		"sail": "canvas",
		"hull": "oak",
		"flag": "black",
		"flag_style": "small",
		"decorations": {},
		"hp": 0.0,
	}
	for id in Catalog.UPGRADES:
		config["upgrades"][id] = 0
	config["hp"] = float(ship_stats(config)["max_hp"])
	return config


func active_ship() -> Dictionary:
	return owned_ships[active_ship_index]


## Beregner skibets endelige værdier ud fra skibstype + opgraderinger.
func ship_stats(config: Dictionary) -> Dictionary:
	var base: Dictionary = Catalog.SHIPS[config["type"]]
	var stats := {
		"max_hp": float(base["max_hp"]),
		"speed": float(base["speed"]),
		"acceleration": float(base["acceleration"]),
		"turn": float(base["turn"]),
		"cargo": float(base["cargo"]),
		"armor": 0.0,
		"damage": Catalog.CANNON_BASE["damage"],
		"range": Catalog.CANNON_BASE["range"],
		"reload": Catalog.CANNON_BASE["reload"],
		"ball_speed": Catalog.CANNON_BASE["ball_speed"],
		"cannons": int(config["cannons"]),
		"max_cannons": int(base["max_cannons"]),
		"size": float(base["look"]["length"]) / 58.0,
		"max_crew": int(base["crew"]),
		"no_food": base.get("no_food", false),
	}
	for id in Catalog.UPGRADES:
		var up: Dictionary = Catalog.UPGRADES[id]
		var level: int = config["upgrades"].get(id, 0)
		var stat: String = up["stat"]
		if stat == "armor":
			stats["armor"] = clampf(level * up["per_level"], 0.0, 0.6)
		elif stat == "tow":
			pass # lægges til nedenfor
		else:
			stats[stat] = stats[stat] * (1.0 + level * up["per_level"])
		if stat == "speed":
			stats["acceleration"] *= 1.0 + level * up["per_level"]
	stats["cargo"] = floorf(stats["cargo"])
	stats["tow"] = Catalog.base_tow_slots(config["type"]) + int(config["upgrades"].get("tow", 0))
	return stats


## Fartfaktor når man slæber erobrede skibe (1.0 = ingen slæb).
func tow_speed_factor() -> float:
	var penalty := 0.0
	for c in towed:
		penalty += Catalog.TOW_SPEED_PENALTY * float(Catalog.SHIPS[c["type"]]["look"]["length"]) / 58.0
	return maxf(0.45, 1.0 - penalty)


func free_tow_slots() -> int:
	return int(ship_stats(active_ship())["tow"]) - towed.size()


func towed_sell_price(config: Dictionary) -> int:
	var hp_ratio: float = clampf(config["hp"] / ship_stats(config)["max_hp"], 0.2, 1.0)
	return int(Catalog.SHIPS[config["type"]]["price"] * Catalog.TOW_SELL_FACTOR * hp_ratio)


## Antal skud / granater tilbage til et våben (-1 = ubegrænset, f.eks. sværdet).
func weapon_ammo(id: String) -> int:
	var w: Dictionary = Catalog.WEAPONS[id]
	match w["kind"]:
		"gun":
			return shot
		"grenade":
			return grenades.get(id, 0)
	return -1


## Samlet værdi af en stat fra det udstyr, kaptajnen har på (luck, armor ...).
func gear_stat(stat: String) -> float:
	var total := 0.0
	for slot in equipped:
		total += float(Catalog.GEAR[equipped[slot]].get(stat, 0.0))
	return total


func sword() -> Dictionary:
	return Catalog.GEAR[equipped.get("sword", "cutlass")]


func equip(id: String) -> void:
	if not owned_gear.get(id, false):
		return
	equipped[Catalog.GEAR[id]["slot"]] = id
	changed.emit()


func has_weapon(id: String) -> bool:
	var w: Dictionary = Catalog.WEAPONS[id]
	if w["kind"] == "grenade":
		return grenades.get(id, 0) > 0
	return owned_weapons.get(id, false)


func max_crew() -> int:
	return int(ship_stats(active_ship())["max_crew"])


## Skift aktivt skib. Overskydende besætning går i land.
func set_active_ship(index: int) -> void:
	active_ship_index = index
	if owned_ships[index].has("captain"):
		# Du overtager selv rattet – kaptajnen går i land og venter på et nyt skib
		var c := captain_by_id(int(owned_ships[index]["captain"]))
		owned_ships[index].erase("captain")
		if not c.is_empty():
			notify("%s goes ashore and waits for a new ship" % c["name"], Color(1, 0.8, 0.5))
	if int(owned_ships[index].get("crew", 0)) > 0:
		# Eskortens folk bliver om bord og slutter sig til din besætning
		crew += int(owned_ships[index]["crew"])
		owned_ships[index].erase("crew")
	var cap := max_crew()
	if crew > cap:
		notify("%d sailors went ashore – there is only room for %d" % [crew - cap, cap], Color(1, 0.8, 0.5))
		crew = cap
	changed.emit()


func upgrade_cost(config: Dictionary, id: String) -> int:
	return Catalog.upgrade_price(id, int(config["upgrades"].get(id, 0)))


# --- Kaptajner ---------------------------------------------------------------

func captain_by_id(id: int) -> Dictionary:
	for c in captains:
		if int(c["id"]) == id:
			return c
	return {}


## Skibet en kaptajn fører (tom hvis han venter i land).
func captain_ship(id: int) -> Dictionary:
	for i in owned_ships.size():
		if i != active_ship_index and int(owned_ships[i].get("captain", 0)) == id:
			return owned_ships[i]
	return {}


## Skibe der sejler som eskorte lige nu (har en kaptajn og er ikke dit eget aktive skib).
func escort_configs() -> Array:
	var out: Array = []
	for i in owned_ships.size():
		if i != active_ship_index and not captain_by_id(int(owned_ships[i].get("captain", 0))).is_empty():
			out.append(owned_ships[i])
	return out


## Folk om bord på alle eskorteskibene (de kan gå med i kamp mod kongeriger).
func escort_crew_total() -> int:
	var n := 0
	for cfg in escort_configs():
		n += int(cfg.get("crew", 0))
	return n


## Flyt folk mellem dit eget skib og et eskorteskib (positiv = til eskorten).
func move_crew_to_escort(cfg: Dictionary, amount: int) -> void:
	var cap := int(ship_stats(cfg)["max_crew"])
	var have := int(cfg.get("crew", 0))
	if amount > 0:
		amount = mini(amount, mini(crew - 1, cap - have))
	else:
		amount = -mini(-amount, mini(have, max_crew() - crew))
	if amount == 0:
		return
	cfg["crew"] = have + amount
	crew -= amount
	changed.emit()


## Hyr nye folk direkte til et eskorteskib.
func hire_escort_crew(cfg: Dictionary, amount: int) -> void:
	var cap := int(ship_stats(cfg)["max_crew"])
	var n := mini(amount, cap - int(cfg.get("crew", 0)))
	if n <= 0 or not spend(n * Catalog.CREW_PRICE):
		return
	cfg["crew"] = int(cfg.get("crew", 0)) + n
	changed.emit()


## Sæt en kaptajn på et skib (index i owned_ships) – eller -1 for at tage ham i land.
func assign_captain(id: int, ship_index: int) -> void:
	for config in owned_ships:
		if int(config.get("captain", 0)) == id:
			config.erase("captain")
	if ship_index >= 0 and ship_index != active_ship_index:
		owned_ships[ship_index]["captain"] = id
	changed.emit()


func hire_captain(candidate: Dictionary) -> bool:
	if captains.size() >= captain_slots:
		notify("No free captain slots – buy more in a harbor", Color(1, 0.6, 0.5))
		return false
	if not spend(Catalog.captain_hire_price(candidate)):
		return false
	var c := candidate.duplicate()
	c["id"] = next_captain_id
	next_captain_id += 1
	captains.append(c)
	notify("%s is hired! Give them a ship under Captains." % c["name"], Color(0.6, 0.9, 0.6))
	changed.emit()
	return true


func dismiss_captain(id: int) -> void:
	assign_captain(id, -1)
	captains = captains.filter(func(c: Dictionary) -> bool: return int(c["id"]) != id)
	changed.emit()


func upgrade_captain(id: int, skill: String) -> void:
	var c := captain_by_id(id)
	if c.is_empty():
		return
	var price := Catalog.captain_upgrade_price(int(c[skill]))
	if price > 0 and spend(price):
		c[skill] = int(c[skill]) + 1
		changed.emit()


## En ny kaptajn man kan ansætte (tilfældigt navn og evner).
func random_captain_candidate() -> Dictionary:
	var used: Array = captains.map(func(c: Dictionary) -> String: return c["name"])
	var names: Array = Catalog.CAPTAIN_NAMES.filter(func(n: String) -> bool: return not n in used)
	return {"name": names.pick_random() if not names.is_empty() else "Captain Unknown",
		"sailing": randi_range(0, 2), "gunnery": randi_range(0, 2), "courage": randi_range(0, 2)}


## Skibets værdier med kaptajnens evner lagt oveni (til eskorteskibe).
func escort_stats(config: Dictionary) -> Dictionary:
	var stats := ship_stats(config)
	var c := captain_by_id(int(config.get("captain", 0)))
	if c.is_empty():
		return stats
	var s := float(c["sailing"])
	var g := float(c["gunnery"])
	var m := float(c["courage"])
	stats["speed"] *= 1.0 + 0.04 * s
	stats["acceleration"] *= 1.0 + 0.04 * s
	stats["turn"] *= 1.0 + 0.04 * s
	stats["damage"] *= 1.0 + 0.08 * g
	stats["reload"] *= maxf(0.4, 1.0 - 0.03 * g)
	stats["max_hp"] *= 1.0 + 0.06 * m
	stats["armor"] = minf(stats["armor"] + 0.02 * m, 0.75)
	return stats


# --- Kongeriger ---------------------------------------------------------------

## Antal soldater i slottets garnison (vokser hver gang du slår kongeriget).
func kingdom_garrison(index: int) -> int:
	var k: Dictionary = Catalog.KINGDOMS[index]
	return int(k["garrison"]) + int(kingdom_wins.get(k["id"], 0)) * Catalog.GARRISON_GROWTH


## Sekunder til kongeriget kan udfordres igen (0 = klar nu).
func kingdom_wait(index: int) -> float:
	var id: String = Catalog.KINGDOMS[index]["id"]
	return maxf(0.0, float(kingdom_ready_at.get(id, 0.0)) - Time.get_unix_time_from_system())


func kingdom_cooldown(index: int) -> void:
	kingdom_ready_at[Catalog.KINGDOMS[index]["id"]] = Time.get_unix_time_from_system() + Catalog.DUEL_COOLDOWN_MIN * 60.0


# --- Guld og varer -----------------------------------------------------------

func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


func spend(amount: int) -> bool:
	if amount > gold:
		notify("Not enough gold", Color(1, 0.6, 0.5))
		return false
	gold -= amount
	changed.emit()
	return true


func cargo_used() -> int:
	var used := 0
	for id in cargo:
		used += int(cargo[id]) * int(Catalog.ITEMS[id]["weight"])
	for box in boxes:
		used += int(Catalog.BOXES[box["type"]]["weight"])
	return used


# --- Kasser ---------------------------------------------------------------------

func box_item_count(box: Dictionary) -> int:
	var n := 0
	for id in box["contents"]:
		n += int(box["contents"][id])
	return n


## Hvad en kasse kan sælges for i en bestemt havn.
func box_value(box: Dictionary, harbor_name: String, kind: String) -> int:
	var total := 0
	for id in box["contents"]:
		var n := int(box["contents"][id])
		if Catalog.ITEMS.has(id):
			if harbor_buys(kind, id):
				total += price_at(harbor_name, kind, id, false) * n
		elif Catalog.SUPPLIES.has(id):
			total += int(Catalog.SUPPLIES[id]["price"]) * n
	return total


func boxes_value(harbor_name: String, kind: String) -> int:
	var total := 0
	for box in boxes:
		total += box_value(box, harbor_name, kind)
	return total


## Sælg alle kasser i lastrummet på én gang.
func sell_all_boxes(harbor_name: String, kind: String) -> int:
	var total := boxes_value(harbor_name, kind)
	if boxes.is_empty():
		return 0
	var count := boxes.size()
	boxes.clear()
	add_harbor_rep(harbor_name, total)
	add_gold(total)
	Sfx.play("coin")
	log_line("Sold %d box%s for %d gold" % [count, "" if count == 1 else "es", total], Color(1, 0.92, 0.55), "gold")
	return total


func cargo_capacity() -> int:
	return int(ship_stats(active_ship())["cargo"])


## Tilføjer varer/forsyninger. Returnerer hvor mange der faktisk blev plads til.
func add_item(id: String, amount: int) -> int:
	if id == "cannonball":
		cannonballs += amount
	elif id == "shot":
		shot += amount
	elif id == "repair_kit":
		repair_kits += amount
	elif Catalog.GEAR.has(id):
		# Udstyr fra en kiste: nyt udstyr, eller guld hvis man allerede har det
		if owned_gear.get(id, false):
			add_gold(int(Catalog.GEAR[id]["price"] * 0.4))
		else:
			owned_gear[id] = true
			notify("You found %s! Equip it under Esc → Gear" % Catalog.GEAR[id]["name"], Color(0.95, 0.8, 0.45))
	elif Catalog.WEAPONS.has(id) and Catalog.WEAPONS[id]["kind"] == "grenade":
		grenades[id] = grenades.get(id, 0) + amount
	elif id == "food":
		food += amount
	elif Catalog.ITEMS.has(id):
		var weight: int = Catalog.ITEMS[id]["weight"]
		var room := floori(float(cargo_capacity() - cargo_used()) / weight)
		amount = mini(amount, room)
		if amount <= 0:
			return 0
		cargo[id] = cargo.get(id, 0) + amount
	else:
		push_warning("Unknown item: %s" % id)
		return 0
	changed.emit()
	return amount


func remove_item(id: String, amount: int) -> bool:
	if cargo.get(id, 0) < amount:
		return false
	cargo[id] -= amount
	if cargo[id] <= 0:
		cargo.erase(id)
	changed.emit()
	return true


func item_name(id: String) -> String:
	if id == "repair_kit":
		return "Repair kit"
	if Catalog.GEAR.has(id):
		return Catalog.GEAR[id]["name"]
	if Catalog.WEAPONS.has(id):
		return Catalog.WEAPONS[id]["name"]
	if Catalog.SUPPLIES.has(id):
		return Catalog.SUPPLIES[id]["name"]
	return Catalog.ITEMS[id]["name"] if Catalog.ITEMS.has(id) else id


## Slår en loot-tabel op, giver spilleren tingene og viser dem som popups.
func give_loot(table_id: String, world_pos: Vector2) -> void:
	var table: Dictionary = Catalog.LOOT[table_id] if Catalog.LOOT.has(table_id) else Catalog.QUEST_LOOT[table_id]
	var messages: Array[String] = []
	var icons: Array[String] = []
	var g: Array = table["gold"]
	var luck := gear_stat("luck")
	var gold_amount := int(randi_range(g[0], g[1]) * (1.0 + luck))
	if gold_amount > 0:
		add_gold(gold_amount)
		messages.append("+%d gold" % gold_amount)
		icons.append("gold")
	var cargo_full := false
	for entry in table["items"]:
		if randf() > minf(float(entry[3]) + luck * 0.5, 1.0):
			continue
		var wanted := randi_range(entry[1], entry[2])
		var got := add_item(entry[0], wanted)
		if got > 0:
			messages.append("+%d %s" % [got, item_name(entry[0])])
			icons.append(entry[0])
		if got < wanted:
			cargo_full = true
	var colors: Array[Color] = []
	for i in messages.size():
		colors.append(Color(1, 0.92, 0.55))
	# En sjælden gang ligger der noget helt særligt i byttet
	var rare := roll_rare_drop(table_id, luck)
	if rare != "":
		if add_item(rare, 1) > 0:
			var rarity: String = Catalog.ITEMS[rare]["rarity"]
			var col: Color = Catalog.RARITY_COLORS[rarity]
			messages.append("%s! %s" % [rarity.to_upper(), item_name(rare)])
			icons.append(rare)
			colors.append(col)
			notify("%s find: %s (worth ~%d gold)" % ["Epic" if rarity == "epic" else "Rare", item_name(rare), Catalog.ITEMS[rare]["price"]], col)
			Sfx.play("coin", 2.0)
		else:
			cargo_full = true
	if messages.is_empty():
		messages.append("Nothing of value")
		icons.append("")
		colors.append(Color(1, 0.92, 0.55))
	for i in messages.size():
		popup(messages[i], world_pos + Vector2(0, -14 * i), colors[i], icons[i])
	for i in messages.size():
		log_line(messages[i], colors[i], icons[i])
	if cargo_full:
		notify("The cargo hold is full!", Color(1, 0.6, 0.5))
	Sfx.play("coin")


## Slår et terningkast for et sjældent eller episk fund. Returnerer et item-id eller "".
func roll_rare_drop(table_id: String, luck := 0.0) -> String:
	var chances: Array = Catalog.RARE_DROPS.get(table_id, Catalog.RARE_DROPS["default"])
	var roll := randf()
	var rarity := ""
	if roll < float(chances[1]) * (1.0 + luck):
		rarity = "epic"
	elif roll < (float(chances[0]) + float(chances[1])) * (1.0 + luck):
		rarity = "rare"
	if rarity == "":
		return ""
	var pool: Array[String] = []
	for id in Catalog.ITEMS:
		if Catalog.ITEMS[id].get("rarity", "") == rarity:
			pool.append(id)
	return pool.pick_random()


# --- Handel ------------------------------------------------------------------

## Pris i en bestemt havn. Hver havn har sine egne prisniveauer (fast pr. havn).
func price_at(harbor_name: String, kind: String, id: String, buying: bool) -> int:
	var key := harbor_name + ":" + id
	if not _price_cache.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		_price_cache[key] = rng.randf_range(0.7, 1.4)
	var mod: float = _price_cache[key]
	var base: float = Catalog.ITEMS[id]["price"]
	if kind == "pirate":
		mod *= 1.15 if buying else 1.0
	var friend := harbor_level(harbor_name) * Catalog.FRIEND_PRICE_STEP
	var buy := maxi(1, int(round(base * mod * (1.0 - friend) * 1.15)))
	if buying:
		return buy
	var sell := maxi(1, int(round(base * mod * (1.0 + friend) * 0.85)))
	return mini(sell, maxi(1, buy - 1)) # man skal aldrig kunne tjene penge på at købe og sælge i samme havn


# --- Venskab med havnene ------------------------------------------------------

## Hvilken fraktion ejer havnen? (Navnene ligger fast pr. fraktion i Catalog.HARBOR_NAMES.)
func faction_of(harbor_name: String) -> String:
	for f in Catalog.HARBOR_NAMES:
		if harbor_name in Catalog.HARBOR_NAMES[f]:
			return f
	return "free"


func faction_rep(faction: String) -> float:
	return float(harbor_rep.get(faction, 0.0))


## Venskabsniveau med havnens fraktion – alle fraktionens havne giver samme priser og kasser.
func harbor_level(harbor_name: String) -> int:
	return faction_level(faction_of(harbor_name))


func faction_level(faction: String) -> int:
	var rep := faction_rep(faction)
	var level := 0
	for i in Catalog.FRIEND_LEVELS.size():
		if rep >= float(Catalog.FRIEND_LEVELS[i]["need"]):
			level = i
	return level


func add_harbor_rep(harbor_name: String, amount: float) -> void:
	var faction := faction_of(harbor_name)
	var before := faction_level(faction)
	harbor_rep[faction] = faction_rep(faction) + amount
	var after := faction_level(faction)
	if after > before:
		notify("The %s now sees you as: %s! Better prices in all their harbors%s" % [Catalog.FACTIONS[faction]["name"], Catalog.FRIEND_LEVELS[after]["name"],
			" and new crates" if _crate_unlocked_at(after) else ""], UiTheme.ACCENT)
		Sfx.play("coin")


func _crate_unlocked_at(level: int) -> bool:
	for crate in Catalog.CRATES:
		if int(crate["level"]) == level:
			return true
	return false


## Pris for en kasse i en bestemt havn (enkeltpriser minus kassens rabat).
func crate_price(harbor_name: String, kind: String, crate: Dictionary) -> int:
	var total := 0.0
	var contents: Dictionary = crate["contents"]
	for id in contents:
		var n := float(contents[id])
		if Catalog.ITEMS.has(id):
			total += price_at(harbor_name, kind, id, true) * n
		elif Catalog.SUPPLIES.has(id):
			total += float(Catalog.SUPPLIES[id]["price"]) * n
		elif id == "repair_kit":
			total += Catalog.REPAIR_KIT_PRICE * n
		elif Catalog.WEAPONS.has(id):
			total += float(Catalog.WEAPONS[id]["price"]) * n
	return maxi(1, roundi(total * (1.0 - float(crate["discount"]))))


## Plads en kasse fylder i lastrummet (kun handelsvarer fylder).
func crate_weight(crate: Dictionary) -> int:
	var w := 0
	var contents: Dictionary = crate["contents"]
	for id in contents:
		if Catalog.ITEMS.has(id):
			w += int(Catalog.ITEMS[id]["weight"]) * int(contents[id])
	return w


func buy_crate(harbor_name: String, kind: String, crate: Dictionary) -> bool:
	if cargo_used() + crate_weight(crate) > cargo_capacity():
		notify("Not enough room in the cargo hold for the crate", Color(1, 0.6, 0.5))
		return false
	if not spend(crate_price(harbor_name, kind, crate)):
		return false
	var contents: Dictionary = crate["contents"]
	for id in contents:
		add_item(id, int(contents[id]))
	notify("You bought a %s" % String(crate["name"]).to_lower(), Color(0.6, 0.9, 0.6))
	Sfx.play("chest")
	return true


## Antal af en vare i lastrummet.
func cargo_count(id: String) -> int:
	return int(cargo.get(id, 0))


func harbor_buys(kind: String, id: String) -> bool:
	return kind == "pirate" or Catalog.ITEMS[id]["category"] != "stolen"


# --- Verden ------------------------------------------------------------------

## Vanddybde 0..1 (0 ved stranden, 1 på åbent hav) – samme formel som hav-shaderen.
# --- Øer: hurtigt opslag i et gitter (verdenen har ~300 øer) ------------------

const ISLAND_CELL := 3000.0
var _island_grid: Dictionary = {} ## Vector2i -> Array[Island] (øer hvis lagune rækker ind i cellen)
const _NO_ISLANDS: Array = []


func register_island(island: Island, reach: float) -> void:
	var p := island.global_position
	var a := Vector2i(floori((p.x - reach) / ISLAND_CELL), floori((p.y - reach) / ISLAND_CELL))
	var b := Vector2i(floori((p.x + reach) / ISLAND_CELL), floori((p.y + reach) / ISLAND_CELL))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var key := Vector2i(x, y)
			if not _island_grid.has(key):
				_island_grid[key] = []
			(_island_grid[key] as Array).append(island)


func unregister_island(island: Island) -> void:
	for key in _island_grid:
		(_island_grid[key] as Array).erase(island)


## Øerne hvis lagune kan nå punktet.
func islands_near(pos: Vector2) -> Array:
	return _island_grid.get(Vector2i(floori(pos.x / ISLAND_CELL), floori(pos.y / ISLAND_CELL)), _NO_ISLANDS)


func water_depth(pos: Vector2) -> float:
	var depth := 1.0
	for island in islands_near(pos):
		depth = minf(depth, (island as Island).depth_at(pos))
	return depth


const SAFE_DEPTH := 0.45 ## i det stille, lave strandvand angriber ingen

## Fredeligt strandvand: fjendeskibe angriber dig ikke her.
func is_safe_water(pos: Vector2) -> bool:
	return water_depth(pos) < SAFE_DEPTH


func is_land(pos: Vector2) -> bool:
	for island in islands_near(pos):
		if (island as Island).is_on_land(pos):
			return true
	return false


func popup(text: String, pos: Vector2, color := Color.WHITE, icon := "") -> void:
	if world_root == null:
		return
	var p := PopupText.new()
	p.text = text
	p.icon = icon
	p.color = color
	p.position = pos
	world_root.add_child(p)


## Skriv en linje i loggen (med et lille ikon, f.eks. et vare-id eller "gold").
func log_line(text: String, color := Color.WHITE, icon := "") -> void:
	logged.emit(text, color, icon)


func notify(text: String, color := Color.WHITE) -> void:
	notification.emit(text, color)


# --- Gem og indlæs --------------------------------------------------------------

const _SAVED_FIELDS := ["gold", "cannonballs", "food", "crew", "user_zoom", "shot", "owned_weapons",
	"grenades", "selected_weapon", "cargo", "owned_ships", "active_ship_index", "unlocked_cosmetics", "towed",
	"owned_gear", "equipped", "tools", "repair_kits", "boxes", "captains", "captain_slots", "next_captain_id", "harbor_rep", "kingdom_wins", "kingdom_ready_at", "world_time", "visited_harbors", "captain_look"]


## Gemmer spillet. Kaldes automatisk (hvert minut, ved havn og når spillet lukkes).
func save_game() -> void:
	var data := {"version": SAVE_VERSION, "time": Time.get_unix_time_from_system()}
	for key in _SAVED_FIELDS:
		data[key] = get(key)
	var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
	if ship:
		data["ship_position"] = ship.global_position
		data["ship_rotation"] = ship.rotation
	if last_harbor:
		data["last_harbor"] = (last_harbor as Harbor).harbor_name
	for extra in _extra_savers:
		extra.call(data)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(var_to_str(data))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var text := FileAccess.get_file_as_string(save_path)
	var data = str_to_var(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Could not read the saved game")
		return false
	for key in _SAVED_FIELDS:
		if data.has(key):
			set(key, data[key])
	# Nye felter i ældre gemte skibe
	var old_upgrades: bool = int(data.get("version", 1)) < 2
	for config in owned_ships + towed:
		config["upgrades"].merge(new_ship_config(config["type"])["upgrades"])
		if old_upgrades: # de gamle 3 trin svarer til ca. 33 nye trin hver
			for id in config["upgrades"]:
				if id != "tow":
					config["upgrades"][id] = mini(int(config["upgrades"][id]) * 33, Catalog.UPGRADE_MAX_LEVEL)
		if not config.has("flag_style"):
			config["flag_style"] = "small"
	active_ship_index = clampi(active_ship_index, 0, owned_ships.size() - 1)
	# Venskab var pr. havn før – nu pr. fraktion
	for key in harbor_rep.keys():
		if not Catalog.FACTIONS.has(key):
			var f := faction_of(key)
			harbor_rep[f] = faction_rep(f) + float(harbor_rep[key])
			harbor_rep.erase(key)
	saved_ship_position = data.get("ship_position", null)
	if int(data.get("version", 1)) < 3:
		saved_ship_position = null # verdenen er bygget om (10x større) – start i havnen
	saved_ship_rotation = data.get("ship_rotation", 0.0)
	saved_harbor_name = data.get("last_harbor", "")
	# Older saves have no list of visited harbors: the start harbor and the last one you were in count
	visited_harbors[Catalog.HARBOR_NAMES["free"][0]] = true
	if saved_harbor_name != "":
		visited_harbors[saved_harbor_name] = true
	_loaded_data = data
	for extra in _extra_loaders:
		extra.call(data)
	loaded_from_save = true
	changed.emit()
	return true


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## Tests call this first: from then on they save, load and delete their own files and never
## touch the player's real save game or settings.
func use_test_files() -> void:
	_test_mode = true
	save_path = "user://test_save.dat"
	Settings.config_path = "user://test_settings.cfg"


## Andre systemer (f.eks. hjemøen) kan tilføje deres egne data til gemningen.
var _extra_savers: Array[Callable] = []
var _extra_loaders: Array[Callable] = []
var _loaded_data: Dictionary = {}


## Systemer der starter efter indlæsningen får de gemte data med det samme.
func register_save_hooks(saver: Callable, loader: Callable) -> void:
	_extra_savers.append(saver)
	_extra_loaders.append(loader)
	if not _loaded_data.is_empty():
		loader.call(_loaded_data)


# --- Input -------------------------------------------------------------------

## Nye taster oprettes her, så de altid findes (kan også ændres under Projekt → Input Map).
func _ensure_input_actions() -> void:
	_add_key_action("fire_left", [KEY_Q])
	_add_key_action("fire_right", [KEY_E])
	_add_key_action("attack", [KEY_SPACE])
	_add_key_action("map", [KEY_M])
	_add_key_action("zoom_in", [KEY_EQUAL, KEY_KP_ADD, KEY_PLUS])
	for i in 8:
		_add_key_action("weapon_%d" % (i + 1), [KEY_1 + i])
	_add_key_action("zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT])
	_add_key_action("repair", [KEY_R])
	_add_key_action("toggle_log", [KEY_L])
	if not InputMap.has_action("attack_mouse"):
		InputMap.add_action("attack_mouse")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack_mouse", mb)


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
