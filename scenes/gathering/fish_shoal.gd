class_name FishShoal
extends Node2D
## Fiskestime i vandet (boblende ringe). Stop skibet tæt på – eller stå på stranden – og tryk F.
## Vent på bid, og tryk F igen når fisken hugger.

const RANGE_SHIP := 80.0
const RANGE_FOOT := 55.0

var catches_left: int = Catalog.FISHING["catches_per_shoal"]
var state: String = "idle" ## idle, waiting, bite
var _timer: float = 0.0
var _time: float = 0.0
var _angler: Node2D


func _ready() -> void:
	add_to_group("fish_shoals")
	_time = randf() * 10.0


func in_range(pos: Vector2, on_ship: bool) -> bool:
	return pos.distance_to(global_position) < (RANGE_SHIP if on_ship else RANGE_FOOT)


func status_text() -> String:
	match state:
		"waiting":
			return "Waiting for a bite ..."
		"bite":
			return "BITE! Press F now!"
	return "F: Fish"


## Kaldes når spilleren trykker F i nærheden.
func interact(angler: Node2D) -> void:
	if not Game.tools.get("rod", false):
		Game.notify("You have no fishing rod – buy one in a harbor", UiTheme.BAD)
		return
	match state:
		"idle":
			_angler = angler
			state = "waiting"
			_timer = randf_range(Catalog.FISHING["bite_min"], Catalog.FISHING["bite_max"])
			Sfx.play_at("splash", global_position, -16.0)
		"waiting":
			Game.notify("Too early – the fish got scared away", UiTheme.MUTED)
			state = "idle"
		"bite":
			_catch()


func cancel() -> void:
	state = "idle"


func _catch() -> void:
	state = "idle"
	var messages: Array[String] = []
	for y in Catalog.FISHING["yields"]:
		if randf() <= float(y[3]):
			var got := Game.add_item(y[0], randi_range(y[1], y[2]))
			if got > 0:
				messages.append("+%d %s" % [got, Game.item_name(y[0])])
	if messages.is_empty():
		messages.append("The cargo hold is full!")
	for i in messages.size():
		Game.popup(messages[i], global_position + Vector2(0, -12 * i), Color(0.7, 0.9, 1.0))
	Sfx.play_at("splash", global_position, -6.0)
	catches_left -= 1
	if catches_left <= 0:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_time += delta
	if state == "waiting":
		_timer -= delta
		if _timer <= 0.0:
			state = "bite"
			_timer = Catalog.FISHING["window"]
			Sfx.play_at("splash", global_position, -4.0)
	elif state == "bite":
		_timer -= delta
		if _timer <= 0.0:
			state = "idle"
			Game.notify("The fish got away", UiTheme.MUTED)
	# Stop hvis fiskeren er gået sin vej
	if state != "idle" and is_instance_valid(_angler) and _angler.global_position.distance_to(global_position) > RANGE_SHIP * 1.5:
		state = "idle"
	queue_redraw()


func _draw() -> void:
	for i in 3:
		var r := fmod(_time * 8.0 + i * 7.0, 20.0) + 3.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(1, 1, 1, 0.3 * (1.0 - r / 23.0)), 1.0, true)
	for i in 5: # små fisk der svømmer rundt
		var a := _time * (0.8 + i * 0.13) + i * 1.3
		var p := Vector2(cos(a), sin(a * 1.3)) * (6.0 + i * 1.5)
		draw_circle(p, 1.3, Color(0.2, 0.3, 0.4, 0.6), true, -1.0, true)
	if state == "waiting":
		draw_circle(Vector2(0, sin(_time * 4.0) * 1.0), 1.6, Color(0.9, 0.2, 0.2), true, -1.0, true) # flåd
	elif state == "bite":
		draw_circle(Vector2.ZERO, 2.2, Color(0.9, 0.2, 0.2), true, -1.0, true)
		draw_arc(Vector2.ZERO, 8.0 + sin(_time * 20.0) * 2.0, 0.0, TAU, 20, Color(1, 1, 0.6, 0.9), 1.5, true)
