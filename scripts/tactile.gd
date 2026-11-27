extends CanvasLayer

## Contrôles tactiles (téléphone, tablette) : une croix directionnelle à gauche, les boutons
## A (agir, valider), B (retour, menu) et Carte à droite.
##
## Chaque bouton envoie au jeu la même touche que le clavier (flèches, Entrée, Échap, M) :
## le jeu ne fait aucune différence entre un doigt et une touche, et aucun script n'a besoin
## de connaître le tactile.
##
## Visible d'emblée sur téléphone et tablette ; sur ordinateur, seulement après un contact du doigt.
## Se cache dès qu'on joue au clavier. Sur téléphone en portrait, un message demande de tourner l'appareil.

const FONT := preload("res://assets/fonts/Cinzel-VariableFont_wght.ttf")
const GOLD := Color(0.78, 0.63, 0.36)
const TEXT := Color(0.93, 0.90, 0.84)
const FILL := Color(0.04, 0.05, 0.10, 0.38)
const FILL_PRESSED := Color(0.78, 0.63, 0.36, 0.45)

## Croix directionnelle : rayon (unités de l'écran de base 1920 × 1080) et marge au bord.
const PAD_RADIUS := 165.0
const MARGIN := 70.0
const BUTTON_RADIUS := 78.0
const SMALL_RADIUS := 52.0
## Zone morte au centre de la croix (part du rayon).
const DEAD_ZONE := 0.22

## Boutons d'action : touche envoyée, libellé, rayon. La position est calculée par _layout().
var _buttons := {
	"a": {"key": KEY_ENTER, "label": "A", "radius": BUTTON_RADIUS, "pos": Vector2.ZERO},
	"b": {"key": KEY_ESCAPE, "label": "B", "radius": BUTTON_RADIUS, "pos": Vector2.ZERO},
	"carte": {"key": KEY_M, "label": "Carte", "radius": SMALL_RADIUS, "pos": Vector2.ZERO},
}

var _view: Control
var _pad_center := Vector2.ZERO
var _pad_touch := -1            # doigt posé sur la croix (-1 : aucun)
var _dirs: Array[int] = []      # flèches actuellement enfoncées par la croix
var _held := {}                 # doigt -> bouton tenu ("a", "b", "carte")
var _active := false

func _ready() -> void:
	layer = 98   # au-dessus des menus (50) et de la mini-carte (40), sous les fondus (99, 100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_controls)
	add_child(_view)
	get_viewport().size_changed.connect(_layout)
	get_tree().root.window_input.connect(_on_window_input)
	_layout()
	visible = false
	_set_active(_mobile())

## Aide à l'écran adaptée aux contrôles : au tactile, « Entrée » devient A et « Échap » devient B.
func hint(text: String) -> String:
	if not _active:
		return text
	return text.replace("Entrée", "A").replace("Échap", "B")

func _set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	visible = on
	if not on:
		_release_all()

func _layout() -> void:
	var size := _screen_size()
	_pad_center = Vector2(MARGIN + PAD_RADIUS, size.y - MARGIN - PAD_RADIUS)
	var a := Vector2(size.x - MARGIN - BUTTON_RADIUS, size.y - MARGIN - BUTTON_RADIUS - 70.0)
	_buttons["a"]["pos"] = a
	_buttons["b"]["pos"] = a + Vector2(-BUTTON_RADIUS * 2.0 - 30.0, 90.0)
	_buttons["carte"]["pos"] = a + Vector2(-20.0, -BUTTON_RADIUS - SMALL_RADIUS - 70.0)
	if _view:
		_view.queue_redraw()

func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size

## Téléphone ou tablette (navigateur Android / iOS, ou application). Sur ordinateur, les contrôles
## n'apparaissent qu'au premier contact du doigt (écran tactile de portable), sans message de rotation.
func _mobile() -> bool:
	for f in ["web_android", "web_ios", "android", "ios", "tactile"]:
		if OS.has_feature(f):
			return true
	return false

## Téléphone tenu en portrait, d'après la fenêtre (l'écran du jeu, lui, garde le format 16:9 sur le web).
## Sur ordinateur, une fenêtre de navigateur étroite n'est pas un téléphone : pas de message.
func _portrait() -> bool:
	var s := get_window().size
	return _mobile() and s.y > s.x

# --- Entrées ---

