extends CharacterBody2D

@export var speed: float = 150.0

@onready var body_sprite: AnimatedSprite2D = $BodySprite

var direction: Vector2 = Vector2.ZERO
var current_direction: String = "down"

func _ready() -> void:
	_apply_spawn_point()

func _apply_spawn_point() -> void:
	if PlayerData.next_spawn_point == "":
		return

	var spawn_marker := get_tree().current_scene.find_child(PlayerData.next_spawn_point, true, false)

	if spawn_marker and spawn_marker is Node2D:
		global_position = spawn_marker.global_position
	else:
		push_warning("Spawn point '%s' introuvable dans la scène actuelle." % PlayerData.next_spawn_point)

	PlayerData.next_spawn_point = ""  # on consomme le spawn point pour éviter de le réutiliser par erreur

func _physics_process(_delta: float) -> void:
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")
	direction = direction.normalized()

	velocity = direction * speed

	if direction != Vector2.ZERO:
		update_facing_direction()
		play_animation("walk_" + current_direction)
	else:
		stop_animation()

	move_and_slide()

func update_facing_direction() -> void:
	if abs(direction.x) > abs(direction.y):
		current_direction = "right" if direction.x > 0 else "left"
	else:
		current_direction = "down" if direction.y > 0 else "up"

func play_animation(anim_name: String) -> void:
	if body_sprite.sprite_frames and body_sprite.sprite_frames.has_animation(anim_name):
		if body_sprite.animation != anim_name or not body_sprite.is_playing():
			body_sprite.play(anim_name)

func stop_animation() -> void:
	body_sprite.stop()


func _on_direction_timer_timeout() -> void:
	pass # Replace with function body.
