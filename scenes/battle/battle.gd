extends Node

signal finished(result: String)
signal _menu_done(index: int)
signal _message_closed

## Taille du décor en pixels (les fonds font 480×270, affichés en plein écran).
const BASE := Vector2(480, 270)
const ZYLRAK_SHEET := preload("res://assets/sprites/characters/zylrak_with_cape_spridesheet.png")
const YSOLDE_SHEET := preload("res://assets/sprites/characters/arrow_pnj_girl.png")
const FONT := preload("res://assets/fonts/Cinzel-VariableFont_wght.ttf")
## Interface en pixel art (agrandie en nombre entier pour rester nette) :
## cadre et contour des barres de « Tiny RPG – Mana Soul GUI » (tiopalada, CC0),
## remplissages des barres de « Pixel UI Fantasy Free » (heyheythere, CC BY 4.0), main façon SNES.
const UI_SCALE := 3
const FRAME := preload("res://assets/ui/mana_soul/cadre.png")
const FRAME_MARGIN_X := 26   # largeur des volutes des coins (pixels de l'image d'origine)
const FRAME_MARGIN_Y := 18
const BAR_FRAME := preload("res://assets/ui/mana_soul/barre.png")
const BAR_RED := preload("res://assets/ui/pixel_ui_fantasy/bar_red.png")
const BAR_BLUE := preload("res://assets/ui/pixel_ui_fantasy/bar_blue.png")
const HAND := preload("res://assets/ui/main_curseur.png")

var _px_cache := {}
const HERO_HOME := Vector2(378, 178)
## Avec Ysolde : Zylrak devant, Ysolde un peu en retrait.
const ZYLRAK_DUO := Vector2(366, 160)
const YSOLDE_DUO := Vector2(412, 184)
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
## false : combat de gardien, on ne peut pas fuir.
var can_flee := true

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
var _ysolde: AnimatedSprite2D
## Position de Zylrak dans le décor (HERO_HOME seul, ZYLRAK_DUO avec Ysolde).
var hero_home := HERO_HOME
## L'équipe : [{"id": "zylrak" | "ysolde", "name", "sprite", "home", "ui"}].
var party: Array[Dictionary] = []
## Membre dont c'est le tour (son nom s'écrit en doré).
var _active_id := ""
var _rempart_turns := 0

# Interface
var _foe_panel: Panel
var _foe_names: VBoxContainer
var _hero_panel: Panel
var _menu_panel: Panel
var _menu_box: VBoxContainer
var _menu_cursor: Sprite2D
var _message_panel: Panel
var _message_label: Label

var _menu_entries: Array[String] = []
var _menu_enabled: Array[bool] = []
var menu_index := 0
var _menu_cancelable := false
var _target_index := 0
var _waiting_message := false
var _say_token := 0

## Bleu du fond de la boîte de dialogue (moyenne de son image), repris pour les panneaux de combat.
const DIALOG_BLUE := Color(0.042, 0.078, 0.121)
## Couleur du fond du cadre Mana Soul d'origine (remplacée par DIALOG_BLUE).
const FRAME_FILL := Color8(0x11, 0x13, 0x43)

## L'ennemi visé s'illumine doucement pendant le choix de la cible (comme dans les Final Fantasy).
func _process(_delta: float) -> void:
	if state != "cible":
		return
	var alive := _alive_foes()
	var glow := 1.0 + 0.35 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0))
	for k in alive.size():
		var spr: CanvasItem = alive[k].sprite
		spr.self_modulate = Color(glow, glow, glow) if k == _target_index else Color(1, 1, 1)

## Agrandit une image de pixel art d'un facteur entier, sans lissage.
## `opaque` : rend opaques les pixels déjà visibles (fond translucide du cadre d'origine)
## et passe le fond du cadre au bleu des dialogues.
func _px(tex: Texture2D, k: int, opaque := false) -> Texture2D:
	var key := "%s@%d%s" % [tex.resource_path, k, "o" if opaque else ""]
	if not _px_cache.has(key):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		if opaque:
			img.convert(Image.FORMAT_RGBA8)
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.3:
						if absf(c.r - FRAME_FILL.r) + absf(c.g - FRAME_FILL.g) + absf(c.b - FRAME_FILL.b) < 0.03:
							c = DIALOG_BLUE
						c.a = 1.0
						img.set_pixel(x, y, c)
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		_px_cache[key] = ImageTexture.create_from_image(img)
	return _px_cache[key]

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
				if _alive(_member(actor)):
					if actor == "zylrak":
						await _hero_turn()
					else:
						await _ysolde_turn()
			elif actor.alive:
				await _foe_turn(actor)
			if _alive_foes().is_empty():
				result = "victoire"
			elif _alive_party().is_empty():
				result = "defaite"
		if _rempart_turns > 0:
			_rempart_turns -= 1
	await _ending()
	state = "fin"
	finished.emit(result)

