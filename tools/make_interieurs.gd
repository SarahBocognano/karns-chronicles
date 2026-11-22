extends SceneTree
# Lancer : Godot --headless --path . -s tools/make_interieurs.gd [-- jumelles]  (sans argument : toutes)
# Intérieurs de maisons du village, construits comme les salles du temple (tools/make_temple.gd) :
# un plan de sol (rectangles de cases), les murs (2 cases de haut, au nord de chaque sol), les
# dessus de murs et leurs coins posés automatiquement. Tuiles : houses_interriors (Szadi art) ;
# meubles : FL_Houses_int_FurnituresA et furnitures ; coins rentrants : tools/dev/draw_interieurs.gd.
# - MaisonJumellesMap : la maison de Mirabelle et Myrtille, où Myrtille tient sa boutique d'herbes
#   et de potions (scenes/maps/marchande.gd, scripts/ui/boutique.gd).
# - MaisonMargotMap : la ferme-fournil de la mère Margot (contrat du voleur) : four à pain, pétrin,
#   sacs de farine, et des traces de pas d'enfant dans la farine renversée.
# - MaisonAelisMap : la chambre qu'Aelis loue ; sur le rebord de la fenêtre, des poils de chien.

const T := 32
const HOUSES := "res://assets/sprites/tilesets/Buildings/houses_interriors.png"
const CORNERS := "res://assets/sprites/tilesets/Buildings/maison_coins.png"
const FURN_A := "res://assets/sprites/tilesets/Buildings/FL_Houses_int_FurnituresA.png"
const FURN := "res://assets/sprites/tilesets/Buildings/furnitures.png"
const TILESET_OUT := "res://resources/tilesets/maisons.tres"

# --- tuiles (source 0 : houses_interriors ; source 1 : coins rentrants) ---
const FILL := Vector2i(6, 1)
const RIM_TOP := Vector2i(1, 0)       # rebord en haut de la case
const RIM_BOTTOM := Vector2i(1, 3)
const RIM_LEFT := Vector2i(0, 1)
const RIM_RIGHT := Vector2i(3, 1)
const CORNER_TL := Vector2i(0, 0)
const CORNER_TR := Vector2i(3, 0)
const CORNER_BL := Vector2i(0, 3)
const CORNER_BR := Vector2i(3, 3)
const INNER_BR := 0
const INNER_BL := 1
const INNER_TR := 2
const INNER_TL := 3
## Murs (2 cases de haut) : [rangée du haut, rangée du bas] ; 7 colonnes par motif (0 à 6, crème).
const WALL_PLAIN := [5, 6]
const WALL_WINDOWS := [9, 10]
const FLOOR := [Vector2i(5, 30), Vector2i(6, 30), Vector2i(5, 31), Vector2i(6, 31)]

# --- meubles ---
const SHELF_POTS := Rect2(416, 140, 32, 66)
const SHELF_BOOKS := Rect2(448, 140, 32, 66)
const SHELF_MISC := Rect2(480, 140, 32, 66)
const SHELF_JARS := Rect2(448, 236, 32, 66)
const SHELF_DISHES := Rect2(416, 236, 32, 66)
const COUNTER := Rect2(256, 338, 96, 46)
const PLANTS := [Rect2(420, 192, 20, 42), Rect2(454, 202, 20, 32), Rect2(486, 202, 20, 32), Rect2(518, 200, 20, 34), Rect2(550, 198, 20, 36), Rect2(582, 200, 20, 34)]
const PLANTER := Rect2(616, 208, 48, 26)       # jardinière
const WALL_SHELF := Rect2(424, 270, 48, 30)    # étagère murale avec pots
const BARRELS := Rect2(740, 320, 24, 64)
const LOW_CABINETS := [Rect2(480, 224, 32, 50), Rect2(512, 224, 32, 50)]   # buffets bas, herbes et fioles dessus
const RUG := Rect2(128, 1088, 128, 96)        # tapis vert
const FURN_C := "res://assets/sprites/tilesets/Buildings/FL_Houses_int_FurnituresC.png"
const DECO := "res://assets/sprites/tilesets/Buildings/FL_Houses_decoratives.png"
const OVEN := Rect2(480, 30, 64, 84)            # four à pain (FurnituresC)
const BREAD_RACKS := [Rect2(576, 14, 32, 50), Rect2(576, 78, 32, 50)]   # casiers à pain
const SACKS := [Rect2(225, 324, 26, 22), Rect2(257, 324, 24, 22), Rect2(290, 350, 26, 34)]   # sacs de farine (decoratives)
const BED_BLUE := Rect2(288, 8, 32, 64)         # lit à couverture bleue (FurnituresA)
const WARDROBE := Rect2(0, 8, 32, 72)
const VOLEUR := "res://assets/sprites/objets/voleur/"
const DIALOGUES := "res://resources/dialogues/"

