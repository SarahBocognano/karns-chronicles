extends Node2D

## Compagnon de Zylrak (Ysolde) : il le suit à quelques pas, en reprenant exactement son trajet,
## et peut aussi marcher tout seul pendant une scène (walk_to, face).
## Le point d'origine est le centre du personnage, comme pour Zylrak (même tri en Y).

## Feuille LPC du personnage (cases de 64 px).
@export var sheet: Texture2D
@export var sprite_scale: float = 0.7
## Distance (le long du trajet de Zylrak) à laquelle le compagnon reste derrière lui.
@export var follow_distance: float = 30.0
@export var speed: float = 150.0
## false : le compagnon reste sur place (ex. Ysolde qui attend Zylrak à l'entrée des ruines).
@export var following: bool = true
@export_enum("up", "down", "left", "right") var facing: String = "down"

const FRAME := 64
const WALK_ROWS := {"up": 8, "left": 9, "down": 10, "right": 11}
## Au-delà de cette distance, le compagnon rejoint Zylrak d'un coup (ex. après un passage étroit).
const TELEPORT_DISTANCE := 240.0

var sprite: AnimatedSprite2D
var _trail: Array[Vector2] = []
var _player: Node2D
var _scripted := false

func _ready() -> void:
	add_to_group("Compagnon")
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.sprite_frames = _build_frames()
	add_child(sprite)
	face(facing)

func _physics_process(delta: float) -> void:
	if _scripted or not following:
		return
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return
	var target := _player.global_position
	if _trail.is_empty() or _trail[-1].distance_to(target) > 2.0:
		_trail.append(target)
	var remaining := _trail_length()
	if remaining > TELEPORT_DISTANCE:
		global_position = target - _facing_vector(_player_facing()) * follow_distance
		_trail.clear()
		return
	if remaining <= follow_distance + 0.5:
		_play("idle_" + facing)
		return
	# Un peu plus vite quand il est distancé, pour recoller à Zylrak.
	var pace := speed * (1.3 if remaining > follow_distance * 2.5 else 1.0)
	var step := minf(pace * delta, remaining - follow_distance)
	var moved := Vector2.ZERO
	while step > 0.0 and not _trail.is_empty():
		var to := _trail[0] - global_position
		var d := to.length()
		if d <= step:
			global_position = _trail[0]
			_trail.pop_front()
			step -= d
		else:
			global_position += to / d * step
			step = 0.0
		if d > 0.01:
			moved = to
	if moved != Vector2.ZERO:
		facing = _direction_name(moved)
		_play("walk_" + facing)

## Le compagnon se met à suivre Zylrak (après une scène, par exemple).
func start_following() -> void:
	following = true
	_trail.clear()

# --- Scènes automatiques ---

## Marche jusqu'à `target` (à appeler avec `await`).
func walk_to(target: Vector2, walk_speed: float = 80.0) -> void:
	_scripted = true
	while is_inside_tree() and global_position.distance_to(target) > 0.5:
		var to := target - global_position
		facing = _direction_name(to)
		_play("walk_" + facing)
		global_position = global_position.move_toward(target, walk_speed * get_physics_process_delta_time())
		await get_tree().physics_frame
	global_position = target
	_play("idle_" + facing)
	_trail.clear()
	_scripted = false

func face(dir: String) -> void:
	facing = dir
	_play("idle_" + dir)

# --- Outils ---

func _trail_length() -> float:
	var total := 0.0
	var prev := global_position
	for p in _trail:
		total += prev.distance_to(p)
		prev = p
	return total

func _play(anim: String) -> void:
	if sprite and sprite.sprite_frames.has_animation(anim) and (sprite.animation != anim or not sprite.is_playing()):
		sprite.play(anim)

func _find_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("Player"):
		if node is CharacterBody2D:
			return node
	return null

func _player_facing() -> String:
	var pd := get_node_or_null("/root/PlayerData")
	return pd.facing if pd else "down"

static func _facing_vector(dir: String) -> Vector2:
	match dir:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN

static func _direction_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir: String in WALK_ROWS:
		var walk := "walk_" + dir
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 10.0)
		frames.set_animation_loop(walk, true)
		for i in range(1, 9):
			frames.add_frame(walk, _frame(i, WALK_ROWS[dir]))
		# Attente : la pose debout de la marche (les rangées « idle » de la feuille LPC
		# n'ont pas tous les vêtements du personnage).
		var idle := "idle_" + dir
		frames.add_animation(idle)
		frames.add_frame(idle, _frame(0, WALK_ROWS[dir]))
	return frames

func _frame(col: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(col * FRAME, row * FRAME, FRAME, FRAME)
	return atlas
