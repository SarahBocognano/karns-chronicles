extends Node

## Scénario d'une salle de la grotte (tools/make_grotte.gd). Chaque partie est facultative :
## - une arrivée (conversation `arrival`, jouée une fois : flag `arrival_flag`) ;
## - la gardienne du filon : quand Zylrak approche, l'araignée géante se dresse, combat (on ne peut
##   pas fuir) ; vaincue, elle s'effondre (flag "araignee_geante_vaincue") et le filon peut être
##   examiné (point_inspection.gd : la pierre-de-braise).

@export var arrival: DialogueConversation
@export var arrival_flag: String = ""
@export var monster: MonsterData
@export var battle_background: Texture2D
@export var boss_wake: DialogueConversation
@export var boss_defeated: DialogueConversation
@export var boss_path: NodePath
@export var boss_zone_path: NodePath

const BOSS_FLAG := "araignee_geante_vaincue"

var _busy := false

func _ready() -> void:
	var boss := get_node_or_null(boss_path) as Node2D
	if boss and PlayerData.get_flag(BOSS_FLAG):
		boss.queue_free()
	var zone := get_node_or_null(boss_zone_path) as Area2D
	if zone:
		zone.body_entered.connect(func(body: Node2D):
			if body is CharacterBody2D and body.is_in_group("Player"):
				_on_boss_zone(body))
	if arrival and arrival_flag != "" and not PlayerData.get_flag(arrival_flag):
		_arrive.call_deferred()

func _free() -> bool:
	return not _busy and not PlayerData.controls_locked and not SceneTransition.in_battle

func _say(lines: Array[DialogueLine]) -> void:
	var cs := Cutscene.new()
	add_child(cs)
	await cs.say(lines)
	if is_instance_valid(cs):
		cs.queue_free()

func _arrive() -> void:
	_busy = true
	PlayerData.controls_locked = true
	await get_tree().create_timer(0.6).timeout   # fin du fondu d'arrivée
	if not is_inside_tree():
		return
	await _say(arrival.lines)
	PlayerData.set_flag(arrival_flag, true)
	PlayerData.controls_locked = false
	_busy = false

func _on_boss_zone(player: Node2D) -> void:
	if not _free() or PlayerData.get_flag(BOSS_FLAG) or monster == null:
		return
	_busy = true
	PlayerData.controls_locked = true
	if player.has_method("face"):
		player.face("up")
	var boss := get_node_or_null(boss_path) as Node2D
	if boss:
		await _rear(boss)
	if boss_wake:
		await _say(boss_wake.lines)
	if not is_inside_tree():
		return
	SceneTransition.start_battle(battle_background, [monster], false)
	var result: String = await SceneTransition.battle_finished
	if result != "victoire" or not is_inside_tree():
		_busy = false   # défaite : Zylrak se réveille au village
		return
	PlayerData.set_flag(BOSS_FLAG, true)
	PlayerData.controls_locked = true
	boss = get_node_or_null(boss_path) as Node2D
	if boss:
		await _collapse(boss)
	if boss_defeated:
		await _say(boss_defeated.lines)
	PlayerData.controls_locked = false
	_busy = false

## L'araignée se dresse : elle grandit d'un coup et tremble.
func _rear(boss: Node2D) -> void:
	var s0 := boss.scale
	var x0 := boss.position.x
	var tw := create_tween()
	tw.tween_property(boss, "scale", s0 * Vector2(1.12, 1.18), 0.25).set_trans(Tween.TRANS_BACK)
	for i in 6:
		tw.tween_property(boss, "position:x", x0 + (2.0 if i % 2 == 0 else -2.0), 0.05)
	tw.tween_property(boss, "position:x", x0, 0.05)
	tw.tween_property(boss, "scale", s0, 0.2)
	await tw.finished

## Elle s'effondre et s'efface.
func _collapse(boss: Node2D) -> void:
	var body := boss.get_node_or_null("Corps") as CollisionObject2D
	if body:
		body.process_mode = Node.PROCESS_MODE_DISABLED
	var tw := create_tween().set_parallel()
	tw.tween_property(boss, "modulate", Color(1.0, 0.3, 0.2, 0.0), 1.2)
	tw.tween_property(boss, "scale", boss.scale * Vector2(1.2, 0.6), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	boss.queue_free()
