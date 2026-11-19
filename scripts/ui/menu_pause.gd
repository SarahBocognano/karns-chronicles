extends CanvasLayer

## Menu du jeu (autoload « MenuPause »), ouvert avec Échap sur les cartes (hors combat, dialogue
## ou scène automatique). Le jeu est en pause tant qu'il est ouvert.
## À gauche : Objets, Statut, Sauvegarder, Charger, Écran titre, Reprendre ; en dessous, le lieu
## et le temps de jeu. À droite : l'équipe, ou le contenu de la commande choisie.

signal _back

const PORTRAITS := {
	"Zylrak": preload("res://assets/portrait/zylrak_normal.tres"),
	"Ysolde": preload("res://assets/portrait/ysolde_neutre.tres"),
}
const COMMANDS := ["Objets", "Statut", "Sauvegarder", "Charger", "Écran titre", "Reprendre"]
enum { OBJETS, STATUT, SAUVER, CHARGER, TITRE, REPRENDRE }

var is_open := false
var _root: Control
var _cmds: ListeMenu
var _content: Control
var _place: Label
var _time: Label
var _waiting_back := false

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	# Commandes (le menu se rouvre toujours sur la liste de gauche)
	var left := UiKit.panel(Vector2(70, 70), Vector2(450, 560))
	_root.add_child(left)
	_cmds = ListeMenu.new()
	_cmds.position = Vector2(70, 70)
	_cmds.set_entries(COMMANDS)
	left.add_child(_cmds)
	# Lieu et temps de jeu
	var info := UiKit.panel(Vector2(70, 660), Vector2(450, 250))
	_root.add_child(info)
	var col := VBoxContainer.new()
	col.position = Vector2(70, 56)
	col.add_theme_constant_override("separation", 4)
	info.add_child(col)
	col.add_child(UiKit.label("Lieu", 22, UiKit.GOLD))
	_place = UiKit.label("", 26)
	_place.custom_minimum_size = Vector2(320, 0)
	_place.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_place)
	col.add_child(UiKit.label("Temps de jeu", 22, UiKit.GOLD))
	_time = UiKit.label("", 26)
	col.add_child(_time)
	# Contenu
	var main := UiKit.panel(Vector2(560, 70), Vector2(1290, 940))
	_root.add_child(main)
	_content = Control.new()
	_content.position = Vector2(90, 66)
	_content.size = Vector2(1110, 808)
	main.add_child(_content)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("ui_cancel") and _can_open():
			get_viewport().set_input_as_handled()
			open()
		return
	if _waiting_back and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_back.emit()

func _can_open() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.begins_with("res://scenes/maps/") \
		and not PlayerData.controls_locked and not SceneTransition.in_battle and not get_tree().paused

func open() -> void:
	is_open = true
	get_tree().paused = true
	PlayerData.controls_locked = true
	_place.text = Sauvegarde.place_name()
	_time.text = Sauvegarde.format_time(PlayerData.play_time)
	_cmds.index = 0
	_cmds._chosen_once = false
	_root.visible = true
	_run()

func close() -> void:
	is_open = false
	_root.visible = false
	_clear()
	get_tree().paused = false
	PlayerData.controls_locked = false

func _run() -> void:
	while is_open:
		_show_party()
		var i := await _cmds.choose()
		match i:
			OBJETS:
				await _items()
			STATUT:
				await _status()
			SAUVER:
				await _save_screen()
			CHARGER:
				if await _load_screen():
					return
			TITRE:
				if await _confirm("Retourner à l'écran titre ? Ce qui n'est pas sauvegardé sera perdu."):
					close()
					PlayerData.controls_locked = true
					Sauvegarde.to_title()
					return
			_:
				close()

# --- Contenu ---

func _clear() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

func _title(text: String) -> void:
	var t := UiKit.label(text, 36, UiKit.GOLD)
	_content.add_child(t)

func _heroes() -> Array[Dictionary]:
	var pd := PlayerData
	var out: Array[Dictionary] = [{
		"nom": "Zylrak", "titre": "Ashwarden de l'Ordre des Cendres",
		"pv": pd.current_hp, "pv_max": pd.max_hp, "pm": pd.current_energy, "pm_max": pd.max_energy,
		"stats": [["Attaque", pd.attack], ["Défense", pd.defense], ["Magie", pd.magic], ["Vitesse", pd.speed]],
		"talents_nom": "Signes", "talents": pd.known_signs(),
	}]
	if pd.ysolde_in_party():
		out.append({
			"nom": "Ysolde", "titre": "Archère",
			"pv": pd.ysolde_hp, "pv_max": pd.ysolde_max_hp(), "pm": pd.ysolde_energy, "pm_max": pd.ysolde_max_energy(),
			"stats": [["Attaque", pd.ysolde_attack()], ["Défense", pd.ysolde_defense()], ["Vitesse", pd.ysolde_speed()]],
			"talents_nom": "Talents", "talents": BattleCatalog.TALENTS,
		})
	return out

