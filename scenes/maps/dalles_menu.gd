extends CanvasLayer
class_name DallesMenu

## Énigme de la porte du temple : Zylrak pose les quatre fragments gravés dans les encoches des dalles.
## En haut, les quatre encoches (de gauche à droite) ; en dessous, les pierres qu'il lui reste en main.
## ← → : choisir une pierre · Entrée : la poser dans l'encoche suivante · Échap : reprendre la
## dernière pierre posée (ou quitter si aucune n'est posée).
## Signaux : slots_changed(order) à chaque pierre posée ou reprise ; done(order) quand les quatre
## sont posées ; cancelled() si on quitte.

signal slots_changed(order: Array)
signal done(order: Array)
signal cancelled

const FONT := preload("res://assets/fonts/Cinzel-VariableFont_wght.ttf")
const FRAME := preload("res://assets/ui/mana_soul/cadre.png")
const FRAME_MARGIN_X := 26
const FRAME_MARGIN_Y := 18
const UI_SCALE := 3
const ICON := 72            # fragments dessinés en 24 px, agrandis ×3
const SLOT := 96
const GOLD := Color("#f2c14e")
const CREAM := Color("#f4e6c4")
const SLOT_BG := Color("#0d0f2a")
const NUMERALS := ["I", "II", "III", "IV"]

var order: Array[String] = []
var _hand: Array[String] = []
var _cursor := 0
var _closing := false
var _slots: Array[Panel] = []
var _slot_icons: Array[TextureRect] = []
var _hand_box: HBoxContainer

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in FragmentYrenn.SYMBOLS:
		if PlayerData.get_flag(FragmentYrenn.flag_for(s)):
			_hand.append(s)
	_build()
	_refresh()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var panel := Panel.new()
	var sb := StyleBoxTexture.new()
	sb.texture = _px(FRAME, UI_SCALE)
	sb.texture_margin_left = FRAME_MARGIN_X * UI_SCALE
	sb.texture_margin_right = FRAME_MARGIN_X * UI_SCALE
	sb.texture_margin_top = FRAME_MARGIN_Y * UI_SCALE
	sb.texture_margin_bottom = FRAME_MARGIN_Y * UI_SCALE
	panel.add_theme_stylebox_override("panel", sb)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.size = Vector2(760, 540)
	panel.position = (Vector2(1920, 1080) - panel.size) / 2.0 - Vector2(0, 60)
	add_child(panel)
	var col := VBoxContainer.new()
	col.position = Vector2(90, 58)
	col.size = panel.size - Vector2(180, 116)
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	col.add_child(_label("Les encoches du sceau", 34, GOLD))
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 22)
	col.add_child(slots)
	for i in 4:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		slots.add_child(box)
		var p := Panel.new()
		p.custom_minimum_size = Vector2(SLOT, SLOT)
		var st := StyleBoxFlat.new()
		st.bg_color = SLOT_BG
		st.border_color = GOLD.darkened(0.35)
		st.set_border_width_all(3)
		st.set_corner_radius_all(4)
		p.add_theme_stylebox_override("panel", st)
		box.add_child(p)
		var icon := TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(ICON, ICON)
		icon.position = Vector2((SLOT - ICON) / 2.0, (SLOT - ICON) / 2.0)
		p.add_child(icon)
		var num := _label(NUMERALS[i], 22, CREAM.darkened(0.2))
		box.add_child(num)
		_slots.append(p)
		_slot_icons.append(icon)
	col.add_child(_label("Tes pierres", 24, CREAM))
	_hand_box = HBoxContainer.new()
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_box.add_theme_constant_override("separation", 26)
	_hand_box.custom_minimum_size = Vector2(0, ICON + 12)
	col.add_child(_hand_box)
	var hint := _label(Tactile.hint("← →  choisir     Entrée  poser     Échap  reprendre"), 18, CREAM.darkened(0.25))
	col.add_child(hint)

func _refresh() -> void:
	for i in 4:
		_slot_icons[i].texture = FragmentYrenn.icon_for(order[i]) if i < order.size() else null
		var st := _slots[i].get_theme_stylebox("panel") as StyleBoxFlat
		st.border_color = GOLD if i == order.size() else GOLD.darkened(0.35)
	for c in _hand_box.get_children():
		c.queue_free()
	_cursor = clampi(_cursor, 0, maxi(0, _hand.size() - 1))
	for i in _hand.size():
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(ICON + 12, ICON + 12)
		var icon := TextureRect.new()
		icon.texture = FragmentYrenn.icon_for(_hand[i])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(ICON, ICON)
		icon.position = Vector2(6, 6)
		slot.add_child(icon)
		if i == _cursor:
			var ring := Panel.new()
			var st := StyleBoxFlat.new()
			st.draw_center = false
			st.border_color = GOLD
			st.set_border_width_all(3)
			st.set_corner_radius_all(6)
			ring.add_theme_stylebox_override("panel", st)
			ring.size = slot.custom_minimum_size
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ring)
		_hand_box.add_child(slot)

func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_cursor = maxi(0, _cursor - 1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_cursor = mini(_hand.size() - 1, _cursor + 1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_place()
	elif event.is_action_pressed("ui_cancel"):
		_take_back()
	else:
		return
	get_viewport().set_input_as_handled()
	if not _closing:
		_refresh()

## Pose la pierre choisie dans l'encoche suivante.
func place(symbol: String) -> void:
	var i := _hand.find(symbol)
	if i == -1 or order.size() >= 4:
		return
	_cursor = i
	_place()
	if not _closing:
		_refresh()

func _place() -> void:
	if _hand.is_empty():
		return
	order.append(_hand[_cursor])
	_hand.remove_at(_cursor)
	slots_changed.emit(order)
	if order.size() == 4:
		_closing = true
		_refresh()
		await get_tree().create_timer(0.5).timeout
		done.emit(order)
		queue_free()

func _take_back() -> void:
	if order.is_empty():
		_closing = true
		cancelled.emit()
		queue_free()
		return
	var s: String = order.pop_back()
	_hand.insert(mini(FragmentYrenn.SYMBOLS.find(s), _hand.size()), s)
	slots_changed.emit(order)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	l.add_theme_constant_override("outline_size", 4)
	return l

static func _px(tex: Texture2D, k: int) -> Texture2D:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
