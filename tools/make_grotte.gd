extends SceneTree
# Lancer : Godot --headless --path . -s tools/make_grotte.gd [-- entree|toiles|filon]  (sans argument : toutes)
# La grotte du sentier (contrat « Dans le noir de la grotte », voir scripts/contrats.gd) : trois
# petites salles, construites comme les salles du temple et les intérieurs (tools/make_interieurs.gd) :
# un plan de sol (rectangles de cases), une falaise de 2 cases au nord de chaque sol, et autour, la
# roche (son dessus noir, ses rebords de rochers, ses coins posés automatiquement).
# - GrotteEntreeMap : on y entre depuis le chariot ; stalagmites, cristaux bleus, le jour derrière soi.
# - GrotteToilesMap : un couloir en lacets couvert de toiles ; les araignées attaquent.
# - GrotteFilonMap : la salle du filon de pierre-de-braise, éclairée de rouge, et l'araignée géante.
# Tuiles et décor : pack Caves de Szadi art (MainLev2.0 : modèle de salle à la rangée 13 pour la
# roche grise, à la rangée 0 pour la roche chaude ; decorative : stalagmites, cristaux) ;
# coins rentrants et toiles : tools/dev/draw_grotte.gd. Il fait noir : la torche du forgeron
# (scenes/maps/torche_joueur.gd) éclaire autour de Zylrak.

const T := 32
const MAIN := "res://assets/sprites/tilesets/Caves/MainLev2.0.png"
const CORNERS := "res://assets/sprites/tilesets/Caves/grotte_coins.png"
const DECO := "res://assets/sprites/tilesets/Caves/decorative.png"
const WEBS := "res://assets/sprites/objets/grotte/toiles.png"
const SPIDER := "res://assets/sprites/monsters/araignees/araignee_geante.png"
const TILESET_OUT := "res://resources/tilesets/grotte.tres"
const MUSIC := "res://assets/audio/musique/ruines.wav"
const BATTLE_BG := "res://assets/battle_backgrounds/battle_grotte.png"
const DIALOGUES := "res://resources/dialogues/grotte/"

# --- tuiles (source 0 : MainLev2.0 ; source 1 : coins rentrants) ---
## Première rangée du modèle de salle : roche grise, roche chaude.
const GREY := 13
const WARM := 0
## Dans le modèle (colonnes 2 à 7) : rangée 0 rebord du haut, 1-5 rebords des côtés, 6 rebord du bas,
## 7-8 la falaise ; 9-12 (colonnes 7-9) une arche, l'entrée d'un passage.
const COL_LEFT := 2
const COL_RIGHT := 7
const MIDDLE := [3, 4, 5, 6]
const INNER_BR := 0
const INNER_BL := 1
const INNER_TR := 2
const INNER_TL := 3
## Sols : gris sombre (salles grises) ou brun-violet (salle du filon).
const FLOOR_GREY := {"plain": [Vector2i(0, 46), Vector2i(1, 46), Vector2i(0, 47), Vector2i(1, 47)],
	"pebbles": [Vector2i(0, 42), Vector2i(1, 42), Vector2i(2, 42), Vector2i(3, 42), Vector2i(0, 43), Vector2i(1, 43), Vector2i(2, 43), Vector2i(3, 43), Vector2i(0, 44), Vector2i(1, 44), Vector2i(2, 44), Vector2i(3, 44)],
	"tufts": [Vector2i(4, 41), Vector2i(5, 41), Vector2i(6, 42), Vector2i(7, 42), Vector2i(8, 41)]}
const FLOOR_WARM := {"plain": [Vector2i(9, 45), Vector2i(10, 45), Vector2i(11, 46), Vector2i(12, 46), Vector2i(9, 47), Vector2i(10, 47)],
	"pebbles": [Vector2i(9, 41), Vector2i(10, 41), Vector2i(11, 42), Vector2i(12, 42), Vector2i(9, 43), Vector2i(10, 43)],
	"tufts": []}

