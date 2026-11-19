extends Node

## Énigme de la porte du temple des Yrenn (carte du parvis).
## 1. Découverte (première arrivée, flag "porte_temple_vue") : Zylrak suit tout seul les traces de sang
##    jusqu'aux dalles devant la porte ; Ysolde et lui découvrent le sceau et les quatre encoches.
##    Les fragments gravés apparaissent alors dans les ruines (voir fragment_yrenn.gd).
## 2. Sur les dalles : s'il manque des fragments, Zylrak le dit ; sinon on les pose dans l'ordre
##    (menu DallesMenu). L'ordre qui ouvre la porte : lune, loup, épée, flamme (indice de Théobald).
## 3. Bon ordre : les pierres s'illuminent, le sceau se brise (flag "temple_ouvert").
##    Mauvais ordre : les pierres ressortent de leurs encoches.

const SOLUTION: Array[String] = ["lune", "loup", "epee", "flamme"]

## Où Zylrak s'arrête devant les dalles pendant la découverte.
@export var stop_path: NodePath
@export var sceau_path: NodePath
## Zone des dalles (Area2D) : y entrer lance l'énigme.
@export var plates_zone_path: NodePath
## Centre de l'encoche I (la plus à gauche) ; les suivantes sont décalées de `slot_step`.
@export var first_slot := Vector2.ZERO
@export var slot_step := Vector2(32, 0)
## Recul de Zylrak quand il quitte les dalles (pour ne pas rester dans la zone).
@export var push_back := Vector2(0, 26)
@export var discovery: DialogueConversation
@export var discovery_hint: DialogueConversation      # s'il a parlé à Théobald
@export var discovery_no_hint: DialogueConversation   # sinon
@export var wrong_order: DialogueConversation
@export var wrong_hint: DialogueConversation
@export var wrong_no_hint: DialogueConversation
@export var opening: DialogueConversation
@export var opened: DialogueConversation               # en revenant devant la porte ouverte

var _stones: Node2D
var _busy := false

func _ready() -> void:
	# Les pierres posées vont avec le décor au sol (sous les personnages).
	_stones = Node2D.new()
	_stones.name = "PierresPosees"
	var ground_decor := get_parent().get_node_or_null("DetailsSol")
	(ground_decor if ground_decor else get_parent()).add_child.call_deferred(_stones)
	if PlayerData.get_flag("temple_ouvert"):
		_show_stones.call_deferred(SOLUTION, true)
	var zone := get_node_or_null(plates_zone_path) as Area2D
	if zone:
		zone.body_entered.connect(_on_plates_entered)
	if not PlayerData.get_flag("porte_temple_vue"):
		_discover.call_deferred()

# --- 1. Découverte ---

func _discover() -> void:
	var player := Cutscene.find_player(get_tree())
	if player == null:
		return
	_busy = true
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	add_child(cs)
	await cs.wait(0.6)   # fin du fondu d'arrivée
	if not is_inside_tree():
		return   # la carte a changé pendant la scène (on arrête tout)
	await player.walk_to((get_node(stop_path) as Node2D).global_position, 70.0)
	if not is_inside_tree():
		return
	player.face("up")
	await cs.wait(0.4)
	if not is_inside_tree():
		return
	await cs.say(discovery.lines)
	if not is_inside_tree():
		return
	var extra := discovery_hint if PlayerData.get_flag("talked_to_theobald") else discovery_no_hint
	if extra:
		await cs.say(extra.lines)
		if not is_inside_tree():
			return
	PlayerData.set_flag("porte_temple_vue", true)
	cs.queue_free()
	player.global_position += push_back
	PlayerData.controls_locked = false
	_busy = false

# --- 2. Les dalles ---

