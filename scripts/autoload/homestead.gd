extends Node
## Hjemøen (autoload "Homestead"): marker, bygninger, lager og værksted.
## Alt vokser og produceres i rigtig tid – også mens spillet er lukket.

signal changed

var claimed := false
var plots: Array = [] ## [{"crop": "wheat", "planted": unix-tid}] – tom crop = ledig mark
var buildings: Dictionary = {} ## bygnings-id -> niveau
var storage: Dictionary = {} ## vare-id -> antal
var last_update: float = 0.0 ## unix-tid for sidste produktion
var layout: Dictionary = {} ## "x,y" -> {"type": "house"/"building"/"field", "id": bygnings-id, "plot": mark-nummer}
var workers: int = 0 ## ansatte arbejdere på øen
var assigned: Dictionary = {} ## bygnings-id -> antal arbejdere
var valid_cells: Array[Vector2i] = [] ## felter man kan bygge på (sættes af HomeSite ud fra øens form)
var last_report: Dictionary = {} ## hvad der skete mens du var væk (mad spist, sultne timer)


func _ready() -> void:
	reset()
	Game.register_save_hooks(_save, _load)


func reset() -> void:
	claimed = false
	plots = []
	buildings = {}
	storage = {}
	layout = {}
	workers = 0
	assigned = {}
	last_report = {}
	last_update = now()
	for id in Catalog.BUILDINGS:
		buildings[id] = 0
	_sync_plot_count()


func now() -> float:
	return Time.get_unix_time_from_system()


func plot_count() -> int:
	return Catalog.START_PLOTS + 2 * int(buildings.get("fields", 0))


func _sync_plot_count() -> void:
	while plots.size() < plot_count():
		plots.append({"crop": "", "planted": 0.0})


# --- Marker ---------------------------------------------------------------------

## 0..1 hvor langt en afgrøde er kommet.
func growth(plot: Dictionary) -> float:
	if plot["crop"] == "":
		return 0.0
	var minutes: float = Catalog.CROPS[plot["crop"]]["grow"]
	return clampf((now() - plot["planted"]) / (minutes * 60.0), 0.0, 1.0)


func seconds_left(plot: Dictionary) -> float:
	if plot["crop"] == "":
		return 0.0
	var minutes: float = Catalog.CROPS[plot["crop"]]["grow"]
	return maxf(minutes * 60.0 - (now() - plot["planted"]), 0.0)


func plant(index: int, crop: String) -> bool:
	if plots[index]["crop"] != "":
		return false
	if not Game.spend(Catalog.CROPS[crop]["seed_price"]):
		return false
	plots[index] = {"crop": crop, "planted": now()}
	changed.emit()
	return true


func harvest(index: int) -> void:
	var plot: Dictionary = plots[index]
	if plot["crop"] == "" or growth(plot) < 1.0:
		return
	var y: Array = Catalog.CROPS[plot["crop"]]["yield"]
	add_to_storage(y[0], y[1])
	Game.notify("+%d %s in storage" % [y[1], Game.item_name(y[0])], UiTheme.GOOD)
	plots[index] = {"crop": "", "planted": 0.0}
	changed.emit()


# --- Bygninger ------------------------------------------------------------------

func building_cost(id: String) -> int:
	var level: int = buildings.get(id, 0)
	var costs: Array = Catalog.BUILDINGS[id]["costs"]
	return -1 if level >= costs.size() else int(costs[level])


func upgrade_building(id: String) -> void:
	var cost := building_cost(id)
	if cost < 0 or not Game.spend(cost):
		return
	update_production() # det producerede indtil nu tælles med det gamle niveau
	buildings[id] = int(buildings.get(id, 0)) + 1
	_sync_plot_count()
	ensure_layout()
	Sfx.play("chest")
	changed.emit()


