extends CanvasLayer
## Havnemenu: Marked, Forsyninger, Værft (skibe), Opgraderinger og Udseende.
## Åbnes når skibet lægger til kaj. Spillet er pauset imens.

signal closed

var harbor: Harbor

var _root: Control
var _title: Label
var _purse: Label
var _tabs: TabContainer
var _pages: Dictionary = {}


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	Game.changed.connect(func() -> void:
		if visible:
			_refresh())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


var _candidates: Array = [] ## kaptajner man kan ansætte i denne havn (nye hver gang)
var _show_for_sale := false ## om listen med varer til salg er foldet ud
var _upgrade_index := -1 ## hvilket af dine skibe der vises under Upgrades (-1 = det du sejler)


func open(h: Harbor) -> void:
	harbor = h
	_upgrade_index = -1
	_candidates = []
	for i in 3:
		_candidates.append(Game.random_captain_candidate())
	visible = true
	get_tree().paused = true
	_tabs.current_tab = 0
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.make()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 14)
	panel.size = Vector2(592, 332)
	_root.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_title = UiTheme.label("", 14, UiTheme.ACCENT)
	titles.add_child(_title)
	_purse = UiTheme.label("", 9, UiTheme.MUTED)
	titles.add_child(_purse)
	header.add_child(UiTheme.button("Set sail (Esc)", close))

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tabs)
	for page_name in ["Market", "Supplies", "Weapons", "Gear", "Shipyard", "Upgrades", "Captains", "Looks", "Tailor"]:
		var content := VBoxContainer.new()
		var scroll := UiTheme.scroll(content)
		scroll.name = page_name
		_tabs.add_child(scroll)
		_pages[page_name] = content
	_tabs.tab_changed.connect(func(_t: int) -> void: _refresh())


func _refresh() -> void:
	if harbor == null:
		return
	_title.text = "%s – %s" % [harbor.harbor_name, "pirate harbor" if harbor.kind == "pirate" else "trade harbor"]
	_purse.text = "Gold: %d    Cargo: %d/%d    Crew: %d/%d    Cannonballs: %d    Food: %d" % [
		Game.gold, Game.cargo_used(), Game.cargo_capacity(), Game.crew, Game.max_crew(), Game.cannonballs, Game.food]
	match _tabs.get_current_tab_control().name:
		"Market": _build_market(_pages["Market"])
		"Supplies": _build_supplies(_pages["Supplies"])
		"Weapons": _build_weapons(_pages["Weapons"])
		"Gear": GearList.build(_pages["Gear"], true)
		"Shipyard": _build_shipyard(_pages["Shipyard"])
		"Upgrades": _build_upgrades(_pages["Upgrades"])
		"Captains": _build_captains(_pages["Captains"])
		"Looks": _build_looks(_pages["Looks"])
		"Tailor": _build_tailor(_pages["Tailor"])


# --- Marked -------------------------------------------------------------------