func _turn_order() -> Array:
	var order: Array = [["zylrak", PlayerData.stat("zylrak", "vitesse") + rng.randf_range(0, 3)]]
	if not _member("ysolde").is_empty():
		order.append(["ysolde", PlayerData.stat("ysolde", "vitesse") + rng.randf_range(0, 3)])
	for f in foes:
		if f.alive:
			order.append([f, f.data.speed + rng.randf_range(0, 3)])
	order.sort_custom(func(a, b): return a[1] > b[1])
	return order.map(func(e): return e[0])

func _hero_turn() -> void:
	_active_id = "zylrak"
	_refresh_hero()
	var action := await _choose_action()
	_active_id = ""
	_refresh_hero()
	_hide_menu()
	state = "anim"
	match action.type:
		"attaque":
			await _hero_attack(action.target)
		"signe":
			await _hero_sign(action.signe, action.get("target", action.get("ally", {})))
		"objet":
			await _use_item(_member("zylrak"), action.objet, action.ally)
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
	# Le monstre s'en prend à un héros encore debout, au hasard.
	var alive := _alive_party()
	var target: Dictionary = alive[rng.randi() % alive.size()]
	var dmg := _damage(foe.data.attack, _defense_of(target))
	if _rempart_turns > 0:
		dmg = max(1, dmg / 2)
	_set_hp(target, max(0, _hp(target) - dmg))
	var sprite_t: AnimatedSprite2D = target.sprite
	_popup(str(dmg), target.home + Vector2(0, -48), Color(1.0, 0.85, 0.80))
	_shake(sprite_t, target.home)
	await _flash(sprite_t, Color(1.8, 0.5, 0.45), 0.18)
	_refresh_hero()
	if _hp(target) <= 0:
		sprite_t.play("blesse")
		await get_tree().create_timer(0.3).timeout
		_show_message("%s est à terre !" % target.name)
	await get_tree().create_timer(0.55).timeout
	_hide_message()

# =============================================================== choix de Zylrak
func _choose_action() -> Dictionary:
	while true:
		var main := ["Attaque", "Signes", "Objets", "Fuite"]
		var has_items := false
		for id in BattleCatalog.OBJETS:
			if PlayerData.count_item(id) > 0:
				has_items = true
		var i := await _menu(main, [true, true, has_items, true], false)
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
					entries.append("%s  %d" % [s.nom, s.cout])
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
				if signe.type == "soin":
					var who := await _choose_ally(false)
					if who.is_empty():
						continue
					return {"type": "signe", "signe": signe, "ally": who}
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
				var ally := await _choose_ally(BattleCatalog.OBJETS[ids[k2]].has("mana"))
				if ally.is_empty():
					continue
				return {"type": "objet", "objet": ids[k2], "ally": ally}
			3:
				return {"type": "fuite"}
	return {}

## Choix d'un allié (soins, objets) : seul, Zylrak est choisi d'office.
## `mana` : l'objet rend du mana (la liste montre alors le mana de chacun).
func _choose_ally(mana: bool) -> Dictionary:
	if party.size() == 1:
		return party[0]
	var names: Array[String] = []
	var enabled: Array[bool] = []
	for m in party:
		if mana:
			names.append("%s   %d/%d" % [m.name, _mp(m), _max_mp(m)])
		else:
			names.append("%s   %d/%d" % [m.name, _hp(m), _max_hp(m)])
		enabled.append(_alive(m))
	var k := await _menu(names, enabled, true)
	return {} if k < 0 else party[k]

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
	for f in foes:
		(f.sprite as CanvasItem).self_modulate = Color(1, 1, 1)
	for l in _foe_names.get_children():
		l.add_theme_color_override("font_color", TEXT)
	_place_menu_cursor()
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
	var dmg := _damage(PlayerData.stat("zylrak", "attaque"), foe.data.defense)
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
			var dmg := int(PlayerData.stat("zylrak", "magie") * signe.puissance * rng.randf_range(0.9, 1.1)) - int(target.data.defense * 0.25)
			await _hit_foe(target, max(1, dmg), Color(1.0, 0.7, 0.35), "")
		"protection":
			_rempart_turns = signe.tours
			for m in _alive_party():
				_embers(m.home + Vector2(0, -24), Color(0.95, 0.75, 0.45))
				_flash(m.sprite, Color(1.5, 1.25, 0.8), 0.35)
			await get_tree().create_timer(0.35).timeout
			_show_message("Un rempart de cendres protège Zylrak." if party.size() == 1 else "Un rempart de cendres protège l'équipe.")
			await get_tree().create_timer(0.8).timeout
		"soin":
			var who: Dictionary = target if not target.is_empty() else _member("zylrak")
			var heal := int(ceil(_max_hp(who) * signe.soin))
			_heal(who, heal)
			_embers(who.home + Vector2(0, -24), Color(1.0, 0.6, 0.3))
			await _flash(who.sprite, Color(1.4, 1.1, 0.8), 0.3)
			await get_tree().create_timer(0.5).timeout
	if _hero.animation == "sort" and _hero.is_playing():
		await _hero.animation_finished
	_hero.play("garde")
	_hide_message()

