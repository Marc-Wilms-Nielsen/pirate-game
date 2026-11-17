extends Node2D
## En måge, der svæver i cirkler over en ø. Tegnes med kode, så der ikke kræves sprites.

var orbit_radius: float = 150.0
var angular_speed: float = 0.4
var angle: float = 0.0
var height: float = 24.0 ## Bestemmer hvor langt skyggen ligger fra mågen

var _flap_phase: float = randf() * TAU


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	angle += angular_speed * delta
	position = Vector2(cos(angle), sin(angle) * 0.8) * orbit_radius
	var vel := Vector2(-sin(angle), cos(angle) * 0.8) * angular_speed
	rotation = vel.angle()
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# Vingeslag med pauser, hvor mågen glider.
	var flap := sin(t * 5.0 + _flap_phase) * clampf(sin(t * 0.7 + _flap_phase) * 2.0, 0.0, 1.0)
	var span := 6.0 + 1.5 * flap
	var sweep := -2.0 - 1.5 * flap
	var wing := PackedVector2Array([Vector2(sweep, -span), Vector2(1, 0), Vector2(sweep, span)])

	var shadow_offset := Vector2(height * 0.4, height * 0.6).rotated(-rotation)
	var shadow := PackedVector2Array()
	for p in wing:
		shadow.append(p + shadow_offset)

	draw_polyline(shadow, Color(0, 0, 0, 0.18), 1.5, true)
	draw_polyline(wing, Color.WHITE, 1.5, true)
	draw_circle(Vector2(0.5, 0), 1.2, Color.WHITE, true, -1.0, true)