## Lægger produktionen siden sidst på lageret (max BUILDING_CAP_HOURS timer ad gangen).
## Bygningerne kører kun med arbejdere, og arbejderne spiser mad fra lageret.
## Der regnes i små skridt, så mad fra hønsehuset kan nå at blive spist undervejs.
func update_production() -> Dictionary:
	var t := now()
	var hours := clampf((t - last_update) / 3600.0, 0.0, Catalog.BUILDING_CAP_HOURS)
	last_update = t
	var produced := {}
	last_report = {"eaten": 0.0, "hungry_hours": 0.0}
	if not claimed or hours <= 0.0:
		return produced
	var steps := maxi(1, ceili(hours * 4.0))
	var dt := hours / steps
	for i in steps:
		var fed := 1.0
		if workers > 0:
			var need := workers * Catalog.WORKER_FOOD_PER_HOUR * dt
			var have := float(storage.get("food", 0)) + float(_partial.get("food", 0.0))
			fed = clampf(have / need, 0.0, 1.0)
			_eat(need * fed)
			last_report["eaten"] += need * fed
			if fed < 1.0:
				last_report["hungry_hours"] += dt * (1.0 - fed)
		for id in Catalog.BUILDINGS:
			var produce: Dictionary = Catalog.BUILDINGS[id]["produce"]
			if produce.is_empty():
				continue
			var crew := float(working(id))
			for item in produce:
				_partial[item] = _partial.get(item, 0.0) + float(produce[item]) * crew * dt * fed
				var whole := int(_partial[item])
				if whole > 0:
					_partial[item] -= whole
					add_to_storage(item, whole)
					produced[item] = produced.get(item, 0) + whole
	if not produced.is_empty() or last_report["eaten"] > 0.0:
		changed.emit()
	return produced


## Fjern mad fra lageret (brøkdele huskes, så små portioner også tæller).
func _eat(amount: float) -> void:
	var from_partial := minf(float(_partial.get("food", 0.0)), amount)
	_partial["food"] = float(_partial.get("food", 0.0)) - from_partial
	var rest := amount - from_partial
	if rest <= 0.0:
		return
	var whole := ceili(rest)
	var have := int(storage.get("food", 0))
	var taken := mini(whole, have)
	storage["food"] = have - taken
	if storage["food"] <= 0:
		storage.erase("food")
	_partial["food"] = float(_partial.get("food", 0.0)) + float(taken) - rest # overskud fra oprundingen


var _partial: Dictionary = {} ## brøkdele der endnu ikke er blevet til en hel enhed


# --- Arbejdere -----------------------------------------------------------------

func beds() -> int:
	return Catalog.HOUSE_BEDS + Catalog.BEDS_PER_COTTAGE * int(buildings.get("cottage", 0))


## Arbejdere der faktisk arbejder i en bygning (max én pr. niveau).
func working(id: String) -> int:
	return mini(int(assigned.get(id, 0)), int(buildings.get(id, 0)))


func free_workers() -> int:
	var used := 0
	for id in assigned:
		used += int(assigned[id])
	return maxi(workers - used, 0)


func hire_worker() -> bool:
	if workers >= beds():
		Game.notify("No free beds – build or upgrade a workers' cottage", UiTheme.BAD)
		return false
	if not Game.spend(Catalog.WORKER_PRICE):
		return false
	update_production()
	workers += 1
	# Sæt den nye arbejder i den første bygning der mangler folk
	for id in Catalog.BUILDINGS:
		if not Catalog.BUILDINGS[id]["produce"].is_empty() and int(assigned.get(id, 0)) < int(buildings.get(id, 0)):
			assigned[id] = int(assigned.get(id, 0)) + 1
			break
	changed.emit()
	return true


func dismiss_worker() -> void:
	if workers <= 0:
		return
	update_production()
	workers -= 1
	if free_workers() <= 0:
		for id in assigned:
			if int(assigned[id]) > 0:
				assigned[id] = int(assigned[id]) - 1
				break
	changed.emit()


func assign(id: String, delta: int) -> void:
	update_production()
	var now_n := int(assigned.get(id, 0))
	var target := clampi(now_n + delta, 0, int(buildings.get(id, 0)))
	if delta > 0 and free_workers() <= 0:
		return
	assigned[id] = target
	changed.emit()


## Mad til arbejderne: flyt mad fra skibet til lageret.
func store_food(amount: int) -> int:
	var n := mini(amount, Game.food)
	Game.food -= n
	add_to_storage("food", n)
	Game.changed.emit()
	changed.emit()
	return n


