extends Node

## Centralise tous les changements de carte + le fondu écran noir.

signal transition_finished
## Émis à la fin d'un combat, une fois revenu sur la carte ("victoire", "fuite" ou "defaite").
signal battle_finished(result: String)

const BATTLE_SCENE := "res://scenes/battle/Battle.tscn"
const SWIRL_SHADER := preload("res://resources/shaders/battle_swirl.gdshader")
## Où Zylrak se réveille après une défaite (soigné).
const DEFEAT_SCENE := "res://scenes/maps/VillageMap.tscn"
const DEFEAT_SPAWN := "SpawnFromForest"
## Musique des combats (« RPG/JRPG Combat Exploration Themes », version en boucle).
const BATTLE_MUSIC := preload("res://assets/audio/musique/combat.mp3")

@export var fade_duration: float = 0.3

var _fade_rect: ColorRect
## true pendant un combat (les zones de rencontres ne se déclenchent plus).
var in_battle := false

func _ready() -> void:
	# Overlay noir plein écran, au-dessus de tout, créé au démarrage du jeu.
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(_fade_rect)
	call_deferred("_add_overlay", layer)

func _add_overlay(layer: CanvasLayer) -> void:
	get_tree().root.add_child(layer)

func change_scene(scene_path: String, spawn_point: String) -> void:
	PlayerData.next_spawn_point = spawn_point

	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, fade_duration)
	await tween.finished

	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame  # laisse la nouvelle scène s'initialiser

	var tween_in := create_tween()
	tween_in.tween_property(_fade_rect, "modulate:a", 0.0, fade_duration)
	await tween_in.finished

	transition_finished.emit()

## Lance un combat par-dessus la carte actuelle : la carte est figée pendant le combat,
## puis Zylrak la retrouve exactement où il était.
## `monsters` : liste de MonsterData (1 à 3).
func start_battle(background: Texture2D, monsters: Array) -> void:
	if in_battle:
		return
	in_battle = true
	PlayerData.controls_locked = true
	var map := get_tree().current_scene
	Musique.start_battle(BATTLE_MUSIC)
	await _battle_intro()
	if is_instance_valid(map):
		map.process_mode = Node.PROCESS_MODE_DISABLED

	var battle: Node = load(BATTLE_SCENE).instantiate()
	battle.background = background
	battle.monster_list = monsters
	get_tree().root.add_child(battle)
	var tw_in := create_tween()
	tw_in.tween_property(_fade_rect, "modulate:a", 0.0, 0.4)

	var result: String = await battle.finished

	var tw_out := create_tween()
	tw_out.tween_property(_fade_rect, "modulate:a", 1.0, 0.4)
	Musique.end_battle()
	await tw_out.finished
	battle.queue_free()
	if is_instance_valid(map):
		map.process_mode = Node.PROCESS_MODE_INHERIT

	if result == "defaite":
		# Zylrak se réveille au village, soigné.
		PlayerData.current_hp = PlayerData.max_hp
		PlayerData.current_energy = PlayerData.max_energy
		in_battle = false
		await change_scene(DEFEAT_SCENE, DEFEAT_SPAWN)
	else:
		await get_tree().process_frame
		var tw_back := create_tween()
		tw_back.tween_property(_fade_rect, "modulate:a", 0.0, 0.4)
		await tw_back.finished
		in_battle = false
	PlayerData.controls_locked = false
	battle_finished.emit(result)

## Deux flashs blancs, puis l'écran tourbillonne et plonge dans le noir.
func _battle_intro() -> void:
	await RenderingServer.frame_post_draw
	var shot := ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var layer := CanvasLayer.new()
	layer.layer = 99
	get_tree().root.add_child(layer)
	var rect := TextureRect.new()
	rect.texture = shot
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var mat := ShaderMaterial.new()
	mat.shader = SWIRL_SHADER
	mat.set_shader_parameter("screen_size", Vector2(shot.get_size()))
	rect.material = mat
	layer.add_child(rect)
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(white)

	var tw := create_tween()
	for i in 2:
		tw.tween_property(white, "color:a", 0.75, 0.07)
		tw.tween_property(white, "color:a", 0.0, 0.09)
	tw.tween_method(func(p: float): mat.set_shader_parameter("progress", p), 0.0, 1.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_fade_rect.modulate.a = 1.0
	layer.queue_free()