## `user` utilise un objet sur `ally` (potion : PV ; fiole : mana).
func _use_item(user: Dictionary, item_id: String, ally: Dictionary) -> void:
	var item: Dictionary = BattleCatalog.OBJETS[item_id]
	PlayerData.use_item(item_id)
	if ally.id == user.id:
		_show_message("%s utilise : %s." % [user.name, item.nom])
	else:
		_show_message("%s donne : %s à %s." % [user.name, item.nom, ally.name])
	await get_tree().create_timer(0.3).timeout
	if item.has("soin"):
		_heal(ally, item.soin)
		await _flash(ally.sprite, Color(1.1, 1.5, 1.1), 0.3)
	if item.has("mana"):
		_restore_mana(ally, item.mana)
		await _flash(ally.sprite, Color(1.1, 1.2, 1.6), 0.3)
	await get_tree().create_timer(0.6).timeout
	_hide_message()

func _hero_flee() -> void:
	if not can_flee:
		await _say("Impossible de fuir : le gardien barre le passage !", 1.2)
		return
	var foe_speed := 0.0
	var alive := _alive_foes()
	for f in alive:
		foe_speed += f.data.speed
	foe_speed /= max(1, alive.size())
	var chance: float = clamp(0.5 + 0.08 * (PlayerData.stat("zylrak", "vitesse") - foe_speed), 0.2, 0.9)
	if rng.randf() < chance:
		_show_message("Zylrak prend la fuite !" if party.size() == 1 else "L'équipe prend la fuite !")
		var tw := create_tween().set_parallel()
		for m in _alive_party():
			m.sprite.flip_h = true
			m.sprite.play("marche")
			tw.tween_property(m.sprite, "position:x", BASE.x + 40, 0.6)
		await tw.finished
		result = "fuite"
	else:
		await _say("Impossible de fuir !", 0.9)

func _hero_step(dx: float) -> void:
	_hero.play("marche")
	var tw := create_tween()
	tw.tween_property(_hero, "position:x", hero_home.x + dx, 0.2)
	await tw.finished
	_hero.play("garde")

func _hit_foe(foe: Dictionary, dmg: int, color: Color, prefix: String) -> void:
	foe.hp = max(0, foe.hp - dmg)
	_update_hp_bar(foe)
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
		foe.bar.visible = false
		_refresh_foes()

func _heal(m: Dictionary, amount: int) -> void:
	var before := _hp(m)
	_set_hp(m, min(_max_hp(m), before + amount))
	_popup("+%d" % (_hp(m) - before), m.home + Vector2(0, -48), Color(0.6, 1.0, 0.6))
	_refresh_hero()

func _restore_mana(m: Dictionary, amount: int) -> void:
	var before := _mp(m)
	_set_mp(m, min(_max_mp(m), before + amount))
	_popup("+%d" % (_mp(m) - before), m.home + Vector2(0, -48), Color(0.6, 0.8, 1.0))
	_refresh_hero()

func _damage(atk: int, def: int) -> int:
	return max(1, int(round(atk * rng.randf_range(0.85, 1.15) - def * 0.5)))

# =============================================================== Ysolde
func _ysolde_turn() -> void:
	_active_id = "ysolde"
	_refresh_hero()
	var ys := _member("ysolde")
	var action := await _ysolde_choose()
	_active_id = ""
	_refresh_hero()
	_hide_menu()
	state = "anim"
	match action.type:
		"tir":
			await _ysolde_shoot(action.target)
		"talent":
			await _ysolde_talent(action.talent, action.get("target", {}))
		"pillage":
			await _ysolde_pillage(action.target)
		"objet":
			await _use_item(ys, action.objet, action.ally)
		"fuite":
			await _hero_flee()

