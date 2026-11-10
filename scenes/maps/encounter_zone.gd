extends Area2D

## Zone de rencontres aléatoires : tant que Zylrak marche dedans, chaque case parcourue
## a une chance de lancer un combat (SceneTransition.start_battle).

signal player_entered
signal player_exited

## Probabilité de rencontre à chaque case parcourue dans la zone.
@export_range(0.0, 1.0) var encounter_rate: float = 0.08
## Monstres qu'on peut croiser ici (tirés au hasard pour composer le groupe).
@export var monsters: Array[MonsterData] = []
@export_range(1, 3) var min_monsters: int = 1
@export_range(1, 3) var max_monsters: int = 2
## Décor de l'écran de combat (480×270).
@export var battle_background: Texture2D
## Cases sans rencontre en arrivant sur la carte et après chaque combat.
@export var safe_steps: int = 6

const STEP := 32.0

var player_inside := false
var _player: Node2D
var _last_pos := Vector2.ZERO
var _distance := 0.0
var _grace := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_grace = safe_steps
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("Player"):
		player_inside = true
		_player = body
		_last_pos = body.global_position
		player_entered.emit()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("Player"):
		player_inside = false
		player_exited.emit()

func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pos := _player.global_position
	if not player_inside or PlayerData.controls_locked or SceneTransition.in_battle:
		_last_pos = pos
		return
	_distance += pos.distance_to(_last_pos)
	_last_pos = pos
	while _distance >= STEP:
		_distance -= STEP
		if _grace > 0:
			_grace -= 1
		elif _rng.randf() < encounter_rate:
			start_encounter()
			return

## Lance un combat tout de suite avec un groupe tiré au hasard.
func start_encounter() -> void:
	if monsters.is_empty() or SceneTransition.in_battle:
		return
	_grace = safe_steps
	_distance = 0.0
	var group: Array = []
	for i in _rng.randi_range(min_monsters, max(min_monsters, max_monsters)):
		group.append(monsters[_rng.randi() % monsters.size()])
	SceneTransition.start_battle(battle_background, group)
