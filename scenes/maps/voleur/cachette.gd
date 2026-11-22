extends Node2D

## Contrat du voleur : la cachette de Pépin, dans les herbes hautes de la lisière (ForestMap).
## Elle apparaît quand Zylrak a compris (flag "voleur_deduction"). Quand il approche : Pépin et son
## chien Croûton, la viande séchée de Margot, puis des goules attaquent (combat sans fuite) ; Pépin
## rend la bourse, et Zylrak choisit : garder Croûton (il le suit et flaire des objets cachés) ou le
## laisser à Pépin (qui offre son trésor). Les bottes de paille restent ensuite.

const DECO := preload("res://assets/sprites/tilesets/Buildings/FL_Houses_decoratives.png")
const KID := preload("res://assets/sprites/characters/child_spritesheet.png")
const DOG := preload("res://assets/sprites/characters/chien_crouton.png")
const BLANKET := preload("res://assets/sprites/objets/voleur/couverture.png")
const CUSHION := preload("res://assets/sprites/objets/voleur/coussin.png")
const MEET := preload("res://resources/dialogues/voleur/cachette.tres")
const AFTER := preload("res://resources/dialogues/voleur/apres_goules.tres")
const KEEP := preload("res://resources/dialogues/voleur/choix_garder.tres")
const LEAVE := preload("res://resources/dialogues/voleur/choix_laisser.tres")
const GHOUL := preload("res://resources/monsters/goule.tres")
const BATTLE_BG := preload("res://assets/battle_backgrounds/battle_foret.png")

## [région de la planche, pied (par rapport au nœud), solide]
const BALES := [[Rect2(481, 513, 41, 58), Vector2(-30, -6), true], [Rect2(426, 523, 44, 40), Vector2(14, -10), true],
	[Rect2(388, 543, 28, 32), Vector2(44, 2), true], [Rect2(132, 352, 24, 32), Vector2(-56, 6), false],
	[Rect2(134, 318, 24, 24), Vector2(34, 22), false]]

var _kid: AnimatedSprite2D
var _dog: AnimatedSprite2D
var _busy := false

func _ready() -> void:
	if not PlayerData.get_flag("voleur_deduction"):
		queue_free()
		return
	y_sort_enabled = true
	for b in BALES:
		_bale(b[0], b[1], b[2])
	# le nid (couverture, coussin) : posé au sol, trié comme s'il était plus haut, pour rester dessous
	_sprite(BLANKET, Vector2(-34, 4)).offset = Vector2(0, 20)
	_sprite(CUSHION, Vector2(-30, 2)).offset = Vector2(0, 18)
	if PlayerData.get_flag("voleur_goules_vaincues"):
		return
	_kid = _lpc_sprite(KID, Rect2(0, 10 * 64, 64, 64), Vector2(-4, 44))
	_dog = AnimatedSprite2D.new()
	var f := SpriteFrames.new()
	f.remove_animation("default")
	for spec in [["assis", 4, 1.5], ["aboie", 6, 4.0], ["queue", 4, 3.0]]:
		f.add_animation(spec[0])
		f.set_animation_speed(spec[0], spec[2])
		for i in 2:
			var at := AtlasTexture.new()
			at.atlas = DOG
			at.region = Rect2(i * 64, spec[1] * 64, 64, 64)
			f.add_frame(spec[0], at)
	_dog.sprite_frames = f
	_dog.offset = Vector2(0, -28)
	_dog.scale = Vector2(0.6, 0.6)
	_dog.position = Vector2(22, 52)
	_dog.play("assis")
	add_child(_dog)
	var zone := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 80.0
	shape.shape = circle
	shape.position = Vector2(0, 24)
	zone.add_child(shape)
	add_child(zone)
	zone.body_entered.connect(func(body: Node2D):
		if body is CharacterBody2D and body.is_in_group("Player"):
			_meet(body))

func _meet(player: Node2D) -> void:
	if _busy or PlayerData.get_flag("voleur_goules_vaincues") or PlayerData.controls_locked or SceneTransition.in_battle:
		return
	_busy = true
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	add_child(cs)
	if player.has_method("face"):
		player.face("up" if player.global_position.y > global_position.y else "down")
	_dog.play("aboie")
	await cs.say(MEET.lines)
	_dog.play("queue")
	if not is_inside_tree():
		return
	SceneTransition.start_battle(BATTLE_BG, [GHOUL, GHOUL], false)
	var result: String = await SceneTransition.battle_finished
	if result != "victoire" or not is_inside_tree():
		_busy = false   # défaite : Zylrak se réveille au village, la scène reprendra
		return
	PlayerData.controls_locked = true
	var lines: Array[DialogueLine] = AFTER.lines.duplicate()
	var last: DialogueLine = lines.pop_back()
	await cs.say(lines)
	PlayerData.return_purse()
	var choice := await cs.choose(["Garder Croûton", "Le laisser à Pépin"], last)
	PlayerData.set_flag("voleur_goules_vaincues", true)
	if choice == 0:
		PlayerData.set_flag("voleur_chien_garde", true)
		await cs.say(KEEP.lines)
		_kid_leaves()
		_dog_joins(player)
	else:
		PlayerData.set_flag("voleur_chien_pepin", true)
		await cs.say(LEAVE.lines)
		_kid_leaves()
		var tw := create_tween()
		tw.tween_property(_dog, "modulate:a", 0.0, 0.8).set_delay(0.3)
	cs.queue_free()
	PlayerData.controls_locked = false
	_busy = false

## Pépin rentre au village.
func _kid_leaves() -> void:
	var tw := create_tween()
	tw.tween_property(_kid, "position:y", _kid.position.y - 40, 0.8)
	tw.parallel().tween_property(_kid, "modulate:a", 0.0, 0.8)

## Croûton devient le compagnon de Zylrak : il part de là où il est assis.
func _dog_joins(player: Node2D) -> void:
	var dog: Node2D = load("res://scenes/characters/ChienCompagnon.tscn").instantiate()
	player.get_parent().add_child(dog)
	dog.global_position = _dog.global_position
	_dog.queue_free()

func _bale(region: Rect2, foot: Vector2, solid: bool) -> void:
	var s := Sprite2D.new()
	s.texture = DECO
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.offset = Vector2(-region.size.x / 2.0, -region.size.y + 2)
	s.position = foot
	add_child(s)
	if solid:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(region.size.x - 6, 12)
		shape.shape = r
		shape.position = Vector2(0, -6)
		body.add_child(shape)
		s.add_child(body)

func _sprite(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	add_child(s)
	return s

func _lpc_sprite(sheet: Texture2D, region: Rect2, pos: Vector2) -> AnimatedSprite2D:
	var f := SpriteFrames.new()
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = region
	f.add_frame("default", at)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = f
	s.scale = Vector2(0.7, 0.7)
	s.offset = Vector2(0, -26)   # l'origine aux pieds (tri en Y)
	s.position = pos
	add_child(s)
	return s
