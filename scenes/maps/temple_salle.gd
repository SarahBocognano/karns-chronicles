extends Node

## Scénario d'une salle du temple des Yrenn (tools/make_temple.gd). Chaque partie est facultative :
## - une arrivée (conversation `arrival`, jouée une fois : flag `arrival_flag`) ;
## - le cercle de cendres du vestibule (flag "indice_ordre_vu") : la flamme de l'Ordre des Cendres,
##   renversée, tracée avec le sang du marchand ;
## - le gardien de la salle du fond, une armure des Yrenn devant l'escalier : il s'éveille quand
##   Zylrak approche, combat (on ne peut pas fuir) ; vaincu, il s'effondre et le voile de l'escalier
##   se dissipe (flag "gardien_temple_vaincu") ;
## - l'escalier, qui descend dans le noir : il faudra une torche (suite à venir).

@export var arrival: DialogueConversation
@export var arrival_flag: String = ""
## Combat du gardien.
@export var monster: MonsterData
@export var battle_background: Texture2D
@export_group("Dialogues")
@export var circle: DialogueConversation
## Ajouté après `circle` si Zylrak a parlé à l'inconnu de l'auberge.
@export var circle_stranger: DialogueConversation
@export var guardian_wake: DialogueConversation
@export var guardian_defeated: DialogueConversation
@export var stairs: DialogueConversation
@export_group("Nœuds")
@export var guardian_path: NodePath
@export var circle_zone_path: NodePath
@export var guardian_zone_path: NodePath
@export var stairs_zone_path: NodePath
## Voile de l'escalier (sceau_yrenn.gd), qui se dissipe quand le gardien tombe.
@export var veil_path: NodePath
## Recul de Zylrak après le message de l'escalier.
@export var stairs_push_back: Vector2 = Vector2(0, 28)

var _busy := false

func _ready() -> void:
	var guardian := get_node_or_null(guardian_path) as Node2D
	if guardian and PlayerData.get_flag("gardien_temple_vaincu"):
		guardian.queue_free()
	_connect(circle_zone_path, _on_circle_entered)
	_connect(guardian_zone_path, _on_guardian_zone_entered)
	_connect(stairs_zone_path, _on_stairs_entered)
	if arrival and arrival_flag != "" and not PlayerData.get_flag(arrival_flag):
		_arrive.call_deferred()

func _connect(path: NodePath, f: Callable) -> void:
	var zone := get_node_or_null(path) as Area2D
	if zone:
		zone.body_entered.connect(func(body: Node2D):
			if body is CharacterBody2D and body.is_in_group("Player"):
				f.call(body))

func _free() -> bool:
	return not _busy and not PlayerData.controls_locked and not SceneTransition.in_battle

func _say(lines: Array[DialogueLine]) -> void:
	var cs := Cutscene.new()
	add_child(cs)
	await cs.say(lines)
	if is_instance_valid(cs):
		cs.queue_free()

# --- 1. Arrivée ---

func _arrive() -> void:
	_busy = true
	PlayerData.controls_locked = true
	await get_tree().create_timer(SceneTransition.fade_duration + 0.5).timeout
	if not is_inside_tree():
		return
	await _say(arrival.lines)
	PlayerData.set_flag(arrival_flag, true)
	PlayerData.controls_locked = false
	_busy = false

# --- 3. Le cercle de cendres ---

func _on_circle_entered(player: Node2D) -> void:
	if not _free() or PlayerData.get_flag("indice_ordre_vu"):
		return
	_busy = true
	PlayerData.controls_locked = true
	if player.has_method("face"):
		player.face("up")
	var lines: Array[DialogueLine] = circle.lines.duplicate()
	if circle_stranger and PlayerData.get_flag("talked_to_inconnu"):
		lines.append_array(circle_stranger.lines)
	await _say(lines)
	PlayerData.set_flag("indice_ordre_vu", true)
	PlayerData.controls_locked = false
	_busy = false

# --- 4. Le gardien ---

func _on_guardian_zone_entered(player: Node2D) -> void:
	if not _free() or PlayerData.get_flag("gardien_temple_vaincu"):
		return
	_busy = true
	PlayerData.controls_locked = true
	if player.has_method("face"):
		player.face("up")
	var guardian := get_node_or_null(guardian_path) as Node2D
	if guardian:
		await _wake(guardian)
	await _say(guardian_wake.lines)
	if not is_inside_tree():
		return
	SceneTransition.start_battle(battle_background, [monster], false)
	var result: String = await SceneTransition.battle_finished
	if result != "victoire" or not is_inside_tree():
		# fuite impossible ; défaite : Zylrak se réveille au village
		_busy = false
		return
	PlayerData.set_flag("gardien_temple_vaincu", true)
	PlayerData.controls_locked = true
	if is_instance_valid(guardian):
		await _collapse(guardian)
	var veil := get_node_or_null(veil_path)
	if veil and veil.visible:
		await veil.dissipate()
	await _say(guardian_defeated.lines)
	PlayerData.controls_locked = false
	_busy = false

## Une lueur bleue s'allume dans le heaume, l'armure tremble.
func _wake(guardian: Node2D) -> void:
	var tw := create_tween()
	tw.tween_property(guardian, "modulate", Color(1.5, 1.7, 2.2), 0.35)
	tw.tween_property(guardian, "modulate", Color(1.15, 1.2, 1.4), 0.4)
	var x0 := guardian.position.x
	for i in 6:
		tw.tween_property(guardian, "position:x", x0 + (2.0 if i % 2 == 0 else -2.0), 0.05)
	tw.tween_property(guardian, "position:x", x0, 0.05)
	await tw.finished

## L'armure s'effondre et la lueur s'éteint.
func _collapse(guardian: Node2D) -> void:
	var body := guardian.get_node_or_null("Corps") as CollisionObject2D
	if body:
		body.process_mode = Node.PROCESS_MODE_DISABLED
	var tw := create_tween().set_parallel()
	tw.tween_property(guardian, "modulate", Color(0.5, 0.6, 1.0, 0.0), 1.4)
	tw.tween_property(guardian, "scale", Vector2(1.15, 0.7), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	guardian.queue_free()

# --- 5. L'escalier ---

func _on_stairs_entered(player: Node2D) -> void:
	if not _free() or not PlayerData.get_flag("gardien_temple_vaincu"):
		return
	_busy = true
	PlayerData.controls_locked = true
	await _say(stairs.lines)
	if is_instance_valid(player):
		player.global_position += stairs_push_back
	PlayerData.controls_locked = false
	_busy = false
