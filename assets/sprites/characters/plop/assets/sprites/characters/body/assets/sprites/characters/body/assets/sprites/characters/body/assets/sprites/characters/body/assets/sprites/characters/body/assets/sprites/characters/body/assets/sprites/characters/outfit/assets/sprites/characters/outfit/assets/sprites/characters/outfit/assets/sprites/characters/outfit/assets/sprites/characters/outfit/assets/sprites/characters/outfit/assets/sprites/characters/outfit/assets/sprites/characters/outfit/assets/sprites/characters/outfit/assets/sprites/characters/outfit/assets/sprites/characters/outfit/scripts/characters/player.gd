extends CharacterBody2D

@export var speed: float = 150.0

@onready var sprite_2d: Sprite2D = $Sprite2D

var direction: Vector2 = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")
	direction = direction.normalized()  # évite que la diagonale soit plus rapide que les 4 directions

	velocity = direction * speed

	move_and_slide()
