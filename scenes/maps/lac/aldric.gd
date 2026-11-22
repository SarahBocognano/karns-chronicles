extends Node

## Quête de Brenna, au lac (LacMap) :
## - à la première arrivée pendant la quête, Zylrak note que la clairière d'Aldric est à l'ouest ;
## - la clairière saccagée s'examine (point_inspection.gd, flag "aldric_traces_vues") : la barque
##   du ponton (lac/barque.gd) mène alors à l'île ;
## - sur l'île, Aldric blessé raconte les hommes en capuche ; les goules des brumes sortent de l'eau
##   (combat sans fuite) ; vaincues, Zylrak ramène Aldric au ponton (flags "aldric_trouve",
##   "aldric_sauve") et Aldric rentre au village.

const ARRIVAL := preload("res://resources/dialogues/lac/aldric_arrivee.tres")
const MEET := preload("res://resources/dialogues/lac/aldric_ile.tres")
const AFTER := preload("res://resources/dialogues/lac/aldric_apres_combat.tres")
const MIST_GHOUL := preload("res://resources/monsters/goule_brumes.tres")
const GHOUL := preload("res://resources/monsters/goule.tres")
const BATTLE_BG := preload("res://assets/battle_backgrounds/battle_lac.png")

@export var aldric_path: NodePath
@export var island_boat_path: NodePath
@export var pier_boat_path: NodePath
@export var pier_landing_path: NodePath

var _busy := false

func _ready() -> void:
	var aldric := get_node_or_null(aldric_path)
	if aldric and (not PlayerData.get_flag("aldric_quest_started") or PlayerData.get_flag("aldric_sauve")):
		aldric.queue_free()
	var boat := get_node_or_null(pier_boat_path)
	if boat:
		boat.crossed.connect(_on_island)
	if PlayerData.get_flag("aldric_quest_started") and not PlayerData.get_flag("aldric_lac_vu"):
		_arrive.call_deferred()

func _arrive() -> void:
	_busy = true
	PlayerData.controls_locked = true
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	await _say(ARRIVAL.lines)
	PlayerData.set_flag("aldric_lac_vu", true)
	PlayerData.controls_locked = false
	_busy = false

func _on_island() -> void:
	if _busy or PlayerData.get_flag("aldric_sauve") or not PlayerData.get_flag("aldric_traces_vues"):
		return
	_busy = true
	PlayerData.controls_locked = true
	var player := Cutscene.find_player(get_tree())
	var aldric := get_node_or_null(aldric_path) as Node2D
	if player and aldric and player.has_method("face"):
		player.face("right" if aldric.global_position.x > player.global_position.x else "left")
	await _say(MEET.lines)
	if not is_inside_tree():
		return
	SceneTransition.start_battle(BATTLE_BG, [GHOUL, MIST_GHOUL], false)
	var result: String = await SceneTransition.battle_finished
	if result != "victoire" or not is_inside_tree():
		_busy = false   # défaite : Zylrak se réveille au village ; il faudra revenir
		return
	PlayerData.set_flag("aldric_trouve", true)
	PlayerData.controls_locked = true
	await _say(AFTER.lines)
	# retour au ponton, Aldric rentre au village
	await SceneTransition.fade(1.0, 0.5)
	if is_instance_valid(aldric):
		aldric.queue_free()
	var landing := get_node_or_null(pier_landing_path) as Node2D
	player = Cutscene.find_player(get_tree())
	if landing and player:
		player.global_position = landing.global_position
		for group in ["Compagnon", "Chien"]:
			for c in get_tree().get_nodes_in_group(group):
				c.global_position = landing.global_position + Vector2(0, 24)
	PlayerData.set_flag("aldric_sauve", true)
	await get_tree().create_timer(0.3).timeout
	await SceneTransition.fade(0.0, 0.5)
	PlayerData.controls_locked = false
	_busy = false

func _say(lines: Array[DialogueLine]) -> void:
	var cs := Cutscene.new()
	add_child(cs)
	await cs.say(lines)
	if is_instance_valid(cs):
		cs.queue_free()
