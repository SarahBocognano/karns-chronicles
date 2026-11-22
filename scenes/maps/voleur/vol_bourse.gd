extends Node

## Contrat du voleur, au village : peu après que Zylrak a accepté le contrat, Pépin le bouscule
## sur la place et lui prend sa bourse (flag "voleur_bourse_volee", PlayerData.steal_purse).
## Tant que l'affaire n'est pas réglée (flag "voleur_goules_vaincues"), Pépin se cache : le Pépin
## qui court dans le village (`pepin_path`) est retiré de la carte.

const SHEET := preload("res://assets/sprites/characters/child_spritesheet.png")
const LINES := preload("res://resources/dialogues/pepin/pepin_bouscule.tres")

@export var pepin_path: NodePath

var _t := 0.0
var _busy := false

func _ready() -> void:
	if PlayerData.get_flag("voleur_bourse_volee") and not PlayerData.get_flag("voleur_goules_vaincues"):
		var pepin := get_node_or_null(pepin_path)
		if pepin:
			pepin.queue_free()

func _process(delta: float) -> void:
	_t += delta
	if _busy or _t < 1.5 or PlayerData.get_flag("voleur_bourse_volee") or not PlayerData.get_flag("contrat_voleur_accepte"):
		return
	if PlayerData.controls_locked or SceneTransition.in_battle or get_tree().paused:
		return
	var player := Cutscene.find_player(get_tree())
	if player:
		_steal(player)

func _steal(player: Node2D) -> void:
	_busy = true
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	add_child(cs)
	# Pépin arrive en courant de la gauche, passe dans les jambes de Zylrak et file à droite.
	var kid := AnimatedSprite2D.new()
	kid.sprite_frames = _run_frames()
	kid.scale = Vector2(0.7, 0.7)
	kid.z_index = 1
	player.get_parent().add_child(kid)
	kid.global_position = player.global_position + Vector2(-180, 6)
	kid.play("course")
	var tw := create_tween()
	tw.tween_property(kid, "global_position", player.global_position + Vector2(-8, 6), 0.55)
	await tw.finished
	var x0 := player.position.x
	var shake := create_tween()
	for i in 4:
		shake.tween_property(player, "position:x", x0 + (3.0 if i % 2 == 0 else -3.0), 0.04)
	shake.tween_property(player, "position:x", x0, 0.04)
	var tw2 := create_tween()
	tw2.tween_property(kid, "global_position", player.global_position + Vector2(200, 6), 0.6)
	tw2.parallel().tween_property(kid, "modulate:a", 0.0, 0.6).set_delay(0.3)
	await cs.say(LINES.lines)
	kid.queue_free()
	PlayerData.steal_purse()
	PlayerData.set_flag("voleur_bourse_volee", true)
	var pepin := get_node_or_null(pepin_path)
	if pepin:
		pepin.queue_free()
	cs.queue_free()
	PlayerData.controls_locked = false
	_busy = false

func _run_frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation("default")
	f.add_animation("course")
	f.set_animation_speed("course", 14.0)
	for i in range(1, 9):
		var at := AtlasTexture.new()
		at.atlas = SHEET
		at.region = Rect2(i * 64, 11 * 64, 64, 64)   # marche vers la droite
		f.add_frame("course", at)
	return f
