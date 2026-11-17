extends Node
## Globalt spil-state (autoload). Tilgængeligt overalt som `Game`.
## Hold denne fil lille: kun ting der reelt skal deles på tværs af scener.

signal score_changed(new_score: int)

var score: int = 0:
	set(value):
		score = value
		score_changed.emit(score)


func reset() -> void:
	score = 0
