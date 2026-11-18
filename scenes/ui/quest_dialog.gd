class_name QuestDialog
extends CanvasLayer
## Small chat window with the quest giver's portrait, shown when you dock at a harbor with a
## "!" (new quest: Accept / Decline) or a "?" (hand in: Claim reward).
## open(talk, on_closed): talk comes from Quests.talk_at(); on_closed gets "accept",
## "decline" or "turn_in". The game is paused while the window is open.

signal closed(result: String)

var _root: Control
var _panel: PanelContainer
var _portrait: Portrait
var _name: Label
var _role: Label
var _title: Label
var _text: Label
var _extra: Label
var _buttons: HBoxContainer
var _talk: Dictionary = {}
var _type_tween: Tween


func _ready() -> void:
	layer = 20 # above the harbor menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.make()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.position = Vector2(70, 196)
	_panel.size = Vector2(500, 150)
	_root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_panel.add_child(row)
	var left := VBoxContainer.new()
	row.add_child(left)
	_portrait = Portrait.new()
	_portrait.custom_minimum_size = Vector2(76, 76)
	left.add_child(_portrait)
	_name = UiTheme.label("", 10, UiTheme.ACCENT)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.custom_minimum_size.x = 76
	left.add_child(_name)
	_role = UiTheme.label("", 7, UiTheme.MUTED)
	_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role.custom_minimum_size.x = 76
	left.add_child(_role)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_title = UiTheme.label("", 12, UiTheme.ACCENT)
	right.add_child(_title)
	_text = UiTheme.label("", 9, UiTheme.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(380, 60)
	right.add_child(_text)
	_extra = UiTheme.label("", 8, UiTheme.GOOD)
	_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_extra.custom_minimum_size.x = 380 # wrapping labels need a width before the first layout
	right.add_child(_extra)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(_buttons)


func open(talk: Dictionary) -> void:
	_talk = talk
	var person: Dictionary = Catalog.QUEST_PEOPLE[talk["person"]]
	_portrait.look = person["look"]
	_name.text = person["name"]
	_role.text = person["title"]
	var offer: bool = talk["mode"] == "offer"
	_title.text = ("New quest: " if offer else "Quest complete: ") + String(talk["title"])
	_text.text = "\n".join(PackedStringArray(talk["lines"]))
	_extra.text = String(talk.get("goal", "")) if offer else String(talk.get("reward", ""))
	_extra.add_theme_color_override("font_color", UiTheme.ACCENT if offer else UiTheme.GOOD)
	UiTheme.clear(_buttons)
	if offer:
		_buttons.add_child(UiTheme.button("Decline", func() -> void: _close("decline")))
		_buttons.add_child(UiTheme.button("Accept", func() -> void: _close("accept")))
	else:
		_buttons.add_child(UiTheme.button("Claim reward", func() -> void: _close("turn_in")))
	visible = true
	get_tree().paused = true
	_fit()
	_fit.call_deferred() # once more after the first layout, when every label knows its width
	# Type the text out, like someone talking (a click on the text shows it all at once)
	_text.visible_ratio = 0.0
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, clampf(_text.text.length() / 130.0, 0.4, 2.0))


## Sit at the bottom of the screen and grow upwards to fit the text.
func _fit() -> void:
	_panel.size = Vector2(500, 0)
	var h := minf(_panel.get_combined_minimum_size().y, 340.0)
	_panel.size.y = h
	_panel.position = Vector2(70, 352.0 - h)


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _text.visible_ratio < 1.0:
		_type_tween.kill()
		_text.visible_ratio = 1.0


func _close(result: String) -> void:
	if _type_tween:
		_type_tween.kill()
	visible = false
	match result:
		"accept":
			Quests.accept()
		"turn_in":
			Quests.complete()
	closed.emit(result)
