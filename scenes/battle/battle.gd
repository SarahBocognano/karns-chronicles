extends Node

signal finished(result: String)
signal _menu_done(index: int)
signal _message_closed

## Taille du décor en pixels (les fonds font 480×270, affichés en plein écran).
const BASE := Vector2(480, 270)
const ZYLRAK_SHEET := preload("res://assets/sprites/characters/zylrak_with_cape_spridesheet.png")
const FONT := preload("res://assets/fonts/Cinzel-VariableFont_wght.ttf")
const HERO_HOME := Vector2(378, 178)
const FOE_SLOTS := {
	1: [Vector2(128, 176)],
	2: [Vector2(112, 160), Vector2(166, 184)],
	3: [Vector2(70, 152), Vector2(160, 162), Vector2(112, 188)],
}
const GOLD := Color(0.78, 0.63, 0.36)
const TEXT := Color(0.93, 0.90, 0.84)
const GREY := Color(0.55, 0.53, 0.50)

var background: Texture2D
var monster_list: Array = []  # MonsterData

## État lisible par les tests : "intro", "menu", "cible", "message", "anim", "fin".
var state := "intro"
var result := ""
var foes: Array[Dictionary] = []

var rng := RandomNumberGenerator.new()
var _zoom := 4.0
var _offset := Vector2.ZERO
var _world_layer: CanvasLayer
var _ui_layer: CanvasLayer
var _world: Node2D
var _hero: AnimatedSprite2D
var _defending := false
var _rempart_turns := 0

# Interface
var _foe_panel: Panel
var _foe_names: VBoxContainer
var _hero_panel: Panel
var _name_label: Label
var _hp_label: Label
var _ep_label: Label
var _hp_bar: ProgressBar
var _ep_bar: ProgressBar
var _menu_panel: Panel
var _menu_box: VBoxContainer
var _menu_cursor: Polygon2D
var _message_panel: Panel
var _message_label: Label
var _target_cursor: Node2D

var _menu_entries: Array[String] = []
var _menu_enabled: Array[bool] = []
var menu_index := 0
var _menu_cancelable := false
var _target_index := 0
var _waiting_message := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_build_world()
	_build_ui()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_run.call_deferred()

# =============================================================== déroulement
func _run() -> void:
	var intro := "Une goule surgit !" if foes.size() == 1 else "%d goules surgissent !" % foes.size()
	if foes.size() > 1 and _distinct_names() > 1:
		intro = "Des monstres surgissent !"
	elif foes.size() == 1:
		intro = "%s surgit !" % _with_article(foes[0].data.display_name)
	await _say(intro, 1.2)
	while result == "":
		for actor in _turn_order():
			if result != "":
				break
			if actor is String:
				await _hero_turn()
			elif actor.alive:
				await _foe_turn(actor)
			if _alive_foes().is_empty():
				result = "victoire"
			elif PlayerData.current_hp <= 0:
				result = "defaite"
		if _rempart_turns > 0:
			_rempart_turns -= 1
	await _ending()
	state = "fin"
	finished.emit(result)

func _turn_order() -> Array:
	var order: Array = [["hero", PlayerData.speed + rng.randf_range(0, 3)]]
	for f in foes:
		if f.alive:
			order.append([f, f.data.speed + rng.randf_range(0, 3)])
	order.sort_custom(func(a, b): return a[1] > b[1])
	return order.map(func(e): return e[0])

func _hero_turn() -> void:
	if PlayerData.current_hp <= 0:
		return
	_defending = false
	var action := await _choose_action()
	_hide_menu()
	state = "anim"
	match action.type:
		"attaque":
			await _hero_attack(action.target)
		"signe":
			await _hero_sign(action.signe, action.get("target", {}))
		"objet":
			await _hero_item(action.objet)
		"defense":
			_defending = true
			_hero.play("garde")
			await _flash(_hero, Color(1.4, 1.3, 1.0), 0.25)
			await _say("Zylrak se met en garde.", 0.9)
		"fuite":
			await _hero_flee()

