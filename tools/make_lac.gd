extends SceneTree
# Lancer : Godot --headless --path . -s tools/make_lac.gd
# Le lac aux Brumes (scenes/maps/LacMap.tscn), à l'ouest de la cascade : un grand lac entouré de
# forêt, un ponton et sa barque, des roseaux, des nénuphars, de la brume qui dérive sur l'eau, et la
# clairière où Aldric coupait du bois. Le chemin de la cascade y mène une fois la quête de Brenna
# acceptée (flag "aldric_quest_started").
# Sol et chemins : tilesets de la forêt (terrains) ; eau : lac_tileset (auto-tile animé, 4 images,
# généré avec Copilot, l'herbe des rivages rendue transparente) posée par nos règles de bord ;
# décor : lac_props et la végétation de la forêt.

const T := 32
const W := 40
const H := 26
const OUT := "res://scenes/maps/LacMap.tscn"
const LAKE := "res://assets/sprites/tilesets/Lac/lac_rives.png"   # rivages sans leur herbe (tools/dev/draw_lac.gd)
const PROPS := "res://assets/sprites/tilesets/Lac/lac_props.png"
const VEG := "res://assets/sprites/tilesets/TreesAndPlants/veg_decoratives.png"
const TILESET_OUT := "res://resources/tilesets/lac_eau.tres"

# --- auto-tile de l'eau : bloc de 5 × 3 tuiles, 4 images espacées de 5 colonnes ---
const GRASS_ROW := 1   # rivage d'herbe : rangées 1 à 3
const DIRT_ROW := 4    # rivage de terre : rangées 4 à 6
# [colonne, rangée dans le bloc] selon les bords
const E_TL := Vector2i(0, 0)
const E_T := Vector2i(1, 0)
const E_TR := Vector2i(2, 0)
const E_L := Vector2i(0, 1)
const E_C := Vector2i(1, 1)
const E_R := Vector2i(2, 1)
const E_BL := Vector2i(0, 2)
const E_B := Vector2i(1, 2)
const E_BR := Vector2i(2, 2)
const I_TL := Vector2i(3, 0)   # coins rentrants : la terre est en diagonale
const I_TR := Vector2i(4, 0)
const I_BL := Vector2i(3, 1)
const I_BR := Vector2i(4, 1)

# --- décor du lac (lac_props) ---
const P := {
	"roseaux_petit": Rect2(0, 32, 32, 32), "roseaux_moyen": Rect2(32, 16, 32, 48), "roseaux_grand": Rect2(64, 0, 32, 64),
	"filet_peche": Rect2(256, 0, 64, 64), "rocher_grand": Rect2(0, 64, 64, 64), "rocher_large": Rect2(64, 96, 64, 32),
	"rocher_petit": Rect2(128, 96, 32, 32), "panneau_bois": Rect2(288, 96, 32, 32), "bois_flotte": Rect2(320, 96, 32, 32),
	"pierres_moussues": Rect2(352, 96, 32, 32), "tronc_mort": Rect2(0, 128, 96, 32), "barque_amarree": Rect2(96, 128, 64, 32),
	"poteau_1": Rect2(160, 128, 32, 32), "poteau_2": Rect2(192, 128, 32, 32), "ponton_ns": Rect2(224, 128, 32, 32),
	"ponton_bout_nord": Rect2(288, 128, 32, 32), "brume_64": Rect2(96, 160, 64, 32), "brume_96": Rect2(160, 160, 96, 32),
}
const LILIES := [Rect2(0, 176, 16, 16), Rect2(16, 176, 16, 16), Rect2(32, 176, 16, 16), Rect2(48, 176, 16, 16), Rect2(64, 176, 16, 16), Rect2(80, 176, 16, 16)]