## L'équipe : portrait, niveau, PV et PM de chacun.
func _show_party() -> void:
	_clear()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 36)
	_content.add_child(col)
	for h in _heroes():
		col.add_child(_hero_row(h, true))
	var next := PlayerData.xp_for_level(PlayerData.level + 1) - PlayerData.xp
	col.add_child(UiKit.label("Expérience : %d    Prochain niveau dans %d" % [PlayerData.xp, maxi(0, next)], 26, UiKit.TEXT))

func _hero_row(h: Dictionary, big: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	var pic := TextureRect.new()
	pic.texture = PORTRAITS[h.nom]
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(230, 230) if big else Vector2(170, 170)
	row.add_child(pic)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var name_line := HBoxContainer.new()
	name_line.add_theme_constant_override("separation", 24)
	name_line.add_child(UiKit.label(h.nom, 40, UiKit.GOLD))
	name_line.add_child(UiKit.label("Niv. %d" % PlayerData.level, 30))
	info.add_child(name_line)
	if big:
		info.add_child(UiKit.label(h.titre, 22, UiKit.GREY))
	var bar_w := 320.0 if big else 260.0
	info.add_child(UiKit.label("PV  %d / %d" % [h.pv, h.pv_max], 28))
	info.add_child(UiKit.bar(float(h.pv) / h.pv_max, UiKit.HP, bar_w))
	info.add_child(UiKit.label("PM  %d / %d" % [h.pm, h.pm_max], 28))
	info.add_child(UiKit.bar(float(h.pm) / h.pm_max, UiKit.MP, bar_w))
	return row

## Attend Échap ou Entrée.
func _wait_back() -> void:
	_waiting_back = true
	await _back
	_waiting_back = false

## Une question Oui / Non dans le panneau de droite.
func _confirm(question: String) -> bool:
	_clear()
	var q := UiKit.label(question, 30)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(1000, 0)
	_content.add_child(q)
	var yes_no := ListeMenu.new()
	yes_no.position = Vector2(0, 120)
	yes_no.set_entries(["Oui", "Non"])
	yes_no.index = 1
	_content.add_child(yes_no)
	return await yes_no.choose() == 0

## Un message, puis retour (Entrée ou Échap).
func _message(text: String) -> void:
	_clear()
	var m := UiKit.label(text, 30)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size = Vector2(1000, 0)
	_content.add_child(m)
	await _wait_back()

# --- Objets ---

func _items() -> void:
	var cursor := 0
	while true:
		_clear()
		_title("Objets")
		var ids: Array[String] = []
		for id in BattleCatalog.OBJETS:
			if PlayerData.count_item(id) > 0:
				ids.append(id)
		var desc := UiKit.label("", 26, UiKit.GREY)
		desc.position = Vector2(0, 470)
		_content.add_child(desc)
		_key_items(Vector2(0, 560))
		if ids.is_empty():
			var none := UiKit.label("Aucun objet.", 30, UiKit.GREY)
			none.position = Vector2(0, 80)
			_content.add_child(none)
			await _wait_back()
			return
		var entries: Array[String] = []
		for id in ids:
			entries.append("%s   ×%d" % [BattleCatalog.OBJETS[id].nom, PlayerData.count_item(id)])
		var list := ListeMenu.new()
		list.position = Vector2(0, 80)
		list.set_entries(entries)
		list.index = mini(cursor, ids.size() - 1)
		list.moved.connect(func(k: int): desc.text = _describe(ids[k]))
		desc.text = _describe(ids[list.index])
		_content.add_child(list)
		var i := await list.choose()
		if i < 0:
			return
		cursor = i
		var who := await _choose_hero("Sur qui utiliser : %s ?" % BattleCatalog.OBJETS[ids[i]].nom)
		if who >= 0:
			await _message(_use(ids[i], who))

static func _describe(id: String) -> String:
	var o: Dictionary = BattleCatalog.OBJETS[id]
	if o.has("soin"):
		return "Rend %d PV à un allié." % o.soin
	if o.has("mana"):
		return "Rend %d PM à un allié." % o.mana
	return ""

## Objets précieux : les fragments gravés des Yrenn, tant que la porte du temple est scellée.
func _key_items(pos: Vector2) -> void:
	if PlayerData.get_flag("temple_ouvert"):
		return
	var held: Array[String] = []
	for s in FragmentYrenn.SYMBOLS:
		if PlayerData.get_flag(FragmentYrenn.flag_for(s)):
			held.append(s)
	if held.is_empty():
		return
	var box := VBoxContainer.new()
	box.position = pos
	box.add_theme_constant_override("separation", 10)
	_content.add_child(box)
	box.add_child(UiKit.label("Objets précieux", 28, UiKit.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for s in held:
		var icon := TextureRect.new()
		icon.texture = FragmentYrenn.texture_for(s)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(72, 72)
		row.add_child(icon)
	box.add_child(UiKit.label("Fragments gravés des Yrenn (%d sur 4) : ils vont dans les encoches de la porte du temple." % held.size(), 22, UiKit.GREY))

func _choose_hero(question: String) -> int:
	_clear()
	_title(question)
	var heroes := _heroes()
	var entries: Array[String] = []
	for h in heroes:
		entries.append("%s     PV %d/%d     PM %d/%d" % [h.nom, h.pv, h.pv_max, h.pm, h.pm_max])
	var list := ListeMenu.new()
	list.position = Vector2(0, 80)
	list.set_entries(entries)
	_content.add_child(list)
	return await list.choose()

## Utilise l'objet sur le héros `who` (0 : Zylrak, 1 : Ysolde) ; renvoie le message à afficher.
func _use(id: String, who: int) -> String:
	var o: Dictionary = BattleCatalog.OBJETS[id]
	var h: Dictionary = _heroes()[who]
	var pd := PlayerData
	if o.has("soin"):
		if h.pv >= h.pv_max:
			return "%s a déjà tous ses PV." % h.nom
		var gain := mini(o.soin, h.pv_max - h.pv)
		if who == 0:
			pd.current_hp += gain
		else:
			pd.ysolde_hp += gain
		pd.use_item(id)
		return "%s récupère %d PV." % [h.nom, gain]
	if o.has("mana"):
		if h.pm >= h.pm_max:
			return "%s a déjà tous ses PM." % h.nom
		var gain := mini(o.mana, h.pm_max - h.pm)
		if who == 0:
			pd.current_energy += gain
		else:
			pd.ysolde_energy += gain
		pd.use_item(id)
		return "%s récupère %d PM." % [h.nom, gain]
	return ""

# --- Statut ---

func _status() -> void:
	_clear()
	var heroes := _heroes()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	_content.add_child(row)
	for h in heroes:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(530, 0)
		col.add_theme_constant_override("separation", 8)
		row.add_child(col)
		col.add_child(_hero_row(h, false))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 40)
		grid.add_theme_constant_override("v_separation", 6)
		col.add_child(grid)
		for s in h.stats:
			grid.add_child(UiKit.label(s[0], 28, UiKit.GREY))
			grid.add_child(UiKit.label(str(s[1]), 28))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 14)
		col.add_child(gap)
		col.add_child(UiKit.label(h.talents_nom, 30, UiKit.GOLD))
		for t in h.talents:
			col.add_child(UiKit.label("%s   (%d PM)" % [t.nom, t.cout], 26))
	var xp := UiKit.label("Expérience : %d    Prochain niveau dans %d" % [PlayerData.xp, maxi(0, PlayerData.xp_for_level(PlayerData.level + 1) - PlayerData.xp)], 26)
	xp.position = Vector2(0, 760)
	_content.add_child(xp)
	await _wait_back()

# --- Sauvegarder / charger ---

func _slot_entries() -> Array[String]:
	var out: Array[String] = []
	for i in Sauvegarde.SLOTS:
		var d := Sauvegarde.slot_info(i)
		if d.is_empty():
			out.append("%d.   — vide —" % (i + 1))
		else:
			out.append("%d.   %s   ·   Niv. %d   ·   %s" % [i + 1, d.lieu, int(d.joueur.level), Sauvegarde.format_time(d.joueur.play_time)])
	return out

func _slot_list(title: String, only_used: bool, start: int) -> ListeMenu:
	_clear()
	_title(title)
	var entries := _slot_entries()
	var enabled: Array = []
	for i in Sauvegarde.SLOTS:
		enabled.append(not only_used or not Sauvegarde.slot_info(i).is_empty())
	var date := UiKit.label("", 24, UiKit.GREY)
	date.position = Vector2(0, 400)
	_content.add_child(date)
	var list := ListeMenu.new()
	list.position = Vector2(0, 90)
	list.font_size = 30
	list.spacing = 26
	list.index = start
	list.set_entries(entries, enabled)
	var show_date := func(k: int):
		var d := Sauvegarde.slot_info(k)
		date.text = "" if d.is_empty() else "Sauvegardé le " + Sauvegarde.format_date(d.date)
	list.moved.connect(show_date)
	show_date.call(list.index)
	_content.add_child(list)
	return list

func _save_screen() -> void:
	var cursor := 0
	while true:
		var list := _slot_list("Sauvegarder — choisis un emplacement", false, cursor)
		var i := await list.choose()
		if i < 0:
			return
		cursor = i
		if not Sauvegarde.slot_info(i).is_empty():
			if not await _confirm("Écraser la sauvegarde de l'emplacement %d ?" % (i + 1)):
				continue
		var ok := Sauvegarde.save(i)
		await _message("Partie sauvegardée dans l'emplacement %d." % (i + 1) if ok else "La sauvegarde a échoué.")
		return

## Renvoie true si une partie a été chargée (le menu est alors fermé).
func _load_screen() -> bool:
	if not Sauvegarde.has_any_save():
		await _message("Aucune partie sauvegardée.")
		return false
	var list := _slot_list("Charger une partie", true, Sauvegarde.latest_slot())
	var i := await list.choose()
	if i < 0:
		return false
	if not await _confirm("Charger cette partie ? Ce qui n'est pas sauvegardé sera perdu."):
		return false
	close()
	PlayerData.controls_locked = true
	Sauvegarde.load_slot(i)
	return true