func _foe_turn(foe: Dictionary) -> void:
	state = "anim"
	var names: PackedStringArray = foe.data.attack_names
	var attack_name: String = names[rng.randi() % names.size()] if names.size() > 0 else "Attaque"
	_show_message("%s : %s !" % [foe.name, attack_name])
	var sprite: Node2D = foe.sprite
	if sprite is AnimatedSprite2D:
		sprite.play("attaque")
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", foe.home.x + 26, 0.16).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "position:x", foe.home.x, 0.22).set_delay(0.08)
	if sprite is AnimatedSprite2D:
		tw.tween_callback(func(): sprite.play("repos"))
	await get_tree().create_timer(0.18).timeout
	var dmg := _damage(foe.data.attack, PlayerData.defense)
	if _defending:
		dmg = max(1, dmg / 2)
	if _rempart_turns > 0:
		dmg = max(1, dmg / 2)
	PlayerData.current_hp = max(0, PlayerData.current_hp - dmg)
	_popup(str(dmg), HERO_HOME + Vector2(0, -48), Color(1.0, 0.85, 0.80))
	_shake(_hero, HERO_HOME)
	await _flash(_hero, Color(1.8, 0.5, 0.45), 0.18)
	_refresh_hero()
	if PlayerData.current_hp <= 0:
		_hero.play("blesse")
	await get_tree().create_timer(0.55).timeout
	_hide_message()

# =============================================================== choix de Zylrak
func _choose_action() -> Dictionary:
	while true:
		var main := ["Attaque", "Signes", "Objets", "Défense", "Fuite"]
		var has_items := false
		for id in BattleCatalog.OBJETS:
			if PlayerData.count_item(id) > 0:
				has_items = true
		var i := await _menu(main, [true, true, has_items, true, true], false)
		match i:
			0:
				var t := await _choose_target()
				if not t.is_empty():
					return {"type": "attaque", "target": t}
			1:
				var entries: Array[String] = []
				var enabled: Array[bool] = []
				var known := PlayerData.known_signs()
				for s in known:
					entries.append("%s  %d EP" % [s.nom, s.cout])
					enabled.append(PlayerData.current_energy >= s.cout)
				var k := await _menu(entries, enabled, true)
				if k < 0:
					continue
				var signe: Dictionary = known[k]
				if signe.type == "degats":
					var t2 := await _choose_target()
					if t2.is_empty():
						continue
					return {"type": "signe", "signe": signe, "target": t2}
				return {"type": "signe", "signe": signe}
			2:
				var ids: Array[String] = []
				var entries2: Array[String] = []
				var enabled2: Array[bool] = []
				for id in BattleCatalog.OBJETS:
					var n := PlayerData.count_item(id)
					if n > 0:
						ids.append(id)
						entries2.append("%s  ×%d" % [BattleCatalog.OBJETS[id].nom, n])
						enabled2.append(true)
				var k2 := await _menu(entries2, enabled2, true)
				if k2 < 0:
					continue
				return {"type": "objet", "objet": ids[k2]}
			3:
				return {"type": "defense"}
			4:
				return {"type": "fuite"}
	return {}

func _menu(entries: Array, enabled: Array, cancelable: bool) -> int:
	_menu_entries.assign(entries)
	_menu_enabled.assign(enabled)
	_menu_cancelable = cancelable
	for c in _menu_box.get_children():
		c.queue_free()
	for k in entries.size():
		var l := _label(entries[k], _font_size(), TEXT if enabled[k] else GREY)
		_menu_box.add_child(l)
	menu_index = max(0, _menu_enabled.find(true))
	_menu_panel.visible = true
	await get_tree().process_frame  # laisse les libellés se placer avant d'y poser le curseur
	_place_menu_cursor()
	# Le menu n'écoute les touches qu'à partir d'ici (sinon une touche pressée trop tôt serait perdue).
	state = "menu"
	return await _menu_done

func _hide_menu() -> void:
	_menu_panel.visible = false
	_menu_cursor.visible = false

func _choose_target() -> Dictionary:
	var alive := _alive_foes()
	if alive.is_empty():
		return {}
	_target_index = 0
	state = "cible"
	_place_target_cursor()
	var i: int = await _menu_done
	_target_cursor.visible = false
	state = "anim"
	if i < 0:
		return {}
	return alive[i]

