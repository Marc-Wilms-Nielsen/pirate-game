class_name UiTheme
## Shared look and small helpers for the menus.
## Style: deep blue-grey panels with thin gold edges, Pirata One for headings, buttons and tabs,
## IM FELL English for body text (both SIL Open Font License, see CREDITS.md).

const BG := Color(0.10, 0.14, 0.18, 0.95)
const PANEL := Color(0.15, 0.20, 0.25, 1.0)
const ACCENT := Color(0.95, 0.80, 0.45)
const TEXT := Color(0.94, 0.94, 0.92)
const MUTED := Color(0.65, 0.70, 0.72)
const GOOD := Color(0.6, 0.9, 0.6)
const BAD := Color(1.0, 0.55, 0.5)
const GOLD_EDGE := Color(0.95, 0.80, 0.45, 0.35)

const BODY_FONT := "res://assets/fonts/IMFeENrm28P.ttf"
const TITLE_FONT := "res://assets/fonts/PirataOne-Regular.ttf"
const TEXT_SCALE := 0.9 ## all text a little smaller than the sizes asked for
const TITLE_SIZE := 12 ## labels this size or bigger use the pirate heading font

static var _body: Font
static var _title: Font


static func body_font() -> Font:
	if _body == null:
		_body = load(BODY_FONT) as Font
	return _body


static func title_font() -> Font:
	if _title == null:
		_title = load(TITLE_FONT) as Font
	return _title


## Text size after the global scale (never below 7, which stays readable).
static func text_size(size: int) -> int:
	return maxi(7, roundi(size * TEXT_SCALE))


## Makes the body font the default for everything that isn't themed, including the HUD and
## text drawn in code (map, quest marks). Called once at startup by the Settings autoload.
static func install_default_font() -> void:
	ThemeDB.fallback_font = body_font()
	ThemeDB.get_default_theme().default_font = body_font() # unthemed controls such as the HUD


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = text_size(10)
	var panel := StyleBoxFlat.new()
	panel.bg_color = BG
	panel.set_corner_radius_all(6)
	panel.set_border_width_all(1)
	panel.border_color = GOLD_EDGE
	panel.set_content_margin_all(16) # more room between the edge and what is inside
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 6
	theme.set_stylebox("panel", "PanelContainer", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.20, 0.27, 0.33, 0.9)
	btn.set_corner_radius_all(4)
	btn.set_border_width_all(1)
	btn.border_color = Color(0.95, 0.80, 0.45, 0.22)
	btn.content_margin_left = 12
	btn.content_margin_right = 12
	btn.content_margin_top = 4
	btn.content_margin_bottom = 4
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.27, 0.35, 0.42, 0.95)
	hover.border_color = Color(0.95, 0.80, 0.45, 0.6)
	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.16, 0.22, 0.27)
	pressed.border_color = ACCENT
	var disabled := btn.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.15, 0.18, 0.21, 0.8)
	disabled.border_color = Color(1, 1, 1, 0.06)
	for kind in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, btn)
		theme.set_stylebox("hover", kind, hover)
		theme.set_stylebox("pressed", kind, pressed)
		theme.set_stylebox("disabled", kind, disabled)
		theme.set_stylebox("focus", kind, StyleBoxEmpty.new())
		theme.set_font("font", kind, title_font())
		theme.set_font_size("font_size", kind, text_size(11))
		theme.set_color("font_color", kind, TEXT)
		theme.set_color("font_hover_color", kind, ACCENT)
		theme.set_color("font_disabled_color", kind, Color(0.5, 0.52, 0.55))

	# Tabs: a quiet row with a gold line under the open tab
	var tab := StyleBoxFlat.new()
	tab.bg_color = Color(0.12, 0.16, 0.2, 0.9)
	tab.content_margin_left = 12
	tab.content_margin_right = 12
	tab.content_margin_top = 3
	tab.content_margin_bottom = 3
	var tab_sel := tab.duplicate() as StyleBoxFlat
	tab_sel.bg_color = Color(0.18, 0.24, 0.3)
	tab_sel.border_width_bottom = 2
	tab_sel.border_color = ACCENT
	var tab_hover := tab.duplicate() as StyleBoxFlat
	tab_hover.bg_color = Color(0.16, 0.21, 0.26)
	theme.set_stylebox("tab_unselected", "TabContainer", tab)
	theme.set_stylebox("tab_selected", "TabContainer", tab_sel)
	theme.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	var tab_panel := StyleBoxFlat.new()
	tab_panel.bg_color = Color(0.12, 0.16, 0.2, 0.6)
	tab_panel.set_content_margin_all(8)
	tab_panel.set_corner_radius_all(3)
	theme.set_stylebox("panel", "TabContainer", tab_panel)
	theme.set_font("font", "TabContainer", title_font())
	theme.set_font_size("font_size", "TabContainer", text_size(11))
	theme.set_color("font_selected_color", "TabContainer", ACCENT)
	theme.set_color("font_unselected_color", "TabContainer", MUTED)
	theme.set_color("font_hovered_color", "TabContainer", TEXT)

	# Thin gold separator lines
	var line := StyleBoxLine.new()
	line.color = Color(0.95, 0.80, 0.45, 0.25)
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 10)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("h_separation", "GridContainer", 10)
	theme.set_constant("v_separation", "GridContainer", 5)
	theme.set_constant("h_separation", "HFlowContainer", 8)
	theme.set_constant("v_separation", "HFlowContainer", 6)
	return theme


static func label(text: String, size := 10, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	if size >= TITLE_SIZE:
		l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", text_size(size))
	l.add_theme_color_override("font_color", color)
	# Long sentences wrap onto more lines. Otherwise one long line forces its whole menu panel
	# wider than the screen, and buttons on the right end up off-screen.
	if text.length() > 60:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 160.0
	return l


static func button(text: String, on_pressed: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Sfx.play("click", -4.0, 0.03)
		on_pressed.call())
	return b


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s
