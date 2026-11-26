extends "res://scripts/characters/companion.gd"

## Croûton, le chien de Pépin, quand Zylrak l'a gardé (flag "voleur_chien_garde") : il suit Zylrak
## (derrière Ysolde) et flaire les objets cachés (scenes/maps/flair_chien.gd) : quand Zylrak passe
## près d'une cachette, il court s'y arrêter et aboie ; il reprend la route une fois l'objet déterré
## ou si Zylrak s'éloigne. Planche : assets/sprites/characters/chien_crouton.png (cases de 64 px :
## marche bas, gauche, droite, haut ; assis ; renifle ; aboie).

const DOG_ROWS := {"down": 0, "left": 1, "right": 2, "up": 3}
## Distance de Zylrak à laquelle Croûton sent une cachette.
const SNIFF_RANGE := 110.0

var _spot: Node2D

func _ready() -> void:
	add_to_group("Chien")   # pas "Compagnon" : ce groupe-là, c'est Ysolde
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.offset = Vector2(0, -20)
	sprite.sprite_frames = _build_frames()
	add_child(sprite)
	face(facing)

func _physics_process(delta: float) -> void:
	if _scripted:
		return
	if _spot:
		if not is_instance_valid(_spot) or _spot.dug or _player == null or _player.global_position.distance_to(_spot.global_position) > SNIFF_RANGE * 2.0:
			_spot = null
			_trail.clear()
		return
	super._physics_process(delta)
	if _player and is_instance_valid(_player):
		for s in get_tree().get_nodes_in_group("Flair"):
			if not s.dug and s.is_inside_tree() and _player.global_position.distance_to(s.global_position) < SNIFF_RANGE:
				_sniff(s)
				break

func _sniff(spot: Node2D) -> void:
	_spot = spot
	await walk_to(spot.global_position + Vector2(-14, 4), 150.0)
	if not is_instance_valid(spot) or spot.dug:
		return
	face("right")
	_play("renifle")
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(spot) and not spot.dug:
		_play("aboie")
		Sons.play("aboiement")
		spot.reveal()

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir: String in DOG_ROWS:
		var walk := "walk_" + dir
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 9.0)
		for i in 4:
			frames.add_frame(walk, _frame(i, DOG_ROWS[dir]))
		var idle := "idle_" + dir
		frames.add_animation(idle)
		frames.add_frame(idle, _frame(0, DOG_ROWS[dir]))
	for spec in [["assis", 4, 2.0], ["renifle", 5, 5.0], ["aboie", 6, 4.0]]:
		frames.add_animation(spec[0])
		frames.set_animation_speed(spec[0], spec[2])
		for i in 2:
			frames.add_frame(spec[0], _frame(i, spec[1]))
	return frames
