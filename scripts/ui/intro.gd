extends Node2D

## Introduction d'une nouvelle partie (après « Nouvelle partie » sur l'écran titre), à la manière des vieux RPG 2D : un prologue qui
## s'écrit lettre par lettre, sur les vraies cartes du jeu filmées en plans lents (bandes noires
## de cinéma). Il raconte la Bête que les Yrenn ont scellée dans quatre temples il y a mille ans,
## le retour de la lune noire et des créatures de l'Outre-Lune, le chariot, puis l'arrivée de
## Zylrak au village ; enfin les quatre symboles des Yrenn.
## Entrée ou Échap : passer l'intro. Ensuite, la partie commence dans l'auberge.
##
## Les cartes sont chargées sans leur logique (musique, PNJ, rencontres, scènes, sorties) :
## seuls le décor, le vent, la brume et le sceau restent animés.

const MUSIC := preload("res://assets/audio/musique/ruines.wav")
const PLAYER_SCENE := preload("res://scenes/characters/Player.tscn")
const MAPS := {
	"parvis": "res://scenes/maps/RuinesParvisMap.tscn",
	"lisiere": "res://scenes/maps/ForestMap.tscn",
	"chariot": "res://scenes/maps/ForestChariotMap.tscn",
	"village": "res://scenes/maps/VillageV2Map.tscn",
}
## Scripts de logique retirés des cartes (le reste du décor est gardé tel quel).
const STRIPPED_SCRIPTS := ["map_camera_zoom.gd", "npc_dialogue.gd", "pnj_child_blond_hair.gd", "fragment_yrenn.gd"]
const BAR := 140.0          # hauteur des bandes noires
const T := 32.0             # une case
const ZOOM := 3.0
const CREAM := Color(0.95, 0.91, 0.82)
const GOLD := Color(0.86, 0.70, 0.40)

var _stage: Node2D
var _cam: Camera2D
var _map: Node2D
var _eyes_layer: CanvasLayer
var _fade: ColorRect
var _bars: Array[ColorRect] = []
var _caption: Label
var _center: Label
var _skip_hint: Label
var _leaving := false
var _pan_tween: Tween

func _ready() -> void:
	for p in MAPS.values():
		ResourceLoader.load_threaded_request(p)
	_stage = Node2D.new()
	add_child(_stage)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(_cam)
	_cam.make_current()
	_eyes_layer = CanvasLayer.new()
	_eyes_layer.follow_viewport_enabled = true
	add_child(_eyes_layer)
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	# La fenêtre peut être plus haute que 16:9 : tout se cale sur sa taille réelle.
	var screen := get_viewport_rect().size
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.size = Vector2(screen.x, BAR)
		b.position = Vector2(0, 0 if top else screen.y - BAR)
		ui.add_child(b)
		_bars.append(b)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = screen
	ui.add_child(_fade)
	_caption = _text_label(38, Rect2(160, screen.y - BAR - 10, screen.x - 320, BAR))
	ui.add_child(_caption)
	_center = _text_label(46, Rect2(200, screen.y / 2.0 - 200, screen.x - 400, 400))
	ui.add_child(_center)
	_skip_hint = UiKit.label(Tactile.hint("Entrée : passer"), 20, Color(1, 1, 1, 0.4))
	_skip_hint.position = Vector2(screen.x - 220, screen.y - 40)
	_skip_hint.modulate.a = 0.0
	ui.add_child(_skip_hint)
	Musique.set_button_visible(false)
	PlayerData.controls_locked = true
	Musique.play(MUSIC, 2.0)
	_play.call_deferred()

func _text_label(size: int, rect: Rect2) -> Label:
	var l := UiKit.label("", size, CREAM)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = rect.position
	l.size = rect.size
	l.visible_ratio = 0.0
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave(0.5)

# --- Déroulé ---