## Hvor mange timer maden på lageret rækker (INF hvis ingen arbejdere).
func food_hours() -> float:
	if workers <= 0:
		return INF
	return float(storage.get("food", 0)) / (workers * Catalog.WORKER_FOOD_PER_HOUR)


# --- Kasser ---------------------------------------------------------------------

## Pak markerede varer fra lageret i en ny kasse (købes samtidig). Returnerer antal pakkede ting.
func pack_box(box_type: String, marked: Array) -> int:
	var info: Dictionary = Catalog.BOXES[box_type]
	var available := 0
	for id in marked:
		available += int(storage.get(id, 0))
	if available <= 0:
		Game.notify("Mark some goods in storage first", UiTheme.BAD)
		return 0
	if Game.cargo_used() + int(info["weight"]) > Game.cargo_capacity():
		Game.notify("Not enough room in the cargo hold for the box", UiTheme.BAD)
		return 0
	if not Game.spend(int(info["price"])):
		return 0
	var room := int(info["capacity"])
	var contents := {}
	for id in marked:
		if room <= 0:
			break
		var n := take_from_storage(id, room)
		if n > 0:
			contents[id] = n
			room -= n
	Game.boxes.append({"type": box_type, "contents": contents})
	Sfx.play("chest", -4.0)
	Game.changed.emit()
	changed.emit()
	return int(info["capacity"]) - room


## Pak alle kasser ud igen på lageret.
func unpack_boxes() -> int:
	var n := 0
	for box in Game.boxes:
		for id in box["contents"]:
			add_to_storage(id, int(box["contents"][id]))
			n += int(box["contents"][id])
	Game.boxes.clear()
	Game.changed.emit()
	changed.emit()
	return n


# --- Byggefelt ----------------------------------------------------------------

func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func cell_of(k: String) -> Vector2i:
	var parts := k.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


func is_free(cell: Vector2i) -> bool:
	return cell in valid_cells and not layout.has(key(cell))


func building_cell(id: String) -> String:
	for k in layout:
		if layout[k]["type"] == "building" and layout[k]["id"] == id:
			return k
	return ""


func placeable(id: String) -> bool:
	return Catalog.BUILDINGS[id].get("placeable", true)


## Byg en ny bygning på et bestemt felt.
func build_at(id: String, cell: Vector2i) -> bool:
	if int(buildings.get(id, 0)) > 0 or not is_free(cell):
		return false
	var cost := building_cost(id)
	if cost < 0 or not Game.spend(cost):
		return false
	update_production()
	buildings[id] = 1
	layout[key(cell)] = {"type": "building", "id": id}
	Sfx.play("chest")
	changed.emit()
	return true


## Flyt hvad der står på et felt til et andet (ledigt) felt.
func move(from_key: String, to_cell: Vector2i) -> bool:
	if not layout.has(from_key) or not is_free(to_cell):
		return false
	layout[key(to_cell)] = layout[from_key]
	layout.erase(from_key)
	changed.emit()
	return true


## Sæt hus og marker, der ikke har et felt endnu, på ledige felter (også for ældre gemte spil).
func ensure_layout() -> void:
	if not claimed or valid_cells.is_empty():
		return
	var center := Vector2i(floori(Catalog.HOME_GRID.x / 2.0), floori(Catalog.HOME_GRID.y / 2.0))
	var by_distance: Array[Vector2i] = valid_cells.duplicate()
	by_distance.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - center).length() < Vector2(b - center).length())
	var has_house := false
	var placed_plots := {}
	var placed_buildings := {}
	for k in layout.keys():
		if not cell_of(k) in valid_cells:
			layout.erase(k) # øen har ændret form – sæt det på igen herunder
			continue
		match String(layout[k]["type"]):
			"house":
				has_house = true
			"field":
				placed_plots[int(layout[k]["plot"])] = true
			"building":
				placed_buildings[layout[k]["id"]] = true
	if not has_house:
		for c in by_distance:
			if is_free(c):
				layout[key(c)] = {"type": "house"}
				break
	for id in Catalog.BUILDINGS:
		if placeable(id) and int(buildings.get(id, 0)) > 0 and not placed_buildings.has(id):
			for c in by_distance:
				if is_free(c):
					layout[key(c)] = {"type": "building", "id": id}
					break
	for i in plots.size():
		if not placed_plots.has(i):
			for c in by_distance:
				if is_free(c):
					layout[key(c)] = {"type": "field", "plot": i}
					break


