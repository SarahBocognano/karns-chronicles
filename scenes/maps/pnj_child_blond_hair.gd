extends CharacterBody2D

@export var speed: float = 150
@export var min_wait_time: float = 0.1
@export var max_wait_time: float = 1.0
@export var min_move_time: float = 1.0
@export var max_move_time: float = 2.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var direction_timer: Timer = $DirectionTimer

enum State { IDLE, WALKING }
var current_state: State = State.IDLE
var current_direction: Vector2 = Vector2.ZERO

var directions: Dictionary = {
	"up": Vector2.UP,
	"down": Vector2.DOWN,
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT
}

func _ready() -> void:
	direction_timer.timeout.connect(_on_direction_timer_timeout)
	_start_idle()

func _physics_process(_delta: float) -> void:
	# Pépin s'arrête de courir pendant qu'il parle à Zylrak.
	var dialogue := get_node_or_null("Dialogue")
	var talking: bool = dialogue != null and dialogue.in_dialogue
	direction_timer.paused = talking
	if talking:
		velocity = Vector2.ZERO
		sprite.pause()
		return
	if current_state == State.WALKING and not sprite.is_playing():
		sprite.play()
	if current_state == State.WALKING:
		velocity = current_direction * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _start_walking() -> void:
	current_state = State.WALKING
	var dir_names: Array = directions.keys()
	var random_dir_name: String = dir_names[randi() % dir_names.size()]
	current_direction = directions[random_dir_name]
	sprite.play("walk_" + random_dir_name)
	direction_timer.start(randf_range(min_move_time, max_move_time))

func _start_idle() -> void:
	current_state = State.IDLE
	current_direction = Vector2.ZERO
	sprite.stop()
	direction_timer.start(randf_range(min_wait_time, max_wait_time))

func _on_direction_timer_timeout() -> void:
	if current_state == State.WALKING:
		_start_idle()
	else:
		_start_walking()
