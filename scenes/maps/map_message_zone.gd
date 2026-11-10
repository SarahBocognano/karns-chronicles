extends Area2D

## Zone qui fait parler Zylrak quand il y entre (ex. un chemin pas encore accessible),
## puis le repousse doucement pour qu'il ne reste pas coincé dedans.

@export var lines: Array[DialogueLine] = []
## Déplacement appliqué à Zylrak à la fin du message (ex. le faire reculer d'un pas).
@export var push_back: Vector2 = Vector2.ZERO

const DialogueBoxScene = preload("res://scenes/Dialog/dialog_box.tscn")

var dialogue_box: CanvasLayer
var active := false
var line_index := 0
var player: Node2D

func _ready() -> void:
	dialogue_box = DialogueBoxScene.instantiate()
	add_child(dialogue_box)
	dialogue_box.hide_dialogue()
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if active or lines.is_empty() or PlayerData.controls_locked:
		return
	if not (body is CharacterBody2D and body.is_in_group("Player")):
		return
	player = body
	active = true
	line_index = 0
	PlayerData.controls_locked = true
	_show_line()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	line_index += 1
	if line_index >= lines.size():
		_finish()
	else:
		_show_line()

func _show_line() -> void:
	var line := lines[line_index]
	dialogue_box.show_dialogue(line.speaker_name, line.text, line.portrait)

func _finish() -> void:
	active = false
	dialogue_box.hide_dialogue()
	if player:
		player.global_position += push_back
	PlayerData.controls_locked = false
