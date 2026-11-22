extends Node2D

## Une barque pour traverser le lac (LacMap) : du ponton à l'île, et retour. Zylrak (et ses
## compagnons) arrivent au marqueur `destination` après un fondu au noir. Tant que `required_flag`
## n'est pas vrai, elle se contente de se laisser regarder (conversation `idle`).

signal crossed

@export var destination: NodePath
@export var required_flag: String = ""
@export var idle: DialogueConversation
@export var question: String = "Prendre la barque ?"
@export var go_label: String = "Ramer"
@export var reach: float = 46.0

var _busy := false

func _unhandled_input(event: InputEvent) -> void:
	if _busy or PlayerData.controls_locked or not event.is_action_pressed("interact"):
		return
	var player := Cutscene.find_player(get_tree())
	if player == null or player.global_position.distance_to(global_position) > reach:
		return
	get_viewport().set_input_as_handled()
	_use(player)

func _use(player: Node2D) -> void:
	_busy = true
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	add_child(cs)
	if required_flag != "" and not PlayerData.get_flag(required_flag):
		if idle:
			await cs.say(idle.lines)
	else:
		var line := DialogueLine.new()
		line.text = question
		var k := await cs.choose([go_label, "Rester ici"], line)
		if k == 0:
			await cross(player)
	cs.queue_free()
	PlayerData.controls_locked = false
	_busy = false

## La traversée : fondu au noir, Zylrak et ses compagnons arrivent de l'autre côté.
func cross(player: Node2D) -> void:
	var to := get_node_or_null(destination) as Node2D
	if to == null:
		return
	await SceneTransition.fade(1.0, 0.5)
	player.global_position = to.global_position
	for group in ["Compagnon", "Chien"]:
		for c in get_tree().get_nodes_in_group(group):
			c.global_position = to.global_position + Vector2(-20, 6)
			if c.has_method("start_following"):
				c.start_following()
	await get_tree().create_timer(0.4).timeout
	await SceneTransition.fade(0.0, 0.5)
	crossed.emit()