# --- décor (decorative.png) ---
const STALAGMITES_BIG := [Rect2(4, 36, 84, 92), Rect2(296, 164, 84, 92), Rect2(160, 60, 64, 68), Rect2(224, 178, 66, 78)]
const STALAGMITES := [Rect2(96, 50, 50, 78), Rect2(234, 76, 50, 52), Rect2(100, 204, 48, 52), Rect2(160, 188, 62, 68)]
const STALAGMITES_SMALL := [Rect2(302, 80, 38, 48), Rect2(354, 102, 28, 26), Rect2(2, 230, 28, 26), Rect2(40, 206, 42, 50)]
const CRYSTALS := [Rect2(64, 610, 32, 28), Rect2(32, 676, 32, 28), Rect2(68, 580, 26, 22), Rect2(40, 608, 18, 22),
	Rect2(32, 648, 26, 22), Rect2(68, 674, 18, 24)]
# --- toiles (toiles.png) ---
const WEB_CORNER_L := Rect2(0, 0, 48, 48)
const WEB_CORNER_R := Rect2(48, 0, 48, 48)
const WEB_ROUND := Rect2(96, 0, 64, 64)
const COCOON := Rect2(96, 0, 16, 24)
const THREADS := Rect2(112, 0, 16, 40)

const BLUE := Color(0.45, 0.75, 1.0)
const EMBER := Color(1.0, 0.32, 0.15)
const DAYLIGHT := Color(0.85, 0.9, 1.0)

var ts: TileSet
var map_root: Node2D
var W := 0
var H := 0
var r0 := GREY
var floor := {}
var walls := {}       # case -> rangée de la falaise (r0 + 7 ou r0 + 8)
var passages := {}    # cases praticables sous une arche
var arches := {}      # case -> tuile de l'arche
var ysort: Node2D
var decor: Node2D
var lights: Node2D
var light_tex: GradientTexture2D
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms := ["entree", "toiles", "filon"] if args.is_empty() else [args[0]]
	ts = _tileset()
	light_tex = load("res://scenes/maps/sceau_yrenn.gd").glow_texture()
	for r in rooms:
		call("_room_" + r)
	quit()

# =====================================================================================
# Les salles
# =====================================================================================

## L'entrée : 22 × 18 cases. On arrive du chariot par le bas ; l'arche du nord-ouest mène aux toiles.
func _room_entree() -> void:
	_begin("GrotteEntreeMap", 22, 18, [Rect2i(3, 6, 16, 8), Rect2i(14, 4, 4, 2), Rect2i(9, 14, 4, 4)], GREY,
		Color(0.2, 0.2, 0.26), 31)
	_arch(6, 6, "GrotteToilesMap", "SpawnFromEntree", "ExitToToiles")
	_spawn("SpawnFromToiles", Vector2(6.5, 7.2) * T)
	_spawn("SpawnFromChariot", Vector2(11.0, 16.6) * T)
	_exit("ExitToChariot", Vector2(11.0 * T, H * T + 8), Vector2(4 * T, 16), "res://scenes/maps/ForestChariotMap.tscn", "SpawnFromGrotte")
	# le jour qui entre par le passage du bas
	_light("Jour", Vector2(11.0, 17.5) * T, DAYLIGHT, 0.9, 1.3)
	_light("Jour", Vector2(11.0, 14.5) * T, DAYLIGHT, 0.35, 1.0)
	# stalagmites contre les parois, cristaux dans les recoins
	_stalagmite(STALAGMITES_BIG[0], Vector2(4.4, 7.4), true)
	_stalagmite(STALAGMITES[1], Vector2(17.6, 12.8), true)
	_stalagmite(STALAGMITES_SMALL[0], Vector2(3.6, 12.9), true)
	_stalagmite(STALAGMITES_BIG[2], Vector2(16.8, 5.6), true)
	_stalagmite(STALAGMITES_SMALL[1], Vector2(9.2, 9.6), true)
	_stalagmite(STALAGMITES[0], Vector2(13.4, 9.0), true)
	_stalagmite(STALAGMITES_SMALL[2], Vector2(8.6, 13.6), false)
	_crystals([Vector2(18.3, 7.6), Vector2(3.7, 10.4), Vector2(14.6, 4.9), Vector2(12.6, 13.6)])
	_scenario("entree_vue", "arrivee_entree")
	_encounters(Rect2(3, 6, 16, 8), 0.025, 1)
	_torch()
	_save("res://scenes/maps/GrotteEntreeMap.tscn")

