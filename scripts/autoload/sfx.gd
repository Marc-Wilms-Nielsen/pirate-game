extends Node
## Korte lydeffekter (autoload "Sfx"). Sfx.play("cannon") eller Sfx.play_at("cannon", position).

const SOUNDS := {
	"cannon": "res://assets/audio/sfx/cannon_fire.wav",
	"hit": "res://assets/audio/sfx/wood_hit.wav",
	"coin": "res://assets/audio/sfx/coin.wav",
	"chest": "res://assets/audio/sfx/chest_open.wav",
	"swing": "res://assets/audio/sfx/sword_swing.wav",
	"hurt": "res://assets/audio/sfx/hurt.wav",
	"splash": "res://assets/audio/sfx/splash.wav",
	"click": "res://assets/audio/sfx/ui_click_soft.wav", ## deep, soft wooden tock (tools/generate_click.gd)
	"chime": "res://assets/audio/sfx/zone_chime.wav", ## entering a new area of the sea (tools/generate_chime.gd)
	"gunshot": "res://assets/audio/sfx/gunshot.wav",
	"explosion": "res://assets/audio/sfx/explosion.wav",
	"fire": "res://assets/audio/sfx/fire_whoosh.wav",
	"gas": "res://assets/audio/sfx/gas_hiss.wav",
	"flash": "res://assets/audio/sfx/flash_bang.wav",
}

var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # lyde i menuer virker også når spillet er pauset
	for id in SOUNDS:
		var stream := load(SOUNDS[id]) as AudioStream
		if stream:
			_streams[id] = stream


func play(id: String, volume_db := 0.0, pitch_variation := 0.08) -> void:
	if not _streams.has(id):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[id]
	player.volume_db = volume_db
	player.bus = "SFX"
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_at(id: String, pos: Vector2, volume_db := 0.0) -> void:
	if not _streams.has(id) or Game.world_root == null:
		play(id, volume_db)
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = _streams[id]
	player.volume_db = volume_db
	player.bus = "SFX"
	player.max_distance = 1400.0
	player.pitch_scale = randf_range(0.92, 1.08)
	player.position = pos
	Game.world_root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
