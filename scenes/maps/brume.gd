extends Sprite2D

## Nappe de brume qui dérive lentement de gauche à droite et respire (le lac aux Brumes).

@export var drift: float = 40.0
@export var speed: float = 0.12
@export var phase: float = 0.0

var _base := Vector2.ZERO
var _t := 0.0
var _alpha := 0.55

func _ready() -> void:
	_base = position
	_alpha = modulate.a

func _process(delta: float) -> void:
	_t += delta
	position.x = _base.x + sin(_t * speed + phase) * drift
	modulate.a = _alpha * (0.75 + 0.25 * sin(_t * speed * 2.3 + phase))