func _input(event: InputEvent) -> void:
	var accept := event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	var cancel := event.is_action_pressed("ui_cancel")
	var up := event.is_action_pressed("ui_up") or event.is_action_pressed("move_up")
	var down := event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")
	var left := event.is_action_pressed("ui_left") or event.is_action_pressed("move_left")
	var right := event.is_action_pressed("ui_right") or event.is_action_pressed("move_right")
	if state == "menu" and _menu_panel.visible:
		if up or down:
			var n := _menu_entries.size()
			for _i in n:
				menu_index = posmod(menu_index + (1 if down else -1), n)
				if _menu_enabled[menu_index]:
					break
			_place_menu_cursor()
		elif accept and _menu_enabled[menu_index]:
			_menu_done.emit(menu_index)
		elif cancel and _menu_cancelable:
			_menu_done.emit(-1)
		else:
			return
		get_viewport().set_input_as_handled()
	elif state == "cible":
		var n2 := _alive_foes().size()
		if up or left:
			_target_index = posmod(_target_index - 1, n2)
			_place_target_cursor()
		elif down or right:
			_target_index = posmod(_target_index + 1, n2)
			_place_target_cursor()
		elif accept:
			_menu_done.emit(_target_index)
		elif cancel:
			_menu_done.emit(-1)
		else:
			return
		get_viewport().set_input_as_handled()
	elif _waiting_message and accept:
		_message_closed.emit()
		get_viewport().set_input_as_handled()

# =============================================================== actions de Zylrak
func _hero_attack(foe: Dictionary) -> void:
	_show_message("Zylrak attaque !")
	await _hero_step(-34)
	_hero.play("coup")
	await get_tree().create_timer(0.22).timeout
	var dmg := _damage(PlayerData.attack, foe.data.defense)
	var crit := rng.randf() < 0.1
	if crit:
		dmg = int(dmg * 1.5)
	await _hit_foe(foe, dmg, Color(1, 1, 1), "Critique ! " if crit else "")
	# L'animation a pu se terminer pendant que la goule disparaissait.
	if _hero.animation == "coup" and _hero.is_playing():
		await _hero.animation_finished
	await _hero_step(0)
	_hide_message()

func _hero_sign(signe: Dictionary, target: Dictionary) -> void:
	PlayerData.current_energy -= signe.cout
	_refresh_hero()
	_show_message("Signe : %s !" % signe.nom)
	_hero.play("sort")
	await get_tree().create_timer(0.45).timeout
	match signe.type:
		"degats":
			_embers(target.sprite.position + Vector2(0, -24), Color(1.0, 0.55, 0.15))
			var dmg := int(PlayerData.magic * signe.puissance * rng.randf_range(0.9, 1.1)) - int(target.data.defense * 0.25)
			await _hit_foe(target, max(1, dmg), Color(1.0, 0.7, 0.35), "")
		"protection":
			_rempart_turns = signe.tours
			_embers(HERO_HOME + Vector2(0, -24), Color(0.95, 0.75, 0.45))
			await _flash(_hero, Color(1.5, 1.25, 0.8), 0.35)
			_show_message("Un rempart de cendres protège Zylrak.")
			await get_tree().create_timer(0.8).timeout
		"soin":
			var heal := int(ceil(PlayerData.max_hp * signe.soin))
			_heal(heal)
			_embers(HERO_HOME + Vector2(0, -24), Color(1.0, 0.6, 0.3))
			await _flash(_hero, Color(1.4, 1.1, 0.8), 0.3)
			await get_tree().create_timer(0.5).timeout
	if _hero.animation == "sort" and _hero.is_playing():
		await _hero.animation_finished
	_hero.play("garde")
	_hide_message()

func _hero_item(item_id: String) -> void:
	var item: Dictionary = BattleCatalog.OBJETS[item_id]
	PlayerData.use_item(item_id)
	_show_message("Zylrak utilise : %s." % item.nom)
	await get_tree().create_timer(0.3).timeout
	_heal(item.soin)
	await _flash(_hero, Color(1.1, 1.5, 1.1), 0.3)
	await get_tree().create_timer(0.6).timeout
	_hide_message()

