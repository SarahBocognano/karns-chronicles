extends Node2D
class_name PointInspection

## Quelque chose à examiner avec la touche d'action, quand Zylrak est juste à côté : le corps du
## marchand, le parchemin de l'autel... Une petite étincelle le signale tant qu'on ne l'a pas examiné.
## La première fois : `conversation` (et `flag_on_read` passe à vrai) ; ensuite : `conversation_after`.

@export var conversation: DialogueConversation
## Les fois suivantes (vide : plus rien à dire).
@export var conversation_after: DialogueConversation
## Rien à examiner tant que ce flag n'est pas vrai (vide : toujours).
@export var required_flag := ""
@export var flag_on_read := ""
## Distance (en pixels) à laquelle Zylrak peut l'examiner.
@export var reach := 40.0
## Nœud masqué une fois examiné (ex. le parchemin, que Zylrak emporte).
@export var hide_after: NodePath
## Position de l'étincelle, par rapport au nœud.
@export var sparkle_at := Vector2(0, -20)

var _t := 0.0
var _busy := false

func _ready() -> void:
	if flag_on_read != "" and PlayerData.get_flag(flag_on_read):
		_hide_taken()

func _available() -> bool:
	return required_flag == "" or PlayerData.get_flag(required_flag)

func _read_already() -> bool:
	return flag_on_read != "" and PlayerData.get_flag(flag_on_read)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if not _available() or _read_already():
		return
	var pulse := maxf(0.0, sin(_t * 2.6))
	if pulse <= 0.05:
		return
	var c := Color(1.0, 0.95, 0.8, pulse)
	var r := 2.0 + 3.0 * pulse
	draw_line(sparkle_at - Vector2(r, 0), sparkle_at + Vector2(r, 0), c, 1.0)
	draw_line(sparkle_at - Vector2(0, r), sparkle_at + Vector2(0, r), c, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if _busy or not _available() or PlayerData.controls_locked or not event.is_action_pressed("interact"):
		return
	var conv := conversation_after if _read_already() else conversation
	if conv == null:
		return
	var player := Cutscene.find_player(get_tree())
	if player == null or player.global_position.distance_to(global_position) > reach:
		return
	get_viewport().set_input_as_handled()
	_read(conv)

func _read(conv: DialogueConversation) -> void:
	_busy = true
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	get_tree().current_scene.add_child(cs)
	await cs.say(conv.lines)
	cs.queue_free()
	if flag_on_read != "" and not PlayerData.get_flag(flag_on_read):
		Sons.play("objet_rare")
		PlayerData.set_flag(flag_on_read, true)
		_hide_taken()
	PlayerData.controls_locked = false
	_busy = false

func _hide_taken() -> void:
	var n := get_node_or_null(hide_after) as CanvasItem
	if n:
		n.visible = false