## Le couloir aux toiles : 24 × 20 cases, en lacets. On monte depuis l'entrée (en bas) jusqu'à
## l'arche du nord-est, vers la salle du filon.
func _room_toiles() -> void:
	_begin("GrotteToilesMap", 24, 20, [Rect2i(10, 15, 4, 5), Rect2i(4, 11, 10, 4), Rect2i(4, 6, 5, 5), Rect2i(4, 4, 16, 3)],
		GREY, Color(0.17, 0.17, 0.23), 47)
	_arch(17, 4, "GrotteFilonMap", "SpawnFromToiles", "ExitToFilon")
	_spawn("SpawnFromFilon", Vector2(17.5, 5.2) * T)
	_spawn("SpawnFromEntree", Vector2(12.0, 18.6) * T)
	_exit("ExitToEntree", Vector2(12.0 * T, H * T + 8), Vector2(4 * T, 16), "res://scenes/maps/GrotteEntreeMap.tscn", "SpawnFromToiles")
	# les toiles : dans les angles, sur les falaises, des proies emmaillotées
	_web(WEB_CORNER_L, Vector2(4.0, 4.0), false)
	_web(WEB_CORNER_R, Vector2(20.0, 4.0), true)
	_web(WEB_CORNER_L, Vector2(4.0, 11.0), false)
	_web(WEB_CORNER_R, Vector2(14.0, 11.0), true)
	_web(WEB_ROUND, Vector2(11.0, 2.4), false)
	_web(WEB_ROUND, Vector2(6.5, 9.0), false)
	_web(WEB_CORNER_R, Vector2(14.0, 15.0), true)
	_web(WEB_CORNER_L, Vector2(10.0, 15.0), false)
	# des proies emmaillotées, pendues aux parois
	for c in [Vector2(13.6, 4.1), Vector2(8.4, 6.1), Vector2(4.1, 7.4)]:
		_web(COCOON, c, false)
	_web(THREADS, Vector2(9.6, 4.0), false)
	_stalagmite(STALAGMITES[2], Vector2(12.9, 14.6), true)
	_stalagmite(STALAGMITES_SMALL[3], Vector2(4.6, 14.7), true)
	_stalagmite(STALAGMITES_SMALL[1], Vector2(19.4, 6.8), false)
	_crystals([Vector2(4.6, 8.6), Vector2(19.2, 5.0)])
	_chest("CoffreToiles", "antidote", 2, Vector2(7.6, 13.7))
	_scenario("toiles_vue", "arrivee_toiles")
	_encounters(Rect2(4, 4, 16, 16), 0.06, 2)
	_torch()
	_save("res://scenes/maps/GrotteToilesMap.tscn")

