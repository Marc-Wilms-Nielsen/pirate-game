class_name PopupText
extends Node2D
## Lille tekst der svæver op og forsvinder (f.eks. "+25 gold").

var text: String = ""
var color: Color = Color.WHITE
var icon: String = "" ## ikon foran teksten (vare-id, "gold" ...)
var _life: float = 0.0
const DURATION := 1.8


func _ready() -> void:
	z_index = 50


func _process(delta: float) -> void:
	_life += delta
	position.y -= 14.0 * delta
	modulate.a = 1.0 - clampf((_life - DURATION * 0.5) / (DURATION * 0.5), 0.0, 1.0)
	if _life >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var size := 9
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(-width * 0.5, 0)
	if icon != "":
		pos.x += 6.0
		Icons.draw(self, icon, pos + Vector2(-7, -3), 10.0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
