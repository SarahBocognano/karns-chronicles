extends Node2D

@export var camera_zoom: Vector2 = Vector2(3.0, 3.0)
@export var ground_path: NodePath = "Ground"
@export var camera_follows_player: bool = true
## La pièce couvre tout l'écran : le zoom est calculé d'après la taille de la fenêtre
## (camera_zoom est alors ignoré). Si la pièce n'a pas le même format que l'écran,
## la caméra suit Zylrak sur l'axe qui dépasse, sans jamais montrer le fond.
@export var fill_screen: bool = false
## Musique de la carte, jouée en fondu à l'arrivée (vide : la musique s'arrête en fondu).
## Deux cartes avec le même morceau (l'auberge et son étage) le gardent sans le redémarrer.
@export var music: AudioStream
## Limites de la caméra (pixels du monde). Vide : l'emprise du sol (Ground).
## Sert aux cartes en hauteur, où l'on doit voir le vide (et le décor lointain) au-delà du plateau.
@export var camera_bounds: Rect2 = Rect2()

var _cam: Camera2D
var _room := Rect2()

func _get_real_player() -> Node:
	for node in get_tree().get_nodes_in_group("Player"):
		if node.has_node("Camera2D"):
			return node
	return null

func _ready() -> void:
	# (par l'arbre de scène : ce script se compile aussi sans les autoloads, ex. générateur de carte)
	var musique := get_node_or_null("/root/Musique")
	if musique:
		musique.play(music)
	_apply_camera_settings()
	if fill_screen:
		get_viewport().size_changed.connect(_fit_room_to_screen)
	_spawn_companions()
	_spawn_dog()
	Eclairage.apply(self)

## Croûton, si Zylrak l'a gardé (contrat du voleur : flag "voleur_chien_garde"), le suit aussi.
func _spawn_dog() -> void:
	var player_data := get_node_or_null("/root/PlayerData")
	if player_data == null or not player_data.get_flag("voleur_chien_garde"):
		return
	for node in get_tree().get_nodes_in_group("Chien"):
		if not node.is_queued_for_deletion():
			return
	var player := _get_real_player()
	if player == null:
		return
	var dog: Node2D = load("res://scenes/characters/ChienCompagnon.tscn").instantiate()
	dog.facing = player_data.facing
	player.get_parent().add_child(dog)
	player.get_parent().move_child(dog, player.get_index())
	var back := {"up": Vector2.DOWN, "down": Vector2.UP, "left": Vector2.RIGHT, "right": Vector2.LEFT}
	dog.global_position = player.global_position + back.get(player_data.facing, Vector2.UP) * 44.0

## Ysolde, une fois qu'elle a rejoint Zylrak (flag "ysolde_joined"), le suit sur toutes les cartes.
func _spawn_companions() -> void:
	var player_data := get_node_or_null("/root/PlayerData")
	if player_data == null or not player_data.get_flag("ysolde_joined"):
		return
	for node in get_tree().get_nodes_in_group("Compagnon"):
		if not node.is_queued_for_deletion():
			return   # déjà placée dans la carte
	var player := _get_real_player()
	if player == null:
		return
	var companion: Node2D = load("res://scenes/characters/YsoldeCompagnon.tscn").instantiate()
	companion.facing = player_data.facing
	player.get_parent().add_child(companion)
	# Avant Zylrak dans l'arbre : dans les intérieurs (sans tri en Y), elle passe sous lui.
	player.get_parent().move_child(companion, player.get_index())
	# Juste derrière Zylrak, dans le sens où il arrive.
	var back := {"up": Vector2.DOWN, "down": Vector2.UP, "left": Vector2.RIGHT, "right": Vector2.LEFT}
	companion.global_position = player.global_position + back.get(player_data.facing, Vector2.UP) * 28.0

func _apply_camera_settings() -> void:
	var player := _get_real_player()
	if not player:
		print("ERREUR: aucun node avec Camera2D trouvé dans le groupe 'Player'")
		return

	var cam: Camera2D = player.get_node("Camera2D")
	_cam = cam
	cam.zoom = camera_zoom

	var ground = get_node_or_null(ground_path)
	if ground and ground is TileMapLayer:
		var used_rect: Rect2i = ground.get_used_rect()
		var tile_size: Vector2 = ground.tile_set.tile_size
		var top_left: Vector2 = ground.to_global(Vector2(used_rect.position) * tile_size)
		var bottom_right: Vector2 = ground.to_global(Vector2(used_rect.position + used_rect.size) * tile_size)
		if camera_bounds.size != Vector2.ZERO:
			top_left = camera_bounds.position
			bottom_right = camera_bounds.end
		_room = Rect2(top_left, bottom_right - top_left)

		cam.limit_left = int(top_left.x)
		cam.limit_top = int(top_left.y)
		cam.limit_right = int(bottom_right.x)
		cam.limit_bottom = int(bottom_right.y)

		if fill_screen:
			# La caméra suit Zylrak ; les limites l'empêchent de sortir de la pièce.
			cam.top_level = false
			_fit_room_to_screen()
		elif camera_follows_player:
			# Comportement normal : la caméra suit le joueur (enfant de Player)
			cam.top_level = false
		else:
			# Caméra fixe : on la détache du joueur et on la centre sur la pièce
			cam.top_level = true
			var room_center: Vector2 = (top_left + bottom_right) / 2.0
			cam.global_position = room_center
	else:
		print("ERREUR: ground introuvable ou n'est pas un TileMapLayer. ground=", ground)

## Zoom minimal pour que la pièce recouvre tout l'écran (pas de bandes sur les côtés).
func _fit_room_to_screen() -> void:
	if _cam == null or _room.size.x <= 0.0 or _room.size.y <= 0.0:
		return
	var screen := get_viewport().get_visible_rect().size
	var z: float = max(screen.x / _room.size.x, screen.y / _room.size.y)
	_cam.zoom = Vector2(z, z)
	_cam.reset_smoothing()