var ts: TileSet
var map_root: Node2D
var W := 0
var H := 0
var floor := {}
var walls := {}     # case -> rangée d'atlas
var wall_cols := {} # case -> colonne d'atlas
var ysort: Node2D
var decor: Node2D
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms := ["jumelles", "margot", "aelis"] if args.is_empty() else [args[0]]
	ts = _tileset()
	for r in rooms:
		call("_room_" + r)
	quit()

## La maison des jumelles : 16 × 12 cases. Myrtille derrière son comptoir, des étagères de pots et de
## bocaux, des plantes partout (c'est Mirabelle qui les fait pousser).
func _room_jumelles() -> void:
	# le mur du fond : des fenêtres à gauche, un mur plein à droite
	var pattern := {}
	for x in range(1, 15):
		pattern[x] = [WALL_WINDOWS if x <= 7 else WALL_PLAIN, (x - 1) % 7]
	_begin("MaisonJumellesMap", 16, 12, [Rect2i(1, 3, 14, 7), Rect2i(7, 10, 2, 2)], pattern, 21)
	var cx := 8.0 * T
	# étagères contre le mur du fond
	_sprite(ysort, "EtagerePots", FURN_A, SHELF_POTS, Vector2(2.0, 3.6) * T, true)
	_sprite(ysort, "EtagereBocaux", FURN_A, SHELF_JARS, Vector2(3.0, 3.6) * T, true)
	_sprite(ysort, "EtagereDivers", FURN_A, SHELF_MISC, Vector2(12.0, 3.6) * T, true)
	_sprite(ysort, "EtagereVaisselle", FURN_A, SHELF_DISHES, Vector2(13.0, 3.6) * T, true)
	_sprite(decor, "EtagereMurale", FURN, WALL_SHELF, Vector2(10.0, 2.3) * T)
	# le comptoir, Myrtille derrière
	_sprite(ysort, "Comptoir", FURN_A, COUNTER, Vector2(cx, 6.4 * T), true)
	_myrtille(Vector2(cx, 4.8 * T))
	# plantes, jardinières, tonneaux
	var spots := [Vector2(1.5, 5.0), Vector2(1.5, 8.8), Vector2(14.5, 6.0), Vector2(14.5, 9.0), Vector2(5.0, 9.4), Vector2(11.2, 9.4)]
	for i in spots.size():
		_sprite(ysort, "Plante%d" % (i + 1), FURN, PLANTS[i % PLANTS.size()], (spots[i] as Vector2) * T, true)
	_sprite(ysort, "Jardiniere", FURN, PLANTER, Vector2(4.6, 4.2) * T, true)
	_sprite(ysort, "Tonneaux", FURN, BARRELS, Vector2(14.4, 4.6) * T, true)
	_sprite(ysort, "BuffetHerbes", FURN_A, LOW_CABINETS[0], Vector2(6.0, 3.7) * T, true)
	_sprite(ysort, "BuffetFioles", FURN_A, LOW_CABINETS[1], Vector2(10.0, 3.7) * T, true)
	var rug := _sprite(map_root, "Tapis", HOUSES, RUG, Vector2(cx, 8.9 * T))
	map_root.move_child(rug, 1)
	# passages
	_spawn("SpawnFromVillage", Vector2(cx, 9.2 * T))
	_exit("ExitToVillage", Vector2(cx, H * T - 14), Vector2(64, 24), "res://scenes/maps/VillageV2Map.tscn", "SpawnFromJumelles")
	_player(Vector2(cx, 9.2 * T))
	_save("res://scenes/maps/MaisonJumellesMap.tscn")

