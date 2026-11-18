class_name GearList
## Bygger listen over udstyr – bruges både i havnens butik og i ESC-menuen.

static func stat_text(g: Dictionary) -> String:
	match g["slot"]:
		"hat":
			return "Luck +%d %% (more gold and better loot)" % roundi(g["luck"] * 100.0) if g["luck"] > 0.0 else "No bonus"
		"coat":
			return "Armor %d %% (less damage)" % roundi(g["armor"] * 100.0) if g["armor"] > 0.0 else "No bonus"
		"sword":
			return "Damage %d · %.2f s between swings · reach %d" % [int(g["damage"]), g["cooldown"], int(g["reach"])]
	return ""


## shop = true: vis købsknapper. Ellers kun det man ejer.
static func build(box: VBoxContainer, shop: bool) -> void:
	UiTheme.clear(box)
	box.add_child(UiTheme.label("Luck %d %%   Armor %d %%   Weapon: %s" % [
		roundi(Game.gear_stat("luck") * 100.0), roundi(Game.gear_stat("armor") * 100.0), Game.sword()["name"]], 9, UiTheme.MUTED))
	for slot in Catalog.GEAR_SLOTS:
		box.add_child(UiTheme.label(Catalog.GEAR_SLOTS[slot], 10, UiTheme.ACCENT))
		for id in Catalog.GEAR:
			var g: Dictionary = Catalog.GEAR[id]
			if g["slot"] != slot:
				continue
			var owned: bool = Game.owned_gear.get(id, false)
			if not shop and not owned:
				continue
			var worn: bool = Game.equipped.get(slot, "") == id
			var row := HBoxContainer.new()
			box.add_child(row)
			row.add_child(Icons.make(id, 20.0))
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)
			info.add_child(UiTheme.label(g["name"] + ("  (equipped)" if worn else ""), 10, UiTheme.GOOD if worn else UiTheme.TEXT))
			info.add_child(UiTheme.label(stat_text(g), 8, UiTheme.MUTED))
			if owned:
				row.add_child(UiTheme.button("Equipped" if worn else "Equip", func() -> void: Game.equip(id), not worn))
			else:
				row.add_child(UiTheme.button("Buy (%d)" % g["price"], func() -> void:
					if Game.spend(g["price"]):
						Game.owned_gear[id] = true
						Game.equip(id), Game.gold >= g["price"]))