func _hero_flee() -> void:
	var foe_speed := 0.0
	var alive := _alive_foes()
	for f in alive:
		foe_speed += f.data.speed
	foe_speed /= max(1, alive.size())
	var chance: float = clamp(0.5 + 0.08 * (PlayerData.speed - foe_speed), 0.2, 0.9)
	if rng.randf() < chance:
		_show_message("Zylrak prend la fuite !")
		_hero.flip_h = true
		_hero.play("marche")
		var tw := create_tween()
		tw.tween_property(_hero, "position:x", BASE.x + 40, 0.6)
		await tw.finished
		result = "fuite"
	else:
		await _say("Impossible de fuir !", 0.9)

func _hero_step(dx: float) -> void:
	_hero.play("marche")
	var tw := create_tween()
	tw.tween_property(_hero, "position:x", HERO_HOME.x + dx, 0.2)
	await tw.finished
	_hero.play("garde")

func _hit_foe(foe: Dictionary, dmg: int, color: Color, prefix: String) -> void:
	foe.hp = max(0, foe.hp - dmg)
	_popup(prefix + str(dmg), foe.home + Vector2(0, -foe.height - 6), color)
	_shake(foe.sprite, foe.home)
	await _flash(foe.sprite, Color(2.2, 2.2, 2.2), 0.12)
	if foe.hp <= 0:
		foe.alive = false
		if foe.sprite is AnimatedSprite2D:
			foe.sprite.play("mort")
			await foe.sprite.animation_finished
		var tw := create_tween()
		tw.tween_property(foe.sprite, "modulate", Color(1.0, 0.3, 0.3, 0.0), 0.5)
		await tw.finished
		foe.sprite.visible = false
		foe.shadow.visible = false
		_refresh_foes()

func _heal(amount: int) -> void:
	var before := PlayerData.current_hp
	PlayerData.current_hp = min(PlayerData.max_hp, PlayerData.current_hp + amount)
	_popup("+%d" % (PlayerData.current_hp - before), HERO_HOME + Vector2(0, -48), Color(0.6, 1.0, 0.6))
	_refresh_hero()

func _damage(atk: int, def: int) -> int:
	return max(1, int(round(atk * rng.randf_range(0.85, 1.15) - def * 0.5)))

# =============================================================== fin du combat
func _ending() -> void:
	_hide_menu()
	match result:
		"victoire":
			var gained := 0
			for f in foes:
				gained += f.data.xp
			_hero.play("garde")
			await _say("Victoire ! Zylrak gagne %d points d'expérience." % gained, -1.0)
			for up in PlayerData.gain_xp(gained):
				await _level_up(up)
		"defaite":
			await _say("Zylrak s'effondre...", -1.0)
		"fuite":
			pass

## Montée de niveau : flash doré, braises, puis les gains et les Signes appris.
func _level_up(up: Dictionary) -> void:
	_refresh_hero()
	_embers(HERO_HOME + Vector2(0, -20), Color(1.0, 0.85, 0.4))
	_embers(HERO_HOME + Vector2(0, -34), Color(1.0, 0.7, 0.3))
	_popup("Niveau %d !" % up.level, HERO_HOME + Vector2(0, -62), Color(1.0, 0.86, 0.45))
	_flash(_hero, Color(1.8, 1.55, 0.9), 0.4)
	await _say("Zylrak passe au niveau %d !" % up.level, -1.0)
	var names := {"max_hp": "PV max", "max_energy": "EP max", "attack": "Attaque", "defense": "Défense", "magic": "Magie", "speed": "Vitesse"}
	var parts: PackedStringArray = []
	for key in names:
		if up.gains[key] > 0:
			parts.append("%s +%d" % [names[key], up.gains[key]])
	await _say(", ".join(parts), -1.0)
	for signe in up.signes:
		_embers(HERO_HOME + Vector2(0, -24), Color(1.0, 0.55, 0.15))
		await _say("Zylrak apprend le Signe : %s !" % signe, -1.0)

