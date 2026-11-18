extends Node2D
class_name FragmentYrenn

## Fragment de pierre gravé des Yrenn, posé dans le décor des ruines (énigme de la porte du temple).
## Il n'apparaît qu'une fois la porte scellée découverte (flag "porte_temple_vue") ; une petite
## étincelle le signale. Zylrak le ramasse avec la touche d'action quand il est juste à côté
## (flag "fragment_<symbole>"). L'ordre attendu sur les dalles : lune, loup, épée, flamme.

const SHEET := preload("res://assets/sprites/objets/fragments_yrenn.png")
const SIZE := 24
## Les quatre symboles, dans l'ordre de la feuille (et dans l'ordre qui ouvre la porte).
const SYMBOLS: Array[String] = ["lune", "loup", "epee", "flamme"]
const ENGRAVED := {"lune": "une lune", "loup": "une tête de loup", "epee": "une épée", "flamme": "une flamme"}

@export_enum("lune", "loup", "epee", "flamme") var symbol: String = "lune"
## Distance (en pixels) à laquelle Zylrak peut le ramasser.
@export var reach: float = 34.0

var _sprite: Sprite2D
var _t := 0.0
var _busy := false

static func flag_for(s: String) -> String:
	return "fragment_" + s

static func found_count() -> int:
	var n := 0
	for s in SYMBOLS:
		if PlayerData.get_flag(flag_for(s)):
			n += 1
	return n

## Image d'un fragment (pour les dalles et le menu de l'énigme).
static func texture_for(s: String) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = SHEET
	a.region = Rect2(SYMBOLS.find(s) * SIZE, 0, SIZE, SIZE)
	return a

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture_for(symbol)
	_sprite.offset = Vector2(0, -SIZE / 2.0 + 3)   # posé au sol, le pied à l'origine
	add_child(_sprite)
	PlayerData.flag_changed.connect(func(_f: String, _v: bool): _refresh())
	_refresh()

func _refresh() -> void:
	visible = PlayerData.get_flag("porte_temple_vue") and not PlayerData.get_flag(flag_for(symbol))

func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()

## Petite étincelle qui scintille au-dessus de la pierre, pour qu'on la remarque.
func _draw() -> void:
	var pulse := maxf(0.0, sin(_t * 2.6))
	if pulse <= 0.05:
		return
	var c := Color(0.85, 0.96, 1.0, pulse)
	var p := Vector2(6, -18)
	var r := 2.0 + 3.0 * pulse
	draw_line(p - Vector2(r, 0), p + Vector2(r, 0), c, 1.0)
	draw_line(p - Vector2(0, r), p + Vector2(0, r), c, 1.0)
	draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, pulse))

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _busy or PlayerData.controls_locked or not event.is_action_pressed("interact"):
		return
	var player := Cutscene.find_player(get_tree())
	if player == null or player.global_position.distance_to(global_position) > reach:
		return
	get_viewport().set_input_as_handled()
	_pick_up()

func _pick_up() -> void:
	_busy = true
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	get_tree().current_scene.add_child(cs)
	var lines: Array[DialogueLine] = [_line("Zylrak", "zylrak_reflexion", "Un éclat de pierre, gravé d'%s... Il brille d'une drôle de lueur bleue." % ENGRAVED[symbol])]
	PlayerData.set_flag(flag_for(symbol), true)
	var n := found_count()
	if n < SYMBOLS.size():
		lines.append(_line("Zylrak", "zylrak_normal", "Et de %d. Il en reste %d à trouver pour les encoches de la porte." % [n, SYMBOLS.size() - n]))
	else:
		lines.append(_line("Ysolde", "ysolde_sourire", "C'est la dernière ! Retournons à la porte du temple."))
	await cs.say(lines)
	cs.queue_free()
	PlayerData.controls_locked = false
	_busy = false

static func _line(speaker: String, portrait: String, text: String) -> DialogueLine:
	var l := DialogueLine.new()
	l.speaker_name = speaker
	l.portrait = load("res://assets/portrait/%s.tres" % portrait)
	l.text = text
	return l