## La ferme-fournil de Margot : 16 × 12 cases. Le four et les casiers à pain au fond, le pétrin,
## les sacs de farine ; Margot près du four.
func _room_margot() -> void:
	var pattern := {}
	for x in range(1, 15):
		pattern[x] = [WALL_WINDOWS if x >= 9 else WALL_PLAIN, (x - 1) % 7]
	_begin("MaisonMargotMap", 16, 12, [Rect2i(1, 3, 14, 7), Rect2i(7, 10, 2, 2)], pattern, 37)
	var cx := 8.0 * T
	_sprite(ysort, "Four", FURN_C, OVEN, Vector2(3.0, 3.9) * T, true)
	_sprite(ysort, "CasierPain", FURN_C, BREAD_RACKS[0], Vector2(5.2, 3.6) * T, true)
	_sprite(ysort, "CasierPain2", FURN_C, BREAD_RACKS[1], Vector2(6.3, 3.6) * T, true)
	_sprite(ysort, "Petrin", FURN_A, COUNTER, Vector2(8.2, 6.4) * T, true)
	_sprite(ysort, "Sac", DECO, SACKS[2], Vector2(12.6, 3.9) * T, true)
	_sprite(ysort, "Sac2", DECO, SACKS[0], Vector2(13.6, 4.2) * T, true)
	_sprite(ysort, "Sac3", DECO, SACKS[1], Vector2(13.2, 5.1) * T, true)
	_sprite(ysort, "Tonneaux", FURN, BARRELS, Vector2(14.4, 8.6) * T, true)
	_sprite(ysort, "Plante", FURN, PLANTS[2], Vector2(1.5, 9.0) * T, true)
	var rug := _sprite(map_root, "Tapis", HOUSES, RUG, Vector2(cx + 2.0 * T, 8.9 * T))
	map_root.move_child(rug, 1)
	# la farine renversée au pied du pétrin, avec les traces de pas (on peut l'examiner)
	var flour := Sprite2D.new()
	flour.texture = load(VOLEUR + "farine.png")
	flour.position = Vector2(9.0, 7.5) * T
	_own(flour, "Farine", decor)
	var look := Node2D.new()
	look.set_script(load("res://scenes/maps/point_inspection.gd"))
	look.set("conversation", load(DIALOGUES + "margot/farine.tres"))
	look.set("conversation_after", load(DIALOGUES + "margot/farine.tres"))
	look.set("sparkle_at", Vector2(0, -10))
	_own(look, "LireFarine", ysort)
	look.position = Vector2(9.0, 7.6) * T
	var convs: Array[DialogueConversation] = []
	for c in ["margot_fin_chien", "margot_fin_pepin", "margot_enquete", "margot_rappel", "margot_bonjour", "margot_avant"]:
		convs.append(load(DIALOGUES + "margot/%s.tres" % c))
	_pnj("Margot", "res://assets/sprites/characters/margot.png", Vector2(4.6, 5.2) * T, convs, "down")
	_watch()
	_spawn("SpawnFromVillage", Vector2(cx, 9.2 * T))
	_exit("ExitToVillage", Vector2(cx, H * T - 14), Vector2(64, 24), "res://scenes/maps/VillageV2Map.tscn", "SpawnFromMargot")
	_player(Vector2(cx, 9.2 * T))
	_save("res://scenes/maps/MaisonMargotMap.tscn")

