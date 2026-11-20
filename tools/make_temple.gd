extends SceneTree
# Lancer : Godot --headless --path . -s tools/make_temple.gd [-- vestibule | galerie | gardien]  (sans argument : les trois)
# Le temple des Yrenn, derrière la porte scellée du parvis : trois salles, de plus en plus profondes.
# - TempleVestibuleMap : les quatre fresques murales qui racontent la Bête, et le cercle de cendres
#   où la flamme de l'Ordre est tracée à l'envers avec le sang du marchand.
# - TempleGalerieMap : une longue galerie hantée (combats), deux alcôves avec un coffre.
# - TempleGardienMap : la salle du combat final. Le grand cercle rituel, les sceaux au sol devant
#   l'escalier fermé par un voile turquoise, et le gardien, une armure des Yrenn.
# Chaque salle part d'un plan de sol (rectangles de cases) : les murs (4 cases de haut, au nord de
# chaque sol), les dessus de murs et leurs coins sont posés automatiquement, ce qui permet les alcôves.
# Tuiles et décor : castle_interriors / castle_decoratives et leurs animations (Szadi art, pack CASTLE),
# cristaux (pack Caves), jarres (Ruines) ; fresques, sceaux, cercle rituel et pierres gravées faits
# pour le projet (assets/sprites/objets/temple) ; coins rentrants et fissures : tools/dev/draw_temple.gd.

const T := 32
const INTERIORS := "res://assets/sprites/tilesets/Temple/castle_interriors.png"
const CORNERS := "res://assets/sprites/tilesets/Temple/antichambre_coins.png"
const DECO := "res://assets/sprites/tilesets/Temple/castle_decoratives.png"
const TORCH := "res://assets/sprites/tilesets/Temple/Anim/torch.png"
const BOWL := "res://assets/sprites/tilesets/Temple/Anim/light1a.png"
const STAND := "res://assets/sprites/tilesets/Temple/Anim/light2a.png"
const CAVES := "res://assets/sprites/tilesets/Caves/decorative.png"
const PROPS_A := "res://assets/sprites/tilesets/Ruines/propsA.png"
const OBJ := "res://assets/sprites/objets/temple/"
const TRACES := "res://assets/sprites/tilesets/traces/"
const DIALOGUES := "res://resources/dialogues/temple/"
const TILESET_OUT := "res://resources/tilesets/temple.tres"
const MUSIC := "res://assets/audio/musique/ruines.wav"
const BATTLE_BG_INSIDE := "res://assets/battle_backgrounds/battle_temple_interieur.png"

# --- tuiles (source 0 : castle_interriors ; source 1 : coins rentrants) ---
const FILL := Vector2i(2, 2)
const RIM_TOP := Vector2i(2, 0)       # rebord en haut de la case
const RIM_LEFT := Vector2i(0, 2)
const RIM_RIGHT := Vector2i(4, 2)
const CORNER_TL := Vector2i(0, 0)     # coins saillants
const CORNER_TR := Vector2i(4, 0)
const INNER_BR := 0                   # coins rentrants (source 1)
const INNER_BL := 1
const INNER_TR := 2
const INNER_TL := 3
const WALL_PLAIN := 17                # colonne d'atlas : rangée 0 = haut du mur, 1-4 = mur de briques
const WALL_PILASTER := 22             # idem avec un pilastre à pierres bleues ; rangée 5 = son pied
const FLOOR := [Vector2i(14, 37), Vector2i(15, 37)]
const AISLE_PANEL := Vector2i(14, 38) # dalle ornée 2 × 2
const AISLE_MAZE := Vector2i(14, 35)  # dalles à méandres 2 × 2

# --- sprites ---
const ARCH := Rect2(368, 992, 64, 96)          # arche de pierre et l'escalier qui descend
const DOORWAY := Rect2(368, 992, 64, 64)       # la même, sans les marches : un passage
const PILLAR_A := Rect2(948, 282, 24, 144)
const PILLAR_B := Rect2(996, 282, 26, 144)
const MEDALLION := Rect2(864, 320, 64, 64)
const RUBBLE := [Rect2(2, 112, 28, 40), Rect2(34, 106, 26, 48), Rect2(64, 102, 30, 58), Rect2(98, 98, 28, 48),
	Rect2(128, 104, 64, 56), Rect2(290, 96, 28, 46), Rect2(356, 104, 26, 48), Rect2(386, 108, 28, 42)]
const CHAIN_SHORT := Rect2(266, 288, 12, 32)
const CHAIN_LONG := [Rect2(266, 352, 12, 50), Rect2(314, 352, 12, 50)]
const CRYSTALS := [Rect2(64, 610, 32, 28), Rect2(32, 676, 32, 28), Rect2(68, 580, 26, 22), Rect2(40, 608, 18, 22),
	Rect2(32, 648, 26, 22), Rect2(68, 674, 18, 24)]
