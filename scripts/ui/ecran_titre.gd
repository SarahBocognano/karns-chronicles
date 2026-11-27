extends Control

## Écran titre : le ciel d'aube et les sommets (ceux du parvis du temple), qui défilent lentement,
## le titre du jeu, et le menu : Continuer, Nouvelle partie, Charger, Quitter.

const SKY := preload("res://assets/sprites/backdrops/ciel_aube.png")
const FAR := preload("res://assets/sprites/backdrops/sommets_loin.png")
const NEAR := preload("res://assets/sprites/backdrops/sommets_pres.png")
const MUSIC := preload("res://assets/audio/musique/village.wav")
const K := 3   # images de 640 px de large, agrandies pour remplir l'écran (1920)
enum { CONTINUER, NOUVELLE, CHARGER, QUITTER }

var _far: TextureRect
var _near: TextureRect
var _menu: ListeMenu
var _slots_panel: Panel

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Le décor se cale sur le bas de l'écran (la fenêtre peut être plus haute que 16:9).
	var h := maxf(1080.0, get_viewport_rect().size.y)
	var sky := _layer(SKY, 0.0)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = Vector2(1920, h)
	_far = _layer(FAR, h - FAR.get_height() * K - 150)
	_near = _layer(NEAR, h - NEAR.get_height() * K)
	var title := UiKit.label("Karn's Chronicles", 120, UiKit.GOLD)
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1920, 160)
	title.position = Vector2(0, 150)
	add_child(title)
	var sub := UiKit.label("Le Serment des Cendres", 52, UiKit.TEXT)
	sub.add_theme_constant_override("outline_size", 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(1920, 80)
	sub.position = Vector2(0, 310)
	add_child(sub)
	_menu = ListeMenu.new()
	_menu.font_size = 40
	_menu.spacing = 18
	_menu.cancelable = false
	_menu.position = Vector2(800, 560)
	var saved := Sauvegarde.has_any_save()
	# Sur le web, « Quitter » ne ferait rien : le joueur ferme simplement l'onglet.
	var entries := ["Continuer", "Nouvelle partie", "Charger"]
	if not OS.has_feature("web"):
		entries.append("Quitter")
	_menu.set_entries(entries, [saved, true, saved, true].slice(0, entries.size()))
	add_child(_menu)
	Musique.play(MUSIC)
	_run.call_deferred()

func _layer(tex: Texture2D, y: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiKit.px(tex, K)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.size = Vector2(1920 * 2, tex.get_height() * K)
	r.position = Vector2(0, y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _process(delta: float) -> void:
	# Les sommets défilent lentement (les plus proches un peu plus vite).
	_far.position.x = fposmod(_far.position.x - 8.0 * delta, 1920.0) - 1920.0
	_near.position.x = fposmod(_near.position.x - 18.0 * delta, 1920.0) - 1920.0

func _run() -> void:
	while true:
		var i := await _menu.choose()
		match i:
			CONTINUER:
				Sauvegarde.load_slot(Sauvegarde.latest_slot())
				return
			NOUVELLE:
				Sauvegarde.new_game()
				return
			CHARGER:
				var slot := await _choose_slot()
				if slot >= 0:
					Sauvegarde.load_slot(slot)
					return
			QUITTER:
				get_tree().quit()
				return

## Liste des emplacements ; -1 si on revient en arrière.
func _choose_slot() -> int:
	_menu.visible = false
	_slots_panel = UiKit.panel(Vector2(360, 500), Vector2(1200, 420))
	add_child(_slots_panel)
	var t := UiKit.label("Charger une partie", 34, UiKit.GOLD)
	t.position = Vector2(90, 58)
	_slots_panel.add_child(t)
	var entries: Array[String] = []
	var enabled: Array = []
	for i in Sauvegarde.SLOTS:
		var d := Sauvegarde.slot_info(i)
		enabled.append(not d.is_empty())
		entries.append("%d.   — vide —" % (i + 1) if d.is_empty() else "%d.   %s   ·   Niv. %d   ·   %s" % [i + 1, d.lieu, int(d.joueur.level), Sauvegarde.format_time(d.joueur.play_time)])
	var list := ListeMenu.new()
	list.position = Vector2(90, 130)
	list.font_size = 30
	list.spacing = 24
	list.index = Sauvegarde.latest_slot()
	list.set_entries(entries, enabled)
	_slots_panel.add_child(list)
	var i := await list.choose()
	_slots_panel.queue_free()
	_menu.visible = true
	return i
