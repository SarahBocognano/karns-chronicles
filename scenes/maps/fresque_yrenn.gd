extends Node2D
class_name FresqueYrenn

## Fresque des Yrenn, dans un mur du temple, qui luit doucement. Deux styles :
## - "murale" : une dalle gravée encadrée de pierre, le symbole en turquoise (le vestibule) ;
## - "medaillon" : un médaillon serti de pierres bleues, le symbole au centre (la salle du gardien).
## Si elle a une conversation, Zylrak la lit avec la touche d'action quand il se tient au pied du
## mur, juste dessous (flag "fresque_<symbole>_lue" pour les fresques murales) : ce que montre la
## fresque, puis ce qu'en disent Zylrak et Ysolde. Le nœud est au centre de la fresque.

const SHEET := preload("res://assets/sprites/tilesets/Temple/castle_interriors.png")
const MEDALLION := Rect2(864, 320, 64, 64)
const GLYPHS := preload("res://assets/sprites/objets/temple/glyphes_yrenn.png")
const GLYPH_SIZE := 24
const MURALS := preload("res://assets/sprites/objets/temple/fresques_murales.png")
const MURAL_SIZE := Vector2(64, 96)

@export_enum("murale", "medaillon") var style: String = "murale"
@export_enum("lune", "loup", "epee", "flamme") var symbol: String = "lune"
@export var conversation: DialogueConversation
## Où se tient Zylrak pour la lire (au pied du mur), par rapport au nœud.
@export var read_spot: Vector2 = Vector2(0, 96)
## Distance (en pixels) à `read_spot` jusqu'à laquelle Zylrak peut la lire.
@export var reach: float = 40.0

var _glyph: Sprite2D   # ce qui luit (le symbole du médaillon, ou toute la fresque murale)
var _t := 0.0
var _busy := false

static func flag_for(s: String) -> String:
	return "fresque_%s_lue" % s

func _ready() -> void:
	if style == "murale":
		_glyph = Sprite2D.new()
		_glyph.texture = MURALS
		_glyph.region_enabled = true
		_glyph.region_rect = Rect2(Vector2(FragmentYrenn.SYMBOLS.find(symbol) * MURAL_SIZE.x, 0), MURAL_SIZE)
		add_child(_glyph)
		return
	var medallion := Sprite2D.new()
	medallion.texture = SHEET
	medallion.region_enabled = true
	medallion.region_rect = MEDALLION
	add_child(medallion)
	_glyph = Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = GLYPHS
	a.region = Rect2(FragmentYrenn.SYMBOLS.find(symbol) * GLYPH_SIZE, 0, GLYPH_SIZE, GLYPH_SIZE)
	_glyph.texture = a
	_glyph.position = Vector2(0, 1)
	add_child(_glyph)

func _process(delta: float) -> void:
	# le symbole respire, un peu plus fort tant qu'on ne l'a pas lu
	_t += delta
	var k := 0.5 + 0.5 * sin(_t * 2.2)
	if style == "murale":
		_glyph.modulate = Color(1.0, 1.0 + 0.12 * k, 1.0 + 0.1 * k)
	else:
		var lo := 0.75 if PlayerData.get_flag(flag_for(symbol)) else 0.85
		k = lo + (1.0 - lo) * k
		_glyph.modulate = Color(k * 1.25, k * 1.3, k * 1.45, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if _busy or conversation == null or PlayerData.controls_locked or not event.is_action_pressed("interact"):
		return
	var player := Cutscene.find_player(get_tree())
	if player == null or player.global_position.distance_to(global_position + read_spot) > reach:
		return
	get_viewport().set_input_as_handled()
	_read(player)

func _read(player: Node2D) -> void:
	_busy = true
	PlayerData.controls_locked = true
	if player.has_method("face"):
		player.face("up")
	if style == "medaillon":
		var tw := create_tween()
		tw.tween_property(_glyph, "scale", Vector2(1.25, 1.25), 0.2)
		tw.tween_property(_glyph, "scale", Vector2.ONE, 0.3)
	var cs := Cutscene.new()
	get_tree().current_scene.add_child(cs)
	await cs.say(conversation.lines)
	cs.queue_free()
	if style == "murale":
		PlayerData.set_flag(flag_for(symbol), true)
	PlayerData.controls_locked = false
	_busy = false
