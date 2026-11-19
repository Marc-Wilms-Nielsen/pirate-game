class_name ZoneBanner
extends CanvasLayer
## The name of the area you sail into, shown in the upper third of the screen: in the slender
## pirate font with a thin edge, a thin gold line and the subtitle. Fades in, stays, fades out,
## with a soft bell. WorldZones calls show_zone() when you have settled in a new area.

const HOLD := 2.5
const TITLE_Y := 80.0

var _root: Control
var _title: Label
var _subtitle: Label
var _line: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 4 # over the world and the HUD, under the menus
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)
	# Smaller and lighter than a big title: a thin dark edge only, so the letters stay slender
	_title = UiTheme.label("", 18, UiTheme.ACCENT)
	_title.add_theme_font_override("font", UiTheme.title_font())
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.6))
	_title.add_theme_constant_override("outline_size", 2)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_title.add_theme_constant_override("shadow_offset_y", 1)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, TITLE_Y)
	_title.size = Vector2(640, 24)
	_root.add_child(_title)
	_line = ColorRect.new()
	_line.color = Color(0.95, 0.8, 0.45, 0.55)
	_line.position = Vector2(270, TITLE_Y + 25.0)
	_line.size = Vector2(100, 1)
	_root.add_child(_line)
	_subtitle = UiTheme.label("", 8, UiTheme.TEXT)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.55))
	_subtitle.add_theme_constant_override("outline_size", 2)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position = Vector2(0, TITLE_Y + 27.0)
	_subtitle.size = Vector2(640, 14)
	_root.add_child(_subtitle)


func show_zone(zone: Dictionary) -> void:
	_title.text = String(zone["name"])
	_subtitle.text = String(zone["subtitle"])
	# The line follows the title's width
	var w := clampf(_title.get_theme_font("font").get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_title.get_theme_font_size("font_size")).x * 0.6, 60.0, 200.0)
	_line.position.x = 320.0 - w * 0.5
	_line.size.x = w
	Sfx.play("chime", -6.0, 0.0)
	if _tween:
		_tween.kill()
	_root.modulate.a = 0.0
	_title.position.y = TITLE_Y + 6.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_root, "modulate:a", 1.0, 0.7)
	_tween.tween_property(_title, "position:y", TITLE_Y, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(_root, "modulate:a", 0.0, 1.0)


func is_showing() -> bool:
	return _root.modulate.a > 0.01


func shown_name() -> String:
	return _title.text
