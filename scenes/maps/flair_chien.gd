extends Node2D

## Un objet enfoui, que seul Croûton (scripts/characters/chien_compagnon.gd) sait trouver : quand
## il le flaire, il aboie et la terre apparaît remuée ; Zylrak creuse avec la touche d'action.
## Donne `contenu` (objet ou équipement de BattleCatalog, ou "ecus") une seule fois :
## flag "flair_<carte>_<nom du nœud>".

const MOUND := preload("res://assets/sprites/objets/voleur/monticule.png")

@export var contenu: String = "potion"
@export var quantite: int = 1
@export var reach: float = 36.0

var dug := false
var _revealed := false
var _t := 0.0

func _ready() -> void:
	add_to_group("Flair")
	dug = PlayerData.get_flag(_flag())
	z_index = -1

func _flag() -> String:
	var scene := get_tree().current_scene
	return "flair_%s_%s" % [scene.name if scene else "", name]

func reveal() -> void:
	_revealed = true
	queue_redraw()

func _process(delta: float) -> void:
	if _revealed and not dug:
		_t += delta
		queue_redraw()

func _draw() -> void:
	if not _revealed or dug:
		return
	draw_texture(MOUND, -MOUND.get_size() / 2.0)
	var pulse := maxf(0.0, sin(_t * 3.0))
	if pulse > 0.1:
		var c := Color(1.0, 0.95, 0.8, pulse)
		var r := 2.0 + 2.5 * pulse
		draw_line(Vector2(-r, -10), Vector2(r, -10), c, 1.0)
		draw_line(Vector2(0, -10 - r), Vector2(0, -10 + r), c, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if dug or not _revealed or PlayerData.controls_locked or not event.is_action_pressed("interact"):
		return
	var player := Cutscene.find_player(get_tree())
	if player == null or player.global_position.distance_to(global_position) > reach:
		return
	get_viewport().set_input_as_handled()
	_dig()

func _dig() -> void:
	dug = true
	queue_redraw()
	PlayerData.set_flag(_flag(), true)
	var what := ""
	if contenu == "ecus":
		PlayerData.ecus += quantite
		what = "%d écus" % quantite
	elif BattleCatalog.EQUIPEMENTS.has(contenu):
		PlayerData.gear_bag.append(contenu)
		what = BattleCatalog.EQUIPEMENTS[contenu].nom
	else:
		for i in quantite:
			PlayerData.inventory.append(contenu)
		what = BattleCatalog.OBJETS[contenu].nom + ("" if quantite == 1 else " ×%d" % quantite)
	var line := DialogueLine.new()
	line.text = "Zylrak gratte la terre là où Croûton aboie... et déterre : %s !" % what
	var lines: Array[DialogueLine] = [line]
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	add_child(cs)
	await cs.say(lines)
	cs.queue_free()
	PlayerData.controls_locked = false