# =============================================================== construction
func _build_world() -> void:
	_world_layer = CanvasLayer.new()
	_world_layer.layer = 40
	add_child(_world_layer)
	_world = Node2D.new()
	_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_layer.add_child(_world)

	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = background
	if background:
		bg.scale = BASE / Vector2(background.get_size())
	_world.add_child(bg)

	# Monstres
	var slots: Array = FOE_SLOTS.get(clamp(monster_list.size(), 1, 3))
	var counts := {}
	for m in monster_list:
		counts[m.display_name] = counts.get(m.display_name, 0) + 1
	var seen := {}
	for i in min(monster_list.size(), 3):
		var data: MonsterData = monster_list[i]
		var home: Vector2 = slots[i]
		var shadow := _shadow(home, 16)
		shadow.visible = data.shadow
		var s: Node2D
		# Hauteur réellement dessinée (au-dessus des pieds), pour placer la flèche de cible et les dégâts.
		var height := 48.0
		if data.lpc_sheet:
			# Monstre du générateur LPC : animé, même format de planche que Zylrak.
			var a := AnimatedSprite2D.new()
			a.sprite_frames = _lpc_monster_frames(data.lpc_sheet)
			a.offset = Vector2(0, -28)
			a.flip_h = data.flip_h
			a.play("repos")
			var used := a.sprite_frames.get_frame_texture("repos", 0).get_image().get_used_rect()
			height = (60 - used.position.y) * data.sprite_scale
			s = a
		else:
			var sp := Sprite2D.new()
			sp.texture = data.texture
			sp.centered = false
			sp.flip_h = data.flip_h
			if data.texture:
				var size := Vector2(data.texture.get_size())
				sp.offset = Vector2(-size.x / 2.0, -size.y + 2)
				var used2 := data.texture.get_image().get_used_rect()
				height = (data.texture.get_height() - used2.position.y) * data.sprite_scale
			s = sp
		s.scale = Vector2(data.sprite_scale, data.sprite_scale)
		s.position = home
		_world.add_child(s)
		var label := data.display_name
		if counts[data.display_name] > 1:
			seen[data.display_name] = seen.get(data.display_name, 0) + 1
			label += " " + "ABC"[seen[data.display_name] - 1]
		foes.append({"data": data, "hp": data.max_hp, "alive": true, "sprite": s, "shadow": shadow, "home": home, "name": label, "height": height})

	# Zylrak, tourné vers la gauche
	_shadow(HERO_HOME, 14)
	_hero = AnimatedSprite2D.new()
	_hero.sprite_frames = _hero_frames()
	_hero.offset = Vector2(0, -28)
	_hero.position = HERO_HOME
	_world.add_child(_hero)
	_hero.play("garde")
	_hero.animation_finished.connect(func():
		if _hero.animation == "coup" or _hero.animation == "sort":
			_hero.play("garde"))

	# Curseur de cible (petit triangle doré au-dessus du monstre visé)
	_target_cursor = Node2D.new()
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(-5, -7), Vector2(5, -7), Vector2(0, 0)])
	tri.color = Color(0.1, 0.07, 0.04)
	var tri2 := Polygon2D.new()
	tri2.polygon = PackedVector2Array([Vector2(-3.5, -6), Vector2(3.5, -6), Vector2(0, -1.5)])
	tri2.color = Color(1.0, 0.85, 0.4)
	_target_cursor.add_child(tri)
	_target_cursor.add_child(tri2)
	_target_cursor.visible = false
	_world.add_child(_target_cursor)

func _hero_frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation("default")
	# Planche LPC : cases de 64 px (garde, marche, sort, blessure), cases de 128 px pour le grand coup d'épée.
	# Rangées dans l'ordre haut / gauche / bas / droite : on prend la gauche.
	# (La « garde de combat » de la planche est dessinée sans la tenue : on prend la pose de repos, épée en main.)
	_add_anim(f, "garde", 64, 23, 2, 2.0, true)
	_add_anim(f, "marche", 64, 9, 9, 12.0, true, 1)
	_add_anim(f, "sort", 64, 1, 7, 12.0, false)
	_add_anim(f, "blesse", 64, 20, 6, 10.0, false)
	var slash_y := 3456 + 128  # coup d'épée en grand format, rangée « gauche »
	f.add_animation("coup")
	f.set_animation_loop("coup", false)
	f.set_animation_speed("coup", 14.0)
	for i in 6:
		var at := AtlasTexture.new()
		at.atlas = ZYLRAK_SHEET
		at.region = Rect2(i * 128, slash_y, 128, 128)
		f.add_frame("coup", at)
	return f

