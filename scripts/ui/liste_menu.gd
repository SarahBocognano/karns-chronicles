extends Control
class_name ListeMenu

## Liste de choix verticale avec la main-curseur des combats.
## ↑ ↓ : se déplacer (les entrées grisées sont sautées) · Entrée : choisir · Échap : annuler.
## Usage : `var i := await liste.choose()` (renvoie -1 si on annule).

signal moved(index: int)
signal _done(index: int)

var index := 0
var active := false
var cancelable := true
var font_size := 32
var spacing := 12
## Couleur du texte (encre sombre sur le parchemin, crème sur les fonds sombres).
var text_color := UiKit.TEXT
var disabled_color := UiKit.GREY

var _box: VBoxContainer
var _hand: TextureRect
var _enabled: Array[bool] = []
## true une fois qu'on a choisi dans cette liste : la main reste affichée, grisée, pendant la suite.
var _chosen_once := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.position = Vector2(52, 0)
	add_child(_box)
	_hand = TextureRect.new()
	_hand.texture = UiKit.px(UiKit.HAND, 2)
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand.visible = false
	add_child(_hand)

## Remplace les entrées. `enabled` : une valeur par entrée (toutes actives si vide).
func set_entries(entries: Array, enabled: Array = []) -> void:
	_box.add_theme_constant_override("separation", spacing)
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_enabled.clear()
	for k in entries.size():
		var on: bool = enabled[k] if k < enabled.size() else true
		_enabled.append(on)
		var l := UiKit.label(str(entries[k]), font_size, text_color if on else disabled_color)
		if text_color.get_luminance() < 0.4:
			l.add_theme_constant_override("outline_size", 0)   # encre sur parchemin : pas de contour
		_box.add_child(l)
	index = clampi(index, 0, maxi(0, entries.size() - 1))
	if not _enabled.is_empty() and not _enabled[index]:
		index = maxi(0, _enabled.find(true))
	_place_hand.call_deferred()

func entry_count() -> int:
	return _enabled.size()

## Attend un choix : l'indice choisi, ou -1 si on annule.
func choose() -> int:
	active = true
	_place_hand.call_deferred()
	var i: int = await _done
	active = false
	_chosen_once = i >= 0
	_place_hand()
	return i

func _place_hand() -> void:
	_hand.visible = (active or _chosen_once) and index < _box.get_child_count()
	_hand.modulate = Color(1, 1, 1, 1.0 if active else 0.4)
	if not _hand.visible:
		return
	var l := _box.get_child(index) as Control
	_hand.position = _box.position + l.position + Vector2(-_hand.texture.get_width() - 10, (l.size.y - _hand.texture.get_height()) / 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree() or _enabled.is_empty():
		return
	var up := event.is_action_pressed("move_up") or event.is_action_pressed("ui_up")
	var down := event.is_action_pressed("move_down") or event.is_action_pressed("ui_down")
	var accept := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	var cancel := event.is_action_pressed("ui_cancel")
	if not (up or down or accept or cancel):
		return
	# Marquer la touche comme traitée avant d'émettre : celui qui attend le choix peut retirer la liste.
	get_viewport().set_input_as_handled()
	if up or down:
		var n := _enabled.size()
		for _i in n:
			index = posmod(index + (1 if down else -1), n)
			if _enabled[index]:
				break
		_place_hand()
		moved.emit(index)
	elif accept:
		if _enabled[index]:
			_done.emit(index)
	elif cancelable:
		_done.emit(-1)