func set_valid_cells(cells: Array[Vector2i]) -> void:
	valid_cells = cells
	ensure_layout()


# --- Lager ----------------------------------------------------------------------

func add_to_storage(id: String, amount: int) -> void:
	storage[id] = int(storage.get(id, 0)) + amount


func take_from_storage(id: String, amount: int) -> int:
	var have: int = storage.get(id, 0)
	var n := mini(have, amount)
	storage[id] = have - n
	if storage[id] <= 0:
		storage.erase(id)
	changed.emit()
	return n


## Hvor mange af en vare man har i alt (lager + lastrum).
func total(id: String) -> int:
	return int(storage.get(id, 0)) + Game.cargo_count(id)


## Lægger alle materialer fra lastrummet på lageret.
func store_all_materials() -> int:
	var moved := 0
	for id in Game.cargo.keys():
		var cat: String = Catalog.ITEMS[id]["category"]
		if cat == "material":
			var n: int = Game.cargo[id]
			Game.remove_item(id, n)
			add_to_storage(id, n)
			moved += n
	changed.emit()
	return moved


# --- Værksted -------------------------------------------------------------------

func can_craft(recipe: Dictionary) -> bool:
	if int(buildings.get("workshop", 0)) < int(recipe["level"]):
		return false
	for id in recipe["inputs"]:
		if total(id) < int(recipe["inputs"][id]):
			return false
	if recipe.has("gear") and Game.owned_gear.get(recipe["gear"], false):
		return false
	return true


func craft(recipe: Dictionary) -> void:
	if not can_craft(recipe):
		return
	for id in recipe["inputs"]:
		var need: int = recipe["inputs"][id]
		need -= take_from_storage(id, need)
		if need > 0:
			Game.remove_item(id, need)
	if recipe.has("gear"):
		Game.owned_gear[recipe["gear"]] = true
		Game.notify("You crafted: %s" % Catalog.GEAR[recipe["gear"]]["name"], UiTheme.GOOD)
	else:
		var out: Array = recipe["output"]
		if Catalog.ITEMS.has(out[0]) and Catalog.ITEMS[out[0]]["category"] in ["material", "treasure"]:
			add_to_storage(out[0], out[1])
		else:
			Game.add_item(out[0], out[1])
		Game.notify("+%d %s" % [out[1], Game.item_name(out[0])], UiTheme.GOOD)
	Sfx.play("chest", -6.0)
	Game.changed.emit()
	changed.emit()


# --- Gem ------------------------------------------------------------------------

func _save(data: Dictionary) -> void:
	data["home"] = {"claimed": claimed, "plots": plots, "buildings": buildings, "storage": storage,
		"last_update": last_update, "partial": _partial, "layout": layout, "workers": workers, "assigned": assigned}


func _load(data: Dictionary) -> void:
	var h: Dictionary = data.get("home", {})
	if h.is_empty():
		return
	claimed = h.get("claimed", false)
	plots = h.get("plots", [])
	buildings.merge(h.get("buildings", {}), true)
	storage = h.get("storage", {})
	last_update = h.get("last_update", now())
	_partial = h.get("partial", {})
	layout = h.get("layout", {})
	if h.has("workers"):
		workers = int(h["workers"])
		assigned = h.get("assigned", {})
	else:
		# Ældre gemt spil: bygningerne får arbejdere (og senge) gratis, så intet går i stå
		workers = 0
		for id in buildings:
			if not Catalog.BUILDINGS.has(id) or Catalog.BUILDINGS[id]["produce"].is_empty():
				continue
			assigned[id] = int(buildings[id])
			workers += int(buildings[id])
		while beds() < workers:
			buildings["cottage"] = int(buildings.get("cottage", 0)) + 1
	_sync_plot_count()
	ensure_layout()
	changed.emit()