## Reçoit les événements avant tous les nœuds (un menu qui consomme la touche ne nous la cache pas).
func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.has_meta("tactile"):
		_set_active(false)   # on joue au clavier : les contrôles tactiles laissent la place

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_set_active(true)
			if _portrait():
				return
			if _on_pad(event.position):
				_pad_touch = event.index
				_update_pad(event.position)
				get_viewport().set_input_as_handled()
			else:
				var id := _button_at(event.position)
				if id != "":
					_held[event.index] = id
					_send(_buttons[id]["key"], true)
					get_viewport().set_input_as_handled()
		else:
			if event.index == _pad_touch:
				_pad_touch = -1
				_set_dirs([])
			elif _held.has(event.index):
				_send(_buttons[_held[event.index]]["key"], false)
				_held.erase(event.index)
		_view.queue_redraw()
	elif event is InputEventScreenDrag and event.index == _pad_touch:
		_update_pad(event.position)
		get_viewport().set_input_as_handled()

func _on_pad(pos: Vector2) -> bool:
	return pos.distance_to(_pad_center) <= PAD_RADIUS * 1.35

func _button_at(pos: Vector2) -> String:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		if pos.distance_to(b["pos"]) <= b["radius"] * 1.3:
			return id
	return ""

## Huit directions : les diagonales n'occupent qu'un secteur étroit, pour ne pas faire
## bouger les menus de deux crans d'un coup quand le doigt est un peu de travers.
func _update_pad(pos: Vector2) -> void:
	var v := pos - _pad_center
	if v.length() < PAD_RADIUS * DEAD_ZONE:
		_set_dirs([])
		return
	var angle := fposmod(rad_to_deg(v.angle()), 360.0)   # 0 = droite, 90 = bas
	var dirs: Array[int] = []
	var sectors := [[0.0, KEY_RIGHT], [90.0, KEY_DOWN], [180.0, KEY_LEFT], [270.0, KEY_UP], [360.0, KEY_RIGHT]]
	for s in sectors:
		if absf(angle - s[0]) <= 67.5 and not dirs.has(s[1]):
			dirs.append(s[1])
	if dirs.size() == 2:
		# Diagonale seulement à moins de 15° de l'axe à 45° : sinon, la direction la plus proche.
		var nearest: Array = sectors[0]
		for s in sectors:
			if absf(angle - s[0]) < absf(angle - nearest[0]):
				nearest = s
		if absf(angle - nearest[0]) < 30.0:
			dirs = [nearest[1]]
	_set_dirs(dirs)

func _set_dirs(dirs: Array[int]) -> void:
	for k in _dirs:
		if not dirs.has(k):
			_send(k, false)
	for k in dirs:
		if not _dirs.has(k):
			_send(k, true)
	_dirs = dirs
	_view.queue_redraw()

func _release_all() -> void:
	_set_dirs([])
	_pad_touch = -1
	for index in _held:
		_send(_buttons[_held[index]]["key"], false)
	_held.clear()

## La même touche que le clavier : elle déclenche les mêmes actions (move_*, ui_*, interact…).
func _send(key: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = pressed
	ev.set_meta("tactile", true)
	Input.parse_input_event(ev)

# --- Dessin ---

func _draw_controls() -> void:
	var size := _screen_size()
	if _portrait():
		_view.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.92))
		_text("Tourne ton appareil", size / 2.0 - Vector2(0, 30), 64, GOLD)
		_text("pour jouer en paysage", size / 2.0 + Vector2(0, 50), 44, TEXT)
		return
	# Croix
	_view.draw_circle(_pad_center, PAD_RADIUS, FILL)
	_view.draw_arc(_pad_center, PAD_RADIUS, 0.0, TAU, 64, Color(GOLD, 0.5), 3.0, true)
	var arrows := {KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN, KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT}
	for k in arrows:
		var d: Vector2 = arrows[k]
		var tip := _pad_center + d * PAD_RADIUS * 0.78
		var base := _pad_center + d * PAD_RADIUS * 0.45
		var side := d.orthogonal() * PAD_RADIUS * 0.2
		var col := Color(GOLD, 0.95) if _dirs.has(k) else Color(TEXT, 0.55)
		_view.draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), col)
	# Boutons
	var pressed_ids := _held.values()
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var on: bool = pressed_ids.has(id)
		_view.draw_circle(b["pos"], b["radius"], FILL_PRESSED if on else FILL)
		_view.draw_arc(b["pos"], b["radius"], 0.0, TAU, 48, Color(GOLD, 0.6), 3.0, true)
		var fs := 60 if b["radius"] >= BUTTON_RADIUS else 26
		_text(b["label"], b["pos"], fs, Color(TEXT, 0.9))

func _text(s: String, center: Vector2, font_size: int, color: Color) -> void:
	var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := center + Vector2(-w.x / 2.0, FONT.get_ascent(font_size) / 2.0 - 4.0)
	_view.draw_string_outline(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.02, 0.02, 0.03, 0.8))
	_view.draw_string(FONT, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
