extends Node2D

## PNJ qui parle avec Zylrak.
## - `conversations` : le PNJ joue la première conversation disponible selon les flags de PlayerData.
## - `dialogue_lines` : liste simple, utilisée seulement si `conversations` est vide (ex. le Forgeron).

@export var conversations: Array[DialogueConversation] = []
@export var dialogue_lines: Array[DialogueLine] = []

@export_group("Interaction")
## Rayon de la zone d'interaction créée automatiquement si le PNJ n'a pas d'InteractionArea.
@export var interaction_radius: float = 30.0

@export_group("Marqueur de quête")
## Décalage du « ! » (placé automatiquement au-dessus de la tête du sprite).
@export var marker_offset: Vector2 = Vector2.ZERO

@export_group("Approche automatique")
## Vitesse de marche quand le PNJ vient vers Zylrak (conversation `auto_start`).
@export var walk_speed: float = 55.0
## Distance à laquelle il s'arrête devant Zylrak.
@export var stop_distance: float = 26.0
## Délai avant qu'il se mette en route (laisse le fondu d'arrivée se terminer).
@export var approach_delay: float = 0.6

const DialogueBoxScene = preload("res://scenes/Dialog/dialog_box.tscn")
## Feuilles LPC : cases de 64 px, marche sur les rangées 8 (haut) à 11 (droite).
const LPC_FRAME := 64
const LPC_WALK_ROWS := {"up": 8, "left": 9, "down": 10, "right": 11}

var player_in_range := false
var player_ref: Node2D = null
var in_dialogue := false
var current_line := 0
var current_lines: Array[DialogueLine] = []
var current_conversation: DialogueConversation = null

var dialogue_box: CanvasLayer
var sprite: AnimatedSprite2D
var _marker_holder: Node2D

func _ready() -> void:
	sprite = get_node_or_null("AnimatedSprite2D")
	var area := _get_or_create_interaction_area()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	# La boîte de dialogue est un enfant du PNJ : elle disparaît avec la scène.
	dialogue_box = DialogueBoxScene.instantiate()
	add_child(dialogue_box)
	dialogue_box.hide_dialogue()

	_create_quest_marker()
	PlayerData.flag_changed.connect(_on_flag_changed)
	_update_quest_marker()

	var conversation := _pick_conversation()
	if conversation and conversation.auto_start:
		_play_auto_start.call_deferred(conversation)

# --- Zone d'interaction ---

func _get_or_create_interaction_area() -> Area2D:
	var area := get_node_or_null("InteractionArea") as Area2D
	if area:
		return area
	area = Area2D.new()
	area.name = "InteractionArea"
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = interaction_radius
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	return area

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = false
		player_ref = null

# --- Déroulé du dialogue ---

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if in_dialogue:
		get_viewport().set_input_as_handled()
		advance_dialogue()
	elif player_in_range and not PlayerData.controls_locked:
		get_viewport().set_input_as_handled()
		start_dialogue()

func _pick_conversation() -> DialogueConversation:
	for conversation in conversations:
		if conversation and conversation.is_available(PlayerData.get_flag):
			return conversation
	return null

func start_dialogue() -> void:
	var conversation := _pick_conversation()
	if conversation:
		_start_lines(conversation.lines, conversation)
	elif conversations.is_empty() and not dialogue_lines.is_empty():
		_start_lines(dialogue_lines, null)

func _start_lines(lines: Array[DialogueLine], conversation: DialogueConversation) -> void:
	current_lines = lines
	current_conversation = conversation
	current_line = 0
	in_dialogue = true
	PlayerData.controls_locked = true
	_update_quest_marker()
	_show_current_line()

func advance_dialogue() -> void:
	current_line += 1
	if current_line >= current_lines.size():
		end_dialogue()
	else:
		_show_current_line()

func _show_current_line() -> void:
	var line: DialogueLine = current_lines[current_line]
	dialogue_box.show_dialogue(line.speaker_name, line.text, line.portrait)

func end_dialogue() -> void:
	in_dialogue = false
	dialogue_box.hide_dialogue()
	PlayerData.controls_locked = false
	if current_conversation:
		for flag in current_conversation.flags_on_finish:
			PlayerData.set_flag(flag, true)
	current_conversation = null
	_update_quest_marker()

# --- Marqueur de quête « ! » ---

func _create_quest_marker() -> void:
	_marker_holder = QuestMarker.new()
	_marker_holder.name = "QuestMarker"
	_marker_holder.z_index = 10
	add_child(_marker_holder)
	# Taille constante à l'écran, quelle que soit l'échelle du PNJ (souvent 0.7).
	_marker_holder.scale = Vector2.ONE / global_scale
	var base := _marker_base_position()
	_marker_holder.position = base

	var tween := create_tween().set_loops()
	tween.tween_property(_marker_holder, "position:y", base.y - 2.0 / global_scale.y, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_marker_holder, "position:y", base.y, 0.45).set_trans(Tween.TRANS_SINE)

