extends Node2D

## Sceau magique devant la porte du temple des Yrenn (voile de lumière, shader sceau.gdshader).
## Le nœud est posé au pied de la porte (pour le tri en profondeur) ; le voile remplit l'embrasure.
## Disparaît quand le temple est ouvert (flag "temple_ouvert") ; dissipate() le fait se briser en scène.

const SHADER := preload("res://resources/shaders/sceau.gdshader")

## Embrasure de la porte, par rapport au nœud (en pixels).
@export var doorway := Rect2(-15, -49, 30, 43)

var _veil: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("size", doorway.size)
	_veil = ColorRect.new()
	_veil.position = doorway.position
	_veil.size = doorway.size
	_veil.material = _mat
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	visible = not PlayerData.get_flag("temple_ouvert")

## Le voile s'illumine d'un coup, puis s'efface.
func dissipate() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): _mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.35)
	tw.tween_interval(0.15)
	tw.tween_method(func(v: float): _mat.set_shader_parameter("strength", v), 1.0, 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	await tw.finished
	visible = false
