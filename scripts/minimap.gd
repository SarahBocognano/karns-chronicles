extends CanvasLayer

## Mini-carte (autoload « MiniCarte »), en haut à gauche de l'écran, sur les cartes extérieures.
## Les données de chaque carte (assets/ui/minimap/<NomDeLaCarte>.png) sont préparées par
## tools/bake_minimaps.tscn ; ici on les peint en aplats de couleur, façon carte de JRPG,
## et on y place Zylrak (flèche dorée), Ysolde (point bleu) et les quêtes en cours (losange doré).
## Touche M : afficher / masquer. Masquée pendant les dialogues, les scènes et les combats.

const DATA_DIR := "res://assets/ui/minimap/"
## Pixels d'écran par case de la carte.
const K := 4
const MARGIN := Vector2(26, 22)
## Cadre : celui des boîtes de dialogue (bronze, pierres bleues), recomposé à la taille de la carte.
const DIALOG_FRAME := preload("res://assets/ui/image_ad298c1e-removebg-preview.png")
## Le cadre est assemblé en taille d'origine, puis réduit de moitié.
const FRAME_SCALE := 0.5
## Débord du cadre autour de la carte, à l'écran (la bordure recouvre un peu le bord de la carte).
const FRAME_PAD := Vector2(9, 9)

enum { GRASS, PATH, STONE, FOREST, WATER, BUILT }
const PALETTE := {
	GRASS: Color("#86b24e"), PATH: Color("#cfae72"), STONE: Color("#a19c94"),
	FOREST: Color("#2e5427"), WATER: Color("#4b86b4"), BUILT: Color("#6d5a4c"),
}
const EDGE := Color("#1d2a1a")
const GOLD := Color("#f2c14e")
const OUTLINE := Color("#1a1410")
const ALLY := Color("#a8dcff")

var shown_by_player := true
var _scene: Node
var _world_rect := Rect2()   # emprise de la carte, en pixels du monde
var _cell := 32.0
var _root: Control
var _map: TextureRect
var _marks: Control
var _frame: TextureRect
var _cache := {}
var _frame_cache := {}

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.position = MARGIN
	_root.modulate.a = 0.0
	add_child(_root)
	_map = TextureRect.new()
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_map)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	_root.add_child(_marks)
	_frame = TextureRect.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		shown_by_player = not shown_by_player

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_load_scene(scene)
	var want := _map.texture != null and shown_by_player and not _hidden_by_game()
	_root.modulate.a = move_toward(_root.modulate.a, 1.0 if want else 0.0, delta * 6.0)
	if _root.modulate.a > 0.0:
		_marks.queue_redraw()

func _hidden_by_game() -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	var st := get_node_or_null("/root/SceneTransition")
	return (pd and pd.controls_locked) or (st and st.in_battle)

# --- Carte ---

func _load_scene(scene: Node) -> void:
	_map.texture = null
	if scene == null:
		return
	var path: String = DATA_DIR + scene.name + ".png"
	var ground := scene.get_node_or_null("Ground") as TileMapLayer
	if ground == null or not ResourceLoader.exists(path):
		return
	var used := ground.get_used_rect()
	var ts := Vector2(ground.tile_set.tile_size) * ground.scale
	_cell = ts.x
	_world_rect = Rect2(ground.global_position + Vector2(used.position) * ts, Vector2(used.size) * ts)
	if not _cache.has(path):
		var data: Image = (load(path) as Texture2D).get_image()
		if data.is_compressed():
			data.decompress()
		data.convert(Image.FORMAT_RGBA8)
		_cache[path] = ImageTexture.create_from_image(_paint(data))
	_map.texture = _cache[path]
	_map.size = _map.texture.get_size()
	_marks.size = _map.size
	var frame_size := Vector2i(_map.size + FRAME_PAD * 2.0)
	if not _frame_cache.has(frame_size):
		_frame_cache[frame_size] = ImageTexture.create_from_image(_build_frame(frame_size))
	_frame.texture = _frame_cache[frame_size]
	_frame.position = -FRAME_PAD
	_frame.size = Vector2(frame_size)

