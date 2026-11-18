class_name MusicDirector
extends Node
## Baggrundsmusik der skifter blødt efter situationen: dag, nat, havn og kamp.
## To afspillere toner over i hinanden, så skiftene aldrig er bratte.

const TRACKS := {
	"day": "res://assets/audio/music/day.ogg",
	"night": "res://assets/audio/music/night.ogg",
	"harbor": "res://assets/audio/music/harbor.ogg",
	"battle": "res://assets/audio/music/battle.ogg",
}
const FADE_TIME := 4.0
const BATTLE_RANGE := 520.0 ## en angribende pirat så tæt på giver kampmusik
const VOLUME_DB := -6.0

var current: String = ""
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _check: float = 0.0
var _battle_hold: float = 0.0 ## kampmusikken bliver lidt efter kampen
var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # musikken spiller videre i menuerne
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	for id in TRACKS:
		var stream := load(TRACKS[id]) as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_streams[id] = stream


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		var wanted := _wanted_track(1.0)
		if wanted != current:
			_switch_to(wanted)
	# Krydstoning
	for i in _players.size():
		var p := _players[i]
		var target := VOLUME_DB if i == _active else -60.0
		var current_db := p.volume_db
		var step := 60.0 / FADE_TIME * delta
		p.volume_db = move_toward(current_db, target, step if target < current_db else step * 0.6)
		if i != _active and p.playing and p.volume_db <= -59.0:
			p.stop()


func _wanted_track(dt: float) -> String:
	_battle_hold = maxf(_battle_hold - dt, 0.0)
	if _in_battle():
		_battle_hold = 12.0
	if _battle_hold > 0.0:
		return "battle"
	if Game.current_harbor != null:
		return "harbor"
	return "night" if Game.night > 0.6 else "day"


func _in_battle() -> bool:
	for menu_name in ["BoardingMenu", "DuelMenu"]:
		var menu := get_parent().get_node_or_null(menu_name) as CanvasLayer
		if menu and menu.visible:
			return true
	var ship := get_tree().get_first_node_in_group("player_ship") as Node2D
	if ship == null:
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyShip
		if enemy.state == "attack" and enemy.faction == "pirate" and enemy.global_position.distance_to(ship.global_position) < BATTLE_RANGE:
			return true
	return false


func _switch_to(id: String) -> void:
	current = id
	if not _streams.has(id) or _streams[id] == null:
		return
	_active = 1 - _active
	var p := _players[_active]
	p.stream = _streams[id]
	p.volume_db = -40.0
	p.play()
