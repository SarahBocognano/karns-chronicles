extends Node2D

## La torche du forgeron, dans la grotte : une lumière chaude qui suit Zylrak et vacille (la carte
## est plongée dans la pénombre par un CanvasModulate). Posée par tools/make_grotte.gd.

@export var color := Color(1.0, 0.7, 0.42)
@export var energy := 1.15
## Taille de la lumière (la texture fait 256 px).
@export var radius := 1.8

var _light: PointLight2D
var _glow: PointLight2D
var _noise := FastNoiseLite.new()
var _t := 0.0

func _ready() -> void:
	var tex: Texture2D = load("res://scenes/maps/sceau_yrenn.gd").glow_texture()
	_light = PointLight2D.new()
	_light.texture = tex
	_light.color = color
	_light.texture_scale = radius
	add_child(_light)
	# un halo plus large et plus doux, pour qu'on devine les parois au loin
	_glow = PointLight2D.new()
	_glow.texture = tex
	_glow.color = color
	_glow.energy = 0.35
	_glow.texture_scale = radius * 2.2
	add_child(_glow)
	_noise.frequency = 2.2
	_follow()

func _process(delta: float) -> void:
	_t += delta
	_follow()
	var flicker := _noise.get_noise_1d(_t * 8.0)
	_light.energy = energy + 0.18 * flicker
	_light.texture_scale = radius * (1.0 + 0.04 * flicker)

func _follow() -> void:
	var p := Cutscene.find_player(get_tree())
	if p:
		global_position = p.global_position + Vector2(0, -14)