# --- végétation de la forêt (mêmes rectangles que les ruines) : [rectangle, enfoncement du pied] ---
const OAK_BIG := [[Rect2(2, 8, 130, 244), 14], [Rect2(2, 264, 130, 244), 14]]
const OAK_MED := [[Rect2(176, 80, 94, 172), 12], [Rect2(176, 336, 94, 172), 12]]
const OAK_SMALL := [[Rect2(312, 166, 50, 86), 8], [Rect2(312, 422, 50, 86), 8]]
const BIRCH := [[Rect2(386, 26, 86, 194), 12], [Rect2(386, 250, 86, 194), 12], [Rect2(480, 76, 62, 144), 10]]
const PINE := [[Rect2(586, 20, 66, 168), 10], [Rect2(586, 212, 66, 168), 10], [Rect2(682, 32, 80, 156), 10], [Rect2(682, 224, 80, 156), 10]]
const BUSHY := [[Rect2(584, 458, 48, 72), 6], [Rect2(652, 454, 44, 72), 6], [Rect2(716, 448, 42, 50), 6], [Rect2(584, 554, 48, 72), 6]]
const DEAD := [[Rect2(836, 32, 58, 156), 8], [Rect2(900, 56, 52, 132), 8]]
const STUMPS := [[Rect2(40, 516, 60, 52), 10], [Rect2(198, 536, 40, 32), 6], [Rect2(326, 540, 28, 30), 6]]
const FERNS := [[Rect2(294, 714, 50, 40), 6], [Rect2(422, 714, 50, 40), 6], [Rect2(366, 706, 40, 28), 4], [Rect2(494, 706, 40, 28), 4]]
const FLOWERS := [[Rect2(102, 650, 20, 48), 3], [Rect2(198, 650, 20, 48), 3], [Rect2(134, 658, 20, 40), 3], [Rect2(326, 650, 18, 22), 2]]
const TALL_GRASS := [[Rect2(2, 672, 28, 30), 3], [Rect2(34, 672, 28, 30), 3], [Rect2(66, 672, 28, 30), 3], [Rect2(162, 768, 28, 32), 3], [Rect2(196, 768, 26, 32), 3]]

const ENTRY_ROWS := [16, 17, 18, 19]   # le chemin arrive de la cascade par le bord est

var map_root: Node2D
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var forest := {}
var water := {}
var path_cells := {}
var pier := {}
var ysort: Node2D
var sol: Node2D

func _initialize() -> void:
	rng.seed = 4242
	noise.seed = 7
	noise.frequency = 0.12
	_masks()
	map_root = Node2D.new()
	map_root.name = "LacMap"
	map_root.set_script(load("res://scenes/maps/map_camera_zoom.gd"))
	map_root.set("music", load("res://assets/audio/musique/lac.wav"))
	map_root.set("camera_bounds", Rect2(0, 0, W * T, H * T))
	_ground()
	_water_layer()
	sol = _own(Node2D.new(), "DetailsSol", map_root)
	ysort = _own(Node2D.new(), "YSortLayer", map_root)
	ysort.y_sort_enabled = true
	_pier()
	_shore_decor()
	_clearing()
	_meadow()
	_trees()
	_mist()
	_bounds()
	_zones()
	var cm := CanvasModulate.new()
	cm.color = Color(0.86, 0.9, 1.0)
	_own(cm, "Brume", map_root)
	var p: Node2D = load("res://scenes/characters/Player.tscn").instantiate()
	p.position = Vector2(38.0, 17.5) * T
	_own(p, "Player", ysort)
	p.add_to_group("Player", true)
	var packed := PackedScene.new()
	print("pack ", packed.pack(map_root), ", save ", ResourceSaver.save(packed, OUT))
	quit()

# =====================================================================================
# Plan : la forêt sur les bords, le lac, le chemin, le ponton
# =====================================================================================

