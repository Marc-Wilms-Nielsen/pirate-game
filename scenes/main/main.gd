extends Node2D
## Hovedscenen: hav, øer, skib og stemningslyd.

const OCEAN_SOUND := "res://assets/audio/ambience/ocean_loop.wav"


func _ready() -> void:
	var ocean := AudioStreamPlayer.new()
	ocean.stream = load(OCEAN_SOUND) as AudioStream
	ocean.volume_db = -6.0
	add_child(ocean)
	ocean.finished.connect(ocean.play) # reserve, hvis loop-punktet ikke blev importeret
	ocean.play()
