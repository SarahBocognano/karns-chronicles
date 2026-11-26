extends CanvasLayer

## Le grimoire de l'Ashwarden (autoload « MenuPause »), ouvert avec Échap sur les cartes (hors combat,
## dialogue ou scène automatique). Le jeu est en pause tant qu'il est ouvert.
## Style : pack Dark Ages UI (cadre orné, parchemin, cases, onglets, barres), police Cinzel.
##
## Onglets : Équipe, Équipement, Objets, Précieux, Journal, Système.
## ← → : changer d'onglet · Entrée ou ↓ : entrer dans l'onglet · Échap : revenir, puis fermer.

signal _tab_signal(action: String)
signal _back

const PORTRAITS := {
	"zylrak": preload("res://assets/portrait/zylrak_normal.tres"),
	"ysolde": preload("res://assets/portrait/ysolde_neutre.tres"),
}
const TABS := ["Équipe", "Équipement", "Objets", "Précieux", "Journal", "Système"]
enum { EQUIPE, EQUIPEMENT, OBJETS, PRECIEUX, JOURNAL, SYSTEME }
const FRAME_POS := Vector2(110, 150)
const FRAME_SIZE := Vector2(1700, 830)
const CONTENT_POS := Vector2(80, 76)      # dans le cadre
const CONTENT_SIZE := Vector2(1540, 640)
const GREEN := Color("#7fc06a")
const RED := Color("#e07a62")

var is_open := false
var tab := EQUIPE
var _root: Control
var _frame: Panel
var _tabs_box: HBoxContainer
var _content: Control     # zone de la page : _view (dessin, redessiné à volonté) + listes par-dessus
var _view: Control
var _footer_left: Label
var _footer_right: Label
var _focus := "tabs"      # "tabs" : on choisit l'onglet ; "page" : on est dans l'onglet
var _waiting_back := false

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	var screen := get_viewport().get_visible_rect().size
	var off := Vector2((screen.x - 1920) / 2.0, (screen.y - 1080) / 2.0)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_tabs_box = HBoxContainer.new()
	_tabs_box.position = off + FRAME_POS + Vector2(70, -58)
	_tabs_box.add_theme_constant_override("separation", 10)
	_root.add_child(_tabs_box)
	_frame = UiKit.da_panel(UiKit.DA_FRAME, 20, off + FRAME_POS, FRAME_SIZE)
	_root.add_child(_frame)
	_content = Control.new()
	_content.position = CONTENT_POS
	_content.size = CONTENT_SIZE
	_frame.add_child(_content)
	_view = Control.new()
	_view.size = CONTENT_SIZE
	_content.add_child(_view)
	var div := UiKit.da_image(UiKit.DA_DIVIDER)
	div.position = Vector2((FRAME_SIZE.x - UiKit.DA_DIVIDER.size.x * UiKit.DA) / 2.0, FRAME_SIZE.y - 112)
	_frame.add_child(div)
	_footer_left = UiKit.label("", 24, UiKit.TEXT)
	_footer_left.position = Vector2(84, FRAME_SIZE.y - 88)
	_frame.add_child(_footer_left)
	_footer_right = UiKit.label("", 22, UiKit.GREY)
	_footer_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer_right.position = Vector2(FRAME_SIZE.x - 84 - 900, FRAME_SIZE.y - 86)
	_footer_right.size = Vector2(900, 30)
	_frame.add_child(_footer_right)

# --- Ouverture / fermeture ---

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("ui_cancel") and _can_open():
			get_viewport().set_input_as_handled()
			open()
		return
	if _waiting_back and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_back.emit()
		return
	if _focus != "tabs":
		return
	var action := ""
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		action = "left"
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		action = "right"
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		action = "enter"
	elif event.is_action_pressed("ui_cancel"):
		action = "close"
	if action != "":
		get_viewport().set_input_as_handled()
		_tab_signal.emit(action)

func _can_open() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.begins_with("res://scenes/maps/") \
		and not PlayerData.controls_locked and not SceneTransition.in_battle and not get_tree().paused

func open() -> void:
	is_open = true
	get_tree().paused = true
	PlayerData.controls_locked = true
	tab = EQUIPE
	_build()
	_root.visible = true
	Sons.play("ouvrir")
	_run()

func close() -> void:
	Sons.play("fermer")
	is_open = false
	_root.visible = false
	_focus = "tabs"
	get_tree().paused = false
	PlayerData.controls_locked = false

func _run() -> void:
	while is_open:
		_focus = "tabs"
		_draw_tabs()
		_show_page(tab)
		_footer_right.text = "← →  onglets      Entrée  ouvrir      Échap  fermer"
		var action: String = await _tab_signal
		match action:
			"left":
				tab = posmod(tab - 1, TABS.size())
			"right":
				tab = posmod(tab + 1, TABS.size())
			"close":
				close()
			"enter":
				_focus = "page"
				_footer_right.text = "Flèches  choisir      Entrée  valider      Échap  revenir"
				if await _enter_page(tab):
					return   # partie chargée, écran titre ou reprise