func _ysolde_choose() -> Dictionary:
	while true:
		var has_items := false
		for id in BattleCatalog.OBJETS:
			if PlayerData.count_item(id) > 0:
				has_items = true
		# Même menu que Zylrak : Attaque (un tir à l'arc), Talents (dont le Pillage), Objets, Fuite.
		var i := await _menu(["Attaque", "Talents", "Objets", "Fuite"], [true, true, has_items, true], false)
		match i:
			0:
				var t := await _choose_target()
				if not t.is_empty():
					return {"type": "tir", "target": t}
			1:
				var entries: Array[String] = []
				var enabled: Array[bool] = []
				for tl in BattleCatalog.TALENTS:
					entries.append("%s  %d" % [tl.nom, tl.cout] if tl.cout > 0 else tl.nom)
					enabled.append(PlayerData.ysolde_energy >= tl.cout)
				var k := await _menu(entries, enabled, true)
				if k < 0:
					continue
				var talent: Dictionary = BattleCatalog.TALENTS[k]
				if talent.type == "pillage":
					var t3 := await _choose_target()
					if t3.is_empty():
						continue
					return {"type": "pillage", "target": t3}
				if talent.type == "pluie":
					return {"type": "talent", "talent": talent}
				var t2 := await _choose_target()
				if t2.is_empty():
					continue
				return {"type": "talent", "talent": talent, "target": t2}
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
				var ally := await _choose_ally(BattleCatalog.OBJETS[ids[k2]].has("mana"))
				if ally.is_empty():
					continue
				return {"type": "objet", "objet": ids[k2], "ally": ally}
			3:
				return {"type": "fuite"}
	return {}

## Tir simple : Ysolde bande son arc, la flèche file vers le monstre.
func _ysolde_shoot(foe: Dictionary) -> void:
	_show_message("Ysolde attaque !")
	await _bow_draw()
	await _arrow(foe)
	var dmg := _damage(PlayerData.stat("ysolde", "attaque"), foe.data.defense)
	var crit := rng.randf() < 0.15
	if crit:
		dmg = int(dmg * 1.5)
	await _hit_foe(foe, dmg, Color(1, 1, 1), "Critique ! " if crit else "")
	_ysolde.play("garde")
	_hide_message()

func _ysolde_talent(talent: Dictionary, target: Dictionary) -> void:
	PlayerData.ysolde_energy -= talent.cout
	_refresh_hero()
	_show_message("Talent : %s !" % talent.nom)
	await _bow_draw()
	match talent.type:
		"percant":
			# la flèche traverse l'armure : la défense du monstre ne compte pas
			await _arrow(target, Color(0.75, 0.9, 1.0))
			var dmg: int = max(1, int(round(PlayerData.stat("ysolde", "attaque") * talent.puissance * rng.randf_range(0.9, 1.1))))
			await _hit_foe(target, dmg, Color(0.75, 0.9, 1.0), "")
		"pluie":
			var alive := _alive_foes()
			for f in alive:
				_arrow(f, Color(1.0, 0.95, 0.8))
				await get_tree().create_timer(0.08).timeout
			await get_tree().create_timer(0.22).timeout
			for f in alive:
				var dmg := _damage(int(round(PlayerData.stat("ysolde", "attaque") * talent.puissance)), f.data.defense)
				_hit_foe(f, dmg, Color(1.0, 0.95, 0.8), "")
			await get_tree().create_timer(0.9).timeout
	_ysolde.play("garde")
	_hide_message()

## Pillage : Ysolde file jusqu'au monstre et lui dérobe un objet (une fois par monstre).
func _ysolde_pillage(foe: Dictionary) -> void:
	_show_message("Ysolde tente un pillage !")
	var home: Vector2 = YSOLDE_DUO
	_ysolde.play("marche")
	var tw := create_tween()
	tw.tween_property(_ysolde, "position", foe.home + Vector2(30, 0), 0.32).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	_shake(foe.sprite, foe.home)
	await get_tree().create_timer(0.2).timeout
	var text := ""
	if foe.get("pille", false):
		text = "Il n'y a plus rien à prendre."
	else:
		var chance: float = clamp(0.65 + 0.05 * (PlayerData.stat("ysolde", "vitesse") - foe.data.speed), 0.3, 0.95)
		if rng.randf() < chance:
			foe["pille"] = true
			var item_id := _loot()
			PlayerData.inventory.append(item_id)
			text = "Ysolde dérobe : %s !" % BattleCatalog.OBJETS[item_id].nom
			_popup(BattleCatalog.OBJETS[item_id].nom, foe.home + Vector2(0, -foe.height - 6), Color(1.0, 0.86, 0.45))
		else:
			text = "Raté ! %s se méfie." % foe.name
	var back := create_tween()
	back.tween_property(_ysolde, "position", home, 0.32).set_trans(Tween.TRANS_QUAD)
	await back.finished
	_ysolde.play("garde")
	await _say(text, 1.3)

