extends SceneTree
# Lancer : Godot --headless --path . -s tools/make_village_v2.gd   (voir aussi tools/dev/regen_village_v2.sh, qui remet les uids)
# Village du jeu (recentré) : scenes/maps/VillageV2Map.tscn, construit à partir du village dessiné
# à la main, scenes/maps/VillageMap.tscn (qui n'est pas modifié et sert de référence).
# L'auberge et la forge échangent leur place : l'auberge s'installe en haut de la place du puits,
# face à la route qui arrive de la forêt ; la forge prend l'ancienne place de l'auberge, sur la rue
# de l'ouest. Tout le reste (végétation, chemins, autres maisons, PNJ) ne bouge pas.
# On déplace les tuiles des calques de bâtiments, les zones d'entrée et les points d'arrivée,
# puis on ajoute les enseignes (chope, enclume) et un coffre.

const SRC := "res://scenes/maps/VillageMap.tscn"
const OUT := "res://scenes/maps/VillageV2Map.tscn"
const ORIGIN_CELL := Vector2i(-30, -17)   # case (0, 0) de la carte dans les calques
const ORIGIN := Vector2(-960, -544)
const T := 32.0
const BUILDING_LAYERS := ["YSortLayer/Building", "YSortLayer/Building/Superposition1",
	"YSortLayer/Building/Superposition1/Superposition2", "YSortLayer/UnderBuildings",
	"YSortLayer/UnderBuildings/TileMapLayer"]
const DECOR_LAYERS := ["YSortLayer/SuperpositionRocks", "YSortLayer/SuperpositionRocks/SuperpositionFeuillage"]

# Groupes à déplacer : [rectangles (x0, y0, x1, y1 inclus, en cases de la carte), calques (vide : tous), décalage]
const INN_OFFSET := Vector2i(19, -4)
const FORGE_OFFSET := Vector2i(-19, 4)
# Une tuile prise par un groupe n'est plus prise par les suivants (la corde à linge passe en premier).
var GROUPS := [
	# la corde à linge (deux colonnes de tuiles) : pas collée au mur, entre l'auberge et la maison au toit rouge
	[[Rect2i(11, 13, 2, 3)], ["YSortLayer/Building/Superposition1/Superposition2"], INN_OFFSET + Vector2i(1, -1)],
	# l'auberge, ses tonneaux sur le toit, le baquet devant
	[[Rect2i(4, 11, 8, 5), Rect2i(4, 10, 6, 1), Rect2i(4, 16, 2, 1)], [], INN_OFFSET],
	# dernier tonneau du toit (la case appartient aussi à l'abri voisin : seuls les calques de décor bougent)
	[[Rect2i(10, 10, 1, 1)], ["YSortLayer/UnderBuildings", "YSortLayer/UnderBuildings/TileMapLayer"], INN_OFFSET],
	# la forge et les caisses devant sa porte
	[[Rect2i(23, 7, 9, 6)], [], FORGE_OFFSET],
]

func _initialize() -> void:
	var packed: PackedScene = load(SRC)
	var root: Node2D = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	root.name = "VillageV2Map"
	# le village d'origine a ses propres enseignes et son coffre (placés pour sa disposition) :
	# on les retire, ce générateur repose les siens aux bons endroits
	for n in ["YSortLayer/EnseigneAuberge", "YSortLayer/EnseigneForge", "YSortLayer/CoffreVillage"]:
		var old := root.get_node_or_null(n)
		if old:
			old.get_parent().remove_child(old)
			old.free()
	_move_buildings(root)
	_steps_to_ground(root)
	_complete_pines(root)
	_shift(root, "EnterAuberge", INN_OFFSET, true)
	_shift(root, "SpawnFromAuberge", INN_OFFSET, false)
	_shift(root, "EnterWeaponsShop", FORGE_OFFSET, true)
	_shift(root, "SpawnFromWeaponShop", FORGE_OFFSET, false)
	# enseignes, accrochées au mur, à droite de chaque porte
	var auberge_door := Vector2(8, 15) + Vector2(INN_OFFSET)
	var forge_door := Vector2(27, 11) + Vector2(FORGE_OFFSET)
	add_sign(root, "EnseigneAuberge", 0, auberge_door + Vector2(1.6, 1.0))
	add_sign(root, "EnseigneForge", 1, forge_door + Vector2(1.6, 1.0))
	add_chest(root, "CoffreVillage", "fiole", 2, Vector2(14.6, 10.7))
	add_arrival(root)
	add_board(root)
	add_signpost(root)
	add_door(root, "EnterJumelles", Vector2(13.0, 27.95), "res://scenes/maps/MaisonJumellesMap.tscn", "SpawnFromVillage",
		"SpawnFromJumelles", Vector2(13.0, 30.2))
	var out := PackedScene.new()
	print("pack ", out.pack(root))
	print("save ", ResourceSaver.save(out, OUT))
	ResourceSaver.set_uid(OUT, ResourceUID.text_to_id("uid://bifvlrqj3ww4f"))   # garde le même uid d'une génération à l'autre
	quit()

