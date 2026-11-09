extends Node2D

@export var dialogue_lines: Array[DialogueLine] = []

var player_in_range: bool = false
var player_ref: Node2D = null
var in_dialogue: bool = false
var current_line: int = 0

const DialogueBoxScene = preload("res://scenes/Dialog/dialog_box.tscn")
var dialogue_box: CanvasLayer

func _ready() -> void:
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)
	dialogue_box = DialogueBoxScene.instantiate()
	get_tree().root.call_deferred("add_child", dialogue_box)
	dialogue_box.hide_dialogue()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = false
		player_ref = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if in_dialogue:
			advance_dialogue()
		elif player_in_range:
			start_dialogue()

func start_dialogue() -> void:
	current_line = 0
	in_dialogue = true
	_show_current_line()

func advance_dialogue() -> void:
	current_line += 1
	if current_line >= dialogue_lines.size():
		end_dialogue()
	else:
		_show_current_line()

func _show_current_line() -> void:
	var line: DialogueLine = dialogue_lines[current_line]
	dialogue_box.show_dialogue(line.speaker_name, line.text, line.portrait)

func end_dialogue() -> void:
	in_dialogue = false
	dialogue_box.hide_dialogue()