func _play() -> void:
	create_tween().tween_property(_skip_hint, "modulate:a", 1.0, 1.5).set_delay(1.0)
	# Prologue, sur fond noir : la Bête (son nom, Karn, n'est révélé qu'à la fin du jeu)
	await _wait(1.0)
	await _say_center("Il y a mille ans, par une nuit de lune noire, une effroyable créature fit son apparition sur les montagnes de Karn.", 8.4)
	await _say_center("Ni homme, ni bête, certains disent qu'elle avait une apparence de loup sur deux pattes... et les morts se relevaient sur son passage.", 9.6)
	# Les temples-sceaux : du ciel d'aube jusqu'à la porte scellée
	_show_map("parvis", Color(0.92, 0.88, 1.0))
	_frame(Vector2(14, 3.5) * T)
	await _fade_to(0.0, 1.2)
	_pan(Vector2(14, 9.6) * T, 25.0)
	await _say("Les Yrenn, peuple d'elfes magiciens aujourd'hui disparus, furent appelés pour terrasser la Bête.", 7.4)
	await _say("Ne réussissant pas à la détruire totalement, ils fragmentèrent son âme et la scellèrent dans quatre temples.", 8.2)
	await _say("Pour renforcer les sceaux, ils y lièrent leurs propres âmes. Des centaines d'années passèrent, et le peuple des Yrenn disparut.", 9.4)
	await _fade_to(1.0, 1.0)
	# La forêt, la nuit : des yeux rouges entre les arbres
	_show_map("lisiere", Color(0.30, 0.36, 0.62))
	_frame(Vector2(9.5, 16.0) * T)
	for e in [Vector2(3.2, 18.6), Vector2(8.6, 19.8), Vector2(16.4, 19.2), Vector2(23.7, 18.4), Vector2(27.6, 19.6), Vector2(12.2, 20.4), Vector2(1.6, 12.6)]:
		_eyes(e * T)
	await _fade_to(0.0, 1.2)
	_pan(Vector2(20.5, 16.0) * T, 14.0)
	await _say("Mille ans plus tard, la lune noire est revenue, et avec elle les créatures de la Bête.", 6.6)
	await _say("Passant par les failles de l'Outre-Lune, elles rôdent de nouveau dans les forêts du sud...", 7.0)
	await _fade_to(1.0, 1.0)
	# Le chariot du marchand, renversé : les villages se barricadent
	_show_map("chariot", Color(0.58, 0.56, 0.78))
	_frame(Vector2(9.6, 12.4) * T)
	await _fade_to(0.0, 1.2)
	_pan(Vector2(12.6, 11.6) * T, 9.5)
	await _say("Dans les villages, on barricade les portes avant la nuit, on s'enferme en espérant qu'une nouvelle journée s'offrira à eux.", 9.0)
	await _fade_to(1.0, 1.0)
	# Le village au crépuscule (plan large) ; Zylrak arrive par la route de la forêt
	_show_map("village", Color(1.0, 0.76, 0.66))
	var zylrak := _add_zylrak(_at(0.552, 0.93))
	_frame(_at(0.552, 0.70), 2.2)
	await _fade_to(0.0, 1.2)
	_pan(_at(0.54, 0.58), 12.0)
	if is_instance_valid(zylrak):
		zylrak.walk_to(_at(0.552, 0.66), 45.0)
	await _say("Un soir, un étranger arrive par la route de la forêt au village d'Eclatvin, pour une halte après un long voyage.", 8.4)
	await _say("« Zylrak, Ashwarden de l'Ordre des Cendres. »", 3.6, GOLD)
	await _fade_to(1.0, 1.0)
	_clear_map()
	_frame(Vector2.ZERO)
	# Les quatre symboles des Yrenn s'allument un à un, puis l'écran titre
	await _symbols()
	_leave(0.0)

## Attente liée à l'intro (s'arrête net si on passe l'intro : pas d'erreur de reprise).
func _wait(seconds: float) -> void:
	await create_tween().tween_interval(seconds).finished

func _fade_to(alpha: float, seconds: float) -> void:
	await create_tween().tween_property(_fade, "color:a", alpha, seconds).finished

