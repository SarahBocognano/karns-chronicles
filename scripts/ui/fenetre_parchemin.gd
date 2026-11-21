extends CanvasLayer
class_name FenetreParchemin

## Fenêtre au style du grimoire (cadre orné du pack Dark Ages UI) : un titre, une liste à gauche
## (la main-curseur des menus), une fiche de parchemin à droite, une ligne d'aide en bas.
## Sert au panneau des contrats et à la boutique. Le jeu est en pause tant qu'elle est ouverte ;
## close() la referme et émet `closed`.

signal closed
signal _key

const FRAME_SIZE := Vector2(1560, 800)
const CARD_POS := Vector2(640, 110)
const CARD_SIZE := Vector2(840, 560)

var list: ListeMenu
var _frame: Panel
var _card: Panel
var _title: Label
var _footer: Label
var _side: Label

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	PlayerData.controls_locked = true
	var screen := get_viewport().get_visible_rect().size
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_frame = UiKit.da_panel(UiKit.DA_FRAME, 20, (screen - FRAME_SIZE) / 2.0, FRAME_SIZE)
	add_child(_frame)
	_title = UiKit.label("", 38, UiKit.GOLD)
	_title.position = Vector2(80, 44)
	_frame.add_child(_title)
	_side = UiKit.label("", 26, UiKit.TEXT)
	_side.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_side.position = Vector2(FRAME_SIZE.x - 80 - 600, 52)
	_side.size = Vector2(600, 34)
	_frame.add_child(_side)
	_card = UiKit.da_panel(UiKit.DA_PARCHMENT, 10, CARD_POS, CARD_SIZE)
	_frame.add_child(_card)
	var div := UiKit.da_image(UiKit.DA_DIVIDER)
	div.position = Vector2((FRAME_SIZE.x - UiKit.DA_DIVIDER.size.x * UiKit.DA) / 2.0, FRAME_SIZE.y - 104)
	_frame.add_child(div)
	_footer = UiKit.label("", 22, UiKit.GREY)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.position = Vector2(0, FRAME_SIZE.y - 78)
	_footer.size = Vector2(FRAME_SIZE.x, 30)
	_frame.add_child(_footer)
	list = ListeMenu.new()
	list.font_size = 30
	list.position = Vector2(70, 130)
	_frame.add_child(list)

func set_title(text: String) -> void:
	_title.text = text

## Texte en haut à droite du cadre (ex. les écus).
func set_side(text: String) -> void:
	_side.text = text

func set_footer(text: String) -> void:
	_footer.text = text

func clear_card() -> void:
	for c in _card.get_children():
		c.queue_free()

## Texte à l'encre sur la fiche ; `width` > 0 : retour à la ligne automatique.
func ink(text: String, size: int, pos: Vector2, color := UiKit.INK, width := 0.0) -> Label:
	var l := UiKit.label(text, size, color)
	l.add_theme_constant_override("outline_size", 0)
	l.position = pos
	_card.add_child(l)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
		l.size = Vector2(width, 0)
	return l

func icon(tex: Texture2D, pos: Vector2, size: float) -> void:
	var t := TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(size, size)
	t.position = pos
	_card.add_child(t)

## Petite liste de choix posée sur la fiche (ex. « Accepter / Plus tard »), renvoie l'indice choisi (-1 : Échap).
func ask(entries: Array, pos: Vector2) -> int:
	var l := ListeMenu.new()
	l.font_size = 28
	l.text_color = UiKit.INK
	l.position = pos
	_card.add_child(l)
	l.set_entries(entries)
	var i: int = await l.choose()
	l.queue_free()
	return i

## Attend Entrée ou Échap.
func wait_key() -> void:
	_waiting = true
	await _key

var _waiting := false

func _unhandled_input(event: InputEvent) -> void:
	if _waiting and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_waiting = false
		_key.emit()

func close() -> void:
	get_tree().paused = false
	PlayerData.controls_locked = false
	closed.emit()
	queue_free()
