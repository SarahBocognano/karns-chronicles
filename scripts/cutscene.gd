extends Node
class_name Cutscene

## Outils pour les scènes automatiques (les personnages bougent et parlent tout seuls).
## À ajouter comme enfant le temps de la scène ; les commandes de Zylrak doivent être bloquées
## (PlayerData.controls_locked) pendant toute la scène.
##
## Exemple :
##     var cs := Cutscene.new()
##     add_child(cs)
##     await player.walk_to(marker.global_position)
##     await cs.say(conversation.lines)

const DialogueBoxScene = preload("res://scenes/Dialog/dialog_box.tscn")

signal _advanced

var _box: CanvasLayer
var _waiting := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = DialogueBoxScene.instantiate()
	add_child(_box)
	_box.hide_dialogue()

## Affiche les répliques une par une ; le joueur passe à la suivante avec la touche d'action.
func say(lines: Array[DialogueLine]) -> void:
	for line in lines:
		if not is_inside_tree():
			return   # la carte a changé pendant la scène
		_box.show_dialogue(line.speaker_name, line.text, line.portrait)
		_waiting = true
		await _advanced
	_box.hide_dialogue()

func wait(seconds: float) -> void:
	if not is_inside_tree():
		return   # la carte a changé pendant la scène
	await get_tree().create_timer(seconds).timeout

func _unhandled_input(event: InputEvent) -> void:
	if _waiting and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_waiting = false
		_advanced.emit()

## Zylrak (le CharacterBody2D du groupe "Player").
static func find_player(tree: SceneTree) -> Node2D:
	for node in tree.get_nodes_in_group("Player"):
		if node is CharacterBody2D:
			return node
	return null