const JARS := [Rect2(2, 42, 26, 22), Rect2(38, 42, 18, 22), Rect2(74, 44, 12, 20), Rect2(106, 44, 14, 20)]
const SHARDS := [Rect2(6, 80, 18, 16), Rect2(38, 82, 16, 14), Rect2(106, 78, 14, 18)]
const SYMBOLS := ["lune", "loup", "epee", "flamme"]

const WARM := Color(1.0, 0.68, 0.38)
const BLUE := Color(0.45, 0.7, 1.0)
const TURQUOISE := Color(0.35, 0.95, 0.85)

var ts: TileSet
var map_root: Node2D
var W := 0
var H := 0
var floor := {}       # case -> true
var walls := {}       # case -> [rangée d'atlas (0 = haut du mur), y du sol au pied de ce mur]
var main_top := 0     # première rangée de sol de la salle principale (pied du mur du fond)
var pilasters: Array = []
var aisle := -1       # première des deux colonnes de l'allée centrale (-1 : pas d'allée)
var rng := RandomNumberGenerator.new()
var ground: TileMapLayer
var sol: Node2D       # décor posé au sol (sous les personnages)
var decor: Node2D     # décor accroché aux murs
var ysort: Node2D
var lights: Node2D
var light_tex: GradientTexture2D
var scenario: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms := ["vestibule", "galerie", "gardien"] if args.is_empty() else [args[0]]
	ts = _tileset()
	for r in rooms:
		call("_room_" + r)
	quit()

# =====================================================================================
# Les salles
# =====================================================================================

## Le vestibule : 20 × 18 cases. On entre par le bas (depuis le parvis), on sort par l'arche du fond.
func _room_vestibule() -> void:
	_begin("TempleVestibuleMap", 20, 18, [Rect2i(2, 6, 16, 10), Rect2i(9, 16, 2, 2)], [2, 5, 8, 11, 14, 17], 9, 11,
		Color(0.5, 0.52, 0.66))
	var cx := 10.0 * T
	_sprite(decor, "Arche", INTERIORS, DOORWAY, Vector2(cx, main_top * T))
	_opening(Vector2(cx, main_top * T))
	# les quatre fresques murales, deux de chaque côté de l'arche
	var i := 0
	for x in [128.0, 224.0, 416.0, 512.0]:
		var f := Node2D.new()
		f.set_script(load("res://scenes/maps/fresque_yrenn.gd"))
		f.set("style", "murale")
		f.set("symbol", SYMBOLS[i])
		f.set("conversation", load(DIALOGUES + "fresque_%s.tres" % SYMBOLS[i]))
		f.set("read_spot", Vector2(0, 80))
		f.position = Vector2(x, 128)
		_own(f, "Fresque" + (SYMBOLS[i] as String).capitalize(), decor)
		_light("Fresque%d" % i, Vector2(x, 140), TURQUOISE, 0.55, 0.55)
		i += 1
	# torches sur les pilastres entre les fresques
	for x in [5, 8, 11, 14]:
		_wall_torch(Vector2(x * T + 16, main_top * T - 34))
	_sprite(sol, "CercleCendres", OBJ + "cercle_cendres.png", Rect2(0, 0, 104, 60), Vector2(cx, 352 + 30))
	_trail([[540.0, 400.0], [322.0, 200.0]], cx)
	for p in [Vector2(5.5, 13.6), Vector2(14.5, 13.6)]:
		_pillar(p * T, PILLAR_A if p.x < 10 else PILLAR_B)
		_bowl(p * T + Vector2(0, 26))
	_crystals([Vector2(2.6, 7.2), Vector2(17.4, 7.4), Vector2(3.0, 15.4), Vector2(17.0, 15.2)])
	_jars([Vector2(2.8, 9.6), Vector2(17.2, 10.2)], [Vector2(3.4, 12.2), Vector2(16.4, 8.4)])
	_bones([[Vector2(4.2, 11.0), 2], [Vector2(15.6, 12.2), 0], [Vector2(16.8, 14.6), 5]])
	_cracks(14)
	# passages
	_spawn("SpawnFromParvis", Vector2(cx, 15.3 * T))
	_exit("ExitToParvis", Vector2(cx, H * T - 14), Vector2(64, 24), "res://scenes/maps/RuinesParvisMap.tscn", "SpawnFromTemple")
	_spawn("SpawnFromGalerie", Vector2(cx, main_top * T + 60))
	_exit("ExitToGalerie", Vector2(cx, main_top * T + 6), Vector2(30, 12), "res://scenes/maps/TempleGalerieMap.tscn", "SpawnFromVestibule")
	_scenario()
	scenario.set("arrival", load(DIALOGUES + "arrivee.tres"))
	scenario.set("arrival_flag", "temple_vestibule_vu")
	scenario.set("circle", load(DIALOGUES + "cercle.tres"))
	scenario.set("circle_stranger", load(DIALOGUES + "cercle_inconnu.tres"))
	_area("ZoneCercle", Vector2(cx, 352), Vector2(84, 44))
	scenario.set("circle_zone_path", NodePath("../ZoneCercle"))
	_player(Vector2(cx, 15.3 * T))
	_save("res://scenes/maps/TempleVestibuleMap.tscn")