func _build_market(box: VBoxContainer) -> void:
	UiTheme.clear(box)
	var note := "Buys stolen goods – no questions asked." if harbor.kind == "pirate" else "Trade harbor: stolen goods can't be sold here."
	box.add_child(UiTheme.label(note, 9, UiTheme.MUTED))
	_build_friendship(box)
	if not Game.boxes.is_empty():
		var brow := HBoxContainer.new()
		box.add_child(brow)
		brow.add_child(Icons.make("medium_box", 16.0))
		var value := Game.boxes_value(harbor.harbor_name, harbor.kind)
		var bl := UiTheme.label("Boxes on board: %d (worth %d gold here)" % [Game.boxes.size(), value], 10, UiTheme.ACCENT)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(bl)
		brow.add_child(UiTheme.button("Sell all boxes (%d)" % value, func() -> void: Game.sell_all_boxes(harbor.harbor_name, harbor.kind)))
		box.add_child(HSeparator.new())
	# Dit lastrum: kun det du faktisk har med, kan sælges her
	box.add_child(UiTheme.label("Sell from your cargo", 11, UiTheme.ACCENT))
	var sell_grid := GridContainer.new()
	sell_grid.columns = 5
	box.add_child(sell_grid)
	var carried := 0
	for id in Catalog.ITEMS:
		var owned: int = Game.cargo.get(id, 0)
		if owned <= 0:
			continue
		carried += 1
		var item: Dictionary = Catalog.ITEMS[id]
		var buys := Game.harbor_buys(harbor.kind, id)
		var sell_price := Game.price_at(harbor.harbor_name, harbor.kind, id, false)
		var color: Color = UiTheme.BAD if item["category"] == "stolen" else Catalog.RARITY_COLORS.get(item.get("rarity", ""), UiTheme.TEXT)
		var name_cell := Icons.labeled(id, "%d x %s" % [owned, item["name"]], 10, color)
		name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell_grid.add_child(name_cell)
		sell_grid.add_child(UiTheme.label("%d each" % sell_price if buys else "not bought here", 10, UiTheme.TEXT if buys else UiTheme.MUTED))
		sell_grid.add_child(UiTheme.label("= %d" % (sell_price * owned) if buys else "", 10, UiTheme.GOOD))
		sell_grid.add_child(UiTheme.button("Sell 1", func() -> void: _sell(id, 1, sell_price), buys))
		sell_grid.add_child(UiTheme.button("Sell all", func() -> void: _sell(id, owned, sell_price), buys))
	if carried == 0:
		box.add_child(UiTheme.label("Your cargo hold is empty.", 10, UiTheme.MUTED))
	box.add_child(HSeparator.new())
	# Varer havnen sælger – skjult indtil man folder listen ud
	var for_sale: Array[String] = []
	for id in Catalog.ITEMS:
		if Catalog.ITEMS[id]["category"] == "trade" or id in ["wood", "stone", "iron_ore", "hemp", "wheat", "rope", "canvas"]:
			for_sale.append(id)
	box.add_child(UiTheme.button(("▼ Hide goods for sale" if _show_for_sale else "▶ Buy goods (%d for sale)" % for_sale.size()), func() -> void:
		_show_for_sale = not _show_for_sale
		_refresh()))
	if not _show_for_sale:
		return
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for id in for_sale:
		var item: Dictionary = Catalog.ITEMS[id]
		var buy_price := Game.price_at(harbor.harbor_name, harbor.kind, id, true)
		var name_cell := Icons.labeled(id, item["name"], 10, UiTheme.TEXT)
		name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_cell)
		grid.add_child(UiTheme.label("%d each" % buy_price))
		grid.add_child(UiTheme.button("Buy 1", func() -> void: _buy(id, 1, buy_price), Game.gold >= buy_price))
		grid.add_child(UiTheme.button("Buy 10", func() -> void: _buy(id, 10, buy_price), Game.gold >= buy_price * 10))


## Venskab med havnen og kasserne det låser op.
func _build_friendship(box: VBoxContainer) -> void:
	var faction := Game.faction_of(harbor.harbor_name)
	var fdata: Dictionary = Catalog.FACTIONS[faction]
	var level := Game.faction_level(faction)
	var rep := Game.faction_rep(faction)
	var levels := Catalog.FRIEND_LEVELS
	var frow := HBoxContainer.new()
	box.add_child(frow)
	var dot := ColorRect.new()
	dot.color = fdata["color"]
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frow.add_child(dot)
	frow.add_child(UiTheme.label("%s harbor – reputation is shared by all %d %s harbors" % [fdata["name"], int(fdata["harbors"]), fdata["short"]], 9, UiTheme.MUTED))
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(Icons.make("friend", 16.0))
	var bonus := roundi(level * Catalog.FRIEND_PRICE_STEP * 100.0)
	row.add_child(UiTheme.label("Reputation: %s (%d/%d)%s" % [levels[level]["name"], level, levels.size() - 1,
		"  –  buy -%d %%, sell +%d %%" % [bonus, bonus] if level > 0 else ""], 10, UiTheme.ACCENT))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	if level < levels.size() - 1:
		var from := float(levels[level]["need"])
		var to := float(levels[level + 1]["need"])
		bar.value = (rep - from) / (to - from) * 100.0
		row.add_child(UiTheme.label("Sell %d more gold → %s" % [ceili(to - rep), levels[level + 1]["name"]], 8, UiTheme.MUTED))
	else:
		bar.value = 100.0
	# Kasser
	var crates := HFlowContainer.new()
	box.add_child(crates)
	for crate in Catalog.CRATES:
		var unlocked := level >= int(crate["level"])
		var price := Game.crate_price(harbor.harbor_name, harbor.kind, crate)
		var cell := HBoxContainer.new()
		cell.add_child(Icons.make(crate["id"], 18.0))
		var parts: Array[String] = []
		var contents: Dictionary = crate["contents"]
		for id in contents:
			parts.append("%d %s" % [contents[id], Game.item_name(id).to_lower()])
		var b := UiTheme.button("%s (%d)" % [crate["name"], price] if unlocked else "%s (%s)" % [(crate["name"] as String).replace(" crate", ""), levels[crate["level"]]["name"]],
			func() -> void: Game.buy_crate(harbor.harbor_name, harbor.kind, crate), unlocked and Game.gold >= price)
		b.tooltip_text = "Contents: " + ", ".join(PackedStringArray(parts)) + "\nDiscount: %d %%" % roundi(float(crate["discount"]) * 100.0)
		cell.add_child(b)
		crates.add_child(cell)
	box.add_child(HSeparator.new())