func _masks() -> void:
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var n := noise.get_noise_2d(x, y)
			var band := 3.4 + n * 2.2
			var d := mini(mini(x, W - 1 - x), mini(y, H - 1 - y))
			var entry := x >= W - 4 and ENTRY_ROWS.has(y)
			if d < band and not entry:
				forest[c] = true
	# le lac : une ellipse déformée, et une anse au sud-ouest
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var e := pow((x - 17.0) / 12.5, 2) + pow((y - 10.5) / 7.0, 2)
			var bay := pow((x - 9.0) / 4.5, 2) + pow((y - 15.5) / 3.2, 2)
			var wob := noise.get_noise_2d(x * 1.7, y * 1.7) * 0.25
			if e < 1.0 + wob or bay < 1.0 + wob:
				water[c] = true
				forest.erase(c)
	_smooth()
	# une petite île au milieu (après le lissage, qui la refermerait), 3 × 3 cases
	for y in range(7, 10):
		for x in range(11, 14):
			water.erase(Vector2i(x, y))
	_thicken()
	# le chemin : de la cascade (est) jusqu'au ponton, puis vers la clairière (ouest)
	var shore_x := 21
	var shore_y := 0
	for y in range(H - 1, -1, -1):
		if water.has(Vector2i(shore_x, y)):
			shore_y = y
			break
	_path_line(Vector2(W - 0.5, 17.6), Vector2(30.0, 19.2))
	_path_line(Vector2(30.0, 19.2), Vector2(shore_x, shore_y + 1.6))
	_path_line(Vector2(shore_x, shore_y + 1.6), Vector2(13.0, 21.0))
	_path_line(Vector2(13.0, 21.0), Vector2(6.0, 20.8))
	# le ponton : 4 cases vers le nord, depuis la rive
	for k in 4:
		pier[Vector2i(shore_x, shore_y - k)] = true

## Lisse le contour du lac (règle de la majorité) : moins de marches d'escalier.
func _smooth() -> void:
	for pass_i in 3:
		var next := {}
		for y in H:
			for x in W:
				var c := Vector2i(x, y)
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if water.has(c + Vector2i(dx, dy)):
							n += 1
				if n >= 5:
					next[c] = true
		water = next
	for c in water:
		forest.erase(c)

## Pas de bande d'eau ni de bande de terre d'une seule case (le rivage ne sait pas les dessiner).
func _thicken() -> void:
	var changed := true
	var guard := 0
	while changed and guard < 20:
		changed = false
		guard += 1
		for c in water.keys():
			var ns: bool = not water.has(c + Vector2i.UP) and not water.has(c + Vector2i.DOWN)
			var ew: bool = not water.has(c + Vector2i.LEFT) and not water.has(c + Vector2i.RIGHT)
			if ns or ew:
				water.erase(c)
				changed = true
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				var c := Vector2i(x, y)
				if water.has(c):
					continue
				if (water.has(c + Vector2i.UP) and water.has(c + Vector2i.DOWN)) or (water.has(c + Vector2i.LEFT) and water.has(c + Vector2i.RIGHT)):
					water[c] = true
					forest.erase(c)
					changed = true

func _path_line(a: Vector2, b: Vector2) -> void:
	var steps := int(a.distance_to(b) * 3) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps) + Vector2(0, sin(i * 0.4) * 0.3)
		for d in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0)]:
			var c := Vector2i(floor(p.x + d.x - 0.5), floor(p.y + d.y - 0.5))
			if c.x >= 0 and c.x < W and c.y >= 0 and c.y < H and not water.has(c):
				path_cells[c] = true
				forest.erase(c)

func walkable(c: Vector2i) -> bool:
	if pier.has(c):
		return true
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H and not forest.has(c) and not water.has(c)

# =====================================================================================
# Sol, eau
# =====================================================================================

func _ground() -> void:
	var ground := TileMapLayer.new()
	ground.tile_set = load("res://resources/tilesets/foret_sol.tres")
	_own(ground, "Ground", map_root)
	var all: Array[Vector2i] = []
	for y in H:
		for x in W:
			all.append(Vector2i(x, y))
	ground.set_cells_terrain_connect(all, 0, 1, false)
	_crop(ground)
	var path := TileMapLayer.new()
	path.tile_set = load("res://resources/tilesets/foret_chemins.tres")
	_own(path, "Path", map_root)
	var cells: Array[Vector2i] = []
	cells.assign(path_cells.keys())
	path.set_cells_terrain_connect(cells, 0, 0, false)
	_crop(path)

func _crop(l: TileMapLayer) -> void:
	for c in l.get_used_cells():
		if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
			l.erase_cell(c)