## La chambre qu'Aelis loue : 12 × 10 cases. Un lit, une armoire ; la fenêtre du fond, à droite,
## où quelqu'un a pris le coussin brodé (et laissé des poils de chien).
func _room_aelis() -> void:
	var pattern := {}
	for x in range(2, 14):
		pattern[x] = [WALL_WINDOWS if x >= 9 else WALL_PLAIN, (x - 1) % 7]
	_begin("MaisonAelisMap", 16, 12, [Rect2i(2, 3, 12, 7), Rect2i(7, 10, 2, 2)], pattern, 43)
	var cx := 8.0 * T
	_sprite(ysort, "Lit", FURN_A, BED_BLUE, Vector2(2.7, 5.4) * T, true)
	_sprite(ysort, "Armoire", FURN_A, WARDROBE, Vector2(4.0, 3.7) * T, true)
	_sprite(ysort, "Buffet", FURN_A, LOW_CABINETS[0], Vector2(6.2, 3.7) * T, true)
	_sprite(ysort, "Plante", FURN, PLANTS[4], Vector2(13.4, 8.6) * T, true)
	var rug := _sprite(map_root, "Tapis", HOUSES, RUG, Vector2(cx, 7.4 * T))
	map_root.move_child(rug, 1)
	# les poils sur le rebord de la fenêtre du fond, à droite
	var hair := Sprite2D.new()
	hair.texture = load(VOLEUR + "poils.png")
	hair.position = Vector2(11.5, 2.86) * T
	hair.z_index = 2
	_own(hair, "Poils", decor)
	var look := Node2D.new()
	look.set_script(load("res://scenes/maps/point_inspection.gd"))
	look.set("conversation", load(DIALOGUES + "aelis/aelis_fenetre.tres"))
	look.set("conversation_after", load(DIALOGUES + "aelis/aelis_fenetre_apres.tres"))
	look.set("required_flag", "voleur_aelis_parle")
	look.set("flag_on_read", "voleur_poils_trouves")
	look.set("sparkle_at", Vector2(0, -22))
	look.set("hide_after", NodePath("../../Decor/Poils"))
	_own(look, "LireFenetre", ysort)
	look.position = Vector2(11.5, 3.5) * T
	_watch()
	_spawn("SpawnFromVillage", Vector2(cx, 9.2 * T))
	_exit("ExitToVillage", Vector2(cx, H * T - 14), Vector2(64, 24), "res://scenes/maps/VillageV2Map.tscn", "SpawnFromAelis")
	_player(Vector2(cx, 9.2 * T))
	_save("res://scenes/maps/MaisonAelisMap.tscn")

## Un PNJ à feuille LPC (scenes/maps/pnj_lpc.gd).
func _pnj(nm: String, sheet: String, pos: Vector2, convs: Array[DialogueConversation], facing: String) -> void:
	var n := Node2D.new()
	n.set_script(load("res://scenes/maps/pnj_lpc.gd"))
	n.set("sheet", load(sheet))
	n.set("facing", facing)
	n.set("conversations", convs)
	n.set("interaction_radius", 46.0)
	n.scale = Vector2(0.7, 0.7)
	_own(n, nm, ysort)
	n.position = pos

## Le contrat du voleur : Zylrak fait le point quand il a tous les indices (scenes/maps/voleur/enquete.gd).
func _watch() -> void:
	var w := Node.new()
	w.set_script(load("res://scenes/maps/voleur/enquete.gd"))
	_own(w, "EnqueteVoleur", map_root)

