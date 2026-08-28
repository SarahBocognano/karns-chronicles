extends Node

## Centralise tous les changements de carte + le fondu écran noir.

signal transition_finished

@export var fade_duration: float = 0.3

var _fade_rect: ColorRect

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