## La galerie : 20 × 30 cases, un long couloir hanté, une alcôve de chaque côté avec un coffre.
func _room_galerie() -> void:
	_begin("TempleGalerieMap", 20, 30, [Rect2i(5, 6, 10, 22), Rect2i(3, 12, 2, 3), Rect2i(15, 19, 2, 3), Rect2i(9, 28, 2, 2)],
		[5, 7, 12, 14], 9, 9, Color(0.42, 0.44, 0.58))
	var cx := 10.0 * T
	_sprite(decor, "Arche", INTERIORS, DOORWAY, Vector2(cx, main_top * T))
	_opening(Vector2(cx, main_top * T))
	for x in [7, 12]:
		_wall_torch(Vector2(x * T + 16, main_top * T - 34))
	_stand(Vector2(cx - 64, main_top * T + 30))
	_stand(Vector2(cx + 64, main_top * T + 30))
	for y in [9.6, 17.4, 25.0]:
		_pillar(Vector2(6.5, y) * T, PILLAR_A)
		_pillar(Vector2(13.5, y) * T, PILLAR_B)
	for p in [Vector2(5.7, 15.6), Vector2(14.3, 18.2)]:
		_bowl(p * T)
	# alcôves : l'amulette à gauche, des potions à droite
	_chest("CoffreGalerieOuest", "amulette_yrenn", 1, Vector2(3.9, 13.6) * T)
	_chest("CoffreGalerieEst", "potion", 2, Vector2(16.1, 20.6) * T)
	_light("AlcoveOuest", Vector2(4, 12.6) * T, TURQUOISE, 0.6, 0.45)
	_light("AlcoveEst", Vector2(16, 19.6) * T, TURQUOISE, 0.6, 0.45)
	_crystals([Vector2(3.4, 12.4), Vector2(16.6, 19.4), Vector2(5.5, 7.0), Vector2(14.4, 26.8), Vector2(5.6, 22.6)])
	_jars([Vector2(14.3, 8.4), Vector2(5.6, 16.2), Vector2(14.4, 14.6)], [Vector2(5.8, 26.4), Vector2(13.9, 23.6), Vector2(6.0, 19.8)])
	_chains([Vector2(3.5 * T, 8 * T + 6), Vector2(16.5 * T, 15 * T + 6), Vector2(5.5 * T, 70)])
	_bones([[Vector2(6.0, 11.6), 0], [Vector2(13.6, 12.4), 1], [Vector2(7.2, 20.6), 4], [Vector2(12.8, 26.2), 2],
		[Vector2(4.4, 14.4), 3], [Vector2(15.6, 21.4), 5]])
	_wall_overlays([[3, 12, 0], [4, 12, 1], [15, 19, 2], [16, 19, 0]])
	_wall_overlays([[6, main_top, 1], [13, main_top, 2]])
	_cracks(26)
	_trail([[880.0, 200.0]], cx)
	# combats
	var enc := Area2D.new()
	enc.set_script(load("res://scenes/maps/encounter_zone.gd"))
	var monsters: Array[MonsterData] = [load("res://resources/monsters/goule.tres"), load("res://resources/monsters/zombie.tres"),
		load("res://resources/monsters/squelette.tres")]
	enc.set("monsters", monsters)
	enc.set("battle_background", load(BATTLE_BG_INSIDE))
	enc.set("encounter_rate", 0.04)
	_own(enc, "EncounterZone", map_root)
	_shape(enc, "Forme", Vector2(cx, 17 * T), Vector2(10 * T, 18 * T))
	_spawn("SpawnFromVestibule", Vector2(cx, 26.6 * T))
	_exit("ExitToVestibule", Vector2(cx, H * T - 14), Vector2(64, 24), "res://scenes/maps/TempleVestibuleMap.tscn", "SpawnFromGalerie")
	_spawn("SpawnFromGardien", Vector2(cx, main_top * T + 60))
	_exit("ExitToGardien", Vector2(cx, main_top * T + 6), Vector2(30, 12), "res://scenes/maps/TempleGardienMap.tscn", "SpawnFromGalerie")
	_player(Vector2(cx, 26.6 * T))
	_save("res://scenes/maps/TempleGalerieMap.tscn")

