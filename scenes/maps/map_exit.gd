extends "res://scenes/maps/map_message_zone.gd"

## Sortie vers une autre carte. Tant que les flags requis ne sont pas remplis, la sortie est
## fermée : Zylrak dit les répliques de `lines` (s'il y en a) et recule de `push_back`.

@export_file("*.tscn") var target_scene: String
## Nom du Marker2D d'arrivée dans la carte de destination.
@export var spawn_point: String
@export var required_flags: Array[String] = []

var _leaving := false

func _ready() -> void:
	super._ready()
	# Pas de sortie déclenchée dans la toute première image (Zylrak peut apparaître juste à côté).
	monitoring = false
	set_deferred("monitoring", true)

func _on_body_entered(body: Node2D) -> void:
	if _leaving or not (body is CharacterBody2D and body.is_in_group("Player")):
		return
	for flag in required_flags:
		if not PlayerData.get_flag(flag):
			super._on_body_entered(body)
			return
	_leaving = true
	SceneTransition.change_scene(target_scene, spawn_point)