func _myrtille(pos: Vector2) -> void:
	var n := Node2D.new()
	n.set_script(load("res://scenes/maps/marchande.gd"))
	n.position = pos
	n.scale = Vector2(0.7, 0.7)
	var convs: Array[DialogueConversation] = [load("res://resources/dialogues/myrtille/myrtille_rencontre.tres"),
		load("res://resources/dialogues/myrtille/myrtille_bonjour.tres")]
	n.set("conversations", convs)
	n.set("interaction_radius", 110.0)   # (réduit par l'échelle 0,7) : on lui parle par-dessus le comptoir
	_own(n, "PNJMyrtille", ysort)
	# même tête que sa jumelle (planche de Mirabelle), debout derrière le comptoir
	var sf := SpriteFrames.new()
	var a := AtlasTexture.new()
	a.atlas = load("res://assets/sprites/characters/pink_arrosoir_pnj(1).png")
	a.region = Rect2(0, 640, 64, 64)
	sf.add_frame("default", a)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.position = Vector2(-3, -5)
	_own(s, "AnimatedSprite2D", n)

# =====================================================================================

func _begin(nm: String, w: int, h: int, rects: Array, pattern: Dictionary, seed_v: int) -> void:
	W = w
	H = h
	floor.clear()
	walls.clear()
	wall_cols.clear()
	rng.seed = seed_v
	for r: Rect2i in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				floor[Vector2i(x, y)] = true
	var main_top := (rects[0] as Rect2i).position.y
	map_root = Node2D.new()
	map_root.name = nm
	map_root.set_script(load("res://scenes/maps/map_camera_zoom.gd"))
	map_root.set("camera_zoom", Vector2(3.5, 3.5))
	map_root.set("camera_follows_player", false)
	map_root.set("fill_screen", true)
	map_root.set("music", load("res://assets/audio/musique/village.wav"))
	var ground := _layer("Ground", 0)
	var wall_layer := _layer("Murs", 0)
	var tops := _layer("DessusDesMurs", 1)
	decor = _own(Node2D.new(), "Decor", map_root)
	ysort = _own(Node2D.new(), "YSortLayer", map_root)
	ysort.y_sort_enabled = true
	# murs : 2 cases au nord de chaque sol
	for c: Vector2i in floor:
		if floor.has(c + Vector2i.UP):
			continue
		var spec: Array = pattern.get(c.x, [WALL_PLAIN, posmod(c.x, 7)]) if c.y == main_top else [WALL_PLAIN, posmod(c.x, 7)]
		var rows: Array = spec[0]
		for r in 2:
			var p := c + Vector2i(0, -2 + r)
			if not floor.has(p):
				walls[p] = rows[r]
				wall_cols[p] = spec[1]
	# le parquet couvre toute la carte (sous les murs aussi) : la caméra des intérieurs se cale dessus
	for y in H:
		for x in W:
			ground.set_cell(Vector2i(x, y), 0, FLOOR[rng.randi() % FLOOR.size()])
	for p: Vector2i in walls:
		wall_layer.set_cell(p, 0, Vector2i(wall_cols[p], walls[p]))
	_paint_tops(tops)
	_bounds()

func _open(p: Vector2i) -> bool:
	return floor.has(p) or walls.has(p)

func _paint_tops(l: TileMapLayer) -> void:
	for y in H:
		for x in W:
			var p := Vector2i(x, y)
			if floor.has(p) or walls.has(p):
				continue
			var up := floor.has(p + Vector2i.UP)
			var down := walls.has(p + Vector2i.DOWN)
			var left := _open(p + Vector2i.LEFT)
			var right := _open(p + Vector2i.RIGHT)
			if up and right:
				l.set_cell(p, 0, CORNER_TR)
			elif up and left:
				l.set_cell(p, 0, CORNER_TL)
			elif up:
				l.set_cell(p, 0, RIM_TOP)
			elif down and right:
				l.set_cell(p, 0, CORNER_BR)
			elif down and left:
				l.set_cell(p, 0, CORNER_BL)
			elif down:
				l.set_cell(p, 0, RIM_BOTTOM)
			elif right:
				l.set_cell(p, 0, RIM_RIGHT)
			elif left:
				l.set_cell(p, 0, RIM_LEFT)
			elif _open(p + Vector2i(1, 1)):
				l.set_cell(p, 1, Vector2i(INNER_BR, 0))
			elif _open(p + Vector2i(-1, 1)):
				l.set_cell(p, 1, Vector2i(INNER_BL, 0))
			elif _open(p + Vector2i(1, -1)):
				l.set_cell(p, 1, Vector2i(INNER_TR, 0))
			elif _open(p + Vector2i(-1, -1)):
				l.set_cell(p, 1, Vector2i(INNER_TL, 0))
			else:
				l.set_cell(p, 0, FILL)