## Peint la carte : chaque case reçoit la couleur de sa catégorie, avec un contour sombre
## entre ce qui est praticable et ce qui ne l'est pas.
func _paint(data: Image) -> Image:
	var w := data.get_width()
	var h := data.get_height()
	var cls := PackedInt32Array()
	cls.resize(w * h)
	for y in h:
		for x in w:
			cls[y * w + x] = _classify(data.get_pixel(x, y))
	# Lissage : une case isolée prend la catégorie majoritaire autour d'elle.
	var smooth := cls.duplicate()
	for y in h:
		for x in w:
			var free := _free(data, x, y)
			var counts := {}
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := clampi(x + dx, 0, w - 1)
					var ny := clampi(y + dy, 0, h - 1)
					if _free(data, nx, ny) == free:
						var c := cls[ny * w + nx]
						counts[c] = counts.get(c, 0) + (2 if dx == 0 and dy == 0 else 1)
			var best := cls[y * w + x]
			for c in counts:
				if counts[c] > counts.get(best, 0):
					best = c
			smooth[y * w + x] = best
	var out := Image.create(w * K, h * K, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := smooth[y * w + x]
			var col: Color = PALETTE[c]
			if c == BUILT:
				col = col.lerp(data.get_pixel(x, y), 0.35)   # toits rouges, pierre grise, falaise ocre
				col.a = 1.0
			out.fill_rect(Rect2i(x * K, y * K, K, K), col)
			if _free(data, x, y):
				if x > 0 and not _free(data, x - 1, y):
					out.fill_rect(Rect2i(x * K, y * K, 1, K), EDGE)
				if x < w - 1 and not _free(data, x + 1, y):
					out.fill_rect(Rect2i(x * K + K - 1, y * K, 1, K), EDGE)
				if y > 0 and not _free(data, x, y - 1):
					out.fill_rect(Rect2i(x * K, y * K, K, 1), EDGE)
				if y < h - 1 and not _free(data, x, y + 1):
					out.fill_rect(Rect2i(x * K, y * K + K - 1, K, 1), EDGE)
	return out

func _free(data: Image, x: int, y: int) -> bool:
	return data.get_pixel(x, y).a > 0.5

func _classify(c: Color) -> int:
	var hue := c.h * 360.0
	if c.a > 0.5:
		if c.s < 0.22:
			return STONE
		if hue < 55.0 or hue > 330.0:
			return PATH
		return GRASS
	if hue >= 170.0 and hue <= 260.0 and c.s > 0.2:
		return WATER
	if hue >= 65.0 and hue < 170.0 and c.s > 0.36:
		return FOREST
	return BUILT

# --- Marqueurs ---

func _to_map(world: Vector2) -> Vector2:
	return (world - _world_rect.position) / _cell * K

func _draw_marks() -> void:
	if _scene == null or _map.texture == null:
		return
	# Quêtes : les PNJ qui ont leur flèche dorée allumée.
	for marker in _scene.find_children("QuestMarker", "", true, false):
		if marker.is_visible_in_tree():
			var p := _to_map(marker.get_parent().global_position)
			_marks.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(4, 0), p + Vector2(0, 5), p + Vector2(-4, 0)]), OUTLINE)
			_marks.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3.5), p + Vector2(2.5, 0), p + Vector2(0, 3.5), p + Vector2(-2.5, 0)]), GOLD)
	for ally in get_tree().get_nodes_in_group("Compagnon"):
		if ally.is_inside_tree() and not ally.is_queued_for_deletion():
			var p := _to_map(ally.global_position)
			_marks.draw_circle(p, 3.0, OUTLINE)
			_marks.draw_circle(p, 2.0, ALLY)
	var player := _player()
	if player:
		var p := _to_map(player.global_position)
		var pd := get_node_or_null("/root/PlayerData")
		var dir := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(pd.facing if pd else "down", Vector2.DOWN) as Vector2
		var side := Vector2(-dir.y, dir.x)
		var tri := PackedVector2Array([p + dir * 6.0, p - dir * 4.0 + side * 5.0, p - dir * 4.0 - side * 5.0])
		var big := PackedVector2Array([p + dir * 8.5, p - dir * 5.5 + side * 7.0, p - dir * 5.5 - side * 7.0])
		_marks.draw_colored_polygon(big, OUTLINE)
		_marks.draw_colored_polygon(tri, GOLD)

func _player() -> Node2D:
	for n in get_tree().get_nodes_in_group("Player"):
		if n is CharacterBody2D:
			return n
	return null

# --- Cadre ---

## Assemble le cadre des dialogues à la taille voulue (pixels d'écran) : on reprend la moitié
## basse du cadre d'origine et son reflet (la moitié haute porte l'onglet du nom), puis on pose
## les quatre coins, des bords droits répétés, et la pierre bleue au milieu en haut et en bas.
## Le fond bleu nuit du cadre devient transparent : seule la bordure recouvre la carte.
func _build_frame(screen_size: Vector2i) -> Image:
	var src := DIALOG_FRAME.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var half := src.get_region(Rect2i(4, 206, 604, 142))
	var top := half.duplicate() as Image
	top.flip_y()
	var f := Image.create(604, 284, false, Image.FORMAT_RGBA8)
	f.blit_rect(top, Rect2i(0, 0, 604, 142), Vector2i(0, 0))
	f.blit_rect(half, Rect2i(0, 0, 604, 142), Vector2i(0, 142))
	const C := 70     # coins (volutes et pierres)
	const SEG := 40   # morceau de bord droit, répété
	var t := Vector2i(Vector2(screen_size) / FRAME_SCALE)
	var out := Image.create(t.x, t.y, false, Image.FORMAT_RGBA8)
	for x in range(C, t.x - C, SEG):
		var w := mini(SEG, t.x - C - x)
		out.blit_rect(f, Rect2i(150, 0, w, C), Vector2i(x, 0))
		out.blit_rect(f, Rect2i(150, 284 - C, w, C), Vector2i(x, t.y - C))
	for y in range(C, t.y - C, SEG):
		var h := mini(SEG, t.y - C - y)
		out.blit_rect(f, Rect2i(0, 60, C, h), Vector2i(0, y))
		out.blit_rect(f, Rect2i(604 - C, 60, C, h), Vector2i(t.x - C, y))
	out.blit_rect(f, Rect2i(0, 0, C, C), Vector2i(0, 0))
	out.blit_rect(f, Rect2i(604 - C, 0, C, C), Vector2i(t.x - C, 0))
	out.blit_rect(f, Rect2i(0, 284 - C, C, C), Vector2i(0, t.y - C))
	out.blit_rect(f, Rect2i(604 - C, 284 - C, C, C), Vector2i(t.x - C, t.y - C))
	if t.x > 2 * C + 64:
		out.blit_rect(f, Rect2i(270, 0, 64, C), Vector2i(t.x / 2 - 32, 0))
		out.blit_rect(f, Rect2i(270, 284 - C, 64, C), Vector2i(t.x / 2 - 32, t.y - C))
	for y in t.y:
		for x in t.x:
			var c := out.get_pixel(x, y)
			if c.a > 0.0 and c.b >= c.r and c.v < 0.3:
				out.set_pixel(x, y, Color(c, 0.0))
	out.resize(screen_size.x, screen_size.y, Image.INTERPOLATE_LANCZOS)
	return out
