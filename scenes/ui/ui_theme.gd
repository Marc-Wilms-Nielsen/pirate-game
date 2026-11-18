class_name UiTheme
## Fælles udseende og små hjælpefunktioner til menuerne.

const BG := Color(0.10, 0.14, 0.18, 0.95)
const PANEL := Color(0.15, 0.20, 0.25, 1.0)
const ACCENT := Color(0.95, 0.80, 0.45)
const TEXT := Color(0.94, 0.94, 0.92)
const MUTED := Color(0.65, 0.70, 0.72)
const GOOD := Color(0.6, 0.9, 0.6)
const BAD := Color(1.0, 0.55, 0.5)


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 10
	var panel := StyleBoxFlat.new()
	panel.bg_color = BG
	panel.set_corner_radius_all(8)
	panel.set_border_width_all(1)
	panel.border_color = Color(1, 1, 1, 0.12)
	panel.set_content_margin_all(10)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.22, 0.30, 0.36)
	btn.set_corner_radius_all(4)
	btn.set_content_margin_all(4)
	btn.content_margin_left = 8
	btn.content_margin_right = 8
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.30, 0.40, 0.46)
	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.18, 0.24, 0.28)
	var disabled := btn.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.16, 0.19, 0.22)
	theme.set_stylebox("normal", "Button", btn)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.52, 0.55))
	theme.set_color("font_color", "Label", TEXT)
	theme.set_constant("separation", "VBoxContainer", 4)
	theme.set_constant("separation", "HBoxContainer", 6)
	theme.set_constant("h_separation", "GridContainer", 8)
	theme.set_constant("v_separation", "GridContainer", 4)
	return theme


static func label(text: String, size := 10, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_pressed: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Sfx.play("click", -6.0, 0.02)
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