## La salle du gardien : 34 × 22 cases, le combat final de l'étage. Au fond, l'autel où reposait le
## fragment d'âme, gardé par l'armure corrompue ; le corps du marchand gît à côté.
func _room_gardien() -> void:
	_begin("TempleGardienMap", 34, 22, [Rect2i(3, 6, 28, 14), Rect2i(1, 11, 2, 3), Rect2i(31, 11, 2, 3), Rect2i(16, 20, 2, 2)],
		[4, 9, 14, 19, 24, 29], 16, 16, Color(0.45, 0.47, 0.6))
	var cx := 17.0 * T
	var wall_foot := main_top * T
	# une niche en arc derrière l'autel
	_sprite(decor, "Niche", INTERIORS, DOORWAY, Vector2(cx, wall_foot))
	# médaillons (non lus) entre les pilastres, une torche de chaque côté
	var i := 0
	for x in [224.0, 384.0, 704.0, 864.0]:
		var m := Node2D.new()
		m.set_script(load("res://scenes/maps/fresque_yrenn.gd"))
		m.set("style", "medaillon")
		m.set("symbol", SYMBOLS[i])
		m.position = Vector2(x, 118)
		_own(m, "Medaillon" + (SYMBOLS[i] as String).capitalize(), decor)
		_light("Medaillon%d" % i, Vector2(x, 148), BLUE, 0.6, 0.5)
		_wall_torch(Vector2(x - 48, wall_foot - 34))
		_wall_torch(Vector2(x + 48, wall_foot - 34))
		i += 1
	_wall_overlays([[5, main_top, 0], [13, main_top, 1], [20, main_top, 2], [28, main_top, 0], [1, 11, 1], [32, 11, 2]])
	_chains([Vector2(cx - 112, 76), Vector2(cx + 112, 76)])
	# l'autel, le parchemin dessus ; un brasero de chaque côté
	var altar := _sprite(ysort, "Autel", DECO, RUBBLE[4], Vector2(cx, wall_foot + 40), 4.0)
	_box(altar, "Corps", Vector2(0, -8), Vector2(58, 16))
	var scroll := _sprite(altar, "Parchemin", OBJ + "parchemin.png", Rect2(0, 0, 20, 12), Vector2(0, -40))
	_light("Autel", Vector2(cx, wall_foot + 4), Color(0.55, 0.75, 1.0), 0.6, 0.4)
	var read := _inspect("LireParchemin", Vector2(cx, wall_foot + 52), "parchemin.tres", "", "parchemin_yrenn", Vector2(0, -52))
	read.set("reach", 46.0)
	read.set("hide_after", read.get_path_to(scroll))
	_stand(Vector2(cx - 76, wall_foot + 34))
	_stand(Vector2(cx + 76, wall_foot + 34))
	# le corps du marchand, là où le sang s'arrête
	var body_at := Vector2(cx - 84, wall_foot + 112)
	var puddle := _sprite(sol, "FlaqueMarchand", TRACES + "sang_flaque.png", Rect2(0, 0, 32, 19), body_at + Vector2(6, 4))
	puddle.scale = Vector2(1.6, 1.4)
	var corpse := _sprite(sol, "CorpsMarchand", "res://assets/sprites/characters/random_pnj_brown.png", Rect2(320, 1280, 64, 64), body_at, 14.0)
	corpse.modulate = Color(0.82, 0.78, 0.78)
	_inspect("ExaminerMarchand", body_at + Vector2(0, -8), "marchand_corps.tres", "marchand_corps_apres.tres", "marchand_retrouve", Vector2(0, -30))
	# le grand cercle rituel, et les quatre sceaux au sol, deux de chaque côté de l'allée
	_sprite(sol, "CercleRituel", OBJ + "cercle_rituel.png", Rect2(0, 0, 160, 160), Vector2(cx, 420 + 80))
	_light("Cercle", Vector2(cx, 420), TURQUOISE, 0.5, 1.0)
	var sx := [cx - 164, cx - 100, cx + 100, cx + 164]
	for k in 4:
		_sprite(sol, "Sceau" + (SYMBOLS[k] as String).capitalize(), OBJ + "sceaux_sol.png", Rect2(k * 64, 0, 64, 64), Vector2(sx[k], 572))
		_light("Sceau%d" % k, Vector2(sx[k], 540), TURQUOISE, 0.35, 0.35)
	_trail([[640.0, 504.0], [336.0, 318.0]], cx)
	_trail_to(Vector2(cx, 318), body_at + Vector2(10, -6))
	# piliers ; à leur pied, côté mur, une statue de mage yrenn
	var px := [10.5, 23.5]
	var k2 := 0
	for y in [11.2, 16.6]:
		_pillar(Vector2(px[0], y) * T, PILLAR_A)
		_pillar(Vector2(px[1], y) * T, PILLAR_B)
		_statue(Vector2(px[0] - 1.15, y + 0.2) * T, k2 % 2)
		_statue(Vector2(px[1] + 1.15, y + 0.2) * T, (k2 + 1) % 2)
		k2 += 1
	_bowl(Vector2(14.5, 19.0) * T)
	_bowl(Vector2(19.5, 19.0) * T)
	# alcôves : un coffre à gauche, une inscription à droite
	_chest("CoffreGardien", "fiole", 2, Vector2(1.9, 13.6) * T)
	_light("AlcoveOuest", Vector2(2, 12.4) * T, TURQUOISE, 0.6, 0.45)
	var ins := Node2D.new()
	ins.set_script(load("res://scenes/maps/fresque_yrenn.gd"))
	ins.set("style", "medaillon")
	ins.set("symbol", "flamme")
	ins.set("conversation", load(DIALOGUES + "inscription_gardien.tres"))
	ins.set("read_spot", Vector2(0, 2.4 * T))
	ins.position = Vector2(32 * T, 8.6 * T)
	_own(ins, "Inscription", decor)
	_light("AlcoveEst", Vector2(32, 12.4) * T, BLUE, 0.7, 0.45)
	_crystals([Vector2(3.6, 7.2), Vector2(30.4, 7.0), Vector2(3.4, 19.2), Vector2(30.6, 19.4), Vector2(1.4, 11.4), Vector2(32.6, 13.6)])
	_jars([Vector2(5.0, 18.8), Vector2(29.0, 9.0)], [Vector2(6.2, 7.6), Vector2(27.6, 18.6)])
	_bones([[Vector2(5.6, 9.4), 4], [Vector2(28.2, 12.6), 0], [Vector2(7.4, 15.0), 2], [Vector2(26.8, 17.2), 5], [Vector2(12.0, 7.6), 3],
		[Vector2(21.6, 8.0), 1]])
	_cracks(30)
	# le gardien, devant l'autel
	var g := Node2D.new()
	g.position = Vector2(cx, wall_foot + 96)
	_own(g, "Gardien", ysort)
	var armor := Sprite2D.new()
	armor.texture = load("res://assets/sprites/monsters/morts_vivants/cursed_armor.png")
	armor.offset = Vector2(0, -28)
	_own(armor, "Armure", g)
	_box(g, "Corps", Vector2(0, -6), Vector2(30, 14))
	# passages
	_spawn("SpawnFromGalerie", Vector2(cx, 19.3 * T))
	_exit("ExitToGalerie", Vector2(cx, H * T - 14), Vector2(64, 24), "res://scenes/maps/TempleGalerieMap.tscn", "SpawnFromGardien")
	_scenario()
	scenario.set("arrival", load(DIALOGUES + "salle_gardien.tres"))
	scenario.set("arrival_flag", "salle_gardien_vue")
	scenario.set("monster", load("res://resources/monsters/gardien_yrenn.tres"))
	scenario.set("battle_background", load(BATTLE_BG_INSIDE))
	scenario.set("guardian_wake", load(DIALOGUES + "gardien_eveil.tres"))
	scenario.set("guardian_defeated", load(DIALOGUES + "gardien_vaincu.tres"))
	scenario.set("fragment_caught", load(DIALOGUES + "fragment_capture.tres"))
	_area("ZoneGardien", g.position + Vector2(0, 40), Vector2(190, 136))
	scenario.set("guardian_path", NodePath("../YSortLayer/Gardien"))
	scenario.set("guardian_zone_path", NodePath("../ZoneGardien"))
	_player(Vector2(cx, 19.3 * T))
	_save("res://scenes/maps/TempleGardienMap.tscn")

