extends Node

## Prépare les mini-cartes des cartes extérieures.
## À lancer depuis l'éditeur (ouvrir tools/bake_minimaps.tscn, puis F6) après avoir modifié une carte.
##
## Pour chaque carte, l'outil fait un rendu de la carte entière, puis écrit une petite image
## (1 pixel par case de 32 px) dans assets/ui/minimap/<NomDeLaCarte>.png :
## - couleur = couleur moyenne de la case dans le rendu (herbe, chemin, toit, eau…) ;
## - alpha 255 = on peut y marcher ; 160 = bloqué par un petit objet (chariot, tonneau, rocher,
##   puits…) ; 96 = bloqué par le décor (arbre, maison, falaise…).
## Le style final (aplats de couleur, contours) est calculé en jeu par scripts/minimap.gd.

const MAPS := [
	"res://scenes/maps/VillageMap.tscn",
	"res://scenes/maps/VillageV2Map.tscn",
	"res://scenes/maps/ForestMap.tscn",
	"res://scenes/maps/ForestCascadeMap.tscn",
	"res://scenes/maps/ForestChariotMap.tscn",
	"res://scenes/maps/RuinesMonteeMap.tscn",
	"res://scenes/maps/RuinesParvisMap.tscn",
	"res://scenes/maps/LacMap.tscn",
	"res://scenes/maps/GrotteEntreeMap.tscn",
	"res://scenes/maps/GrotteToilesMap.tscn",
	"res://scenes/maps/GrotteFilonMap.tscn",
]
const OUT_DIR := "res://assets/ui/minimap/"

func _ready() -> void:
	_bake_all.call_deferred()

func _bake_all() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for path in MAPS:
		await _bake(path)
	print("Mini-cartes prêtes.")
	get_tree().quit()

func _bake(path: String) -> void:
	var map: Node = load(path).instantiate()
	var ground: TileMapLayer = map.get_node("Ground")
	var used := ground.get_used_rect()
	var ts := Vector2(ground.tile_set.tile_size)
	var cell := ts.x * ground.scale.x
	var rect := Rect2(ground.position + Vector2(used.position) * ts * ground.scale, Vector2(used.size) * ts * ground.scale)
	var vp := SubViewport.new()
	vp.size = Vector2i(rect.size)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(map)
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.position = rect.position
	vp.add_child(cam)
	for i in 50:
		cam.make_current()
		_hide_characters(map)
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var cols := int(round(rect.size.x / cell))
	var rows := int(round(rect.size.y / cell))
	var out := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var space := vp.world_2d.direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collide_with_areas = false
	var step := maxi(1, int(cell / 8.0))
	for y in rows:
		for x in cols:
			var acc := Color(0, 0, 0, 0)
			var n := 0
			for py in range(0, int(cell), step):
				for px in range(0, int(cell), step):
					acc += img.get_pixel(clampi(int(x * cell) + px, 0, img.get_width() - 1), clampi(int(y * cell) + py, 0, img.get_height() - 1))
					n += 1
			acc /= n
			var free := true
			var only_props := true
			for o in [Vector2(0.5, 0.5), Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]:
				q.position = rect.position + (Vector2(x, y) + o) * cell
				for hit in space.intersect_point(q, 4):
					if hit.collider is StaticBody2D or hit.collider is TileMapLayer:
						free = false
						if not _is_prop(hit.collider, q.position, cell):
							only_props = false
			acc.a = 1.0 if free else (160.0 if only_props else 96.0) / 255.0
			out.set_pixel(x, y, acc)
	var out_path := OUT_DIR + map.name + ".png"
	out.save_png(ProjectSettings.globalize_path(out_path))
	print("Mini-carte ", map.name, " : ", cols, "×", rows, " cases -> ", out_path)
	vp.queue_free()
	await get_tree().process_frame

## Petit objet posé dans le décor (chariot, tonneau, rocher, puits, PNJ…), par opposition aux
## bâtiments et aux falaises : sur la mini-carte, il prend la couleur du sol autour de lui.
func _is_prop(collider: Object, pos: Vector2, cell: float) -> bool:
	if collider is TileMapLayer:
		var layer: TileMapLayer = collider
		var cc := layer.local_to_map(layer.to_local(pos))
		var sid := layer.get_cell_source_id(cc)
		if sid == -1:
			return false
		var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
		var file := src.texture.resource_path.get_file() if src and src.texture else ""
		return file.contains("decoratives") or file.contains("building elements")
	# Corps physique : petit s'il tient dans 3 × 3 cases (les murs de falaise sont bien plus longs).
	var body: CollisionObject2D = collider
	var box := Rect2()
	var first := true
	for owner_id in body.get_shape_owners():
		var xf := body.global_transform * body.shape_owner_get_transform(owner_id)
		for i in body.shape_owner_get_shape_count(owner_id):
			var r := xf * body.shape_owner_get_shape(owner_id, i).get_rect()
			box = r if first else box.merge(r)
			first = false
	return not first and box.size.x < cell * 3.0 and box.size.y < cell * 3.0

## Personnages, brume, boîtes de dialogue : pas sur la mini-carte.
func _hide_characters(map: Node) -> void:
	for n in map.find_children("*", "", true, false):
		if n is CanvasLayer or n.name == "Ambiance" or n is CharacterBody2D or n.is_in_group("Compagnon") or n.has_node("AnimatedSprite2D"):
			n.visible = false
