class_name ZoomCamera
extends Camera2D
## Kamera med spillerens egen zoom (musehjul eller + / -) oven i en automatisk "basis-zoom".
## Zoom-niveauet deles mellem skib og kaptajn (gemt i Game.user_zoom).

const MIN_USER_ZOOM := 0.18 ## hvor langt man kan zoome ud
const MAX_USER_ZOOM := 1.8
const STEP := 1.15

var base_zoom: float = 1.3 ## sættes af ejeren (f.eks. skibet ud fra fart)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _unhandled_input(event: InputEvent) -> void:
	if not is_current():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change(STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change(1.0 / STEP)
	elif event.is_action_pressed("zoom_in"):
		_change(STEP * STEP)
	elif event.is_action_pressed("zoom_out"):
		_change(1.0 / (STEP * STEP))


func _change(factor: float) -> void:
	Game.user_zoom = clampf(Game.user_zoom * factor, MIN_USER_ZOOM, MAX_USER_ZOOM)


func _process(delta: float) -> void:
	var target := base_zoom * Game.user_zoom
	zoom = zoom.lerp(Vector2(target, target), 1.0 - exp(-4.0 * delta))