## Animations d'un monstre LPC tourné vers la droite (rangées « droite » de la planche).
## Les planches du générateur ont une rangée « repos » (rangée 25) ; les plus anciennes non :
## on prend alors la première image de la marche.
func _lpc_monster_frames(sheet: Texture2D) -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation("default")
	if sheet.get_height() >= 26 * 64:
		_add_sheet_anim(f, sheet, "repos", 25, 2, 2.0, true)
	else:
		_add_sheet_anim(f, sheet, "repos", 11, 1, 1.0, true)
	_add_sheet_anim(f, sheet, "attaque", 15, 6, 14.0, false)
	_add_sheet_anim(f, sheet, "mort", 20, 6, 10.0, false)
	return f

func _add_sheet_anim(f: SpriteFrames, sheet: Texture2D, name: String, row: int, count: int, fps: float, loop: bool) -> void:
	f.add_animation(name)
	f.set_animation_loop(name, loop)
	f.set_animation_speed(name, fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 64, row * 64, 64, 64)
		f.add_frame(name, at)

func _add_anim(f: SpriteFrames, name: String, cell: int, row: int, count: int, fps: float, loop: bool, first := 0) -> void:
	f.add_animation(name)
	f.set_animation_loop(name, loop)
	f.set_animation_speed(name, fps)
	for i in range(first, count):
		var at := AtlasTexture.new()
		at.atlas = ZYLRAK_SHEET
		at.region = Rect2(i * cell, row * cell, cell, cell)
		f.add_frame(name, at)

func _shadow(pos: Vector2, rx: float) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * rx * 0.28))
	p.polygon = pts
	p.color = Color(0, 0, 0, 0.32)
	p.position = pos + Vector2(0, 1)
	_world.add_child(p)
	return p

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 41
	add_child(_ui_layer)

	_foe_panel = _panel()
	_foe_names = VBoxContainer.new()
	_foe_panel.add_child(_foe_names)

	_menu_panel = _panel()
	_menu_box = VBoxContainer.new()
	_menu_panel.add_child(_menu_box)
	_menu_panel.visible = false
	_menu_cursor = Polygon2D.new()
	_menu_cursor.polygon = PackedVector2Array([Vector2(0, -9), Vector2(12, 0), Vector2(0, 9)])
	_menu_cursor.color = Color(1.0, 0.85, 0.4)
	_menu_cursor.visible = false
	_ui_layer.add_child(_menu_cursor)

	_hero_panel = _panel()
	var hero_box := VBoxContainer.new()
	_hero_panel.add_child(hero_box)
	_name_label = _label("", _font_size(), GOLD)
	hero_box.add_child(_name_label)
	_hp_label = _label("", _font_size(), TEXT)
	hero_box.add_child(_hp_label)
	_hp_bar = _bar(Color(0.75, 0.22, 0.18))
	hero_box.add_child(_hp_bar)
	_ep_label = _label("", _font_size(), TEXT)
	hero_box.add_child(_ep_label)
	_ep_bar = _bar(Color(0.88, 0.52, 0.18))
	hero_box.add_child(_ep_bar)

	_message_panel = _panel()
	_message_label = _label("", _font_size(), TEXT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_panel.add_child(_message_label)
	_message_panel.visible = false

	_refresh_foes()
	_refresh_hero()

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	_zoom = max(screen.x / BASE.x, screen.y / BASE.y)
	_offset = (screen - BASE * _zoom) / 2.0
	_world_layer.transform = Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, _offset)
	var m := screen.y * 0.02
	var h := screen.y * 0.25
	var y := screen.y - h - m
	_foe_panel.position = Vector2(m, y)
	_foe_panel.size = Vector2(screen.x * 0.30, h)
	_menu_panel.position = Vector2(m * 2 + screen.x * 0.30, y)
	_menu_panel.size = Vector2(screen.x * 0.26, h)
	_hero_panel.position = Vector2(m * 3 + screen.x * 0.56, y)
	_hero_panel.size = Vector2(screen.x - (m * 4 + screen.x * 0.56), h)
	_message_panel.position = Vector2(screen.x * 0.2, m)
	_message_panel.size = Vector2(screen.x * 0.6, screen.y * 0.09)
	for p in [_foe_panel, _menu_panel, _hero_panel, _message_panel]:
		var child: Control = p.get_child(0)
		child.position = Vector2(m * 1.6, m * 1.1)
		child.size = p.size - Vector2(m * 3.2, m * 2.2)
	_place_menu_cursor()

