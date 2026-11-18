class_name ZoomCamera
extends Camera2D
## Camera with the player's own zoom (mouse wheel or + / -) on top of an automatic "base zoom".
## The zoom level is shared between the ship and the captain (saved in Game.user_zoom).
## On foot (PlayerCharacter sets min_user_zoom) you can zoom out much less than at sea,
## for a closer, more personal view; the ship's wider zoom is kept for when you go back aboard.

const MIN_USER_ZOOM := 0.18 ## how far out you can zoom at sea
const ON_FOOT_MIN_ZOOM := 0.65 ## how far out you can zoom on land (about 3.6x closer than at sea)
const MAX_USER_ZOOM := 1.8
const STEP := 1.15

var base_zoom: float = 1.3 ## set by the owner (e.g. the ship, from its speed)
var min_user_zoom: float = MIN_USER_ZOOM


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
	# Start from what this camera actually shows, so zooming in on land responds at once
	var current := clampf(Game.user_zoom, min_user_zoom, MAX_USER_ZOOM)
	Game.user_zoom = clampf(current * factor, min_user_zoom, MAX_USER_ZOOM)


## The user zoom this camera uses right now.
func effective_user_zoom() -> float:
	return clampf(Game.user_zoom, min_user_zoom, MAX_USER_ZOOM)


func _process(delta: float) -> void:
	var target := base_zoom * effective_user_zoom()
	zoom = zoom.lerp(Vector2(target, target), 1.0 - exp(-4.0 * delta))
