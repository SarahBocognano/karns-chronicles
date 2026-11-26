extends PointLight2D

## Une lueur posée par l'éclairage des cartes (scripts/eclairage.gd) : une flamme qui vacille
## (torche, bougie, cheminée, lanterne) ou une lumière fixe (fenêtre).

## Énergie de base ; le vacillement s'y ajoute.
@export var base_energy := 1.0
## Ampleur du vacillement (0 : lumière fixe).
@export var flicker := 0.0

var _noise := FastNoiseLite.new()
var _t := 0.0
var _scale := 1.0

func _ready() -> void:
	if texture == null:
		texture = load("res://scenes/maps/sceau_yrenn.gd").glow_texture()
	_noise.seed = randi()
	_noise.frequency = 2.0
	_t = randf() * 100.0     # deux flammes voisines ne vacillent pas ensemble
	_scale = texture_scale
	energy = base_energy
	set_process(flicker > 0.0)

func _process(delta: float) -> void:
	_t += delta
	var n := _noise.get_noise_1d(_t * 7.0)
	energy = base_energy * (1.0 + flicker * n)
	texture_scale = _scale * (1.0 + 0.25 * flicker * n)