## La salle du filon : 20 × 17 cases, éclairée de rouge par la pierre-de-braise. L'araignée géante
## garde le filon, contre la paroi du fond.
func _room_filon() -> void:
	_begin("GrotteFilonMap", 20, 17, [Rect2i(3, 4, 14, 9), Rect2i(8, 13, 4, 4)], WARM, Color(0.24, 0.17, 0.16), 63)
	_spawn("SpawnFromToiles", Vector2(10.0, 15.6) * T)
	_exit("ExitToToiles", Vector2(10.0 * T, H * T + 8), Vector2(4 * T, 16), "res://scenes/maps/GrotteToilesMap.tscn", "SpawnFromFilon")
	# le filon : des cristaux rougis contre la paroi du fond, qui rougeoient
	var vein := _own(Node2D.new(), "Filon", ysort) as Node2D
	vein.position = Vector2(10.0, 4.5) * T
	for spec in [[CRYSTALS[0], Vector2(-26, 0)], [CRYSTALS[1], Vector2(0, -2)], [CRYSTALS[4], Vector2(24, 2)], [CRYSTALS[2], Vector2(-8, 8)], [CRYSTALS[5], Vector2(12, 9)]]:
		var s := _sprite(vein, _uid("Eclat", vein), DECO, spec[0], spec[1], 2.0)
		s.modulate = Color(1.6, 0.55, 0.4)
	_box(vein, "Corps", Vector2(0, 2), Vector2(72, 14))
	_light("Filon", vein.position + Vector2(0, -6), EMBER, 1.3, 1.6)
	_light("Filon", vein.position + Vector2(0, 40), EMBER, 0.5, 2.6)
	var read := Node2D.new()
	read.set_script(load("res://scenes/maps/point_inspection.gd"))
	read.set("conversation", load(DIALOGUES + "filon.tres"))
	read.set("conversation_after", load(DIALOGUES + "filon_apres.tres"))
	read.set("required_flag", "araignee_geante_vaincue")
	read.set("flag_on_read", "pierre_de_braise")
	read.set("reach", 52.0)
	read.set("sparkle_at", Vector2(0, -30))
	_own(read, "LireFilon", ysort)
	read.position = vein.position + Vector2(0, 26)
	# l'araignée géante, devant le filon
	var spider := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("repos")
	frames.set_animation_speed("repos", 3.0)
	for i in [4, 5]:
		var at := AtlasTexture.new()
		at.atlas = load(SPIDER)
		at.region = Rect2(i * 64, 2 * 64, 64, 64)   # rangée 2 : tournée vers le bas
		frames.add_frame("repos", at)
	spider.sprite_frames = frames
	spider.autoplay = "repos"
	spider.offset = Vector2(0, -24)
	spider.scale = Vector2(1.5, 1.5)
	_own(spider, "AraigneeGeante", ysort)
	spider.position = Vector2(10.0, 7.2) * T
	_box(spider, "Corps", Vector2(0, -4), Vector2(36, 12))
	# des toiles et des os autour
	_web(WEB_CORNER_L, Vector2(3.0, 4.0), false)
	_web(WEB_CORNER_R, Vector2(17.0, 4.0), true)
	_web(WEB_ROUND, Vector2(5.2, 2.3), false)
	_web(WEB_ROUND, Vector2(14.8, 2.3), false)
	for c in [Vector2(3.1, 7.4), Vector2(16.4, 6.6)]:
		_web(COCOON, c, false)
	_stalagmite(STALAGMITES_BIG[1], Vector2(15.6, 12.4), true)
	_stalagmite(STALAGMITES[3], Vector2(4.3, 12.5), true)
	_stalagmite(STALAGMITES_SMALL[0], Vector2(3.7, 5.6), true)
	# le combat : quand Zylrak approche du filon
	var zone := Area2D.new()
	_own(zone, "ZoneAraignee", map_root)
	_shape(zone, "Forme", Vector2(10.0, 10.2) * T, Vector2(14 * T, 2 * T))
	var sc := Node.new()
	sc.set_script(load("res://scenes/maps/grotte_scenario.gd"))
	sc.set("arrival", load(DIALOGUES + "arrivee_filon.tres"))
	sc.set("arrival_flag", "grotte_filon_vue")
	sc.set("monster", load("res://resources/monsters/araignee_geante.tres"))
	sc.set("battle_background", load(BATTLE_BG))
	sc.set("boss_wake", load(DIALOGUES + "araignee_reveil.tres"))
	sc.set("boss_defeated", load(DIALOGUES + "araignee_vaincue.tres"))
	_own(sc, "Scenario", map_root)
	sc.set("boss_path", NodePath("../YSortLayer/AraigneeGeante"))
	sc.set("boss_zone_path", NodePath("../ZoneAraignee"))
	_torch()
	_save("res://scenes/maps/GrotteFilonMap.tscn")