static func cell_to_world(c: Vector2) -> Vector2:
	return ORIGIN + c * T

func _move_buildings(root: Node) -> void:
	# 1) on relève les tuiles de chaque groupe ; 2) on les efface ; 3) on les repose décalées
	var moves := []   # [calque, case, source, atlas, alternative, décalage]
	var taken := {}
	for g in GROUPS:
		var layers: Array = g[1] if not (g[1] as Array).is_empty() else BUILDING_LAYERS
		for lp in layers:
			var l: TileMapLayer = root.get_node(lp)
			for r in g[0]:
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						var c := Vector2i(x, y) + ORIGIN_CELL
						var sid := l.get_cell_source_id(c)
						var key := [lp, c]
						if sid != -1 and not taken.has(key):
							taken[key] = true
							moves.append([l, c, sid, l.get_cell_atlas_coords(c), l.get_cell_alternative_tile(c), g[2]])
	for m in moves:
		(m[0] as TileMapLayer).erase_cell(m[1])
	var landed := {}
	for m in moves:
		var dest: Vector2i = m[1] + m[5]
		(m[0] as TileMapLayer).set_cell(dest, m[2], m[3], m[4])
		landed[dest] = true
	# les petits cailloux et touffes posés sous un bâtiment arrivé là disparaissent (pas les arbres)
	var cleared := 0
	for lp in DECOR_LAYERS:
		var l: TileMapLayer = root.get_node(lp)
		for c in landed:
			if l.get_cell_source_id(c) != -1:
				l.erase_cell(c)
				cleared += 1
	print("tuiles déplacées : ", moves.size(), ", cailloux retirés : ", cleared)

## Les marches devant certaines portes débordent d'une case sous le mur ; dans le calque des
## bâtiments (toujours dessiné au-dessus des personnages), elles passaient sur la tête de Zylrak.
## On les met dans un calque « Marches » au niveau du sol, sous les personnages.
func _steps_to_ground(root: Node) -> void:
	var sup: TileMapLayer = root.get_node("YSortLayer/Building/Superposition1")
	var building: TileMapLayer = root.get_node("YSortLayer/Building")
	var steps := TileMapLayer.new()
	steps.name = "Marches"
	steps.tile_set = sup.tile_set
	steps.z_index = -1   # ces tuiles ont un z de 1 dans le tileset : on revient au niveau du sol
	root.add_child(steps)
	root.move_child(steps, root.get_node("YSortLayer").get_index())
	steps.owner = root
	var moved := 0
	for c in sup.get_used_cells():
		var ac := sup.get_cell_atlas_coords(c)
		# rangée 20 de houses_outside : marches sous une porte ouverte, sans mur derrière
		if ac.y == 20 and ac.x <= 3 and building.get_cell_source_id(c) == -1:
			steps.set_cell(c, sup.get_cell_source_id(c), ac, sup.get_cell_alternative_tile(c))
			sup.erase_cell(c)
			moved += 1
	print("marches mises au sol : ", moved)

## Sapins (tuiles 18-20 × 7-11 du tileset de végétation, pied en (19, 11)) : leur pointe est dans
## la tuile (19, 6), jamais posée dans la carte d'origine, d'où des cimes coupées à plat ; et deux
## sapins voisins se partageaient une colonne de cases, l'un écrasant l'autre. On repose chaque
## sapin en entier, pointe comprise, dans le calque Trees ou, s'il chevauche un sapin déjà posé,
## dans un calque suivant (le sapin le plus bas passe devant).
const PINE_FOOT := Vector2i(19, 11)

func _complete_pines(root: Node) -> void:
	var trees: TileMapLayer = root.get_node("YSortLayer/Trees")
	var stamp := {Vector2i(0, -5): Vector2i(19, 6)}   # décalage depuis le pied -> tuile
	for dy in range(-4, 1):
		for dx in range(-1, 2):
			stamp[Vector2i(dx, dy)] = PINE_FOOT + Vector2i(dx, dy)
	var feet: Array[Vector2i] = []
	for c in trees.get_used_cells():
		if trees.get_cell_atlas_coords(c) == PINE_FOOT:
			feet.append(c)
	if feet.is_empty():
		return
	feet.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var sid := trees.get_cell_source_id(feet[0])
	# on retire les sapins (et eux seuls) avant de les reposer
	for f in feet:
		for o in stamp:
			var ac := trees.get_cell_atlas_coords(f + o)
			if trees.get_cell_source_id(f + o) == sid and ac.x >= 18 and ac.x <= 20 and ac.y >= 6 and ac.y <= 11:
				trees.erase_cell(f + o)
	var layers: Array[TileMapLayer] = [trees]
	var placed := []   # [pied, indice du calque]
	for f in feet:
		var min_layer := 0
		for p in placed:
			if absi(p[0].x - f.x) <= 2 and absi(p[0].y - f.y) <= 5:
				min_layer = maxi(min_layer, p[1] + 1)
		var li := min_layer
		while true:
			if li == layers.size():
				var extra := TileMapLayer.new()
				extra.name = "Sapins%d" % (li + 1)
				extra.tile_set = trees.tile_set
				extra.z_index = trees.z_index
				extra.y_sort_enabled = true
				trees.get_parent().add_child(extra)
				trees.get_parent().move_child(extra, layers[-1].get_index() + 1)
				extra.owner = root
				layers.append(extra)
			var free := true
			for o in stamp:
				if layers[li].get_cell_source_id(f + o) != -1:
					free = false
			if free:
				break
			li += 1
		for o in stamp:
			layers[li].set_cell(f + o, sid, stamp[o])
		placed.append([f, li])
	print("sapins reposés : ", feet.size(), " sur ", layers.size(), " calque(s)")