func _panel() -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.13, 0.93)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	_ui_layer.add_child(p)
	return p

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, _font_size() * 0.4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.03, 0.05)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b

func _font_size() -> int:
	return int(round(get_viewport().get_visible_rect().size.y / 1080.0 * 30.0))

func _refresh_foes() -> void:
	if _foe_names == null:
		return
	for c in _foe_names.get_children():
		c.queue_free()
	for f in foes:
		if f.alive:
			_foe_names.add_child(_label(f.name, _font_size(), TEXT))

func _refresh_hero() -> void:
	_name_label.text = "Zylrak    Niv. %d" % PlayerData.level
	_hp_label.text = "PV  %d / %d" % [PlayerData.current_hp, PlayerData.max_hp]
	_ep_label.text = "EP  %d / %d" % [PlayerData.current_energy, PlayerData.max_energy]
	_hp_bar.max_value = PlayerData.max_hp
	_hp_bar.value = PlayerData.current_hp
	_ep_bar.max_value = PlayerData.max_energy
	_ep_bar.value = PlayerData.current_energy

func _place_menu_cursor() -> void:
	if _menu_cursor == null or not _menu_panel.visible or _menu_box.get_child_count() <= menu_index:
		if _menu_cursor:
			_menu_cursor.visible = false
		return
	var l: Control = _menu_box.get_child(menu_index)
	_menu_cursor.visible = true
	_menu_cursor.position = l.global_position + Vector2(-_font_size() * 0.7, l.size.y / 2.0)

func _place_target_cursor() -> void:
	var alive := _alive_foes()
	if alive.is_empty():
		return
	var f: Dictionary = alive[_target_index]
	_target_cursor.position = f.home + Vector2(0, -f.height - 2)
	_target_cursor.visible = true

# =============================================================== messages et effets
## Affiche un message. `duration` < 0 : attend que le joueur appuie sur Entrée.
func _say(text: String, duration: float) -> void:
	_show_message(text)
	state = "message"
	if duration < 0.0:
		_waiting_message = true
		await _message_closed
		_waiting_message = false
	else:
		await get_tree().create_timer(duration).timeout
	_hide_message()

func _show_message(text: String) -> void:
	_message_label.text = text
	_message_panel.visible = true

func _hide_message() -> void:
	_message_panel.visible = false

func _popup(text: String, world_pos: Vector2, color: Color) -> void:
	var l := _label(text, int(_font_size() * 1.5), color)
	l.add_theme_constant_override("outline_size", 8)
	_ui_layer.add_child(l)
	l.reset_size()
	var p := world_pos * _zoom + _offset - l.size / 2.0
	l.position = p
	var tw := create_tween()
	tw.tween_property(l, "position:y", p.y - _font_size() * 1.6, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.tween_callback(l.queue_free)

func _flash(node: CanvasItem, color: Color, duration: float) -> void:
	node.self_modulate = color
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(node):
		node.self_modulate = Color(1, 1, 1)

func _shake(node: Node2D, home: Vector2) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(node, "position:x", home.x + (3 if i % 2 == 0 else -3), 0.04)
	tw.tween_property(node, "position:x", home.x, 0.04)

## Petites braises qui montent (effet des Signes).
func _embers(at: Vector2, color: Color) -> void:
	for i in 10:
		var e := Polygon2D.new()
		e.polygon = PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)])
		e.color = color.lightened(rng.randf_range(0.0, 0.4))
		e.position = at + Vector2(rng.randf_range(-14, 14), rng.randf_range(-10, 14))
		_world.add_child(e)
		var tw := create_tween()
		tw.tween_property(e, "position:y", e.position.y - rng.randf_range(16, 30), rng.randf_range(0.5, 0.8))
		tw.parallel().tween_property(e, "modulate:a", 0.0, 0.6).set_delay(0.2)
		tw.tween_callback(e.queue_free)

# =============================================================== utilitaires
func _alive_foes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in foes:
		if f.alive:
			out.append(f)
	return out

func _distinct_names() -> int:
	var names := {}
	for f in foes:
		names[f.data.display_name] = true
	return names.size()

func _with_article(name: String) -> String:
	return "Une " + name.to_lower() if name.ends_with("e") else "Un " + name.to_lower()
