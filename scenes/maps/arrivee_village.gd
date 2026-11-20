extends Node2D

## Début de partie (après l'intro) : Zylrak arrive au village par la route de la forêt et marche
## seul jusqu'à l'auberge, en passant par les marqueurs enfants dans l'ordre (un marqueur dont le
## nom commence par « Halte » le fait s'arrêter un instant). À la porte, petite coupure au noir et
## la partie commence dans l'auberge, où Oswin lui tombe dessus.
## Ne se joue qu'une fois, quand PlayerData.arrival_pending est vrai (Sauvegarde.begin_adventure).
## Nœud ajouté par tools/make_village_v2.gd.

const AUBERGE := "res://scenes/maps/AubergeMap.tscn"
const AUBERGE_SPAWN := "SpawnFromVillage"

@export var walk_speed: float = 90.0
@export var halt_time: float = 0.8
## Temps passé sur l'écran noir en entrant dans l'auberge.
@export var black_cut: float = 0.6
@export var door_path: NodePath = ^"../EnterAuberge"

func _ready() -> void:
	if not PlayerData.arrival_pending:
		return
	PlayerData.arrival_pending = false
	PlayerData.controls_locked = true
	# c'est cette scène qui fait entrer Zylrak dans l'auberge, pas la zone de la porte
	var door := get_node_or_null(door_path) as Area2D
	if door:
		door.set_deferred("monitoring", false)
	_play.call_deferred()

func _play() -> void:
	var player := Cutscene.find_player(get_tree())
	if player == null or not player.has_method("walk_to"):
		PlayerData.controls_locked = false
		return
	await get_tree().create_timer(SceneTransition.fade_duration + 0.4).timeout   # fin du fondu d'arrivée
	for m in get_children():
		if not is_inside_tree():
			return   # la carte a changé pendant la scène
		if m is Marker2D:
			await player.walk_to(m.global_position, walk_speed)
			if m.name.begins_with("Halte") and is_inside_tree():
				player.face("up")
				await get_tree().create_timer(halt_time).timeout
	if not is_inside_tree():
		return
	# il pousse la porte pendant le fondu ; les commandes restent bloquées : la scène d'Oswin,
	# dans l'auberge, les reprend
	SceneTransition.change_scene(AUBERGE, AUBERGE_SPAWN, black_cut)
	await player.walk_to(player.global_position + Vector2(0, -20), walk_speed * 0.6)
