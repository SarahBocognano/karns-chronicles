extends Node2D

## Sceau magique devant la porte du temple des Yrenn (voile de lumière, shader sceau.gdshader).
## Le nœud est posé au pied de la porte (pour le tri en profondeur) ; le voile remplit l'embrasure.
## Disparaît quand son flag est vrai (à la porte du parvis : "temple_ouvert") ; dissipate() le fait
## se briser en scène. Dans le temple, le voile est turquoise et une lueur pulse doucement autour.

const SHADER := preload("res://resources/shaders/sceau.gdshader")

## Embrasure de la porte, par rapport au nœud (en pixels).
@export var doorway := Rect2(-15, -49, 30, 43)
## Le voile disparaît quand ce flag est vrai.
@export var flag_name := "temple_ouvert"
@export var deep := Color(0.22, 0.50, 0.92)
@export var light := Color(0.72, 0.93, 1.0)
## Lueur (PointLight2D) qui pulse autour du voile ; 0 : pas de lueur.
@export var glow_energy := 0.0

var _veil: ColorRect
var _mat: ShaderMaterial
var _glow: PointLight2D

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("size", doorway.size)
	_mat.set_shader_parameter("deep", deep)
	_mat.set_shader_parameter("bright", light)
	_veil = ColorRect.new()
	_veil.position = doorway.position
	_veil.size = doorway.size
	_veil.material = _mat
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	visible = not PlayerData.get_flag(flag_name)
	if glow_energy > 0.0:
		_glow = PointLight2D.new()
		_glow.texture = glow_texture()
		_glow.color = light
		_glow.texture_scale = 0.9
		_glow.position = doorway.get_center()
		add_child(_glow)

func _process(_delta: float) -> void:
	if _glow:
		_glow.energy = glow_energy * (0.8 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 1.8))

## Halo rond, blanc au centre et noir au bord (une lumière prend la couleur, pas la transparence).
static func glow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1))
	g.set_color(1, Color(0, 0, 0))
	g.add_point(0.4, Color(0.42, 0.42, 0.42))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex

## Le voile s'illumine d'un coup, puis s'efface.
func dissipate() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): _mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.35)
	tw.tween_interval(0.15)
	tw.tween_method(func(v: float): _mat.set_shader_parameter("strength", v), 1.0, 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	if _glow:
		tw.parallel().tween_property(_glow, "energy", 0.0, 1.2)
		set_process(false)
	await tw.finished
	visible = false
