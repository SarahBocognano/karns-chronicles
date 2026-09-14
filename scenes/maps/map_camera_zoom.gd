extends Node2D

@export var camera_zoom: Vector2 = Vector2(3.0, 3.0)
@export var ground_path: NodePath = "Ground"
@export var camera_follows_player: bool = true

func _get_real_player() -> Node:
	for node in get_tree().get_nodes_in_group("Player"):
		if node.has_node("Camera2D"):
			return node
	return null

func _ready() -> void:
	_apply_camera_settings()

func _apply_camera_settings() -> void:
	var player := _get_real_player()
	if not player:
		print("ERREUR: aucun node avec Camera2D trouvé dans le groupe 'Player'")
		return

	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom = camera_zoom

	var ground = get_node_or_null(ground_path)
	if ground and ground is TileMapLayer:
		var used_rect: Rect2i = ground.get_used_rect()
		var tile_size: Vector2 = ground.tile_set.tile_size
		var top_left: Vector2 = ground.to_global(Vector2(used_rect.position) * tile_size)
		var bottom_right: Vector2 = ground.to_global(Vector2(used_rect.position + used_rect.size) * tile_size)

		cam.limit_left = int(top_left.x)
		cam.limit_top = int(top_left.y)
		cam.limit_right = int(bottom_right.x)
		cam.limit_bottom = int(bottom_right.y)

		if camera_follows_player:
			# Comportement normal : la caméra suit le joueur (enfant de Player)
			cam.top_level = false
		else:
			# Caméra fixe : on la détache du joueur et on la centre sur la pièce
			cam.top_level = true
			print("cam.top_level", cam.top_level)
			var room_center: Vector2 = (top_left + bottom_right) / 2.0
			cam.global_position = room_center
	else:
		print("ERREUR: ground introuvable ou n'est pas un TileMapLayer. ground=", ground)