func _loot() -> String:
	var total := 0
	for e in BattleCatalog.BUTIN:
		total += e[1]
	var r := rng.randi() % total
	for e in BattleCatalog.BUTIN:
		r -= e[1]
		if r < 0:
			return e[0]
	return BattleCatalog.BUTIN[0][0]

func _bow_draw() -> void:
	_ysolde.play("tir")
	await get_tree().create_timer(0.5).timeout

## Une flèche (petit trait) part d'Ysolde vers le monstre.
func _arrow(foe: Dictionary, color := Color(0.95, 0.9, 0.8)) -> void:
	var a := Line2D.new()
	a.points = PackedVector2Array([Vector2(-7, 0), Vector2(5, 0)])
	a.width = 1.5
	a.default_color = color
	var tip := Polygon2D.new()
	tip.polygon = PackedVector2Array([Vector2(-9, -1.5), Vector2(-6, 0), Vector2(-9, 1.5)])
	tip.color = Color(0.85, 0.85, 0.9)
	a.add_child(tip)
	var from: Vector2 = YSOLDE_DUO + Vector2(-12, -24)
	var to: Vector2 = foe.home + Vector2(0, -foe.height * 0.55)
	a.position = from
	a.rotation = (from - to).angle()
	_world.add_child(a)
	var tw := create_tween()
	tw.tween_property(a, "position", to, 0.18)
	await tw.finished
	a.queue_free()

## Animations d'Ysolde (planche LPC, rangées « gauche ») ; garde = pose debout de la marche
## (les rangées « idle » de sa planche n'ont pas tous ses vêtements).
func _ysolde_frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation("default")
	_add_sheet_anim(f, YSOLDE_SHEET, "garde", 9, 1, 1.0, true)
	f.add_animation("marche")
	f.set_animation_loop("marche", true)
	f.set_animation_speed("marche", 12.0)
	for i in range(1, 9):
		var at := AtlasTexture.new()
		at.atlas = YSOLDE_SHEET
		at.region = Rect2(i * 64, 9 * 64, 64, 64)
		f.add_frame("marche", at)
	_add_sheet_anim(f, YSOLDE_SHEET, "tir", 17, 13, 16.0, false)
	_add_sheet_anim(f, YSOLDE_SHEET, "blesse", 20, 6, 10.0, false)
	_add_sheet_anim(f, YSOLDE_SHEET, "victoire", 10, 1, 1.0, false)
	return f

# =============================================================== l'équipe
func _member(id: String) -> Dictionary:
	for m in party:
		if m.id == id:
			return m
	return {}

func _alive(m: Dictionary) -> bool:
	return not m.is_empty() and _hp(m) > 0

func _alive_party() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in party:
		if _hp(m) > 0:
			out.append(m)
	return out

func _hp(m: Dictionary) -> int:
	return PlayerData.current_hp if m.id == "zylrak" else PlayerData.ysolde_hp

func _set_hp(m: Dictionary, v: int) -> void:
	if m.id == "zylrak":
		PlayerData.current_hp = v
	else:
		PlayerData.ysolde_hp = v

func _max_hp(m: Dictionary) -> int:
	return PlayerData.max_hp if m.id == "zylrak" else PlayerData.ysolde_max_hp()

func _mp(m: Dictionary) -> int:
	return PlayerData.current_energy if m.id == "zylrak" else PlayerData.ysolde_energy

func _set_mp(m: Dictionary, v: int) -> void:
	if m.id == "zylrak":
		PlayerData.current_energy = v
	else:
		PlayerData.ysolde_energy = v

func _max_mp(m: Dictionary) -> int:
	return PlayerData.max_energy if m.id == "zylrak" else PlayerData.ysolde_max_energy()

func _defense_of(m: Dictionary) -> int:
	return PlayerData.stat("zylrak" if m.id == "zylrak" else "ysolde", "defense")