func _on_plates_entered(body: Node2D) -> void:
	if _busy or PlayerData.controls_locked or not (body is CharacterBody2D and body.is_in_group("Player")):
		return
	if not PlayerData.get_flag("porte_temple_vue"):
		return
	if PlayerData.get_flag("temple_ouvert"):
		_talk(opened.lines, body)
		return
	var n := FragmentYrenn.found_count()
	if n < SOLUTION.size():
		var lines: Array[DialogueLine] = [
			_line("Zylrak", "zylrak_reflexion", "Quatre encoches..." if n == 0 else "J'ai %d pierre%s sur quatre." % [n, "" if n == 1 else "s"]),
			_line("Ysolde", "ysolde_neutre", "Il en manque encore %d. Cherchons dans les ruines, en bas aussi." % (SOLUTION.size() - n)),
		]
		_talk(lines, body)
		return
	_open_menu(body)

func _talk(lines: Array[DialogueLine], player: Node2D) -> void:
	_busy = true
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	add_child(cs)
	await cs.say(lines)
	if not is_inside_tree():
		return
	cs.queue_free()
	player.global_position += push_back
	PlayerData.controls_locked = false
	_busy = false

func _open_menu(player: Node2D) -> void:
	_busy = true
	PlayerData.controls_locked = true
	var menu := DallesMenu.new()
	menu.slots_changed.connect(func(order: Array): _show_stones(order, false))
	menu.cancelled.connect(func():
		_show_stones([], false)
		player.global_position += push_back
		PlayerData.controls_locked = false
		_busy = false)
	menu.done.connect(func(order: Array): _check(order, player))
	add_child(menu)

## Les pierres posées sur les dalles (dans le monde, derrière le menu).
func _show_stones(order: Array, lit: bool) -> void:
	for c in _stones.get_children():
		c.queue_free()
	for i in order.size():
		var s := Sprite2D.new()
		s.texture = FragmentYrenn.texture_for(order[i])
		s.position = first_slot + slot_step * i
		s.scale = Vector2(0.9, 0.9)
		if lit:
			s.modulate = Color(1.3, 1.5, 1.8)
		_stones.add_child(s)

# --- 3. Bon ou mauvais ordre ---

func _check(order: Array, player: Node2D) -> void:
	var cs := Cutscene.new()
	add_child(cs)
	await cs.wait(0.3)
	if not is_inside_tree():
		return
	if Array(order) == Array(SOLUTION):
		await _open_door(cs)
	else:
		await _wrong(cs)
	if not is_inside_tree():
		return
	cs.queue_free()
	player.global_position += push_back
	PlayerData.controls_locked = false
	_busy = false

func _open_door(cs: Cutscene) -> void:
	# Les pierres s'illuminent l'une après l'autre, puis le sceau se brise.
	for i in _stones.get_child_count():
		var s := _stones.get_child(i) as Sprite2D
		create_tween().tween_property(s, "modulate", Color(1.3, 1.5, 1.8), 0.25)
		await cs.wait(0.3)
		if not is_inside_tree():
			return
	var sceau := get_node_or_null(sceau_path)
	if sceau:
		await sceau.dissipate()
		if not is_inside_tree():
			return
	PlayerData.set_flag("temple_ouvert", true)
	await cs.say(opening.lines)

func _wrong(cs: Cutscene) -> void:
	# Les pierres rougeoient, puis ressortent de leurs encoches.
	for s in _stones.get_children():
		create_tween().tween_property(s, "modulate", Color(1.6, 0.5, 0.4), 0.2)
	await cs.wait(0.6)
	if not is_inside_tree():
		return
	_show_stones([], false)
	await cs.say(wrong_order.lines)
	if not is_inside_tree():
		return
	var extra := wrong_hint if PlayerData.get_flag("talked_to_theobald") else wrong_no_hint
	if extra:
		await cs.say(extra.lines)

static func _line(speaker: String, portrait: String, text: String) -> DialogueLine:
	var l := DialogueLine.new()
	l.speaker_name = speaker
	l.portrait = load("res://assets/portrait/%s.tres" % portrait)
	l.text = text
	return l