## Juste au-dessus de la tête du sprite (+ `marker_offset` pour ajuster à la main).
func _marker_base_position() -> Vector2:
	var head := Vector2.ZERO
	if sprite and sprite.sprite_frames:
		var names := sprite.sprite_frames.get_animation_names()
		if not names.is_empty() and sprite.sprite_frames.get_frame_count(names[0]) > 0:
			var frame_size := sprite.sprite_frames.get_frame_texture(names[0], 0).get_size() * sprite.scale
			var center := sprite.position + (sprite.offset * sprite.scale)
			if not sprite.centered:
				center += frame_size / 2.0
			# Les cases LPC ont ~12 px de vide au-dessus de la tête.
			head = center + Vector2(0, -frame_size.y / 2.0 + 12.0 * sprite.scale.y)
	return head + marker_offset

## « ! » en pixel art : une barre et un point dorés avec un contour sombre.
class QuestMarker extends Node2D:
	const GOLD := Color(0.96, 0.78, 0.29)
	const LIGHT := Color(1.0, 0.93, 0.62)
	const DARK := Color(0.12, 0.08, 0.05)
	func _draw() -> void:
		draw_rect(Rect2(-2.5, -17, 5, 11), DARK)
		draw_rect(Rect2(-2.5, -5, 5, 5), DARK)
		draw_rect(Rect2(-1.5, -16, 3, 9), GOLD)
		draw_rect(Rect2(-1.5, -4, 3, 3), GOLD)
		draw_rect(Rect2(-1.5, -16, 1, 9), LIGHT)

func _update_quest_marker() -> void:
	if not _marker_holder:
		return
	var conversation := _pick_conversation()
	_marker_holder.visible = not in_dialogue and conversation != null and conversation.show_quest_marker

func _on_flag_changed(_flag_name: String, _value: bool) -> void:
	_update_quest_marker()

# --- Approche automatique (conversation `auto_start`) ---

func _play_auto_start(conversation: DialogueConversation) -> void:
	PlayerData.controls_locked = true
	await get_tree().create_timer(approach_delay).timeout
	var player := _find_player()
	if player:
		await _walk_towards(player.global_position)
	_start_lines(conversation.lines, conversation)

func _find_player() -> Node2D:
	# Le groupe "Player" contient aussi des zones de collision : on cherche le CharacterBody2D.
	for node in get_tree().get_nodes_in_group("Player"):
		if node is CharacterBody2D:
			return node
	return null

func _walk_towards(target: Vector2) -> void:
	var to_target := target - global_position
	var distance := to_target.length() - stop_distance
	if distance <= 1.0:
		_face(to_target)
		return
	var destination := global_position + to_target.normalized() * distance
	var has_walk := _ensure_walk_animations()
	if has_walk:
		sprite.play("walk_" + _direction_name(to_target))
	var tween := create_tween()
	tween.tween_property(self, "global_position", destination, distance / walk_speed)
	await tween.finished
	_face(target - global_position)

func _face(direction: Vector2) -> void:
	if _ensure_walk_animations():
		sprite.play("idle_" + _direction_name(direction))

func _direction_name(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "right" if direction.x > 0 else "left"
	return "down" if direction.y > 0 else "up"

## Ajoute des animations walk_*/idle_* à partir de la feuille LPC du sprite, si elles n'existent pas.
func _ensure_walk_animations() -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false
	var frames := sprite.sprite_frames
	if frames.has_animation("walk_down"):
		return true
	var names := frames.get_animation_names()
	if names.is_empty() or frames.get_frame_count(names[0]) == 0:
		return false
	var first := frames.get_frame_texture(names[0], 0)
	if not (first is AtlasTexture):
		return false
	var sheet: Texture2D = first.atlas
	if sheet.get_height() < LPC_FRAME * 12 or sheet.get_width() < LPC_FRAME * 9:
		return false

	frames = frames.duplicate()  # ne modifie pas la ressource partagée de la scène
	sprite.sprite_frames = frames
	for dir: String in LPC_WALK_ROWS:
		var y: int = LPC_WALK_ROWS[dir] * LPC_FRAME
		var walk := "walk_" + dir
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 10.0)
		frames.set_animation_loop(walk, true)
		for i in range(1, 9):
			frames.add_frame(walk, _lpc_frame(sheet, i * LPC_FRAME, y))
		var idle := "idle_" + dir
		frames.add_animation(idle)
		frames.add_frame(idle, _lpc_frame(sheet, 0, y))
	return true

func _lpc_frame(sheet: Texture2D, x: int, y: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(x, y, LPC_FRAME, LPC_FRAME)
	return atlas
