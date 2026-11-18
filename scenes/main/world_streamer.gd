class_name WorldStreamer
extends Node
## Holder kun den del af verdenen "levende", der er tæt på kameraet.
## Verdenen er delt i celler. Ting langt væk sættes på pause (ingen _process, ingen fysik),
## og indholdet på en ø (træer, kister, dyr, landsbyer) bygges først, når man kommer i nærheden.
## Det er det, der gør en 10x større verden mulig uden at billedhastigheden falder.

const CELL := 2000.0
const MARGIN := 1100.0 ## ekstra afstand ud over skærmkanten, hvor tingene allerede er vågne
const TICK := 0.25

var _cells: Dictionary = {} ## Vector2i -> Array[Node2D]
var _active: Dictionary = {} ## Vector2i -> true
var _wide: Array = [] ## [Node2D, radius, Callable (bygges første gang), bool aktiv]
var _cell_builders: Array[Callable] = [] ## kaldes én gang pr. celle første gang den vågner (f.eks. havbunden)
var _built_cells: Dictionary = {}
var _timer := 0.0


func _ready() -> void:
	add_to_group("streamer")


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))


## En lille ting der bliver på sin plads (træ, kiste, krabbe, landsby ...).
func add(node: Node2D) -> void:
	var key := cell_of(node.global_position)
	if not _cells.has(key):
		_cells[key] = []
	(_cells[key] as Array).append(node)
	_set_awake(node, _active.has(key))


## En stor ting (en ø) – vågner når dens kant er tæt på. builder kaldes første gang.
func add_wide(node: Node2D, radius: float, builder := Callable()) -> void:
	_wide.append([node, radius, builder, true])
	_set_awake(node, false)
	_wide[-1][3] = false


func add_cell_builder(builder: Callable) -> void:
	_cell_builders.append(builder)


func is_cell_active(pos: Vector2) -> bool:
	return _active.has(cell_of(pos))


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = TICK
		update_now()


## Opdaterer hvad der er vågent ud fra kameraet. Kaldes også straks efter teleport/start.
func update_now() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	var reach := (get_viewport().get_visible_rect().size / cam.zoom).length() * 0.5 + MARGIN
	# Store ting (øer) først, så deres indhold findes, inden cellerne vækkes
	for w in _wide:
		var node := w[0] as Node2D
		if not is_instance_valid(node):
			continue
		var awake := node.global_position.distance_to(center) - float(w[1]) < reach
		if awake != bool(w[3]):
			w[3] = awake
			if awake and (w[2] as Callable).is_valid():
				var builder: Callable = w[2]
				w[2] = Callable()
				builder.call()
			_set_awake(node, awake)
	# Celler
	var lo := cell_of(center - Vector2.ONE * reach)
	var hi := cell_of(center + Vector2.ONE * reach)
	var now: Dictionary = {}
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			now[Vector2i(x, y)] = true
	for key in _active:
		if not now.has(key):
			_wake_cell(key, false)
	for key in now:
		if not _active.has(key):
			if not _built_cells.has(key):
				_built_cells[key] = true
				for b in _cell_builders:
					b.call(key, Rect2(Vector2(key) * CELL, Vector2.ONE * CELL))
			_wake_cell(key, true)
	_active = now


func _wake_cell(key: Vector2i, awake: bool) -> void:
	if not _cells.has(key):
		return
	var list: Array = _cells[key]
	var i := list.size() - 1
	while i >= 0:
		var n: Variant = list[i]
		if not is_instance_valid(n):
			list.remove_at(i)
		else:
			_set_awake(n as Node2D, awake)
		i -= 1


func _set_awake(node: Node2D, awake: bool) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	node.visible = awake


## Antal vågne ting (til test og fejlfinding).
func awake_count() -> int:
	var n := 0
	for key in _active:
		if _cells.has(key):
			n += (_cells[key] as Array).size()
	return n