func _pan(to: Vector2, seconds: float) -> void:
	_pan_tween = create_tween()
	_pan_tween.tween_property(_cam, "position", to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Place la caméra pour un nouveau plan (en arrêtant le mouvement du plan précédent).
func _frame(pos: Vector2, zoom: float = ZOOM) -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_cam.position = pos
	_cam.zoom = Vector2(zoom, zoom)

## Légende en bas de l'écran : elle s'écrit lettre par lettre, reste, puis s'efface.
func _say(text: String, seconds: float, color := CREAM) -> void:
	await _type(_caption, text, seconds, color)

## Texte au centre de l'écran noir (prologue).
func _say_center(text: String, seconds: float) -> void:
	await _type(_center, text, seconds, CREAM)

func _type(l: Label, text: String, seconds: float, color: Color) -> void:
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.modulate.a = 1.0
	l.visible_ratio = 0.0
	var typing := minf(text.length() * 0.035, seconds * 0.6)
	var tw := create_tween()
	tw.tween_property(l, "visible_ratio", 1.0, typing)
	tw.tween_interval(maxf(0.2, seconds - typing - 0.5))
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	await tw.finished

# --- Cartes ---

func _show_map(key: String, tint: Color) -> void:
	_clear_map()
	var scene: PackedScene = ResourceLoader.load_threaded_get(MAPS[key])
	_map = scene.instantiate()
	_strip(_map)
	_map.set_script(null)
	var mod := CanvasModulate.new()
	mod.color = tint
	_map.add_child(mod)
	_stage.add_child(_map)

func _clear_map() -> void:
	for c in _eyes_layer.get_children():
		c.queue_free()
	if _map:
		_map.queue_free()
		_map = null

## Retire de la carte tout ce qui joue : Zylrak, zones (sorties, rencontres, messages), scènes,
## et la logique des PNJ. Le décor reste.
func _strip(node: Node) -> void:
	for c in node.get_children():
		# (dans le village, le calque du décor est lui aussi dans le groupe « Player » : on ne retire que Zylrak)
		if c is Area2D or (c is CharacterBody2D and c.is_in_group("Player")) or c.name in ["Scenario", "Enigme"]:
			node.remove_child(c)
			c.free()
			continue
		var s: Script = c.get_script()
		if s and s.resource_path.get_file() in STRIPPED_SCRIPTS:
			c.set_script(null)
		_strip(c)

## Position dans la carte en fractions de sa taille (0,0 : coin haut gauche ; 1,1 : coin bas droit).
func _at(fx: float, fy: float) -> Vector2:
	var ground := _map.get_node("Ground") as TileMapLayer
	var used := ground.get_used_rect()
	var ts := Vector2(ground.tile_set.tile_size) * ground.scale
	var origin := ground.position + Vector2(used.position) * ts
	return origin + Vector2(used.size) * ts * Vector2(fx, fy)

## Zylrak, sans ses commandes ni sa caméra : il ne bouge que par walk_to.
func _add_zylrak(pos: Vector2) -> Node2D:
	PlayerData.next_spawn_point = ""
	PlayerData.facing = "up"
	var z: CharacterBody2D = PLAYER_SCENE.instantiate()
	z.position = pos
	z.scripted = true
	(z.get_node("Camera2D") as Camera2D).enabled = false
	var ysort := _map.get_node_or_null("YSortLayer")
	(ysort if ysort else _map).add_child(z)
	z.remove_from_group("Player")
	_cam.make_current()
	return z

## Une paire d'yeux rouges qui s'ouvrent et se ferment dans le noir (hors de la teinte de nuit).
func _eyes(pos: Vector2) -> void:
	var eyes := Node2D.new()
	eyes.position = pos
	for dx in [-2.5, 2.5]:
		var glow := ColorRect.new()
		glow.color = Color(1.0, 0.15, 0.1, 0.35)
		glow.position = Vector2(dx - 2, -2)
		glow.size = Vector2(4, 4)
		eyes.add_child(glow)
		var dot := ColorRect.new()
		dot.color = Color(1.0, 0.25, 0.15)
		dot.position = Vector2(dx - 1, -1)
		dot.size = Vector2(2, 2)
		eyes.add_child(dot)
	eyes.modulate.a = 0.0
	_eyes_layer.add_child(eyes)
	var tw := create_tween().set_loops()
	tw.tween_interval(randf_range(0.2, 2.2))
	tw.tween_property(eyes, "modulate:a", 1.0, 0.25)
	tw.tween_interval(randf_range(1.0, 2.6))
	tw.tween_property(eyes, "modulate:a", 0.0, 0.12)
	tw.tween_interval(randf_range(0.6, 1.8))

## Les quatre symboles gravés s'allument un à un sur fond noir, puis un éclat blanc.
func _symbols() -> void:
	var ui := _fade.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 90)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var screen := get_viewport_rect().size
	row.size = Vector2(screen.x, 200)
	row.position = Vector2(0, screen.y / 2.0 - 100)
	ui.add_child(row)
	var icons: Array[TextureRect] = []
	for s in ["epee", "lune", "flamme", "loup"]:   # pas dans l'ordre de l'énigme
		var icon := TextureRect.new()
		icon.texture = FragmentYrenn.icon_for(s)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(144, 144)
		icon.modulate = Color(0.25, 0.25, 0.3, 0.0)
		row.add_child(icon)
		icons.append(icon)
	await _wait(0.6)
	for icon in icons:
		var tw := create_tween()
		tw.tween_property(icon, "modulate", Color(1.6, 1.8, 2.2, 1.0), 0.35)
		tw.tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.5)
		await _wait(0.7)
	await _wait(1.4)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = get_viewport_rect().size
	ui.add_child(flash)
	await create_tween().tween_property(flash, "color:a", 1.0, 0.6).finished

## Début de la partie (fondu au noir si on passe l'intro).
func _leave(fade: float) -> void:
	if _leaving:
		return
	_leaving = true
	if fade > 0.0:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, fade)
		await tw.finished
	Musique.set_button_visible(true)
	_fade.color.a = 1.0
	Sauvegarde.begin_adventure()
