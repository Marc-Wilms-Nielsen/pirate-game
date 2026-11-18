class_name StyleEditor
extends HBoxContainer
## The customization screen used by the harbor's Looks (ship) and Tailor (captain) tabs:
## a live model on the left, the list of parts, and the chosen part's palette.
##
## Click an option you own and it is used at once. Click one you don't own and the model shows
## it ("try it on") with a Buy button underneath; pick another part or option and the model goes
## back to what you have. Prices: the first option of a part is free, the rest are bought once
## (Game.unlocked_cosmetics, key "<prefix><unlock>:<option id>" – same keys as the old Looks tab).
##
## setup(parts, target, preview, prefix): target is the dictionary that holds the choices (the
## ship's config or Game.captain_look); preview must have show_values(values).

var parts: Array = []
var target: Dictionary = {}
var prefix := "" ## unlock key prefix ("" for the ship, "cap_" for the captain)
var preview: Control
var _part := 0
var _draft: Dictionary = {}
var _trying: Dictionary = {} ## {"part": .., "option": ..} while trying on something not owned
var _parts_box: VBoxContainer
var _title: Label
var _grid: GridContainer
var _info: Label
var _buy: Button


func setup(style_parts: Array, values: Dictionary, model: Control, unlock_prefix := "") -> void:
	parts = style_parts
	target = values
	preview = model
	prefix = unlock_prefix
	add_theme_constant_override("separation", 10)
	preview.custom_minimum_size = Vector2(182, 236)
	add_child(preview)
	var parts_scroll := ScrollContainer.new()
	parts_scroll.custom_minimum_size = Vector2(100, 236)
	parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(parts_scroll)
	_parts_box = VBoxContainer.new()
	_parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parts_box.add_theme_constant_override("separation", 3)
	parts_scroll.add_child(_parts_box)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	_title = UiTheme.label("", 12, UiTheme.ACCENT)
	right.add_child(_title)
	var grid_scroll := ScrollContainer.new()
	grid_scroll.custom_minimum_size = Vector2(0, 170)
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(grid_scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(_grid)
	_info = UiTheme.label("", 9, UiTheme.MUTED)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 200
	right.add_child(_info)
	_buy = UiTheme.button("Buy", _buy_trying)
	_buy.visible = false
	right.add_child(_buy)
	_show_part(0)


## Called when the game changes (gold, a purchase): keeps the chosen part and the try-on.
func refresh() -> void:
	_build_parts()
	_build_options()
	_update_info()


func current_part() -> Dictionary:
	return parts[_part]


func _show_part(index: int) -> void:
	_part = clampi(index, 0, parts.size() - 1)
	_trying = {}
	_draft = target.duplicate(true)
	preview.call("show_values", _draft)
	refresh()


func _build_parts() -> void:
	UiTheme.clear(_parts_box)
	for i in parts.size():
		var p: Dictionary = parts[i]
		var b := UiTheme.button(("▸ " if i == _part else "") + String(p["name"]), _show_part.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", UiTheme.text_size(9))
		if i == _part:
			b.add_theme_color_override("font_color", UiTheme.ACCENT)
		_parts_box.add_child(b)


func _build_options() -> void:
	var part := current_part()
	_title.text = String(part["name"])
	UiTheme.clear(_grid)
	var current := value_of(part)
	var tried := String((_trying.get("option", {}) as Dictionary).get("id", ""))
	for opt in options_of(part):
		var owned := is_owned(part, opt)
		var mark := "✓ " if opt["id"] == current else ("◌ " if opt["id"] == tried else "")
		var text := "%s%s" % [mark, opt["name"]]
		if not owned:
			text += "  %d" % int(opt["price"])
		var b := UiTheme.button(text, _pick.bind(opt))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", UiTheme.text_size(9))
		b.custom_minimum_size = Vector2(112, 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not owned:
			b.add_theme_color_override("font_color", UiTheme.MUTED)
		if opt.has("color"): # a colour swatch at the left of the button
			b.text = "      " + b.text
			var sw := ColorRect.new()
			sw.color = _swatch_color(part, opt)
			sw.position = Vector2(6, 6)
			sw.size = Vector2(9, 9)
			sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(sw)
		_grid.add_child(b)


func _swatch_color(part: Dictionary, opt: Dictionary) -> Color:
	var c: Color = opt["color"]
	if part["key"] == "hull": # hull paints tint the wood
		c = Color(0.6, 0.42, 0.25) * c
	elif part["key"] == "sail":
		c = Color(0.96, 0.92, 0.82) * c
	return Color(c, 1.0)


func _pick(opt: Dictionary) -> void:
	var part := current_part()
	_draft = target.duplicate(true)
	_apply(part, opt, _draft)
	preview.call("show_values", _draft)
	if is_owned(part, opt):
		_trying = {}
		_apply(part, opt, target)
		Game.changed.emit() # the ship (or captain) out in the world changes too
	else:
		_trying = {"part": part, "option": opt}
	refresh()


func _buy_trying() -> void:
	if _trying.is_empty():
		return
	var part: Dictionary = _trying["part"]
	var opt: Dictionary = _trying["option"]
	if not Game.spend(int(opt["price"])):
		return
	Game.unlocked_cosmetics[unlock_key(part, opt)] = true
	_apply(part, opt, target)
	_trying = {}
	_draft = target.duplicate(true)
	preview.call("show_values", _draft)
	Sfx.play("coin")
	Game.notify("Bought: %s – %s" % [part["name"], opt["name"]], UiTheme.GOOD)
	Game.changed.emit()


func _update_info() -> void:
	if _trying.is_empty():
		var part := current_part()
		var opt := Catalog.style_option(options_of(part), value_of(part))
		_info.text = "Using: %s. Pick another to try it on the model." % opt["name"]
		_info.add_theme_color_override("font_color", UiTheme.MUTED)
		_buy.visible = false
	else:
		var opt: Dictionary = _trying["option"]
		_info.text = "Trying on: %s – %d gold" % [opt["name"], int(opt["price"])]
		_info.add_theme_color_override("font_color", UiTheme.ACCENT)
		_buy.visible = true
		_buy.text = "Buy for %d gold" % int(opt["price"])
		_buy.disabled = Game.gold < int(opt["price"])


# --- Parts: plain choices and on/off decorations ----------------------------------------------

func options_of(part: Dictionary) -> Array:
	if part.has("deco"):
		var price := int(Catalog.DECORATIONS[part["deco"]]["price"])
		return [{"id": "off", "name": "No", "price": 0}, {"id": "on", "name": "Yes", "price": price}]
	return part["options"]


func value_of(part: Dictionary) -> String:
	if part.has("deco"):
		return "on" if (target.get("decorations", {}) as Dictionary).get(part["deco"], false) else "off"
	return String(target.get(part["key"], (options_of(part)[0] as Dictionary)["id"]))


func unlock_key(part: Dictionary, opt: Dictionary) -> String:
	if part.has("deco"):
		return "deco:%s" % part["deco"]
	return "%s%s:%s" % [prefix, part.get("unlock", part["key"]), opt["id"]]


func is_owned(part: Dictionary, opt: Dictionary) -> bool:
	return int(opt["price"]) == 0 or Game.unlocked_cosmetics.get(unlock_key(part, opt), false)


func _apply(part: Dictionary, opt: Dictionary, values: Dictionary) -> void:
	if part.has("deco"):
		if not values.has("decorations"):
			values["decorations"] = {}
		values["decorations"][part["deco"]] = opt["id"] == "on"
	else:
		values[part["key"]] = opt["id"]