func _draw_tabs() -> void:
	for c in _tabs_box.get_children():
		_tabs_box.remove_child(c)
		c.queue_free()
	for i in TABS.size():
		var on := i == tab
		var t := Panel.new()
		t.add_theme_stylebox_override("panel", UiKit.da_style(UiKit.DA_TAB_ACTIVE if on else UiKit.DA_TAB, 5))
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.custom_minimum_size = Vector2(220, 58)
		var l := UiKit.label(TABS[i], 26, UiKit.GOLD.lightened(0.25) if on else UiKit.GREY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = t.custom_minimum_size
		t.add_child(l)
		if on:
			var orn := UiKit.da_image(UiKit.DA_TAB_ORNAMENT)
			orn.position = Vector2((220 - UiKit.DA_TAB_ORNAMENT.size.x * UiKit.DA) / 2.0, -22)
			t.add_child(orn)
		_tabs_box.add_child(t)
	_footer_left.text = "%s      ·      %s      ·      %d écus" % [Sauvegarde.place_name(), Sauvegarde.format_time(PlayerData.play_time), PlayerData.ecus]

## Efface le dessin de la page (les listes posées par-dessus restent).
func _clear() -> void:
	for c in _view.get_children():
		_view.remove_child(c)
		c.queue_free()

## Retire les listes posées par-dessus la page.
func _drop_lists() -> void:
	for c in _content.get_children():
		if c != _view:
			_content.remove_child(c)
			c.queue_free()

## Aperçu de l'onglet (sans interaction).
func _show_page(i: int) -> void:
	_drop_lists()
	_clear()
	match i:
		EQUIPE:
			_page_team()
		EQUIPEMENT:
			_page_gear(0, -1, "")
		OBJETS:
			_page_items(0)
		PRECIEUX:
			_page_key_items(0)
		JOURNAL:
			_page_journal(0)
		SYSTEME:
			_page_system()

## Interaction dans l'onglet ; true si le menu s'est fermé (partie chargée, écran titre, reprise).
func _enter_page(i: int) -> bool:
	var closed := false
	match i:
		EQUIPEMENT:
			await _gear_loop()
		OBJETS:
			await _items_loop()
		PRECIEUX:
			await _key_items_loop()
		JOURNAL:
			await _journal_loop()
		SYSTEME:
			closed = await _system_loop()
	if is_open:
		_drop_lists()
	return closed

# --- Briques ---

func _parchment(pos: Vector2, size: Vector2) -> Panel:
	var p := UiKit.da_panel(UiKit.DA_PARCHMENT, 10, pos, size)
	_view.add_child(p)
	return p

func _ink(text: String, size: int, color := UiKit.INK) -> Label:
	var l := UiKit.label(text, size, color)
	l.add_theme_constant_override("outline_size", 0)
	return l

func _place(parent: Control, node: Control, pos: Vector2) -> Control:
	node.position = pos
	parent.add_child(node)
	return node

## Liste posée par-dessus la page (elle survit aux redessins de la page).
func _list(entries: Array, pos: Vector2, enabled: Array = [], ink := false, size := 30) -> ListeMenu:
	var list := ListeMenu.new()
	list.font_size = size
	if ink:
		list.text_color = UiKit.INK
	list.set_entries(entries, enabled)
	_place(_content, list, pos)
	return list

func _heroes() -> Array[String]:
	var out: Array[String] = ["zylrak"]
	if PlayerData.ysolde_in_party():
		out.append("ysolde")
	return out

static func _hero_name(h: String) -> String:
	return "Zylrak" if h == "zylrak" else "Ysolde"

func _hp(h: String) -> Vector2i:
	return Vector2i(PlayerData.current_hp, PlayerData.max_hp) if h == "zylrak" else Vector2i(PlayerData.ysolde_hp, PlayerData.ysolde_max_hp())

func _mp(h: String) -> Vector2i:
	return Vector2i(PlayerData.current_energy, PlayerData.max_energy) if h == "zylrak" else Vector2i(PlayerData.ysolde_energy, PlayerData.ysolde_max_energy())

func _stats_of(h: String) -> Array[String]:
	var out: Array[String] = ["attaque", "defense", "vitesse"]
	if h == "zylrak":
		out.insert(2, "magie")
	return out

func _portrait(h: String, size: float) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = PORTRAITS[h]
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size = Vector2(size, size)
	return pic

func _big_icon(tex: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(size, size)
	return t

## Attend Échap ou Entrée.
func _wait_back() -> void:
	_waiting_back = true
	await _back
	_waiting_back = false

## Message sur un parchemin, puis retour.
func _message(text: String) -> void:
	_drop_lists()
	_clear()
	var p := _parchment(Vector2(320, 200), Vector2(900, 240))
	var m := _ink(text, 30)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m.position = Vector2(50, 30)
	m.size = Vector2(800, 180)
	p.add_child(m)
	await _wait_back()

## Question Oui / Non sur un parchemin.
func _confirm(question: String) -> bool:
	_drop_lists()
	_clear()
	var p := _parchment(Vector2(320, 160), Vector2(900, 320))
	var q := _ink(question, 30)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.position = Vector2(50, 50)
	q.size = Vector2(800, 120)
	p.add_child(q)
	var yes_no := _list(["Oui", "Non"], Vector2(320 + 380, 160 + 180), [], true)
	yes_no.index = 1
	var ok := await yes_no.choose() == 0
	yes_no.queue_free()
	return ok

# --- Équipe ---

func _page_team() -> void:
	var heroes := _heroes()
	for k in heroes.size():
		var x := 0.0 if heroes.size() > 1 else 395.0
		_hero_card(heroes[k], Vector2(x + k * 790, 0))

func _hero_card(h: String, pos: Vector2) -> void:
	var card := _parchment(pos, Vector2(750, 640))
	_place(card, _portrait(h, 200), Vector2(36, 36))
	var name_line := HBoxContainer.new()
	name_line.add_theme_constant_override("separation", 24)
	name_line.add_child(_ink(_hero_name(h), 42, UiKit.INK_GOLD))
	name_line.add_child(_ink("Niv. %d" % PlayerData.level, 30))
	_place(card, name_line, Vector2(260, 40))
	_place(card, _ink("Ashwarden de l'Ordre des Cendres" if h == "zylrak" else "Archère", 22, UiKit.INK_SOFT), Vector2(262, 96))
	if PlayerData.is_poisoned(h):
		_place(card, _ink("Empoisonné", 24, Color("#4f7a2a")), Vector2(600, 96))
	var hp := _hp(h)
	var mp := _mp(h)
	var lvl := PlayerData.level
	var xp_from := PlayerData.xp_for_level(lvl)
	var xp_to := PlayerData.xp_for_level(lvl + 1)
	var rows := [["PV", "%d / %d" % [hp.x, hp.y], float(hp.x) / hp.y, UiKit.DA_FILL_HP],
		["PM", "%d / %d" % [mp.x, mp.y], float(mp.x) / mp.y, UiKit.DA_FILL_MP],
		["XP", "%d / %d" % [PlayerData.xp, xp_to], float(PlayerData.xp - xp_from) / maxf(1.0, xp_to - xp_from), UiKit.DA_FILL_XP]]
	for r in rows.size():
		var y := 140.0 + r * 34
		_place(card, _ink(rows[r][0], 24, UiKit.INK_GOLD), Vector2(262, y - 6))
		_place(card, UiKit.da_bar(rows[r][2], rows[r][3], 300), Vector2(312, y + 4))
		_place(card, _ink(rows[r][1], 22), Vector2(630, y - 4))
	var div := UiKit.da_image(UiKit.DA_DIVIDER)
	div.modulate = Color(0.45, 0.35, 0.2)
	_place(card, div, Vector2((750 - UiKit.DA_DIVIDER.size.x * UiKit.DA) / 2.0, 262))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for s in _stats_of(h):
		grid.add_child(_ink(BattleCatalog.STAT_NAMES[s], 26, UiKit.INK_SOFT))
		grid.add_child(_ink(str(PlayerData.stat(h, s)), 26))
		var bonus := PlayerData.gear_bonus(h, s)
		grid.add_child(_ink("(+%d)" % bonus if bonus > 0 else "", 22, UiKit.INK_GOLD))
	_place(card, grid, Vector2(48, 310))
	var skills := VBoxContainer.new()
	skills.add_theme_constant_override("separation", 6)
	skills.add_child(_ink("Signes" if h == "zylrak" else "Talents", 28, UiKit.INK_GOLD))
	var list: Array = PlayerData.known_signs() if h == "zylrak" else BattleCatalog.TALENTS
	for t in list:
		skills.add_child(_ink("%s   %d PM" % [t.nom, t.cout] if t.cout > 0 else t.nom, 24))
	_place(card, skills, Vector2(400, 310))

# --- Équipement ---

## hero_i : héros affiché ; slot_i : emplacement en cours de changement (-1 : aucun) ;
## preview : pièce dont on prévisualise l'effet ("" : aucune ; "-" : retirer).
func _page_gear(hero_i: int, slot_i: int, preview: String) -> void:
	_clear()
	var h: String = _heroes()[hero_i]
	var left := _parchment(Vector2(0, 0), Vector2(640, 640))
	_place(left, _portrait(h, 150), Vector2(30, 24))
	_place(left, _ink(_hero_name(h), 40, UiKit.INK_GOLD), Vector2(200, 40))
	_place(left, _ink("Niv. %d" % PlayerData.level, 26), Vector2(202, 96))
	for k in BattleCatalog.SLOTS.size():
		var slot: String = BattleCatalog.SLOTS[k]
		var y := 200.0 + k * 130.0
		var frame := UiKit.da_image(UiKit.DA_SLOT_SELECTED if k == slot_i else UiKit.DA_SLOT)
		frame.position = Vector2(40, y) - (Vector2(6, 7) if k == slot_i else Vector2.ZERO)
		left.add_child(frame)
		var id: String = PlayerData.equipment[h][slot]
		if id != "":
			_place(left, _big_icon(UiKit.icon(id), 64), Vector2(50, y + 8))
		_place(left, _ink(BattleCatalog.SLOT_NAMES[slot], 22, UiKit.INK_SOFT), Vector2(170, y + 2))
		_place(left, _ink(BattleCatalog.EQUIPEMENTS[id].nom if id != "" else "—", 28), Vector2(170, y + 34))
	# À droite : caractéristiques, avec l'effet de la pièce en aperçu
	_place(_view, UiKit.label("Caractéristiques", 30, UiKit.GOLD), Vector2(700, 10))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 8)
	for s in _stats_of(h):
		var now := PlayerData.stat(h, s)
		var after := now
		if slot_i >= 0 and preview != "":
			var cur: String = PlayerData.equipment[h][BattleCatalog.SLOTS[slot_i]]
			if cur != "":
				after -= int(BattleCatalog.EQUIPEMENTS[cur].bonus.get(s, 0))
			if preview != "-":
				after += int(BattleCatalog.EQUIPEMENTS[preview].bonus.get(s, 0))
		grid.add_child(UiKit.label(BattleCatalog.STAT_NAMES[s], 26, UiKit.GREY))
		grid.add_child(UiKit.label(str(now), 26))
		grid.add_child(UiKit.label("→" if after != now else "", 26, UiKit.GREY))
		grid.add_child(UiKit.label(str(after) if after != now else "", 26, GREEN if after > now else RED))
	_place(_view, grid, Vector2(700, 66))
	if preview != "" and preview != "-":
		var desc := UiKit.label(BattleCatalog.EQUIPEMENTS[preview].desc, 24, UiKit.TEXT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size = Vector2(820, 100)
		_place(_view, desc, Vector2(700, 270))

## Pièces de l'emplacement que le héros peut porter, prises dans le sac.
func _gear_choices(h: String, slot: String) -> Array[String]:
	var out: Array[String] = []
	for id in PlayerData.gear_bag:
		var e: Dictionary = BattleCatalog.EQUIPEMENTS[id]
		if e.type == slot and (e.pour == "tous" or e.pour == h) and not out.has(id):
			out.append(id)
	return out

func _gear_loop() -> void:
	var heroes := _heroes()
	var hero_i := 0
	while true:
		if heroes.size() > 1:
			_page_gear(hero_i, -1, "")
			var pick := _list(heroes.map(func(h): return _hero_name(h)), Vector2(700, 420))
			pick.index = hero_i
			pick.moved.connect(func(k: int):
				hero_i = k
				_page_gear(hero_i, -1, ""))
			var k := await pick.choose()
			pick.queue_free()
			if k < 0:
				return
			hero_i = k
		await _slots_loop(hero_i)
		if heroes.size() == 1:
			return

func _slots_loop(hero_i: int) -> void:
	var h: String = _heroes()[hero_i]
	var slot_i := 0
	while true:
		_page_gear(hero_i, slot_i, "")
		var entries: Array[String] = []
		for s in BattleCatalog.SLOTS:
			entries.append("Changer : " + BattleCatalog.SLOT_NAMES[s].to_lower())
		var slots := _list(entries, Vector2(700, 420), [], false, 28)
		slots.index = slot_i
		slots.moved.connect(func(k: int):
			slot_i = k
			_page_gear(hero_i, slot_i, ""))
		var k := await slots.choose()
		slots.queue_free()
		if k < 0:
			return
		slot_i = k
		await _pick_gear(hero_i, h, BattleCatalog.SLOTS[slot_i], slot_i)

func _pick_gear(hero_i: int, h: String, slot: String, slot_i: int) -> void:
	var ids: Array[String] = []
	var entries: Array[String] = []
	for id in _gear_choices(h, slot):
		ids.append(id)
		entries.append(BattleCatalog.EQUIPEMENTS[id].nom)
	if PlayerData.equipment[h][slot] != "":
		ids.append("-")
		entries.append("Retirer")
	if ids.is_empty():
		await _message("Aucune pièce à équiper pour cet emplacement.")
		return
	_page_gear(hero_i, slot_i, ids[0])
	var list := _list(entries, Vector2(700, 420), [], false, 28)
	list.moved.connect(func(k: int): _page_gear(hero_i, slot_i, ids[k]))
	var k := await list.choose()
	list.queue_free()
	if k >= 0:
		PlayerData.equip(h, slot, "" if ids[k] == "-" else ids[k])

# --- Objets ---

func _item_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in BattleCatalog.OBJETS:
		var n := PlayerData.count_item(id)
		if n > 0:
			out.append({"id": id, "icon": UiKit.icon(id), "count": n})
	for id in PlayerData.gear_bag:
		out.append({"id": id, "icon": UiKit.icon(id), "count": 1, "gear": true})
	return out

func _page_items(index: int) -> GrilleObjets:
	_clear()
	var entries := _item_entries()
	_place(_view, UiKit.label("Sac", 30, UiKit.GOLD), Vector2(20, 0))
	var card := _parchment(Vector2(640, 0), Vector2(900, 640))
	var grid := GrilleObjets.new()
	grid.index = index
	grid.set_items(entries)
	_place(_view, grid, Vector2(20, 60))
	var show := func(k: int):
		for c in card.get_children():
			c.queue_free()
		if entries.is_empty():
			_place(card, _ink("Le sac est vide.", 30, UiKit.INK_SOFT), Vector2(60, 60))
			return
		var it: Dictionary = entries[k]
		var gear: bool = it.get("gear", false)
		_place(card, _big_icon(it.icon, 128), Vector2(50, 50))
		var info: Dictionary = BattleCatalog.EQUIPEMENTS[it.id] if gear else BattleCatalog.OBJETS[it.id]
		_place(card, _ink(info.nom, 38, UiKit.INK_GOLD), Vector2(210, 60))
		var kind: String = ("Équipement · " + BattleCatalog.SLOT_NAMES[info.type]) if gear else ("Objet · %d en réserve" % it.count)
		_place(card, _ink(kind, 24, UiKit.INK_SOFT), Vector2(212, 116))
		var d := _ink(_describe(it.id, gear), 26)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size = Vector2(780, 220)
		_place(card, d, Vector2(56, 220))
	grid.moved.connect(show)
	show.call(clampi(index, 0, maxi(0, entries.size() - 1)))
	return grid

static func _describe(id: String, gear: bool) -> String:
	if gear:
		var e: Dictionary = BattleCatalog.EQUIPEMENTS[id]
		var parts: Array[String] = []
		for s in e.bonus:
			parts.append("+%d %s" % [e.bonus[s], BattleCatalog.STAT_NAMES[s]])
		var who := "tous" if e.pour == "tous" else ("Zylrak" if e.pour == "zylrak" else "Ysolde")
		return "%s\n\n%s  ·  porté par : %s.\nÀ équiper dans l'onglet Équipement." % [e.desc, ", ".join(parts), who]
	var o: Dictionary = BattleCatalog.OBJETS[id]
	if o.has("soin"):
		return "Rend %d PV à un allié." % o.soin
	if o.has("mana"):
		return "Rend %d PM à un allié." % o.mana
	if o.has("antidote"):
		return "Soigne le venin d'un allié, en combat ou ici. Le venin des araignées ne part pas tout seul : tant qu'il coule, le héros perd des PV à chaque tour de combat."
	return ""

func _items_loop() -> void:
	var index := 0
	while true:
		var grid := _page_items(index)
		if grid.items.is_empty():
			await _wait_back()
			return
		var k := await grid.choose()
		if k < 0:
			return
		index = k
		var it: Dictionary = grid.items[k]
		if it.get("gear", false):
			continue
		var who := await _choose_hero_for()
		if who != "":
			await _message(_use(it.id, who))

func _choose_hero_for() -> String:
	var card := _parchment(Vector2(640, 400), Vector2(900, 240))
	_place(card, _ink("Donner à :", 26, UiKit.INK_SOFT), Vector2(56, 30))
	var heroes := _heroes()
	var entries: Array[String] = []
	for h in heroes:
		var hp := _hp(h)
		var mp := _mp(h)
		entries.append("%s    PV %d/%d    PM %d/%d%s" % [_hero_name(h), hp.x, hp.y, mp.x, mp.y, "    (empoisonné)" if PlayerData.is_poisoned(h) else ""])
	var list := _list(entries, Vector2(640 + 56, 400 + 80), [], true, 28)
	var k := await list.choose()
	list.queue_free()
	return "" if k < 0 else heroes[k]

func _use(id: String, h: String) -> String:
	var o: Dictionary = BattleCatalog.OBJETS[id]
	var who := _hero_name(h)
	if o.has("soin"):
		var hp := _hp(h)
		if hp.x >= hp.y:
			return "%s a déjà tous ses PV." % who
		var gain := mini(o.soin, hp.y - hp.x)
		if h == "zylrak":
			PlayerData.current_hp += gain
		else:
			PlayerData.ysolde_hp += gain
		PlayerData.use_item(id)
		return "%s récupère %d PV." % [who, gain]
	if o.has("mana"):
		var mp := _mp(h)
		if mp.x >= mp.y:
			return "%s a déjà tous ses PM." % who
		var gain := mini(o.mana, mp.y - mp.x)
		if h == "zylrak":
			PlayerData.current_energy += gain
		else:
			PlayerData.ysolde_energy += gain
		PlayerData.use_item(id)
		return "%s récupère %d PM." % [who, gain]
	if o.has("antidote"):
		if not PlayerData.is_poisoned(h):
			return "%s n'est pas empoisonné." % who
		PlayerData.cure_poison(h)
		PlayerData.use_item(id)
		return "Le venin quitte le sang de %s." % who
	return ""

# --- Objets précieux ---

const KEY_ITEM_TEXT := {
	"lune": "Un éclat de pierre gravé d'une lune. « Sous la lune noire... »",
	"loup": "Un éclat gravé d'une tête de loup : c'est ainsi que les Yrenn représentaient la Bête.",
	"epee": "Un éclat gravé d'une épée. « L'épée des Yrenn la fit plier... »",
	"flamme": "Un éclat gravé d'une flamme. « ...et la flamme la scella. »",
}
const SOUL_FRAGMENT_TEXT := "Un morceau de l'âme de la Bête, arraché au gardien du premier temple et enfermé dans la cendre par Zylrak. Il est froid, et il bat doucement, comme un cœur.\n\nIl faut réunir les quatre, et les rendre ensemble à la flamme."
const SCROLL_TEXT := "Le rouleau de l'autel, scellé à la cire bleue. « Quatre éclats, quatre temples. Que les porteurs de cendre rassemblent les éclats et les rendent ensemble à la flamme : alors la Bête dormira mille ans encore. »\n\nLa carte montre un loup sous l'eau : le lac, au sud de la forêt."

const TORCH_TEXT := "Une torche de résine et de chiffon goudronné, faite à la forge. Elle brûle longtemps et ne craint pas les courants d'air.\n\nDans le noir, elle éclaire autour de Zylrak."
const EMBER_TEXT := "Un éclat de minerai rouge, tiède dans la main : au fond de la pierre, quelque chose rougeoie comme une braise.\n\nLe forgeron l'attend pour forger une lame."

## Objets précieux : les fragments gravés (jusqu'à l'ouverture du temple), le fragment d'âme, le parchemin.
func _key_items() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not PlayerData.get_flag("temple_ouvert"):
		var n := 0
		for s in FragmentYrenn.SYMBOLS:
			if PlayerData.get_flag(FragmentYrenn.flag_for(s)):
				n += 1
		for s in FragmentYrenn.SYMBOLS:
			if PlayerData.get_flag(FragmentYrenn.flag_for(s)):
				entries.append({"id": s, "icon": FragmentYrenn.icon_for(s), "count": 1, "titre": "Fragment gravé des Yrenn",
					"sous_titre": "%d sur 4" % n,
					"texte": KEY_ITEM_TEXT[s] + "\n\nLes quatre fragments vont dans les encoches de la porte du temple."})
	if PlayerData.get_flag("fragment_ame_lune"):
		entries.append({"id": "fragment_ame", "icon": UiKit.icon("fragment_ame"), "count": 1, "titre": "Fragment d'âme",
			"sous_titre": "1 sur 4", "texte": SOUL_FRAGMENT_TEXT})
	if PlayerData.get_flag("voleur_margot_vue") and not PlayerData.get_flag("voleur_goules_vaincues"):
		entries.append({"id": "viande_sechee", "icon": UiKit.icon("viande_sechee"), "count": 1, "titre": "Viande séchée",
			"sous_titre": "Donnée par Margot", "texte": "Des lanières de viande séchée et salée, enveloppées dans un torchon. « On ne mène pas une enquête le ventre vide », a dit Margot."})
	if PlayerData.get_flag("torche_forgeron"):
		entries.append({"id": "torche", "icon": UiKit.icon("torche"), "count": 1, "titre": "Torche du forgeron",
			"sous_titre": "Pour la grotte", "texte": TORCH_TEXT})
	if PlayerData.get_flag("pierre_de_braise") and not PlayerData.get_flag("contrat_grotte_termine"):
		entries.append({"id": "pierre_braise", "icon": UiKit.icon("pierre_braise"), "count": 1, "titre": "Pierre-de-braise",
			"sous_titre": "Pour le forgeron", "texte": EMBER_TEXT})
	if PlayerData.get_flag("parchemin_yrenn"):
		entries.append({"id": "parchemin_yrenn", "icon": UiKit.icon("parchemin_yrenn"), "count": 1, "titre": "Parchemin des Yrenn",
			"sous_titre": "Trouvé sur l'autel du gardien", "texte": SCROLL_TEXT})
	return entries

func _page_key_items(index: int) -> GrilleObjets:
	_clear()
	var entries := _key_items()
	_place(_view, UiKit.label("Objets précieux", 30, UiKit.GOLD), Vector2(20, 0))
	var card := _parchment(Vector2(640, 0), Vector2(900, 640))
	var grid := GrilleObjets.new()
	grid.index = index
	grid.set_items(entries)
	_place(_view, grid, Vector2(20, 60))
	var show := func(k: int):
		for c in card.get_children():
			c.queue_free()
		if entries.is_empty():
			_place(card, _ink("Aucun objet précieux pour l'instant.", 28, UiKit.INK_SOFT), Vector2(60, 60))
			return
		_place(card, _big_icon(entries[k].icon, 144), Vector2(50, 40))
		_place(card, _ink(entries[k].titre, 34, UiKit.INK_GOLD), Vector2(220, 60))
		_place(card, _ink(entries[k].sous_titre, 24, UiKit.INK_SOFT), Vector2(222, 112))
		var d := _ink(entries[k].texte, 26)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size = Vector2(780, 360)
		_place(card, d, Vector2(56, 230))
	grid.moved.connect(show)
	show.call(clampi(index, 0, maxi(0, entries.size() - 1)))
	return grid

func _key_items_loop() -> void:
	var grid := _page_key_items(0)
	if grid.items.is_empty():
		await _wait_back()
		return
	while await grid.choose() >= 0:
		pass

# --- Journal ---

## Quêtes connues, d'après les flags : {titre, texte, etapes: [[texte, fait]]}.
func _quests() -> Array[Dictionary]:
	var f := PlayerData.get_flag
	var out: Array[Dictionary] = []
	if f.call("has_accepted_zylrak_quest"):
		var steps: Array = [["Retrouver le chariot du marchand, sur la route de l'est.", f.call("found_merchant_cart")]]
		if f.call("found_merchant_cart"):
			steps.append(["Suivre les traces de sang jusqu'aux ruines des Yrenn.", f.call("ysolde_joined")])
		if f.call("ysolde_joined"):
			var door := "Trouver un moyen d'ouvrir la porte du temple."
			if f.call("porte_temple_vue") and not f.call("temple_ouvert"):
				door += "  (fragments : %d sur 4)" % FragmentYrenn.found_count()
			steps.append([door, f.call("temple_ouvert")])
		if f.call("temple_ouvert"):
			steps.append(["Explorer le temple et retrouver le marchand.", f.call("marchand_retrouve")])
		if f.call("marchand_retrouve"):
			steps.append(["Rentrer à l'auberge annoncer la nouvelle à Oswin.", f.call("quete_marchand_terminee")])
		out.append({"titre": "Le marchand disparu", "texte": "Oswin, l'aubergiste, demande de retrouver le marchand qui devait ravitailler le village et n'est jamais arrivé.", "etapes": steps})
	if f.call("parchemin_yrenn"):
		out.append({"titre": "Les fragments d'âme", "texte": "Le gardien du temple était un fragment de l'âme de la Bête. Le parchemin de l'autel dit qu'il faut réunir les quatre fragments et les rendre ensemble à la flamme pour la resceller.",
			"etapes": [["Enfermer le fragment du premier temple dans la cendre.", f.call("fragment_ame_lune")], ["Trouver le temple du Loup, sous le lac.", false]]})
	for c in Contrats.LIST:
		if Contrats.accepted(c.id):
			out.append({"titre": "Contrat : " + c.titre, "texte": "%s\nRécompense : %s." % [c.commanditaire, c.recompense],
				"etapes": Contrats.steps(c.id)})
	if f.call("aldric_quest_started"):
		var steps: Array = [["Chercher Aldric du côté du lac, au-delà de la cascade : sa clairière est à l'ouest du lac.", f.call("aldric_traces_vues")]]
		if f.call("aldric_traces_vues"):
			steps.append(["Prendre la barque, au bout du ponton, et rejoindre l'île.", f.call("aldric_trouve")])
		if f.call("aldric_trouve"):
			steps.append(["Ramener Aldric à la rive.", f.call("aldric_sauve")])
		if f.call("aldric_sauve"):
			steps.append(["Retrouver Brenna, au village.", f.call("aldric_retrouvailles")])
		out.append({"titre": "Le frère de Brenna", "texte": "Brenna demande de retrouver son frère Aldric, parti couper du bois près du lac et jamais revenu.",
			"etapes": steps})
	return out

## La fiche d'une quête : son titre, sa description et ses étapes, empilés selon leur vraie
## hauteur dans une zone qui défile (`_journal_scroll`), ouverte sur la première étape à faire.
var _journal_scroll: ScrollContainer

func _page_journal(index: int) -> void:
	_clear()
	_journal_scroll = null
	var quests := _quests()
	_place(_view, UiKit.label("Quêtes", 30, UiKit.GOLD), Vector2(20, 0))
	var card := _parchment(Vector2(640, 0), Vector2(900, 640))
	if quests.is_empty():
		var none := _ink("Aucune quête pour l'instant. Oswin, à l'auberge, aurait peut-être du travail.", 26, UiKit.INK_SOFT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.size = Vector2(780, 120)
		_place(card, none, Vector2(56, 60))
		return
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 14)
	for k in quests.size():
		titles.add_child(UiKit.label(quests[k].titre, 30, UiKit.TEXT if k == index else UiKit.GREY))
	_place(_view, titles, Vector2(72, 70))
	var q: Dictionary = quests[clampi(index, 0, quests.size() - 1)]
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size = Vector2(810, 560)
	_place(card, scroll, Vector2(56, 40))
	_journal_scroll = scroll
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(800, 0)
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(_ink(q.titre, 36, UiKit.INK_GOLD))
	var t := _ink(q.texte, 24, UiKit.INK_SOFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(790, 0)
	box.add_child(t)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	box.add_child(gap)
	var first_todo: Control = null
	for st in q.etapes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var dia := UiKit.da_image(UiKit.DA_DIAMOND)
		dia.modulate = Color(0.55, 0.5, 0.45) if st[1] else Color(1, 1, 1)
		dia.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(dia)
		var l := _ink(st[0], 26, UiKit.INK_SOFT if st[1] else UiKit.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(730, 0)
		row.add_child(l)
		box.add_child(row)
		if first_todo == null and not st[1]:
			first_todo = row
	# des flèches discrètes quand il y a plus à lire, au-dessus ou en dessous
	var more_up := _ink("▲", 22, UiKit.INK_SOFT)
	var more_down := _ink("▼", 22, UiKit.INK_SOFT)
	_place(card, more_up, Vector2(860, 14))
	_place(card, more_down, Vector2(860, 604))
	var update_arrows := func():
		if is_instance_valid(scroll) and is_instance_valid(more_up):
			var bar := scroll.get_v_scroll_bar()
			more_up.visible = scroll.scroll_vertical > 2
			more_down.visible = scroll.scroll_vertical < bar.max_value - bar.page - 2
	scroll.get_v_scroll_bar().changed.connect(update_arrows)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v): update_arrows.call())
	# ouverte sur la première étape à faire
	var focus_todo := func():
		if is_instance_valid(scroll) and first_todo and is_instance_valid(first_todo):
			scroll.scroll_vertical = int(maxf(0.0, first_todo.position.y - 120.0))
		update_arrows.call()
	focus_todo.call_deferred()

## Fait défiler la fiche de quête (flèches, molette) jusqu'à Échap ou Entrée.
func _read_journal() -> void:
	var reader := JournalReader.new()
	reader.scroll = _journal_scroll
	_content.add_child(reader)
	await reader.done
	reader.queue_free()

class JournalReader extends Node:
	signal done
	var scroll: ScrollContainer
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _unhandled_input(event: InputEvent) -> void:
		var up := event.is_action_pressed("ui_up") or event.is_action_pressed("move_up")
		var down := event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")
		if up or down:
			if is_instance_valid(scroll):
				scroll.scroll_vertical += -70 if up else 70
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			Sons.play("retour")
			done.emit()

func _journal_loop() -> void:
	var quests := _quests()
	if quests.size() <= 1:
		_page_journal(0)
		if quests.is_empty():
			await _wait_back()
		else:
			await _read_journal()   # une seule quête : les flèches font défiler sa fiche
		return
	var index := 0
	_page_journal(index)
	# seule la main sert : les titres sont déjà dessinés sur la page
	var list := ListeMenu.new()
	list.text_color = Color(0, 0, 0, 0)
	list.disabled_color = Color(0, 0, 0, 0)
	list.spacing = 14
	list.set_entries(quests.map(func(q): return q.titre))
	_place(_content, list, Vector2(20, 70))
	list.moved.connect(func(k: int): _page_journal(k))
	while true:
		var k := await list.choose()
		if k < 0:
			break
		# Entrée sur une quête : on lit sa fiche (les flèches la font défiler), Échap revient à la liste
		await _read_journal()
	list.queue_free()

# --- Système ---

const SYSTEM := ["Sauvegarder", "Charger", "Écran titre", "Reprendre"]

func _page_system() -> void:
	_clear()
	_place(_view, UiKit.label("Système", 30, UiKit.GOLD), Vector2(20, 0))
	var card := _parchment(Vector2(640, 0), Vector2(900, 640))
	_place(card, _ink("Partie en cours", 32, UiKit.INK_GOLD), Vector2(56, 40))
	var info := _ink("%s\nTemps de jeu : %s\nNiveau %d" % [Sauvegarde.place_name(), Sauvegarde.format_time(PlayerData.play_time), PlayerData.level], 26)
	_place(card, info, Vector2(58, 100))
	# aperçu : les commandes, sans la main
	var preview := VBoxContainer.new()
	preview.add_theme_constant_override("separation", 12)
	for k in SYSTEM.size():
		preview.add_child(UiKit.label(SYSTEM[k], 32, UiKit.TEXT if k != 1 or Sauvegarde.has_any_save() else UiKit.GREY))
	_place(_view, preview, Vector2(72, 80))

## true si le menu s'est fermé (partie chargée, écran titre ou reprise).
func _system_loop() -> bool:
	var cursor := 0
	while true:
		_page_system()
		var list := _list(SYSTEM, Vector2(20, 80), [true, Sauvegarde.has_any_save(), true, true], false, 32)
		list.text_color = Color(0, 0, 0, 0)
		list.disabled_color = Color(0, 0, 0, 0)
		list.set_entries(SYSTEM, [true, Sauvegarde.has_any_save(), true, true])
		list.index = cursor
		var k := await list.choose()
		list.queue_free()
		if k >= 0:
			cursor = k
		match k:
			-1:
				return false
			0:
				await _save_screen()
			1:
				if await _load_screen():
					return true
			2:
				if await _confirm("Retourner à l'écran titre ? Ce qui n'est pas sauvegardé sera perdu."):
					close()
					PlayerData.controls_locked = true
					Sauvegarde.to_title()
					return true
			3:
				close()
				return true
	return false

func _slot_list(title: String, only_used: bool, start: int) -> ListeMenu:
	_drop_lists()
	_clear()
	_place(_view, UiKit.label(title, 30, UiKit.GOLD), Vector2(20, 0))
	_parchment(Vector2(0, 60), Vector2(1540, 460))
	var enabled: Array = []
	var entries: Array[String] = []
	for i in Sauvegarde.SLOTS:
		var d := Sauvegarde.slot_info(i)
		enabled.append(not only_used or not d.is_empty())
		if d.is_empty():
			entries.append("%d.   — vide —" % (i + 1))
		else:
			entries.append("%d.   %s   ·   Niv. %d   ·   %s   ·   %s" % [i + 1, d.lieu, int(d.joueur.level), Sauvegarde.format_time(d.joueur.play_time), Sauvegarde.format_date(d.date)])
	var list := ListeMenu.new()
	list.text_color = UiKit.INK
	list.font_size = 30
	list.spacing = 40
	list.index = start
	list.set_entries(entries, enabled)
	_place(_content, list, Vector2(60, 130))
	return list

func _save_screen() -> void:
	var cursor := 0
	while true:
		var list := _slot_list("Sauvegarder — choisis un emplacement", false, cursor)
		var i := await list.choose()
		list.queue_free()
		if i < 0:
			return
		cursor = i
		if not Sauvegarde.slot_info(i).is_empty():
			if not await _confirm("Écraser la sauvegarde de l'emplacement %d ?" % (i + 1)):
				continue
		var ok := Sauvegarde.save(i)
		await _message("Partie sauvegardée dans l'emplacement %d." % (i + 1) if ok else "La sauvegarde a échoué.")
		return

## true si une partie a été chargée (le menu est alors fermé).
func _load_screen() -> bool:
	var list := _slot_list("Charger une partie", true, Sauvegarde.latest_slot())
	var i := await list.choose()
	list.queue_free()
	if i < 0:
		return false
	if not await _confirm("Charger cette partie ? Ce qui n'est pas sauvegardé sera perdu."):
		return false
	close()
	PlayerData.controls_locked = true
	Sauvegarde.load_slot(i)
	return true
