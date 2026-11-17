extends Node2D
## Hovedscenen: hav, øer, skib og stemningslyd.
## Styrer skiftet mellem at sejle skibet og at gå/svømme med kaptajnen.

const OCEAN_SOUND := "res://assets/audio/ambience/ocean_loop.wav"
const PlayerScene := preload("res://scenes/player/player.tscn")

@onready var _ship = $Ship # utypet, så vi kan kalde ship.gd-funktioner
var _player = null


func _ready() -> void:
	var ocean := AudioStreamPlayer.new()
	ocean.stream = load(OCEAN_SOUND) as AudioStream
	ocean.volume_db = -6.0
	add_child(ocean)
	ocean.finished.connect(ocean.play) # reserve, hvis loop-punktet ikke blev importeret
	ocean.play()

	_ship.disembark_requested.connect(_on_disembark_requested)


func _on_disembark_requested() -> void:
	_player = PlayerScene.instantiate()
	# Hop ud over styrbords ræling (skibets højre side)
	_player.position = _ship.global_position + Vector2.DOWN.rotated(_ship.rotation) * 22.0
	add_child(_player)
	_player.board_requested.connect(_on_board_requested)
	_player.get_node("Camera2D").make_current()
	_ship.set_controlled(false)


func _on_board_requested() -> void:
	_player.queue_free()
	_player = null
	_ship.set_controlled(true)