# =====================================================================================
# Construction
# =====================================================================================

func _begin(nm: String, w: int, h: int, rects: Array, rock: int, mood: Color, seed_v: int) -> void:
	W = w
	H = h
	r0 = rock
	floor.clear()
	walls.clear()
	passages.clear()
	arches.clear()
	rng.seed = seed_v
	for r: Rect2i in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				floor[Vector2i(x, y)] = true
	map_root = Node2D.new()
	map_root.name = nm
	map_root.set_script(load("res://scenes/maps/map_camera_zoom.gd"))
	map_root.set("camera_zoom", Vector2(3.0, 3.0))
	map_root.set("music", load(MUSIC))
	_layer("Ground", 0)
	_layer("Falaises", 0)
	_layer("DessusDeLaRoche", 1)
	_layer("Arches", 1)
	decor = _own(Node2D.new(), "Decor", map_root)
	ysort = _own(Node2D.new(), "YSortLayer", map_root)
	ysort.y_sort_enabled = true
	lights = _own(Node2D.new(), "Lueurs", map_root)
	var cm := CanvasModulate.new()
	cm.color = mood
	_own(cm, "Penombre", map_root)
	# la falaise : 2 cases au nord de chaque sol
	for c: Vector2i in floor:
		if floor.has(c + Vector2i.UP):
			continue
		for r in 2:
			var p := c + Vector2i(0, -2 + r)
			if not floor.has(p):
				walls[p] = r0 + 7 + r
	_paint_floor()
	_paint_walls()
	_paint_tops()
	_player(Vector2(W / 2.0, H - 1.5) * T)

func _open(p: Vector2i) -> bool:
	return floor.has(p) or walls.has(p)

## Le sol couvre toute la carte (sous la roche aussi : la caméra se cale sur ce calque).
func _paint_floor() -> void:
	var l := map_root.get_node("Ground") as TileMapLayer
	var set_: Dictionary = FLOOR_WARM if r0 == WARM else FLOOR_GREY
	for y in H:
		for x in W:
			var r := rng.randf()
			var pick: Array = set_.plain
			if r < 0.18:
				pick = set_.pebbles
			elif r < 0.24 and not (set_.tufts as Array).is_empty():
				pick = set_.tufts
			l.set_cell(Vector2i(x, y), 0, pick[rng.randi() % pick.size()])

func _paint_walls() -> void:
	var l := map_root.get_node("Falaises") as TileMapLayer
	for p: Vector2i in walls:
		l.set_cell(p, 0, Vector2i(MIDDLE[posmod(p.x * 7 + p.y, MIDDLE.size())], walls[p]))

func _paint_tops() -> void:
	var l := map_root.get_node("DessusDeLaRoche") as TileMapLayer
	var corner_row := 1 if r0 == WARM else 0
	for y in range(-1, H + 1):
		for x in range(-1, W + 1):
			var p := Vector2i(x, y)
			if floor.has(p) or walls.has(p):
				continue
			var up := floor.has(p + Vector2i.UP)
			var down := walls.has(p + Vector2i.DOWN)
			var left := _open(p + Vector2i.LEFT)
			var right := _open(p + Vector2i.RIGHT)
			var side_row := r0 + 1 + posmod(x * 3 + y * 5, 5)
			var mid_col: int = MIDDLE[posmod(x * 5 + y, MIDDLE.size())]
			if up and right:
				l.set_cell(p, 0, Vector2i(COL_RIGHT, r0))
			elif up and left:
				l.set_cell(p, 0, Vector2i(COL_LEFT, r0))
			elif up:
				l.set_cell(p, 0, Vector2i(mid_col, r0))
			elif down and right:
				l.set_cell(p, 0, Vector2i(COL_RIGHT, r0 + 6))
			elif down and left:
				l.set_cell(p, 0, Vector2i(COL_LEFT, r0 + 6))
			elif down:
				l.set_cell(p, 0, Vector2i(mid_col, r0 + 6))
			elif right:
				l.set_cell(p, 0, Vector2i(COL_RIGHT, side_row))
			elif left:
				l.set_cell(p, 0, Vector2i(COL_LEFT, side_row))
			elif _open(p + Vector2i(1, 1)):
				l.set_cell(p, 1, Vector2i(INNER_BR, corner_row))
			elif _open(p + Vector2i(-1, 1)):
				l.set_cell(p, 1, Vector2i(INNER_BL, corner_row))
			elif _open(p + Vector2i(1, -1)):
				l.set_cell(p, 1, Vector2i(INNER_TR, corner_row))
			elif _open(p + Vector2i(-1, -1)):
				l.set_cell(p, 1, Vector2i(INNER_TL, corner_row))
			else:
				l.set_cell(p, 0, Vector2i(MIDDLE[posmod(x + y * 3, MIDDLE.size())], r0 + 2 + posmod(x * 2 + y, 3)))