# =====================================================================================
# Construction d'une salle
# =====================================================================================

func _begin(nm: String, w: int, h: int, rects: Array, pils: Array, aisle_x: int, seed_v: int, mood: Color) -> void:
	W = w
	H = h
	floor.clear()
	walls.clear()
	pilasters = pils
	aisle = aisle_x
	rng.seed = seed_v * 7919 + nm.length()
	for r: Rect2i in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				floor[Vector2i(x, y)] = true
	main_top = (rects[0] as Rect2i).position.y
	map_root = Node2D.new()
	map_root.name = nm
	map_root.set_script(load("res://scenes/maps/map_camera_zoom.gd"))
	map_root.set("music", load(MUSIC))
	map_root.set("camera_bounds", Rect2(0, 0, W * T, H * T))
	ground = _layer("Ground", 0)
	var wall_layer := _layer("Murs", 0)
	var feet := _layer("PiedsDesMurs", 0)
	var tops := _layer("DessusDesMurs", 1)
	sol = _own(Node2D.new(), "DetailsSol", map_root)
	decor = _own(Node2D.new(), "Decor", map_root)
	ysort = _own(Node2D.new(), "YSortLayer", map_root)
	ysort.y_sort_enabled = true
	lights = _own(Node2D.new(), "Lueurs", map_root)
	var cm := CanvasModulate.new()
	cm.color = mood
	_own(cm, "Penombre", map_root)
	light_tex = load("res://scenes/maps/sceau_yrenn.gd").glow_texture()
	scenario = null
	_compute_walls()
	_paint_floor()
	_paint_walls(wall_layer, feet)
	_paint_tops(tops)
	_bounds()

func _compute_walls() -> void:
	for c: Vector2i in floor:
		if floor.has(c + Vector2i.UP):
			continue
		for r in range(1, 6):
			var p := c + Vector2i(0, -r)
			if not floor.has(p) and not walls.has(p):
				walls[p] = [5 - r if r < 5 else 0, c.y]

