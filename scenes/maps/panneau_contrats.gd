extends Node2D

## Le panneau des contrats, à côté de l'auberge : Zylrak l'ouvre avec la touche d'action quand il est
## juste devant (scripts/ui/panneau_contrats_ui.gd). La bulle « ! » des quêtes (la même qu'au-dessus
## des personnages) flotte au-dessus tant qu'il y a un contrat à accepter. Le nœud est au pied du
## panneau dessiné dans le décor du village.

## Distance (en pixels) à laquelle Zylrak peut le lire.
@export var reach: float = 44.0
## Hauteur de la bulle « ! » au-dessus du nœud.
@export var marker_height: float = 58.0

var _t := 0.0
var _open := false

const BUBBLE := preload("res://assets/ui/bulle_quete.png")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

## La même bulle « ! » que les personnages qui ont une quête, qui monte et descend doucement.
func _draw() -> void:
	if not Contrats.has_new():
		return
	var y := -marker_height - 2.0 * (0.5 + 0.5 * sin(_t * TAU / 0.9))
	draw_texture(BUBBLE, Vector2(-BUBBLE.get_width() / 2.0, y - BUBBLE.get_height()))

func _unhandled_input(event: InputEvent) -> void:
	if _open or PlayerData.controls_locked or not event.is_action_pressed("interact"):
		return
	var player := Cutscene.find_player(get_tree())
	if player == null or player.global_position.distance_to(global_position) > reach:
		return
	get_viewport().set_input_as_handled()
	_open = true
	var ui := PanneauContratsUI.new()
	get_tree().root.add_child(ui)
	await ui.closed
	_open = false