func _buy(id: String, amount: int, price: int) -> void:
	if Game.cargo_used() + int(Catalog.ITEMS[id]["weight"]) * amount > Game.cargo_capacity():
		Game.notify("Not enough room in the cargo hold", UiTheme.BAD)
		return
	if Game.spend(price * amount):
		Game.add_item(id, amount)


func _sell(id: String, amount: int, price: int) -> void:
	if Game.remove_item(id, amount):
		Game.add_harbor_rep(harbor.harbor_name, price * amount)
		Game.add_gold(price * amount)
		Sfx.play("coin", -6.0)


# --- Forsyninger ------------------------------------------------------------

func _build_supplies(box: VBoxContainer) -> void:
	UiTheme.clear(box)
	for id in ["cannonball", "food"]:
		var info: Dictionary = Catalog.SUPPLIES[id]
		var row := HBoxContainer.new()
		box.add_child(row)
		var have: int = Game.cannonballs if id == "cannonball" else Game.food
		var l := UiTheme.label("%s – %d gold each (have %d)" % [info["name"], info["price"], have])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(Icons.make(id))
		row.add_child(l)
		for amount in [10, 50]:
			var cost: int = info["price"] * amount
			row.add_child(UiTheme.button("+%d (%d)" % [amount, cost], func() -> void:
				if Game.spend(cost):
					Game.add_item(id, amount), Game.gold >= cost))

	# Hyr sømænd
	var crew_row := HBoxContainer.new()
	box.add_child(crew_row)
	var crew_label := UiTheme.label("Sailors – %d gold per man (have %d / %d)" % [Catalog.CREW_PRICE, Game.crew, Game.max_crew()])
	crew_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_row.add_child(Icons.make("crew"))
	crew_row.add_child(crew_label)
	var room := Game.max_crew() - Game.crew
	for amount in [1, 5]:
		var n := mini(amount, room)
		var cost := n * Catalog.CREW_PRICE
		crew_row.add_child(UiTheme.button("Hire %d (%d)" % [amount, amount * Catalog.CREW_PRICE], func() -> void:
			if Game.spend(cost):
				Game.crew += n
				Game.changed.emit(), n > 0 and Game.gold >= cost))
	var fill_cost := room * Catalog.CREW_PRICE
	crew_row.add_child(UiTheme.button("Fill up (%d)" % fill_cost, func() -> void:
		if Game.spend(fill_cost):
			Game.crew += room
			Game.changed.emit(), room > 0 and Game.gold >= fill_cost))
	box.add_child(UiTheme.label("More sailors means better odds when boarding. More men eat more.", 9, UiTheme.MUTED))

	box.add_child(HSeparator.new())
	var config := Game.active_ship()
	var stats := Game.ship_stats(config)
	var missing := int(ceil(stats["max_hp"] - config["hp"]))
	var repair_cost := missing * Catalog.REPAIR_PRICE_PER_HP
	var repair_row := HBoxContainer.new()
	box.add_child(repair_row)
	var repair_label := UiTheme.label("Repair %s: %d / %d hull" % [config["name"], int(config["hp"]), int(stats["max_hp"])])
	repair_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repair_row.add_child(Icons.make("repair_kit"))
	repair_row.add_child(repair_label)
	repair_row.add_child(UiTheme.button("Repair all (%d)" % repair_cost, func() -> void:
		if Game.spend(repair_cost):
			config["hp"] = stats["max_hp"]
			Game.changed.emit(), missing > 0 and Game.gold >= repair_cost))
	box.add_child(UiTheme.label("Food is slowly eaten while sailing. Without food the crew sails slower.", 9, UiTheme.MUTED))


