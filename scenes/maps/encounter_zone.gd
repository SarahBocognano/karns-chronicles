extends Area2D

## Zone de rencontres aléatoires (les herbes hautes de la forêt).
## Pour l'instant, elle sait seulement si Zylrak est dedans : le système de combat
## (transition animée + écran de combat) viendra s'y brancher.

signal player_entered
signal player_exited

## Probabilité de rencontre à chaque case parcourue dans la zone.
@export_range(0.0, 1.0) var encounter_rate: float = 0.08
## Monstres qu'on peut croiser ici (identifiants, définis plus tard avec le combat).
@export var monster_pool: Array[String] = ["goule"]

var player_inside := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("Player"):
		player_inside = true
		player_entered.emit()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("Player"):
		player_inside = false
		player_exited.emit()