func _water_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var a := TileSetAtlasSource.new()
	a.texture = load(LAKE)
	a.texture_region_size = Vector2i(T, T)
	for base in [GRASS_ROW]:
		for r in 3:
			for c in 5:
				var at := Vector2i(c, base + r)
				a.create_tile(at)
				a.set_tile_animation_columns(at, 0)
				a.set_tile_animation_separation(at, Vector2i(4, 0))
				a.set_tile_animation_frames_count(at, 4)
				a.set_tile_animation_speed(at, 3.0)
	ts.add_source(a, 0)
	ResourceSaver.save(ts, TILESET_OUT)
	return load(TILESET_OUT)

func _water_layer() -> void:
	var l := TileMapLayer.new()
	l.tile_set = _water_tileset()
	_own(l, "Eau", map_root)
	for c: Vector2i in water:
		var land := func(d: Vector2i) -> bool: return not water.has(c + d)
		var n: bool = land.call(Vector2i.UP)
		var s: bool = land.call(Vector2i.DOWN)
		var w: bool = land.call(Vector2i.LEFT)
		var e: bool = land.call(Vector2i.RIGHT)
		var t := E_C
		if n and w: t = E_TL
		elif n and e: t = E_TR
		elif s and w: t = E_BL
		elif s and e: t = E_BR
		elif n: t = E_T
		elif s: t = E_B
		elif w: t = E_L
		elif e: t = E_R
		elif land.call(Vector2i(-1, -1)): t = I_TL
		elif land.call(Vector2i(1, -1)): t = I_TR
		elif land.call(Vector2i(-1, 1)): t = I_BL
		elif land.call(Vector2i(1, 1)): t = I_BR
		l.set_cell(c, 0, Vector2i(t.x, GRASS_ROW + t.y))

# =====================================================================================
# Décor
# =====================================================================================

