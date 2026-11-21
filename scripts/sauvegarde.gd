extends Node

## Sauvegardes (autoload « Sauvegarde ») : 3 emplacements, un fichier JSON chacun dans
## user://sauvegardes/. On peut sauvegarder partout depuis le menu (hors combat et hors scène).
## Une sauvegarde retient l'état de Zylrak et d'Ysolde (voir PlayerData.to_dict), la carte et
## la position exacte de Zylrak, le temps de jeu et la date.
## S'occupe aussi de la nouvelle partie et du retour à l'écran titre.

const SLOTS := 3
const DIR := "user://sauvegardes/"
const VERSION := 1
const TITLE_SCENE := "res://scenes/EcranTitre.tscn"
## Nouvelle partie : l'intro, puis Zylrak arrive au village par la route de la forêt et marche
## jusqu'à l'auberge (scenes/maps/arrivee_village.gd), où Oswin lui tombe dessus.
const INTRO_SCENE := "res://scenes/Intro.tscn"
const NEW_GAME_SCENE := "res://scenes/maps/VillageV2Map.tscn"
const NEW_GAME_SPAWN := "SpawnFromForest"

## Nom des lieux, affiché dans le menu et sur les emplacements de sauvegarde.
const PLACES := {
	"VillageMap": "Le village",
	"VillageV2Map": "Le village",
	"MaisonJumellesMap": "Eclatvin · la maison des jumelles",
	"AubergeMap": "L'auberge",
	"AubergeEtageMap": "L'auberge · l'étage",
	"WeaponsShopMap": "La forge",
	"ForestMap": "La forêt · la lisière",
	"ForestCascadeMap": "La forêt · la cascade",
	"LacMap": "La forêt · le lac aux Brumes",
	"ForestChariotMap": "La forêt · le chariot",
	"RuinesMonteeMap": "Ruines des Yrenn · la montée",
	"RuinesParvisMap": "Ruines des Yrenn · le parvis",
	"TempleVestibuleMap": "Temple des Yrenn · le vestibule",
	"TempleGalerieMap": "Temple des Yrenn · la galerie",
	"TempleGardienMap": "Temple des Yrenn · la salle du gardien",
	"GrotteEntreeMap": "La grotte du sentier · l'entrée",
	"GrotteToilesMap": "La grotte du sentier · les toiles",
	"GrotteFilonMap": "La grotte du sentier · le filon",
}

## Dossier des sauvegardes (les tests en utilisent un autre).
var dir := DIR
## État de départ (pour « Nouvelle partie »), pris au lancement du jeu.
var _defaults := {}

func _ready() -> void:
	_defaults = PlayerData.to_dict()

func _process(delta: float) -> void:
	# Le temps de jeu avance sur les cartes (pas sur l'écran titre, ni menu ouvert : l'arbre est en pause).
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != TITLE_SCENE:
		PlayerData.play_time += delta

## Nom du lieu où se trouve Zylrak.
func place_name(scene: Node = null) -> String:
	if scene == null:
		scene = get_tree().current_scene
	return PLACES.get(scene.name, scene.name) if scene else ""

static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]

## "2026-11-19 14:02:33" -> "19/11/2026 à 14:02"
static func format_date(iso: String) -> String:
	var parts := iso.replace("T", " ").split(" ")
	if parts.size() < 2:
		return iso
	var d := parts[0].split("-")
	if d.size() != 3:
		return iso
	return "%s/%s/%s à %s" % [d[2], d[1], d[0], parts[1].left(5)]

func _path(slot: int) -> String:
	return dir + "emplacement_%d.json" % (slot + 1)

## Résumé d'un emplacement (lieu, niveau, temps, date), ou {} s'il est vide.
func slot_info(slot: int) -> Dictionary:
	if not FileAccess.file_exists(_path(slot)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	if typeof(data) != TYPE_DICTIONARY or not data.has("joueur"):
		return {}
	return data

func has_any_save() -> bool:
	return latest_slot() != -1

## Emplacement sauvegardé le plus récemment (-1 : aucun).
func latest_slot() -> int:
	var best := -1
	var best_time := -1
	for i in SLOTS:
		if FileAccess.file_exists(_path(i)):
			var t := FileAccess.get_modified_time(_path(i))
			if t > best_time:
				best_time = t
				best = i
	return best

## Peut-on sauvegarder maintenant ? (pas en combat, ni pendant une scène ou un dialogue)
func can_save() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.begins_with("res://scenes/maps/") and not SceneTransition.in_battle

func save(slot: int) -> bool:
	var scene := get_tree().current_scene
	var player := Cutscene.find_player(get_tree())
	if scene == null or player == null:
		return false
	var data := {
		"version": VERSION,
		"carte": scene.scene_file_path,
		"lieu": place_name(scene),
		"position": [player.global_position.x, player.global_position.y],
		"date": Time.get_datetime_string_from_system(false, true),
		"joueur": PlayerData.to_dict(),
	}
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible : %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true

## Charge l'emplacement : rétablit l'état, puis ouvre la carte, Zylrak à sa position sauvegardée.
func load_slot(slot: int) -> bool:
	var data := slot_info(slot)
	if data.is_empty():
		return false
	_reset_world()
	PlayerData.from_dict(_defaults)
	PlayerData.from_dict(data.joueur)
	var pos: Array = data.get("position", [])
	if pos.size() == 2:
		PlayerData.load_position = Vector2(pos[0], pos[1])
	SceneTransition.change_scene(data.carte, "")
	return true

func new_game() -> void:
	_reset_world()
	PlayerData.from_dict(_defaults)
	SceneTransition.change_scene(INTRO_SCENE, "")

## Fin de l'intro (ou intro passée) : la partie commence à l'entrée du village.
func begin_adventure() -> void:
	_reset_world()
	PlayerData.facing = "up"
	PlayerData.arrival_pending = true
	SceneTransition.change_scene(NEW_GAME_SCENE, NEW_GAME_SPAWN)

func to_title() -> void:
	_reset_world()
	SceneTransition.change_scene(TITLE_SCENE, "")

func _reset_world() -> void:
	get_tree().paused = false
	PlayerData.controls_locked = false
	PlayerData.arrival_pending = false
	SceneTransition.in_battle = false