## Une arche dans la falaise du nord, centrée sur la colonne `cx` du sol dont le bord est à la rangée
## `top` : le passage (colonne du milieu) est praticable et mène à une autre salle.
func _arch(cx: int, top: int, target: String, spawn: String, nm: String) -> void:
	var l := map_root.get_node("Arches") as TileMapLayer
	for dx in range(-1, 2):
		for dy in range(-4, 0):
			var p := Vector2i(cx + dx, top + dy)
			(map_root.get_node("Falaises") as TileMapLayer).erase_cell(p)
			(map_root.get_node("DessusDeLaRoche") as TileMapLayer).erase_cell(p)
			l.set_cell(p, 0, Vector2i(8 + dx, r0 + 13 + dy))
	passages[Vector2i(cx, top - 1)] = true
	passages[Vector2i(cx, top - 2)] = true
	_exit(nm, Vector2((cx + 0.5) * T, (top - 1.7) * T), Vector2(T - 4, 12), "res://scenes/maps/%s.tscn" % target, spawn)

# =====================================================================================
# Décor, lumières, zones
# =====================================================================================

func _stalagmite(region: Rect2, cell: Vector2, solid: bool) -> void:
	var s := _sprite(ysort, _uid("Stalagmite", ysort), DECO, region, cell * T, 4.0)
	s.flip_h = rng.randf() < 0.5
	if solid:
		_box(s, "Corps", Vector2(0, -8), Vector2(region.size.x * 0.6, 14))

func _crystals(cells: Array) -> void:
	for c: Vector2 in cells:
		var region: Rect2 = CRYSTALS[rng.randi() % CRYSTALS.size()]
		var s := _sprite(ysort, _uid("Cristaux", ysort), DECO, region, c * T, 2.0)
		s.flip_h = rng.randf() < 0.5
		_light("Cristaux", c * T + Vector2(0, -10), BLUE, 0.55, 0.45)

## Toile posée par son coin haut-gauche (ou haut-droit si `right`), dans le décor (au-dessus du sol,
## sous les personnages).
func _web(region: Rect2, cell: Vector2, right: bool) -> void:
	var s := Sprite2D.new()
	s.texture = load(WEBS)
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.position = cell * T - (Vector2(region.size.x, 0) if right else Vector2.ZERO)
	s.modulate = Color(1, 1, 1, 0.85)
	s.z_index = 1
	_own(s, _uid("Toile", decor), decor)

func _chest(nm: String, contenu: String, n: int, cell: Vector2) -> void:
	var c := Node2D.new()
	c.set_script(load("res://scenes/maps/coffre.gd"))
	c.set("contenu", contenu)
	c.set("quantite", n)
	_own(c, nm, ysort)
	c.position = cell * T

func _light(nm: String, pos: Vector2, color: Color, energy: float, scale: float) -> void:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.position = pos
	l.color = color
	l.energy = energy
	l.texture_scale = scale
	_own(l, _uid(nm, lights), lights)