func _open(p: Vector2i) -> bool:
	return floor.has(p) or (walls.has(p) and walls[p][0] >= 1)

func _paint_floor() -> void:
	for c: Vector2i in floor:
		if aisle >= 0 and (c.x == aisle or c.x == aisle + 1):
			var base := AISLE_PANEL if (c.y / 2) % 2 == 0 else AISLE_MAZE
			ground.set_cell(c, 0, base + Vector2i(c.x - aisle, c.y % 2))
		else:
			ground.set_cell(c, 0, FLOOR[c.x % 2])

func _paint_walls(l: TileMapLayer, feet: TileMapLayer) -> void:
	for p: Vector2i in walls:
		var row: int = walls[p][0]
		var main: bool = walls[p][1] == main_top
		var col := WALL_PILASTER if main and pilasters.has(p.x) else WALL_PLAIN
		l.set_cell(p, 0, Vector2i(col, row))
		if row == 4 and col == WALL_PILASTER:
			feet.set_cell(p + Vector2i.DOWN, 0, Vector2i(col, 5))

func _paint_tops(l: TileMapLayer) -> void:
	for y in H:
		for x in W:
			var p := Vector2i(x, y)
			if floor.has(p) or walls.has(p):
				continue
			var up := _open(p + Vector2i.UP)
			var left := _open(p + Vector2i.LEFT)
			var right := _open(p + Vector2i.RIGHT)
			if up and right:
				l.set_cell(p, 0, CORNER_TR)
			elif up and left:
				l.set_cell(p, 0, CORNER_TL)
			elif up:
				l.set_cell(p, 0, RIM_TOP)
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

## Tout ce qui n'est pas du sol bloque Zylrak (rangées de cases fusionnées), et le bas des passages.
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

# =====================================================================================
# Outils
# =====================================================================================

func _tileset() -> TileSet:
	var t := TileSet.new()
	t.tile_size = Vector2i(T, T)
	var a := TileSetAtlasSource.new()
	a.texture = load(INTERIORS)
	a.texture_region_size = Vector2i(T, T)
	var used := [FILL, RIM_TOP, RIM_LEFT, RIM_RIGHT, CORNER_TL, CORNER_TR] + FLOOR
	for base in [AISLE_PANEL, AISLE_MAZE]:
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			used.append(base + d)
	for col in [WALL_PLAIN, WALL_PILASTER]:
		for r in 6:
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

func _box(parent: Node, nm: String, pos: Vector2, size: Vector2) -> void:
	var b := _own(StaticBody2D.new(), nm, parent)
	_shape(b, "Forme", pos, size)

func _area(nm: String, pos: Vector2, size: Vector2) -> Area2D:
	var a := _own(Area2D.new(), nm, map_root) as Area2D
	a.position = pos
	_shape(a, "Forme", Vector2.ZERO, size)
	return a