func _sprite(parent: Node, nm: String, path: String, region: Rect2, foot: Vector2, pad := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.offset = Vector2(-round(region.size.x / 2.0), -region.size.y + pad)
	s.position = foot.round()
	var i := 1
	var name := nm
	while parent.has_node(name):
		i += 1
		name = "%s%d" % [nm, i]
	return _own(s, name, parent)

func _pier() -> void:
	var cells := pier.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	for k in cells.size():
		var c: Vector2i = cells[k]
		var key := "ponton_bout_nord" if k == cells.size() - 1 else "ponton_ns"
		_sprite(sol, "Ponton", PROPS, P[key], Vector2(c) * T + Vector2(16, 32))
	var tip: Vector2i = cells[-1]
	_sprite(ysort, "Poteau", PROPS, P["poteau_1"], Vector2(tip) * T + Vector2(-2, 30), 2)
	_sprite(ysort, "Poteau", PROPS, P["poteau_2"], Vector2(tip) * T + Vector2(34, 30), 2)
	_sprite(sol, "Barque", PROPS, P["barque_amarree"], Vector2(tip) * T + Vector2(64, 40))
	var base: Vector2i = cells[0]
	_sprite(ysort, "FiletPeche", PROPS, P["filet_peche"], Vector2(base) * T + Vector2(-60, 64), 4)

func _shore_decor() -> void:
	for c: Vector2i in water:
		if pier.has(c) or (pier.has(c + Vector2i.LEFT) or pier.has(c + Vector2i.RIGHT)):
			continue
		var shore := false
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not water.has(c + d):
				shore = true
		if shore:
			if rng.randf() < 0.28:
				var key: String = ["roseaux_petit", "roseaux_moyen", "roseaux_grand"][rng.randi() % 3]
				var s := _sprite(ysort, "Roseaux", PROPS, P[key], Vector2(c) * T + Vector2(16 + rng.randf_range(-6, 6), 30), 2)
				s.flip_h = rng.randf() < 0.5
		elif rng.randf() < 0.07:
			var s := Sprite2D.new()
			s.texture = load(PROPS)
			s.region_enabled = true
			s.region_rect = LILIES[rng.randi() % LILIES.size()]
			s.position = Vector2(c) * T + Vector2(rng.randf_range(8, 24), rng.randf_range(8, 24))
			_own(s, "Nenuphar%d" % sol.get_child_count(), sol)
	# rochers dans l'eau, loin des bords
	var placed := 0
	for c: Vector2i in water.keys():
		if placed >= 4:
			break
		var deep := true
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if not water.has(c + Vector2i(dx, dy)):
					deep = false
		var near_pier := false
		for q: Vector2i in pier:
			if absi(q.x - c.x) <= 4 and absi(q.y - c.y) <= 3:
				near_pier = true
		if deep and not near_pier and rng.randf() < 0.05:
			var key: String = ["rocher_grand", "rocher_large", "rocher_petit"][placed % 3]
			_sprite(ysort, "Rocher", PROPS, P[key], Vector2(c) * T + Vector2(16, 30), 6)
			placed += 1
	# sur la rive : bois flotté, pierres moussues, un tronc mort qui trempe dans l'eau
	var shore_land: Array[Vector2i] = []
	for c: Vector2i in water:
		for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if walkable(c + d) and not path_cells.has(c + d):
				shore_land.append(c + d)
	shore_land.shuffle()
	for i in mini(6, shore_land.size()):
		var key := "bois_flotte" if i % 2 == 0 else "pierres_moussues"
		_sprite(sol, "Rive", PROPS, P[key], Vector2(shore_land[i]) * T + Vector2(16, 28))
	_sprite(ysort, "TroncMort", PROPS, P["tronc_mort"], Vector2(4.6, 13.2) * T, 4)
	# le panneau à l'entrée du lac (on peut le lire)
	var sign_at := Vector2(36.5, 15.9) * T
	_sprite(ysort, "Panneau", PROPS, P["panneau_bois"], sign_at, 2)
	var read := Node2D.new()
	read.set_script(load("res://scenes/maps/point_inspection.gd"))
	read.set("conversation", load("res://resources/dialogues/lac/panneau_lac.tres"))
	read.set("conversation_after", load("res://resources/dialogues/lac/panneau_lac.tres"))
	read.set("sparkle_at", Vector2(0, -36))
	read.position = sign_at + Vector2(0, 4)
	_own(read, "LirePanneau", ysort)

## La clairière d'Aldric, à l'ouest : des souches fraîchement coupées, des bûches empilées.
func _clearing() -> void:
	var spots := [Vector2(5.0, 19.6), Vector2(8.4, 22.2), Vector2(3.6, 22.6), Vector2(10.6, 19.0)]
	for i in spots.size():
		var t: Array = STUMPS[i % STUMPS.size()]
		_sprite(ysort, "Souche", VEG, t[0], spots[i] * T, t[1])

## Herbes hautes, fougères, fleurs sur les clairières (jamais sur le chemin).
func _meadow() -> void:
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if not walkable(c) or path_cells.has(c) or pier.has(c) or x >= W - 3:
				continue
			var r := rng.randf()
			var t: Array = []
			if r < 0.10: t = TALL_GRASS[rng.randi() % TALL_GRASS.size()]
			elif r < 0.15: t = FERNS[rng.randi() % FERNS.size()]
			elif r < 0.19: t = FLOWERS[rng.randi() % FLOWERS.size()]
			if not t.is_empty():
				var s := _sprite(ysort, "Herbe", VEG, t[0], (Vector2(c) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.5, 0.95))) * T, t[1])
				s.flip_h = rng.randf() < 0.5

