extends Node

## Scénario d'une salle du temple des Yrenn (tools/make_temple.gd). Chaque partie est facultative :
## - une arrivée (conversation `arrival`, jouée une fois : flag `arrival_flag`) ;
## - le cercle de cendres du vestibule (flag "indice_ordre_vu") : la flamme de l'Ordre des Cendres,
##   renversée, tracée avec le sang du marchand ;
## - le gardien de la salle du fond, devant l'autel : une armure des Yrenn qu'un fragment de l'âme de
##   la Bête a dévorée sous la lune noire. Il s'éveille quand Zylrak approche, combat (on ne peut pas
##   fuir) ; vaincu, l'armure s'effondre et le fragment, une braise noire, tente de s'enfuir : Zylrak
##   l'enferme dans la cendre (flags "gardien_temple_vaincu", "fragment_ame_lune"). Le corps du
##   marchand et le parchemin de l'autel s'examinent ensuite (point_inspection.gd).

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
## Après la capture du fragment.
@export var fragment_caught: DialogueConversation
@export_group("Nœuds")
@export var guardian_path: NodePath
@export var circle_zone_path: NodePath
@export var guardian_zone_path: NodePath

const SHARD := preload("res://assets/sprites/objets/temple/eclat_ame.png")

var _busy := false
var _hover: Tween

func _ready() -> void:
	var guardian := get_node_or_null(guardian_path) as Node2D
	if guardian and PlayerData.get_flag("gardien_temple_vaincu"):
		guardian.queue_free()
	_connect(circle_zone_path, _on_circle_entered)
	_connect(guardian_zone_path, _on_guardian_zone_entered)
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
	var at := guardian.global_position if is_instance_valid(guardian) else player.global_position
	if is_instance_valid(guardian):
		await _collapse(guardian)
	var shard := _shard_rises(at)
	await _say(guardian_defeated.lines)
	if is_instance_valid(player):
		await _catch(shard, player)
	PlayerData.set_flag("fragment_ame_lune", true)
	await _say(fragment_caught.lines)
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

## La braise noire sort des cendres de l'armure et tourne sur place, comme si elle cherchait une issue.
func _shard_rises(at: Vector2) -> Sprite2D:
	var shard := Sprite2D.new()
	shard.texture = SHARD
	shard.position = at + Vector2(0, -10)
	shard.z_index = 2
	get_parent().add_child(shard)
	var light := PointLight2D.new()
	light.texture = load("res://scenes/maps/sceau_yrenn.gd").glow_texture()
	light.color = Color(1.0, 0.25, 0.3)
	light.energy = 0.9
	light.texture_scale = 0.4
	shard.add_child(light)
	var tw := create_tween()
	tw.tween_property(shard, "position:y", at.y - 34, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_hover = shard.create_tween().set_loops()
		_hover.tween_property(shard, "position:x", at.x + 6, 0.5).set_trans(Tween.TRANS_SINE)
		_hover.tween_property(shard, "position:x", at.x - 6, 0.5).set_trans(Tween.TRANS_SINE))
	return shard

## Zylrak tend la main : la braise file vers lui, la cendre se referme dessus (éclair gris).
func _catch(shard: Sprite2D, player: Node2D) -> void:
	if not is_instance_valid(shard):
		return
	if player.has_method("face"):
		player.face("up")
	if _hover:
		_hover.kill()
	var tw := create_tween()
	tw.tween_property(shard, "global_position", player.global_position + Vector2(0, -14), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(shard, "scale", Vector2(0.5, 0.5), 0.6)
	await tw.finished
	var flash := create_tween()
	flash.tween_property(player, "modulate", Color(1.8, 1.7, 1.6), 0.12)
	flash.tween_property(player, "modulate", Color.WHITE, 0.5)
	shard.queue_free()
	await flash.finished
