extends Node

## Scènes de la montée vers les ruines des Yrenn.
## Rencontre : Ysolde, sur la terrasse au-dessus, prend Zylrak pour l'agresseur du marchand et le met
## en joue ; elle descend l'escalier, le quiproquo se dissipe, et ils font équipe (flag "ysolde_joined").

@export var ysolde_path: NodePath
## Où Zylrak s'arrête en arrivant, quand Ysolde l'interpelle.
@export var zylrak_stop_path: NodePath
## Trajet d'Ysolde pour descendre jusqu'à Zylrak (haut puis bas de l'escalier).
@export var ysolde_route: Array[NodePath] = []
@export var accusation: DialogueConversation
@export var team_up: DialogueConversation

func _ready() -> void:
	if PlayerData.get_flag("ysolde_joined"):
		return
	_meeting.call_deferred()

func _meeting() -> void:
	var ysolde := get_node_or_null(ysolde_path)
	var player := Cutscene.find_player(get_tree())
	if ysolde == null or player == null:
		return
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	add_child(cs)
	await cs.wait(0.5)   # fin du fondu d'arrivée
	await player.walk_to((get_node(zylrak_stop_path) as Node2D).global_position)
	# Ysolde surgit au bord de la terrasse et bande son arc vers lui.
	ysolde.aim(_direction(player.global_position - ysolde.global_position))
	player.face(_direction(ysolde.global_position - player.global_position))
	await cs.wait(0.5)
	await cs.say(accusation.lines)
	# Elle descend l'escalier et vient se planter devant lui.
	for p in ysolde_route:
		await ysolde.walk_to((get_node(p) as Node2D).global_position)
	var side := 1.0 if ysolde.global_position.x >= player.global_position.x else -1.0
	await ysolde.walk_to(player.global_position + Vector2(34.0 * side, -2.0))
	ysolde.aim("left" if side > 0 else "right")
	player.face("right" if side > 0 else "left")
	await cs.wait(0.3)
	await cs.say(team_up.lines)
	ysolde.face("left" if side > 0 else "right")
	PlayerData.restore_ysolde()
	PlayerData.set_flag("ysolde_joined", true)
	ysolde.start_following()
	cs.queue_free()
	PlayerData.controls_locked = false

static func _direction(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"