## Sprite posé par son pied (bas de l'image), un peu enfoncé de `foot_pad` pixels.
func _sprite(parent: Node, nm: String, path: String, region: Rect2, foot: Vector2, foot_pad := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.offset = Vector2(-region.size.x / 2.0, -region.size.y + foot_pad)
	s.position = foot
	return _own(s, nm, parent)

func _uid(prefix: String, parent: Node) -> String:
	var i := 1
	while parent.has_node(prefix + str(i)):
		i += 1
	return prefix + str(i)

## Animation de plusieurs images de la même planche, posée par son pied.
func _anim(parent: Node, prefix: String, path: String, frames: Array, fps: float, foot: Vector2, foot_pad := 0.0) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	var tex: Texture2D = load(path)
	for r: Rect2 in frames:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = r
		sf.add_frame("default", a)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.autoplay = "default"
	s.frame = rng.randi() % frames.size()
	s.speed_scale = rng.randf_range(0.85, 1.15)
	s.centered = false
	var size: Vector2 = (frames[0] as Rect2).size
	s.offset = Vector2(-size.x / 2.0, -size.y + foot_pad)
	s.position = foot
	return _own(s, _uid(prefix, parent), parent)

func _light(nm: String, pos: Vector2, color: Color, energy: float, scale: float) -> void:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.position = pos
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	_own(l, _uid(nm, lights) if lights.has_node(nm) else nm, lights)

func _wall_torch(foot: Vector2) -> void:
	var frames := [Rect2(0, 0, 32, 32), Rect2(32, 0, 32, 32), Rect2(64, 0, 32, 32), Rect2(96, 0, 32, 32), Rect2(0, 32, 32, 32), Rect2(32, 32, 32, 32)]
	_anim(decor, "Torche", TORCH, frames, 9.0, foot)
	_light("Torche", foot + Vector2(0, -24), WARM, 0.85, 0.6)

## Brasero sur pied (32 × 64).
func _stand(foot: Vector2) -> void:
	var frames := [Rect2(0, 0, 32, 64), Rect2(32, 0, 32, 64), Rect2(64, 0, 32, 64), Rect2(96, 0, 32, 64)]
	var s := _anim(ysort, "Brasero", STAND, frames, 8.0, foot, 2.0)
	_box(s, "Corps", Vector2(0, -4), Vector2(16, 8))
	_light("Brasero", foot + Vector2(0, -50), WARM, 1.0, 0.85)

## Vasque de feu posée au sol.
func _bowl(foot: Vector2) -> void:
	var frames := [Rect2(0, 0, 32, 32), Rect2(32, 0, 32, 32), Rect2(64, 0, 32, 32), Rect2(96, 0, 32, 32), Rect2(0, 32, 32, 32), Rect2(32, 32, 32, 32)]
	var s := _anim(ysort, "Vasque", BOWL, frames, 9.0, foot, 4.0)
	_box(s, "Corps", Vector2(0, -6), Vector2(20, 10))
	_light("Vasque", foot + Vector2(0, -16), WARM, 0.8, 0.6)

func _pillar(foot: Vector2, region: Rect2) -> void:
	var s := _sprite(ysort, _uid("Pilier", ysort), INTERIORS, region, foot, 2.0)
	_box(s, "Corps", Vector2(0, -5), Vector2(22, 12))
	_light("Pilier", foot + Vector2(0, -60), BLUE, 0.45, 0.5)

func _rubble(foot: Vector2, k: int) -> void:
	var region: Rect2 = RUBBLE[k]
	var s := _sprite(ysort, _uid("Gravats", ysort), DECO, region, foot, 4.0)
	_box(s, "Corps", Vector2(0, -8), Vector2(region.size.x - 6, 14))

func _crystals(cells: Array) -> void:
	for c: Vector2 in cells:
		var region: Rect2 = CRYSTALS[rng.randi() % CRYSTALS.size()]
		var s := _sprite(ysort, _uid("Cristaux", ysort), CAVES, region, c * T, 2.0)
		s.flip_h = rng.randf() < 0.5
		_light("Cristaux", c * T + Vector2(0, -10), TURQUOISE, 0.4, 0.35)

func _jars(whole: Array, broken: Array) -> void:
	for c: Vector2 in whole:
		var region: Rect2 = JARS[rng.randi() % JARS.size()]
		var s := _sprite(ysort, _uid("Jarre", ysort), PROPS_A, region, c * T, 2.0)
		_box(s, "Corps", Vector2(0, -4), Vector2(region.size.x - 4, 8))
	for c: Vector2 in broken:
		var region: Rect2 = SHARDS[rng.randi() % SHARDS.size()]
		var s := _sprite(sol, _uid("Tessons", sol), PROPS_A, region, c * T, 2.0)
		s.flip_h = rng.randf() < 0.5

## Chaînes brisées accrochées au mur, d'un turquoise éteint.
func _chains(tops: Array) -> void:
	for p: Vector2 in tops:
		var region: Rect2 = CHAIN_SHORT if rng.randf() < 0.5 else CHAIN_LONG[rng.randi() % 2]
		var s := Sprite2D.new()
		s.texture = load(DECO)
		s.region_enabled = true
		s.region_rect = region
		s.centered = false
		s.offset = Vector2(-region.size.x / 2.0, 0)
		s.position = p
		s.modulate = Color(0.55, 1.0, 0.9)
		_own(s, _uid("Chaine", decor), decor)

## Dalles fissurées, au hasard (pas sur l'allée).
func _cracks(n: int) -> void:
	var cells := floor.keys()
	var placed := 0
	var tries := 0
	while placed < n and tries < 500:
		tries += 1
		var c: Vector2i = cells[rng.randi() % cells.size()]
		if aisle >= 0 and (c.x == aisle or c.x == aisle + 1):
			continue
		if c.y < main_top + 1:
			continue
		var s := Sprite2D.new()
		s.texture = load(OBJ + "fissures.png")
		s.region_enabled = true
		s.region_rect = Rect2((rng.randi() % 4) * 32, 0, 32, 32)
		s.position = Vector2(c) * T + Vector2(16, 16)
		s.rotation = (rng.randi() % 4) * PI / 2
		s.modulate = Color(1, 1, 1, rng.randf_range(0.5, 0.8))
		_own(s, _uid("Fissure", sol), sol)
		placed += 1

## Traces du marchand, traîné vers le fond (segments [y de départ, y d'arrivée], de bas en haut).
func _trail(segments: Array, x: float) -> void:
	var traces := _own(Node2D.new(), "TracesMarchand", sol)
	for seg in segments:
		var y: float = seg[0]
		while y > seg[1]:
			var s := Sprite2D.new()
			var kind := rng.randi() % 5
			s.texture = load(TRACES + ["sillons.png", "sang_trace.png", "sang_trace_2.png", "sang_trace.png", "sang_trace_2.png"][kind])
			s.scale = Vector2(1.1, 1.1)
			s.position = Vector2(x + rng.randf_range(-9, 9), y)
			s.rotation = -PI / 2 + rng.randf_range(-0.45, 0.45)
			s.modulate = Color(0.85, 0.8, 0.8, rng.randf_range(0.5, 0.8))
			traces.add_child(s)
			s.owner = map_root
			y -= rng.randf_range(14, 30)

## Point à examiner (point_inspection.gd), disponible une fois le gardien vaincu.
func _inspect(nm: String, pos: Vector2, conv: String, conv_after: String, flag: String, sparkle: Vector2) -> Node2D:
	var n := Node2D.new()
	n.set_script(load("res://scenes/maps/point_inspection.gd"))
	n.set("conversation", load(DIALOGUES + conv))
	if conv_after != "":
		n.set("conversation_after", load(DIALOGUES + conv_after))
	n.set("required_flag", "gardien_temple_vaincu")
	n.set("flag_on_read", flag)
	n.set("sparkle_at", sparkle)
	n.position = pos
	return _own(n, nm, ysort)

## Statue de mage yrenn (0 : au bâton, 1 : en prière), sur son socle.
func _statue(foot: Vector2, kind: int) -> void:
	var s := _sprite(ysort, _uid("Statue", ysort), OBJ + "statues_yrenn.png", Rect2(kind * 32, 0, 32, 64), foot, 2.0)
	_box(s, "Corps", Vector2(0, -6), Vector2(24, 12))
	_light("Statue", foot + Vector2(0, -36), TURQUOISE, 0.3, 0.35)

## Ossements au sol : [case, n° (0 crâne, 1 cage thoracique, 2 os épars, 3 crâne casqué, 4 tas, 5 fémur et mâchoire)].
func _bones(list: Array) -> void:
	for b in list:
		var k: int = b[1]
		var s := _sprite(sol, _uid("Os", sol), OBJ + "ossements.png", Rect2((k % 3) * 32, (k / 3) * 32, 32, 32), (b[0] as Vector2) * T, 4.0)
		s.flip_h = rng.randf() < 0.5

## Racines et mousse sur un mur : [colonne, rangée du sol au pied de ce mur, n° (0 racines, 1 mousse, 2 fissure moussue)].
func _wall_overlays(list: Array) -> void:
	for o in list:
		var top := Vector2((o[0] as int) * T + 16, ((o[1] as int) - 4) * T)
		var s := Sprite2D.new()
		s.texture = load(OBJ + "murs_racines_mousse.png")
		s.region_enabled = true
		s.region_rect = Rect2((o[2] as int) * 32, 0, 32, 96)
		s.centered = false
		s.offset = Vector2(-16, 0)
		s.position = top
		_own(s, _uid("Vegetation", decor), decor)

## Traînée de sang en ligne droite (d'un point à un autre), vers le corps du marchand.
func _trail_to(from: Vector2, to: Vector2) -> void:
	var traces := sol.get_node("TracesMarchand")
	var d := from.distance_to(to)
	var step := 0.0
	while step < d:
		var s := Sprite2D.new()
		s.texture = load(TRACES + ["sang_trace.png", "sang_trace_2.png", "sillons.png"][rng.randi() % 3])
		s.scale = Vector2(1.1, 1.1)
		s.position = from.lerp(to, step / d) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		s.rotation = (to - from).angle() + PI + rng.randf_range(-0.4, 0.4)
		s.modulate = Color(0.85, 0.8, 0.8, rng.randf_range(0.5, 0.8))
		traces.add_child(s)
		s.owner = map_root
		step += rng.randf_range(14, 26)

## Le passage sous l'arche : une ouverture noire, arrondie en haut.
func _opening(foot: Vector2) -> void:
	var pts := PackedVector2Array()
	var r := 15.0
	var top := -54.0
	pts.append(Vector2(-r, 0))
	for i in range(0, 9):
		var a := PI + PI * i / 8.0
		pts.append(Vector2(cos(a) * r, top + r + sin(a) * r))
	pts.append(Vector2(r, 0))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(0.015, 0.015, 0.03)
	poly.position = foot
	_own(poly, "Passage", decor)

func _chest(nm: String, contenu: String, n: int, pos: Vector2) -> void:
	var c := Node2D.new()
	c.set_script(load("res://scenes/maps/coffre.gd"))
	c.set("contenu", contenu)
	c.set("quantite", n)
	c.position = pos
	_own(c, nm, ysort)

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

func _scenario() -> void:
	scenario = Node.new()
	scenario.set_script(load("res://scenes/maps/temple_salle.gd"))
	_own(scenario, "Scenario", map_root)

func _player(pos: Vector2) -> void:
	var p: Node2D = load("res://scenes/characters/Player.tscn").instantiate()
	p.position = pos
	_own(p, "Player", ysort)
	p.add_to_group("Player", true)
