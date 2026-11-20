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

func _shift(root: Node, n: String, offset: Vector2i, area: bool) -> void:
	var node: Node2D = root.get_node(n)
	if area:
		# zones d'entrée : la forme porte la position (la zone elle-même est à l'origine)
		for c in node.get_children():
			if c is CollisionShape2D:
				c.position += Vector2(offset) * T
	else:
		node.position += Vector2(offset) * T

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