# --- Våben ---------------------------------------------------------------------

func _build_weapons(box: VBoxContainer) -> void:
	UiTheme.clear(box)
	box.add_child(UiTheme.label("Firearms (used on foot – not while swimming)", 10, UiTheme.ACCENT))
	for id in Catalog.WEAPON_ORDER:
		var w: Dictionary = Catalog.WEAPONS[id]
		if w["kind"] != "gun":
			continue
		var owned: bool = Game.owned_weapons.get(id, false)
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(Icons.make(id, 18.0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UiTheme.label(w["name"] + ("  (owned)" if owned else ""), 10, UiTheme.GOOD if owned else UiTheme.TEXT))
		info.add_child(UiTheme.label("Damage %d%s · range %d · reload %.1f s · %d shots per load" % [
			int(w["damage"]), " x%d pellets" % w["pellets"] if w["pellets"] > 1 else "", int(w["range"]), w["reload"], w["ammo"]], 8, UiTheme.MUTED))
		row.add_child(UiTheme.button("Owned" if owned else "Buy (%d)" % w["price"], func() -> void:
			if Game.spend(w["price"]):
				Game.owned_weapons[id] = true
				Game.changed.emit(), not owned and Game.gold >= w["price"]))

	box.add_child(UiTheme.label("Tools", 10, UiTheme.ACCENT))
	for tool_id in Catalog.TOOLS:
		var tool: Dictionary = Catalog.TOOLS[tool_id]
		var has_tool: bool = Game.tools.get(tool_id, false)
		var trow := HBoxContainer.new()
		box.add_child(trow)
		var tl := UiTheme.label(tool["name"] + ("  (owned)" if has_tool else ""), 10, UiTheme.GOOD if has_tool else UiTheme.TEXT)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trow.add_child(Icons.make(tool_id))
		trow.add_child(tl)
		trow.add_child(UiTheme.button("Owned" if has_tool else "Buy (%d)" % tool["price"], func() -> void:
			if Game.spend(tool["price"]):
				Game.tools[tool_id] = true
				Game.changed.emit(), not has_tool and Game.gold >= tool["price"]))
	box.add_child(HSeparator.new())

	var shot_row := HBoxContainer.new()
	box.add_child(shot_row)
	var sl := UiTheme.label("Powder and shot – %d gold each (have %d)" % [Catalog.SUPPLIES["shot"]["price"], Game.shot])
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shot_row.add_child(Icons.make("shot"))
	shot_row.add_child(sl)
	for amount in [20, 100]:
		var cost: int = Catalog.SUPPLIES["shot"]["price"] * amount
		shot_row.add_child(UiTheme.button("+%d (%d)" % [amount, cost], func() -> void:
			if Game.spend(cost):
				Game.add_item("shot", amount), Game.gold >= cost))

	box.add_child(HSeparator.new())
	box.add_child(UiTheme.label("Grenades (thrown at the mouse)", 10, UiTheme.ACCENT))
	var effects := {"explosive": "Blows up everything nearby", "fire": "Fire that burns for several seconds",
		"poison": "Poison cloud – hurts and slows animals", "flash": "Blinds animals so they freeze"}
	for id in Catalog.WEAPON_ORDER:
		var w: Dictionary = Catalog.WEAPONS[id]
		if w["kind"] != "grenade":
			continue
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(Icons.make(id, 18.0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UiTheme.label("%s – %d gold (have %d)" % [w["name"], w["price"], Game.grenades.get(id, 0)]))
		info.add_child(UiTheme.label(effects[w["effect"]], 8, UiTheme.MUTED))
		for amount in [1, 5]:
			var cost: int = w["price"] * amount
			row.add_child(UiTheme.button("+%d (%d)" % [amount, cost], func() -> void:
				if Game.spend(cost):
					Game.add_item(id, amount), Game.gold >= cost))


# --- Værft --------------------------------------------------------------------

func _build_shipyard(box: VBoxContainer) -> void:
	UiTheme.clear(box)
	box.add_child(UiTheme.label("Your ships", 11, UiTheme.ACCENT))
	for i in Game.owned_ships.size():
		var config: Dictionary = Game.owned_ships[i]
		var stats := Game.ship_stats(config)
		var row := HBoxContainer.new()
		box.add_child(row)
		var active := i == Game.active_ship_index
		row.add_child(ShipPreview.new(config["type"], config))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		# Skibets navn kan rettes direkte (Enter eller klik væk for at gemme)
		var name_edit := LineEdit.new()
		name_edit.text = config["name"]
		name_edit.max_length = 28
		name_edit.custom_minimum_size = Vector2(170, 0)
		name_edit.tooltip_text = "Click to rename your ship"
		name_edit.add_theme_font_size_override("font_size", 10)
		var save_name := func(text: String) -> void:
			var clean := text.strip_edges()
			if clean != "":
				config["name"] = clean
		name_edit.text_submitted.connect(func(text: String) -> void:
			save_name.call(text)
			name_edit.release_focus())
		name_edit.focus_exited.connect(func() -> void: save_name.call(name_edit.text))
		info.add_child(name_edit)
		info.add_child(UiTheme.label("%s · %d/%d hull · %d cannons per side · room for %d men%s" % [
			Catalog.SHIPS[config["type"]]["name"], int(config["hp"]), int(stats["max_hp"]), config["cannons"], stats["max_crew"], " · sailing now" if active else ""],
			8, UiTheme.GOOD if active else UiTheme.MUTED))
		row.add_child(UiTheme.button("Sail this one", func() -> void: _switch_ship(i), not active))
		var sell_price := int(Catalog.SHIPS[config["type"]]["price"] * 0.5)
		row.add_child(UiTheme.button("Sell (%d)" % sell_price, func() -> void: _sell_ship(i, sell_price), not active))

	if not Game.towed.is_empty():
		box.add_child(HSeparator.new())
		box.add_child(UiTheme.label("In tow (%d / %d slots)" % [Game.towed.size(), int(Game.ship_stats(Game.active_ship())["tow"])], 11, UiTheme.ACCENT))
		for i in Game.towed.size():
			var tc: Dictionary = Game.towed[i]
			var trow := HBoxContainer.new()
			box.add_child(trow)
			trow.add_child(ShipPreview.new(tc["type"], tc))
			var price := Game.towed_sell_price(tc)
			var tl := UiTheme.label("%s – hull %d/%d" % [tc["name"], int(tc["hp"]), int(Game.ship_stats(tc)["max_hp"])], 9)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trow.add_child(tl)
			trow.add_child(UiTheme.button("Sell (%d)" % price, func() -> void:
				Game.towed.remove_at(i)
				Game.add_gold(price)
				Sfx.play("coin")
				Game.notify("Sold for %d gold" % price, UiTheme.GOOD)))
			trow.add_child(UiTheme.button("Keep in fleet", func() -> void:
				Game.owned_ships.append(Game.towed[i])
				Game.towed.remove_at(i)
				Game.changed.emit()))

	box.add_child(HSeparator.new())
	box.add_child(UiTheme.label("Ships for sale", 11, UiTheme.ACCENT))
	for type in Catalog.SHIPS:
		var ship: Dictionary = Catalog.SHIPS[type]
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(ShipPreview.new(type))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UiTheme.label("%s – %d gold" % [ship["name"], ship["price"]], 10, UiTheme.TEXT))
		info.add_child(UiTheme.label(ship["description"], 8, UiTheme.MUTED))
		info.add_child(UiTheme.label("Hull %d · speed %.0f · cargo %d · %d cannons/side · %d men" % [
			ship["max_hp"], ship["speed"] / 10.0, ship["cargo"], ship["max_cannons"], ship["crew"]], 8, UiTheme.MUTED))
		row.add_child(UiTheme.button("Buy", func() -> void: _buy_ship(type), Game.gold >= ship["price"]))


func _switch_ship(index: int) -> void:
	var new_capacity := int(Game.ship_stats(Game.owned_ships[index])["cargo"])
	if Game.cargo_used() > new_capacity:
		Game.notify("Too much cargo for that ship – sell something first", UiTheme.BAD)
		return
	Game.set_active_ship(index)
	Game.notify("You are now sailing the %s" % Game.active_ship()["name"], UiTheme.GOOD)


func _sell_ship(index: int, price: int) -> void:
	var name_text: String = Game.owned_ships[index]["name"]
	Game.owned_ships.remove_at(index)
	if Game.active_ship_index > index:
		Game.active_ship_index -= 1
	Game.add_gold(price)
	Game.notify("%s sold for %d gold" % [name_text, price], UiTheme.GOOD)


func _buy_ship(type: String) -> void:
	if Game.spend(Catalog.SHIPS[type]["price"]):
		var config := Game.new_ship_config(type)
		var count := Game.owned_ships.filter(func(c: Dictionary) -> bool: return c["type"] == type).size()
		if count > 0:
			config["name"] = "%s %d" % [config["name"], count + 1]
		Game.owned_ships.append(config)
		Game.notify("You bought a %s! Pick it under 'Your ships'." % Catalog.SHIPS[type]["name"], UiTheme.GOOD)
		Game.changed.emit()


# --- Opgraderinger --------------------------------------------------------------

func _build_upgrades(box: VBoxContainer) -> void:
	UiTheme.clear(box)
	if _upgrade_index < 0 or _upgrade_index >= Game.owned_ships.size():
		_upgrade_index = Game.active_ship_index
	var config: Dictionary = Game.owned_ships[_upgrade_index]
	var stats := Game.ship_stats(config)
	# Vælg hvilket skib der skal opgraderes – også dem du ikke sejler lige nu
	var pick_row := HBoxContainer.new()
	box.add_child(pick_row)
	var head := UiTheme.label("Upgrade ship:", 11, UiTheme.ACCENT)
	pick_row.add_child(head)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_theme_font_size_override("font_size", 10)
	for i in Game.owned_ships.size():
		var c: Dictionary = Game.owned_ships[i]
		var role := " · sailing now" if i == Game.active_ship_index else ""
		var cap := Game.captain_by_id(int(c.get("captain", 0)))
		if role == "" and not cap.is_empty():
			role = " · Capt. %s" % cap["name"]
		picker.add_item("%s (%s)%s" % [c["name"], Catalog.SHIPS[c["type"]]["name"], role], i)
	picker.select(_upgrade_index)
	picker.item_selected.connect(func(i: int) -> void:
		_upgrade_index = i
		_build_upgrades.call_deferred(box))
	pick_row.add_child(picker)
	pick_row.add_child(ShipPreview.new(config["type"], config))

	var cannon_row := HBoxContainer.new()
	box.add_child(cannon_row)
	var cl := UiTheme.label("Cannons per side: %d / %d" % [config["cannons"], stats["max_cannons"]])
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cannon_row.add_child(Icons.make("cannons", 18.0))
	cannon_row.add_child(cl)
	var can_add: bool = config["cannons"] < stats["max_cannons"]
	cannon_row.add_child(UiTheme.button("+1 cannon per side (%d)" % Catalog.CANNON_PRICE if can_add else "Fully armed", func() -> void:
		if Game.spend(Catalog.CANNON_PRICE):
			config["cannons"] += 1
			Game.changed.emit(), can_add and Game.gold >= Catalog.CANNON_PRICE))

	for id in Catalog.UPGRADES:
		var up: Dictionary = Catalog.UPGRADES[id]
		var level: int = config["upgrades"].get(id, 0)
		var max_level := Catalog.upgrade_max(id)
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(Icons.make(id, 18.0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UiTheme.label("%s – step %d / %d" % [up["name"], level, max_level]))
		var bar := ProgressBar.new()
		bar.max_value = max_level
		bar.value = level
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(150, 5)
		info.add_child(bar)
		info.add_child(UiTheme.label(up["text"], 8, UiTheme.MUTED))
		for steps in ([1, 10] if max_level > 10 else [1]):
			var cost := _upgrade_steps_cost(id, level, steps)
			var text := "Max" if cost < 0 else ("+%d (%d)" % [steps, cost])
			row.add_child(UiTheme.button(text, func() -> void:
				if Game.spend(cost):
					config["upgrades"][id] = mini(level + steps, max_level)
					if id == "hull":
						config["hp"] = Game.ship_stats(config)["max_hp"]
					Sfx.play("coin", -6.0)
					Game.changed.emit(), cost >= 0 and Game.gold >= cost))


## Samlet pris for flere trin (færre hvis max nås). -1 hvis allerede på max.
func _upgrade_steps_cost(id: String, level: int, steps: int) -> int:
	var total := 0
	for i in steps:
		var price := Catalog.upgrade_price(id, level + i)
		if price < 0:
			break
		total += price
	return total if total > 0 else -1


# --- Kaptajner -------------------------------------------------------------------

func _build_captains(box: VBoxContainer) -> void:
	UiTheme.clear(box)
	box.add_child(UiTheme.label("Hired captains sail your other ships as escorts. They follow you, fight pirates and pick up flotsam. Their crews join you when you challenge a kingdom.", 9, UiTheme.MUTED))
	var slot_row := HBoxContainer.new()
	box.add_child(slot_row)
	slot_row.add_child(Icons.make("captain", 16.0))
	var sl := UiTheme.label("Captain slots: %d / %d in use" % [Game.captains.size(), Game.captain_slots], 11, UiTheme.ACCENT)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_row.add_child(sl)
	var extra := Game.captain_slots - Catalog.CAPTAIN_START_SLOTS
	if extra < Catalog.CAPTAIN_SLOT_PRICES.size():
		var price: int = Catalog.CAPTAIN_SLOT_PRICES[extra]
		slot_row.add_child(UiTheme.button("Buy slot (%d)" % price, func() -> void:
			if Game.spend(price):
				Game.captain_slots += 1
				Game.changed.emit(), Game.gold >= price))
	else:
		slot_row.add_child(UiTheme.label("All slots bought", 9, UiTheme.MUTED))

	if Game.captains.is_empty():
		box.add_child(UiTheme.label("You have no captains yet – hire one below.", 9, UiTheme.MUTED))
	for c in Game.captains:
		_captain_row(box, c)
	if Game.owned_ships.size() < 2:
		box.add_child(UiTheme.label("Tip: Buy another ship at the shipyard – a captain needs a ship to command.", 9, UiTheme.ACCENT))

	box.add_child(HSeparator.new())
	box.add_child(UiTheme.label("Captains looking for work", 11, UiTheme.ACCENT))
	var taken: Array = Game.captains.map(func(c: Dictionary) -> String: return c["name"])
	for cand in _candidates:
		if cand["name"] in taken:
			continue
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(Icons.make("captain", 18.0))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UiTheme.label(cand["name"], 10))
		info.add_child(UiTheme.label(_skills_text(cand), 8, UiTheme.MUTED))
		var price := Catalog.captain_hire_price(cand)
		var room := Game.captains.size() < Game.captain_slots
		row.add_child(UiTheme.button("Hire (%d)" % price if room else "No free slot", func() -> void:
			if Game.hire_captain(cand):
				_candidates.erase(cand)
				_refresh(), room and Game.gold >= price))


func _skills_text(c: Dictionary) -> String:
	var parts: Array[String] = []
	for skill in Catalog.CAPTAIN_SKILLS:
		parts.append("%s %d" % [Catalog.CAPTAIN_SKILLS[skill]["name"], int(c[skill])])
	return " · ".join(PackedStringArray(parts))


func _captain_row(box: VBoxContainer, c: Dictionary) -> void:
	var id := int(c["id"])
	var panel := VBoxContainer.new()
	box.add_child(panel)
	var top := HBoxContainer.new()
	panel.add_child(top)
	top.add_child(Icons.make("captain", 20.0))
	var ship := Game.captain_ship(id)
	var where := "commands the %s" % ship["name"] if not ship.is_empty() else "waiting ashore"
	var hp_text := ""
	if not ship.is_empty():
		hp_text = "  (hull %d/%d)" % [int(ship["hp"]), int(Game.escort_stats(ship)["max_hp"])]
	var name_label := UiTheme.label("%s – %s%s" % [c["name"], where, hp_text], 10, UiTheme.GOOD if not ship.is_empty() else UiTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	# Vælg skib
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_item("Ashore", 0)
	var selected := 0
	var indices: Array[int] = [-1]
	for i in Game.owned_ships.size():
		if i == Game.active_ship_index:
			continue
		var cfg: Dictionary = Game.owned_ships[i]
		var other := int(cfg.get("captain", 0))
		var label: String = cfg["name"]
		if other != 0 and other != id:
			label += " (%s)" % Game.captain_by_id(other).get("name", "?")
		pick.add_item(label, indices.size())
		indices.append(i)
		if other == id:
			selected = indices.size() - 1
	pick.select(selected)
	pick.item_selected.connect(func(index: int) -> void: Game.assign_captain(id, indices[index]))
	top.add_child(pick)
	if not ship.is_empty():
		var stats := Game.escort_stats(ship)
		var missing := int(ceil(float(stats["max_hp"]) - float(ship["hp"])))
		var cost := missing * Catalog.REPAIR_PRICE_PER_HP
		top.add_child(UiTheme.button("Repair (%d)" % cost, func() -> void:
			if Game.spend(cost):
				ship["hp"] = stats["max_hp"]
				Game.changed.emit(), missing > 0 and Game.gold >= cost))
	top.add_child(UiTheme.button("Dismiss", func() -> void: Game.dismiss_captain(id)))
	# Evner
	var skills := HBoxContainer.new()
	panel.add_child(skills)
	skills.add_child(Control.new())
	(skills.get_child(0) as Control).custom_minimum_size = Vector2(22, 0)
	for skill in Catalog.CAPTAIN_SKILLS:
		var info: Dictionary = Catalog.CAPTAIN_SKILLS[skill]
		var level := int(c[skill])
		var price := Catalog.captain_upgrade_price(level)
		var cell := HBoxContainer.new()
		cell.add_child(Icons.make(skill, 14.0))
		var b := UiTheme.button("%s %d/%d%s" % [info["name"], level, Catalog.CAPTAIN_MAX_LEVEL, "" if price < 0 else "  +1 (%d)" % price],
			func() -> void: Game.upgrade_captain(id, skill), price > 0 and Game.gold >= price)
		b.tooltip_text = info["text"]
		cell.add_child(b)
		skills.add_child(cell)
	# Besætning på eskorteskibet – går med, når du udfordrer et kongerige
	if not ship.is_empty():
		var crew_row := HBoxContainer.new()
		panel.add_child(crew_row)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(22, 0)
		crew_row.add_child(pad)
		crew_row.add_child(Icons.make("crew", 14.0))
		var cap := int(Game.ship_stats(ship)["max_crew"])
		var have := int(ship.get("crew", 0))
		var cl := UiTheme.label("Crew: %d / %d" % [have, cap], 9)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		crew_row.add_child(cl)
		crew_row.add_child(UiTheme.button("+5 from your ship", func() -> void: Game.move_crew_to_escort(ship, 5), Game.crew > 1 and have < cap))
		crew_row.add_child(UiTheme.button("-5 back", func() -> void: Game.move_crew_to_escort(ship, -5), have > 0 and Game.crew < Game.max_crew()))
		var fill := cap - have
		crew_row.add_child(UiTheme.button("Hire to full (%d)" % (fill * Catalog.CREW_PRICE), func() -> void: Game.hire_escort_crew(ship, fill),
			fill > 0 and Game.gold >= fill * Catalog.CREW_PRICE))
	panel.add_child(HSeparator.new())


# --- Looks (the ship) and Tailor (the captain) ---------------------------------------------------
# Both use StyleEditor: a live model, the parts, and the chosen part's palette. The editor is
# built once and then only refreshed, so it keeps the part you are on and what you try on.

func _build_looks(box: VBoxContainer) -> void:
	_build_style_editor(box, Catalog.SHIP_STYLE_PARTS, Game.active_ship(), "", func() -> Control:
		var model := ShipPreview.new(Game.active_ship()["type"], Game.active_ship())
		model.detailed = true
		return model)


func _build_tailor(box: VBoxContainer) -> void:
	_build_style_editor(box, Catalog.CAPTAIN_STYLE_PARTS, Game.captain_look, "cap_", func() -> Control:
		return CaptainPreview.new())


func _build_style_editor(box: VBoxContainer, parts: Array, values: Dictionary, prefix: String, make_model: Callable) -> void:
	var existing: StyleEditor = null
	for child in box.get_children():
		if child is StyleEditor and not child.is_queued_for_deletion():
			existing = child
	if existing and is_same(existing.target, values):
		existing.refresh()
		return
	UiTheme.clear(box)
	var editor := StyleEditor.new()
	box.add_child(editor)
	editor.setup(parts, values, make_model.call(), prefix)