func _bounds() -> void:
	var b := _own(StaticBody2D.new(), "Bords", map_root)
	var n := 0
	for y in range(-1, H + 1):
		var x := -1
		while x <= W:
			if floor.has(Vector2i(x, y)):
				x += 1
				continue
			var x0 := x
			while x <= W and not floor.has(Vector2i(x, y)):
				x += 1
			_shape(b, "B%d" % n, Vector2((x0 + x) / 2.0 * T, (y + 0.5) * T), Vector2((x - x0) * T, T))
			n += 1

func _save(out: String) -> void:
	var packed := PackedScene.new()
	print(map_root.name, " : pack ", packed.pack(map_root), ", save ", ResourceSaver.save(packed, out))
	map_root.free()

func _tileset() -> TileSet:
	var t := TileSet.new()
	t.tile_size = Vector2i(T, T)
	var a := TileSetAtlasSource.new()
	a.texture = load(HOUSES)
	a.texture_region_size = Vector2i(T, T)
	var used := [FILL, RIM_TOP, RIM_BOTTOM, RIM_LEFT, RIM_RIGHT, CORNER_TL, CORNER_TR, CORNER_BL, CORNER_BR] + FLOOR
	for rows in [WALL_PLAIN, WALL_WINDOWS]:
		for r in rows:
			for col in 7:
				used.append(Vector2i(col, r))
	for c in used:
		if not a.has_tile(c):
			a.create_tile(c)
	t.add_source(a, 0)
	var b := TileSetAtlasSource.new()
	b.texture = load(CORNERS)
	b.texture_region_size = Vector2i(T, T)
	for i in 4:
		b.create_tile(Vector2i(i, 0))
	t.add_source(b, 1)
	ResourceSaver.save(t, TILESET_OUT)
	return load(TILESET_OUT)

func _own(n: Node, nm: String, parent: Node) -> Node:
	n.name = nm
	parent.add_child(n)
	n.owner = map_root
	return n

func _layer(nm: String, z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = ts
	l.z_index = z
	return _own(l, nm, map_root)

func _shape(parent: Node, nm: String, pos: Vector2, size: Vector2) -> void:
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	c.shape = r
	c.position = pos
	_own(c, nm, parent)

## Sprite posé par son pied ; `solid` : on ne le traverse pas (une bande au pied).
func _sprite(parent: Node, nm: String, path: String, region: Rect2, foot: Vector2, solid := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.offset = Vector2(-region.size.x / 2.0, -region.size.y + 2)
	s.position = foot
	_own(s, nm, parent)
	if solid:
		var b := _own(StaticBody2D.new(), "Corps", s)
		_shape(b, "Forme", Vector2(0, -8), Vector2(region.size.x - 4, 16))
	return s

func _spawn(nm: String, pos: Vector2) -> void:
	var m := _own(Marker2D.new(), nm, map_root) as Marker2D
	m.position = pos

func _exit(nm: String, pos: Vector2, size: Vector2, target: String, spawn: String) -> void:
	var a := Area2D.new()
	a.set_script(load("res://scenes/maps/map_exit.gd"))
	a.set("target_scene", target)
	a.set("spawn_point", spawn)
	_own(a, nm, map_root)
	a.position = pos
	_shape(a, "Forme", Vector2.ZERO, size)

func _player(pos: Vector2) -> void:
	var p: Node2D = load("res://scenes/characters/Player.tscn").instantiate()
	p.position = pos
	_own(p, "Player", ysort)
	p.add_to_group("Player", true)