# =============================================================== fin du combat
func _ending() -> void:
	_hide_menu()
	match result:
		"victoire":
			var gained := 0
			var coins := 0
			for f in foes:
				gained += f.data.xp
				coins += maxi(1, f.data.xp / 2) + rng.randi_range(0, 2)
			PlayerData.ecus += coins
			# un héros à terre se relève avec 1 PV
			for m in party:
				if _hp(m) <= 0:
					_set_hp(m, 1)
					m.sprite.play("garde")
			_refresh_hero()
			await _victory_pose()
			if party.size() == 1:
				await _say("Victoire ! Zylrak gagne %d points d'expérience et %d écus." % [gained, coins], 2.4, true)
			else:
				await _say("Victoire ! Zylrak et Ysolde gagnent %d points d'expérience et %d écus." % [gained, coins], 2.4, true)
			for up in PlayerData.gain_xp(gained):
				await _level_up(up)
		"defaite":
			await _say("Zylrak s'effondre..." if party.size() == 1 else "Zylrak et Ysolde s'effondrent...", 2.2, true)
		"fuite":
			pass

## Zylrak se tourne vers nous, fait un petit bond, puis lève les bras (il garde la pose ensuite).
func _victory_pose() -> void:
	if _ysolde:
		_ysolde.play("victoire")
	_hero.play("bond")
	var tw := create_tween()
	tw.tween_property(_hero, "position:y", hero_home.y - 8, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hero, "position:y", hero_home.y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if _hero.animation == "bond" and _hero.is_playing():
		await _hero.animation_finished
	_hero.play("victoire")
	_embers(hero_home + Vector2(0, -40), Color(1.0, 0.85, 0.45))
	await _hero.animation_finished

## Montée de niveau : flash doré, braises, puis les gains et les Signes appris.
func _level_up(up: Dictionary) -> void:
	_refresh_hero()
	_embers(hero_home + Vector2(0, -20), Color(1.0, 0.85, 0.4))
	_embers(hero_home + Vector2(0, -34), Color(1.0, 0.7, 0.3))
	_popup("Niveau %d !" % up.level, hero_home + Vector2(0, -62), Color(1.0, 0.86, 0.45))
	_flash(_hero, Color(1.8, 1.55, 0.9), 0.4)
	await _say("Zylrak passe au niveau %d !" % up.level, 2.0, true)
	var names := {"max_hp": "PV max", "max_energy": "Mana max", "attack": "Attaque", "defense": "Défense", "magic": "Magie", "speed": "Vitesse"}
	var parts: PackedStringArray = []
	for key in names:
		if up.gains[key] > 0:
			parts.append("%s +%d" % [names[key], up.gains[key]])
	await _say(", ".join(parts), 2.8, true)
	for signe in up.signes:
		_embers(hero_home + Vector2(0, -24), Color(1.0, 0.55, 0.15))
		await _say("Zylrak apprend le Signe : %s !" % signe, 2.2, true)
	if _ysolde:
		_embers(YSOLDE_DUO + Vector2(0, -20), Color(1.0, 0.85, 0.4))
		await _say("Ysolde progresse aussi ! PV max +4, Mana max +2, Attaque +1.", 2.4, true)

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
		foes.append({"data": data, "hp": data.max_hp, "alive": true, "sprite": s, "shadow": shadow, "home": home, "name": label, "height": height, "bar": null})

	# Zylrak, tourné vers la gauche (et Ysolde, si elle est de l'équipe)
	if PlayerData.ysolde_in_party():
		hero_home = ZYLRAK_DUO
	_shadow(hero_home, 14)
	_hero = AnimatedSprite2D.new()
	_hero.sprite_frames = _hero_frames()
	_hero.offset = Vector2(0, -28)
	_hero.position = hero_home
	_world.add_child(_hero)
	_hero.play("garde")
	_hero.animation_finished.connect(func():
		if _hero.animation == "coup" or _hero.animation == "sort":
			_hero.play("garde"))
	party.append({"id": "zylrak", "name": "Zylrak", "sprite": _hero, "home": hero_home, "ui": {}})
	if PlayerData.ysolde_in_party():
		_shadow(YSOLDE_DUO, 13)
		_ysolde = AnimatedSprite2D.new()
		_ysolde.sprite_frames = _ysolde_frames()
		_ysolde.offset = Vector2(0, -28)
		_ysolde.position = YSOLDE_DUO
		_world.add_child(_ysolde)
		_ysolde.play("garde")
		_ysolde.animation_finished.connect(func():
			if _ysolde.animation == "tir":
				_ysolde.play("garde"))
		party.append({"id": "ysolde", "name": "Ysolde", "sprite": _ysolde, "home": YSOLDE_DUO, "ui": {}})
	for m in party:
		if _hp(m) <= 0:
			m.sprite.play("blesse")


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
	# Victoire : petit bond face à nous, puis les deux bras levés (rangées « bas » du saut et de l'emote).
	_add_anim(f, "bond", 64, 28, 5, 12.0, false)
	_add_anim(f, "victoire", 64, 36, 3, 8.0, false)
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

## Barre de vie d'un ennemi : la même jauge que celle de Zylrak, posée au-dessus de sa tête.
const FOE_BAR_W := 120.0   # en pixels d'écran
const FOE_BAR_GAP := 9.0   # entre le haut du monstre et le milieu de la barre, en pixels du décor

func _update_hp_bar(foe: Dictionary) -> void:
	_set_gauge(foe.bar, foe.hp, foe.data.max_hp)

func _place_foe_bars() -> void:
	for f in foes:
		var g: Control = f.bar
		if g == null:
			continue
		g.size = Vector2(FOE_BAR_W, BAR_FRAME.get_height() * GAUGE_K)
		var center: Vector2 = (f.home + Vector2(0, -f.height - FOE_BAR_GAP)) * _zoom + _offset
		g.position = center - g.size / 2.0
		_layout_gauge(g)

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
	_menu_cursor = Sprite2D.new()
	_menu_cursor.texture = _px(HAND, 2)
	_menu_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_menu_cursor.visible = false
	_ui_layer.add_child(_menu_cursor)

	# Comme dans Final Fantasy : une ligne par héros (nom, PV et PM en chiffres),
	# avec seulement la jauge de vie, fine, juste en dessous.
	_hero_panel = _panel()
	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 0)
	_hero_panel.add_child(hero_box)
	var fs := _font_size()
	var small := int(fs * 0.8)
	for m in party:
		if m != party[0]:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, fs * 0.35)
			hero_box.add_child(gap)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(fs * 0.3))
		hero_box.add_child(row)
		var name := _label(m.name, fs, TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var hp_value := _stat(row, "PV", fs, small, 3.0)
		var mp_value := _stat(row, "PM", fs, small, 1.4)
		var hp := _bar(BAR_RED, 1)
		hero_box.add_child(hp)
		m.ui = {"name": name, "hp": hp, "hp_value": hp_value, "mp_value": mp_value}

	_message_panel = _panel()
	_message_label = _label("", _font_size(), TEXT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_panel.add_child(_message_label)
	_message_panel.visible = false

	for f in foes:
		f.bar = _bar(BAR_RED)
		_ui_layer.add_child(f.bar)

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
	_message_panel.size = Vector2(screen.x * 0.6, max(screen.y * 0.09, FRAME_MARGIN_Y * UI_SCALE * 2 + 16))
	for p in [_foe_panel, _menu_panel, _hero_panel, _message_panel]:
		var child: Control = p.get_child(0)
		# Texte entre les volutes dorées du haut et du bas, avec la place de la main à gauche.
		var pad := Vector2(max(m * 2.9, 32.0 * UI_SCALE), FRAME_MARGIN_Y * UI_SCALE - 6)
		child.position = pad
		child.size = p.size - pad * 2
	_place_foe_bars()
	_place_menu_cursor()

func _panel() -> Panel:
	var p := Panel.new()
	var sb := StyleBoxTexture.new()
	sb.texture = _px(FRAME, UI_SCALE, true)
	sb.texture_margin_left = FRAME_MARGIN_X * UI_SCALE
	sb.texture_margin_right = FRAME_MARGIN_X * UI_SCALE
	sb.texture_margin_top = FRAME_MARGIN_Y * UI_SCALE
	sb.texture_margin_bottom = FRAME_MARGIN_Y * UI_SCALE
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

## Jauge de Zylrak : contour doré à pointes (Mana Soul) avec un remplissage en dégradé
## (Pixel UI Fantasy) logé à l'intérieur, le tout agrandi ×2. Valeur réglée par _set_gauge().
const GAUGE_K := 2
const GAUGE_INNER := Rect2(6, 4, 83, 7)   # intérieur du contour, en pixels de l'image d'origine

## `k` : agrandissement du contour (2 pour la vie, 1 pour la jauge de mana, plus fine).
func _bar(fill_tex: Texture2D, k: int = GAUGE_K) -> Control:
	var g := Control.new()
	g.set_meta("k", k)
	g.custom_minimum_size = Vector2(0, BAR_FRAME.get_height() * k)
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var back := ColorRect.new()
	back.name = "Fond"
	back.color = Color(0.06, 0.05, 0.10)
	g.add_child(back)
	# L'image de remplissage n'a que quelques pixels colorés au centre : on la recadre et on l'étire.
	var img := fill_tex.get_image()
	if img.is_compressed():
		img.decompress()
	var fill := TextureRect.new()
	fill.name = "Remplissage"
	fill.texture = ImageTexture.create_from_image(img.get_region(img.get_used_rect()))
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	g.add_child(fill)
	var frame := NinePatchRect.new()
	frame.name = "Cadre"
	frame.texture = _px(BAR_FRAME, k)
	frame.patch_margin_left = 8 * k
	frame.patch_margin_right = 8 * k
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.add_child(frame)
	g.set_meta("ratio", 1.0)
	g.resized.connect(func(): _layout_gauge(g))
	return g

func _layout_gauge(g: Control) -> void:
	var k := float(g.get_meta("k", GAUGE_K))
	var inner := Rect2(GAUGE_INNER.position * k, Vector2(g.size.x - (GAUGE_INNER.position.x + BAR_FRAME.get_width() - GAUGE_INNER.end.x) * k, GAUGE_INNER.size.y * k))
	var back: ColorRect = g.get_node("Fond")
	back.position = inner.position
	back.size = inner.size
	var fill: TextureRect = g.get_node("Remplissage")
	fill.position = inner.position
	fill.size = Vector2(max(0.0, inner.size.x * float(g.get_meta("ratio"))), inner.size.y)
	fill.visible = fill.size.x >= 1.0

func _set_gauge(g: Control, value: float, max_value: float) -> void:
	g.set_meta("ratio", clamp(value / max(max_value, 1.0), 0.0, 1.0))
	_layout_gauge(g)

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

## « PV  18/20 » : l'intitulé en doré, la valeur en clair (largeur fixe pour que tout s'aligne).
func _stat(row: HBoxContainer, kind: String, fs: int, small: int, width: float) -> Label:
	var k := _label(kind, small, GOLD)
	row.add_child(k)
	var value := _label("", fs, TEXT)
	value.custom_minimum_size = Vector2(fs * width, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value

func _refresh_hero() -> void:
	for m in party:
		if m.ui.is_empty():
			continue
		(m.ui.hp_value as Label).text = "%d/%d" % [_hp(m), _max_hp(m)]
		(m.ui.mp_value as Label).text = "%d" % _mp(m)
		var color := TEXT
		if _hp(m) <= 0:
			color = GREY
		elif m.id == _active_id or (_active_id == "" and party.size() == 1):
			color = GOLD
		(m.ui.name as Label).add_theme_color_override("font_color", color)
		_set_gauge(m.ui.hp, _hp(m), _max_hp(m))

func _place_menu_cursor() -> void:
	if _menu_cursor == null or not _menu_panel.visible or _menu_box.get_child_count() <= menu_index:
		if _menu_cursor:
			_menu_cursor.visible = false
		return
	var l: Control = _menu_box.get_child(menu_index)
	_menu_cursor.visible = true
	# Le bout du doigt de la main s'arrête juste avant le texte.
	_menu_cursor.position = l.global_position + Vector2(-34, l.size.y / 2.0)

## Choix de la cible : la main pointe le nom visé dans la liste des ennemis, écrit en doré
## (et l'ennemi s'illumine dans le décor, voir _process).
func _place_target_cursor() -> void:
	if _alive_foes().is_empty():
		return
	var labels := _foe_names.get_children()
	for k in labels.size():
		labels[k].add_theme_color_override("font_color", GOLD if k == _target_index else TEXT)
	if _target_index < labels.size():
		var l: Control = labels[_target_index]
		_menu_cursor.visible = true
		_menu_cursor.position = l.global_position + Vector2(-34, l.size.y / 2.0)

# =============================================================== messages et effets
## Affiche un message. `duration` < 0 : attend que le joueur appuie sur Entrée.
## `skippable` : le message se ferme tout seul après `duration`, ou plus tôt avec Entrée.
func _say(text: String, duration: float, skippable := false) -> void:
	_show_message(text)
	state = "message"
	if duration < 0.0 or skippable:
		_waiting_message = true
		_say_token += 1
		var token := _say_token
		if skippable:
			get_tree().create_timer(duration).timeout.connect(func():
				if _waiting_message and token == _say_token:
					_message_closed.emit())
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