func _shift(root: Node, n: String, offset: Vector2i, area: bool) -> void:
	var node: Node2D = root.get_node(n)
	if area:
		# zones d'entrée : la forme porte la position (la zone elle-même est à l'origine)
		for c in node.get_children():
			if c is CollisionShape2D:
				c.position += Vector2(offset) * T
	else:
		node.position += Vector2(offset) * T

## Arrivée de Zylrak en début de partie (scenes/maps/arrivee_village.gd) : depuis la route de la
## forêt, il passe à droite du puits, s'arrête devant l'auberge, puis va à la porte.
const ARRIVAL_ROUTE := [["Route1", Vector2(30.5, 23.0)], ["Route2", Vector2(32.6, 21.2)],
	["Route3", Vector2(32.6, 17.0)], ["HalteAuberge", Vector2(28.4, 14.6)], ["Porte", Vector2(27.05, 12.6)]]

static func add_arrival(root: Node) -> void:
	var a := Node2D.new()
	a.name = "ArriveeVillage"
	a.set_script(load("res://scenes/maps/arrivee_village.gd"))
	root.add_child(a)
	a.owner = root
	for step in ARRIVAL_ROUTE:
		var m := Marker2D.new()
		m.name = step[0]
		m.position = cell_to_world(step[1])
		a.add_child(m)
		m.owner = root

## Le panneau des contrats (scenes/maps/panneau_contrats.gd), au pied du panneau d'affichage déjà
## dessiné dans le décor, à droite de l'auberge.
static func add_board(root: Node) -> void:
	var b := Node2D.new()
	b.name = "PanneauContrats"
	b.set_script(load("res://scenes/maps/panneau_contrats.gd"))
	b.position = cell_to_world(Vector2(33.0, 13.75))
	root.get_node("YSortLayer").add_child(b)
	b.owner = root

## Le poteau indicateur à l'entrée du village (déjà dessiné dans le décor, à gauche du chemin qui
## vient de la forêt) : on peut le lire.
static func add_signpost(root: Node) -> void:
	var read := Node2D.new()
	read.name = "LirePoteau"
	read.set_script(load("res://scenes/maps/point_inspection.gd"))
	var text := load("res://resources/dialogues/panneaux/panneau_eclatvin.tres")
	read.set("conversation", text)
	read.set("conversation_after", text)
	read.set("sparkle_at", Vector2(0, -44))
	read.position = Vector2(-64, 474)
	root.get_node("YSortLayer").add_child(read)
	read.owner = root

## Porte d'une maison : une zone de sortie vers l'intérieur, et le point d'arrivée en ressortant.
static func add_door(root: Node, n: String, door: Vector2, target: String, target_spawn: String, spawn_name: String, spawn: Vector2) -> void:
	var a := Area2D.new()
	a.name = n
	a.set_script(load("res://scenes/maps/map_exit.gd"))
	a.set("target_scene", target)
	a.set("spawn_point", target_spawn)
	a.position = cell_to_world(door)
	root.add_child(a)
	a.owner = root
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 16)
	c.shape = r
	a.add_child(c)
	c.owner = root
	var m := Marker2D.new()
	m.name = spawn_name
	m.position = cell_to_world(spawn)
	root.add_child(m)
	m.owner = root

## Enseigne (0 : auberge, 1 : forge) au pied du mur `cell` (case de la carte).
static func add_sign(root: Node, n: String, frame: int, cell: Vector2) -> void:
	var s := Sprite2D.new()
	s.name = n
	s.texture = load("res://assets/sprites/objets/enseignes.png")
	s.region_enabled = true
	s.region_rect = Rect2(frame * 40, 0, 40, 44)
	s.offset = Vector2(18, -50)   # la potence part du mur et monte au-dessus de la porte
	s.position = cell_to_world(cell)
	s.z_index = 1                 # même niveau que le calque des bâtiments (sinon elle passe derrière)
	root.get_node("YSortLayer").add_child(s)
	s.owner = root

static func add_chest(root: Node, n: String, contenu: String, quantite: int, cell: Vector2) -> void:
	var c := Node2D.new()
	c.name = n
	c.set_script(load("res://scenes/maps/coffre.gd"))
	c.contenu = contenu
	c.quantite = quantite
	c.position = cell_to_world(cell)
	root.get_node("YSortLayer").add_child(c)
	c.owner = root
