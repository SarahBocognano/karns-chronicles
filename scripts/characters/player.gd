extends CharacterBody2D

@export var speed: float = 150.0

@onready var body_sprite: AnimatedSprite2D = $BodySprite
@onready var outfit_sprite: AnimatedSprite2D = $OutfitSprite
@onready var hair_sprite: AnimatedSprite2D = $HairSprite

var layers: Array[AnimatedSprite2D]
var direction: Vector2 = Vector2.ZERO
var current_direction: String = "down"

func _ready() -> void:
	layers = [body_sprite, outfit_sprite, hair_sprite]
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
		play_layered_animation("walk_" + current_direction)
	else:
		stop_layered_animation()

	move_and_slide()

func update_facing_direction() -> void:
	if abs(direction.x) > abs(direction.y):
		current_direction = "right" if direction.x > 0 else "left"
	else:
		current_direction = "down" if direction.y > 0 else "up"

func play_layered_animation(anim_name: String) -> void:
	for layer in layers:
		if layer.sprite_frames and layer.sprite_frames.has_animation(anim_name):
			if layer.animation != anim_name or not layer.is_playing():
				layer.play(anim_name)

func stop_layered_animation() -> void:
	for layer in layers:
		layer.stop()
