extends Node2D
class_name Coffre

## Coffre posé dans le décor : Zylrak l'ouvre avec la touche d'action quand il est juste à côté.
## Il donne son contenu une seule fois (flag "coffre_<carte>_<nom du nœud>", gardé dans la sauvegarde),
## puis reste ouvert. Le contenu est un objet (BattleCatalog.OBJETS : potion, fiole…) ou une pièce
## d'équipement (BattleCatalog.EQUIPEMENTS), à équiper ensuite dans le grimoire.
## Sprites générés avec Copilot dans le style de nos tuiles (Szadi art) : coffre en bois cerclé de fer
## pour les objets, coffre précieux (dorures, pierre bleue) pour l'équipement. 4 images, du coffre
## fermé au coffre grand ouvert.

const SHEET_OBJETS := preload("res://assets/sprites/objets/coffres/coffre_bois.png")
const SHEET_EQUIPEMENT := preload("res://assets/sprites/objets/coffres/coffre_precieux.png")
const FRAMES := 4
const SPRITE_SCALE := 1.0

## Identifiant d'un objet ou d'une pièce d'équipement.
@export var contenu: String = "potion"
@export var quantite: int = 1
## Distance (en pixels) à laquelle Zylrak peut l'ouvrir.
@export var reach: float = 40.0

var _sprite: Sprite2D
var _busy := false

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET_EQUIPEMENT if BattleCatalog.EQUIPEMENTS.has(contenu) else SHEET_OBJETS
	_sprite.hframes = FRAMES
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	var h := _sprite.texture.get_height()
	_sprite.offset = Vector2(0, -h / 2.0 + 2)   # posé au sol, le pied à l'origine
	add_child(_sprite)
	# on ne traverse pas un coffre
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 10)
	shape.shape = r
	shape.position = Vector2(0, -5)
	body.add_child(shape)
	add_child(body)
	_refresh()

func flag_name() -> String:
	var map: String = owner.name if owner else (get_tree().current_scene.name if get_tree().current_scene else "")
	return "coffre_%s_%s" % [map, name]

func is_open() -> bool:
	return PlayerData.get_flag(flag_name())

func _refresh() -> void:
	_sprite.frame = FRAMES - 1 if is_open() else 0

func _unhandled_input(event: InputEvent) -> void:
	if _busy or is_open() or PlayerData.controls_locked or not event.is_action_pressed("interact"):
		return
	var player := Cutscene.find_player(get_tree())
	if player == null or player.global_position.distance_to(global_position) > reach:
		return
	get_viewport().set_input_as_handled()
	_open()

## Nom affiché du contenu, avec la quantité.
func contents_label() -> String:
	var nom: String = contenu
	if BattleCatalog.OBJETS.has(contenu):
		nom = BattleCatalog.OBJETS[contenu].nom
	elif BattleCatalog.EQUIPEMENTS.has(contenu):
		nom = BattleCatalog.EQUIPEMENTS[contenu].nom
	return nom + (" ×%d" % quantite if quantite > 1 else "")

func _open() -> void:
	_busy = true
	PlayerData.controls_locked = true
	var gear := BattleCatalog.EQUIPEMENTS.has(contenu)
	if gear:
		if not PlayerData.owns_gear(contenu):
			PlayerData.gear_bag.append(contenu)
	else:
		for i in quantite:
			PlayerData.inventory.append(contenu)
	PlayerData.set_flag(flag_name(), true)
	Sons.play("coffre")
	# le couvercle s'ouvre (4 images)
	for f in FRAMES:
		_sprite.frame = f
		await get_tree().create_timer(0.09).timeout
	Sons.play("objet_rare" if gear else "objet")
	var cs := Cutscene.new()
	get_tree().current_scene.add_child(cs)
	var text := "Zylrak trouve : %s." % contents_label()
	if gear:
		text += "  (À équiper dans le grimoire, onglet Équipement.)"
	var line := DialogueLine.new()
	line.speaker_name = ""
	line.text = text
	var lines: Array[DialogueLine] = [line]
	await cs.say(lines)
	cs.queue_free()
	PlayerData.controls_locked = false
	_busy = false