func _torch() -> void:
	var t := Node2D.new()
	t.set_script(load("res://scenes/maps/torche_joueur.gd"))
	_own(t, "Torche", map_root)

func _encounters(cells: Rect2, rate: float, most: int) -> void:
	var enc := Area2D.new()
	enc.set_script(load("res://scenes/maps/encounter_zone.gd"))
	var monsters: Array[MonsterData] = [load("res://resources/monsters/araignee.tres")]
	enc.set("monsters", monsters)
	enc.set("battle_background", load(BATTLE_BG))
	enc.set("encounter_rate", rate)
	enc.set("max_monsters", most)
	_own(enc, "EncounterZone", map_root)
	_shape(enc, "Forme", (cells.position + cells.size / 2.0) * T, cells.size * T)

## Une conversation à l'arrivée, une seule fois (flag "grotte_<flag>").
func _scenario(flag: String, conv: String) -> void:
	var sc := Node.new()
	sc.set_script(load("res://scenes/maps/grotte_scenario.gd"))
	sc.set("arrival", load(DIALOGUES + conv + ".tres"))
	sc.set("arrival_flag", "grotte_" + flag)
	_own(sc, "Scenario", map_root)

# =====================================================================================
# Outils
# =====================================================================================

func _bounds() -> void:
	var b := _own(StaticBody2D.new(), "Bords", map_root)
	var n := 0
	for y in range(-1, H + 1):
		var x := -1
		while x <= W:
			if _walkable(Vector2i(x, y)):
				x += 1
				continue
			var x0 := x
			while x <= W and not _walkable(Vector2i(x, y)):
				x += 1
			_shape(b, "B%d" % n, Vector2((x0 + x) / 2.0 * T, (y + 0.5) * T), Vector2((x - x0) * T, T))
			n += 1

## Praticable : le sol, les passages sous les arches, et le bas de la carte sous un couloir qui en sort.
func _walkable(p: Vector2i) -> bool:
	return floor.has(p) or passages.has(p) or (p.y >= H and floor.has(Vector2i(p.x, H - 1)))

func _save(out: String) -> void:
	_bounds()
	var packed := PackedScene.new()
	print(map_root.name, " : pack ", packed.pack(map_root), ", save ", ResourceSaver.save(packed, out))
	map_root.free()

func _tileset() -> TileSet:
	var t := TileSet.new()
	t.tile_size = Vector2i(T, T)
	var a := TileSetAtlasSource.new()
	a.texture = load(MAIN)
	a.texture_region_size = Vector2i(T, T)
	var used: Array = []
	for rock in [GREY, WARM]:
		for row in range(rock, rock + 9):
			for col in range(COL_LEFT, COL_RIGHT + 1):
				used.append(Vector2i(col, row))
		for row in range(rock + 9, rock + 13):
			for col in range(7, 10):
				used.append(Vector2i(col, row))
	for f in [FLOOR_GREY, FLOOR_WARM]:
		for k in f:
			used += f[k]
	for c in used:
		if not a.has_tile(c):
			a.create_tile(c)
	t.add_source(a, 0)
	var b := TileSetAtlasSource.new()
	b.texture = load(CORNERS)
	b.texture_region_size = Vector2i(T, T)
	for row in 2:
		for i in 4:
			b.create_tile(Vector2i(i, row))
	t.add_source(b, 1)
	ResourceSaver.save(t, TILESET_OUT)
	return load(TILESET_OUT)

func _own(n: Node, nm: String, parent: Node) -> Node:
	n.name = nm
	parent.add_child(n)
	n.owner = map_root
	return n

func _uid(prefix: String, parent: Node) -> String:
	var i := 1
	var name := prefix
	while parent.has_node(name):
		i += 1
		name = "%s%d" % [prefix, i]
	return name

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

## Sprite posé par son pied.
func _sprite(parent: Node, nm: String, path: String, region: Rect2, foot: Vector2, pad := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.offset = Vector2(-round(region.size.x / 2.0), -region.size.y + pad)
	s.position = foot
	return _own(s, nm, parent)

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
