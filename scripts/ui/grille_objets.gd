extends Control
class_name GrilleObjets

## Grille de cases d'inventaire (cases sombres du pack Dark Ages ; la case choisie est la case bleue ornée).
## ← → ↑ ↓ : se déplacer · Entrée : choisir (case pleine) · Échap : revenir.
## Usage : set_items([...]) puis `var i := await grille.choose()` (-1 si on revient).

signal moved(index: int)
signal _done(index: int)

const CELL := Vector2(84, 81)        # case de 28 × 27 agrandie ×3
const GAP := 10.0
const ICON_SIZE := 64.0

var cols := 6
var rows := 3
var index := 0
var active := false
## Une entrée par case pleine : {"id", "icon": Texture2D, "count": int}
var items: Array[Dictionary] = []

var _cursor: TextureRect

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_items(list: Array) -> void:
	items.assign(list)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for i in cols * rows:
		var pos := _cell_pos(i)
		var slot := UiKit.da_image(UiKit.DA_SLOT)
		slot.position = pos
		add_child(slot)
		if i < items.size():
			var it: Dictionary = items[i]
			var ic := TextureRect.new()
			ic.texture = it.icon
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.size = Vector2(ICON_SIZE, ICON_SIZE)
			ic.position = pos + (CELL - ic.size) / 2.0
			add_child(ic)
			if it.get("count", 1) > 1:
				var n := UiKit.label("%d" % it.count, 22)
				n.position = pos + Vector2(CELL.x - 30, CELL.y - 34)
				add_child(n)
	_cursor = UiKit.da_image(UiKit.DA_SLOT_SELECTED)
	add_child(_cursor)
	custom_minimum_size = _cell_pos(cols * rows - 1) + CELL
	size = custom_minimum_size
	index = clampi(index, 0, maxi(0, items.size() - 1))
	_place_cursor()

func _cell_pos(i: int) -> Vector2:
	return Vector2(i % cols, i / cols) * (CELL + Vector2(GAP, GAP))

func _place_cursor() -> void:
	_cursor.visible = active and not items.is_empty()
	var big := UiKit.DA_SLOT_SELECTED.size * UiKit.DA
	_cursor.position = _cell_pos(index) + (CELL - big) / 2.0
	# l'icône reste lisible par-dessus la case bleue
	move_child(_cursor, 0)

func choose() -> int:
	active = true
	_place_cursor()
	var i: int = await _done
	active = false
	_place_cursor()
	return i

func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	var d := Vector2i.ZERO
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		d = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		d = Vector2i(1, 0)
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		d = Vector2i(0, -1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		d = Vector2i(0, 1)
	var accept := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	var cancel := event.is_action_pressed("ui_cancel")
	if d == Vector2i.ZERO and not accept and not cancel:
		return
	get_viewport().set_input_as_handled()
	if cancel:
		_done.emit(-1)
	elif accept:
		if index < items.size():
			_done.emit(index)
	elif not items.is_empty():
		var x := clampi(index % cols + d.x, 0, cols - 1)
		var y := clampi(index / cols + d.y, 0, rows - 1)
		var next := mini(y * cols + x, items.size() - 1)
		if next != index:
			index = next
			_place_cursor()
			moved.emit(index)