func _trees() -> void:
	var trunks: Array[Vector2] = []
	var cells := forest.keys()
	cells.shuffle()
	for c: Vector2i in cells:
		var p := Vector2(c) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.4, 0.9))
		var near := false
		for q in trunks:
			if q.distance_squared_to(p) < 2.4:
				near = true
				break
		if near:
			continue
		# près du chemin et de la rive, des arbres plus petits pour ne pas masquer le passage :
		# juste au-dessus (ils le cachent de leur tronc) ou juste en dessous (de leur feuillage)
		var open_below := walkable(c + Vector2i(0, 1)) or walkable(c + Vector2i(0, 2))
		for dy in range(1, 5):
			if walkable(c - Vector2i(0, dy)):
				open_below = true
		var t: Array
		if open_below:
			t = (BUSHY + OAK_SMALL)[rng.randi() % (BUSHY.size() + OAK_SMALL.size())]
		else:
			var r := rng.randf()
			if r < 0.22: t = OAK_BIG[rng.randi() % OAK_BIG.size()]
			elif r < 0.42: t = OAK_MED[rng.randi() % OAK_MED.size()]
			elif r < 0.62: t = PINE[rng.randi() % PINE.size()]
			elif r < 0.74: t = BIRCH[rng.randi() % BIRCH.size()]
			elif r < 0.9: t = BUSHY[rng.randi() % BUSHY.size()]
			else: t = DEAD[rng.randi() % DEAD.size()]
		_sprite(ysort, "Arbre", VEG, t[0], p * T, t[1]).flip_h = rng.randf() < 0.5
		trunks.append(p)
	# l'île : un arbre mort et des roseaux
	_sprite(ysort, "ArbreIle", VEG, DEAD[0][0], Vector2(12.5, 9.2) * T, DEAD[0][1])

## Des nappes de brume qui dérivent lentement sur l'eau.
func _mist() -> void:
	var spots := [Vector2(10, 6), Vector2(20, 8), Vector2(26, 12), Vector2(14, 14), Vector2(8, 11)]
	for i in spots.size():
		var s := Sprite2D.new()
		s.texture = load(PROPS)
		s.region_enabled = true
		s.region_rect = P["brume_96"] if i % 2 == 0 else P["brume_64"]
		s.position = (spots[i] as Vector2) * T
		s.scale = Vector2(2.0, 2.0)
		s.modulate = Color(1, 1, 1, 0.55)
		s.z_index = 2
		s.set_script(load("res://scenes/maps/brume.gd"))
		s.set("phase", i * 1.3)
		_own(s, "Brume%d" % (i + 1), map_root)

func _bounds() -> void:
	var b := _own(StaticBody2D.new(), "Bords", map_root)
	var n := 0
	for y in range(-1, H + 1):
		var x := -1
		while x <= W:
			if walkable(Vector2i(x, y)) or (x == W and ENTRY_ROWS.has(y)):
				x += 1
				continue
			var x0 := x
			while x <= W and not walkable(Vector2i(x, y)) and not (x == W and ENTRY_ROWS.has(y)):
				x += 1
			_shape(b, "B%d" % n, Vector2((x0 + x) / 2.0 * T, (y + 0.5) * T), Vector2((x - x0) * T, T))
			n += 1
	_shape(b, "B%d" % n, Vector2((W + 1.5) * T, 17.5 * T), Vector2(T, 6 * T))

func _zones() -> void:
	var m := _own(Marker2D.new(), "SpawnFromCascade", map_root) as Marker2D
	m.position = Vector2(38.0, 17.5) * T
	var a := Area2D.new()
	a.set_script(load("res://scenes/maps/map_exit.gd"))
	a.set("target_scene", "res://scenes/maps/ForestCascadeMap.tscn")
	a.set("spawn_point", "SpawnFromLac")
	_own(a, "ExitToCascade", map_root)
	a.position = Vector2(W * T + 8, 17.5 * T)
	_shape(a, "Forme", Vector2.ZERO, Vector2(24, 4 * T))
	var enc := Area2D.new()
	enc.set_script(load("res://scenes/maps/encounter_zone.gd"))
	var monsters: Array[MonsterData] = [load("res://resources/monsters/goule.tres"), load("res://resources/monsters/zombie.tres"),
		load("res://resources/monsters/gobelin_aile.tres")]
	enc.set("monsters", monsters)
	enc.set("battle_background", load("res://assets/battle_backgrounds/battle_lac.png"))
	enc.set("encounter_rate", 0.03)
	_own(enc, "EncounterZone", map_root)
	_shape(enc, "Forme", Vector2(17 * T, 18 * T), Vector2(30 * T, 10 * T))

func _shape(parent: Node, nm: String, pos: Vector2, size: Vector2) -> void:
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	c.shape = r
	c.position = pos
	_own(c, nm, parent)

func _own(n: Node, nm: String, parent: Node) -> Node:
	n.name = nm
	parent.add_child(n)
	n.owner = map_root
	return n
