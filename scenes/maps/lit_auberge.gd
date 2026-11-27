extends Node2D

## Un lit de l'étage de l'auberge, qu'Oswin loue pour la nuit : Zylrak (et Ysolde) y dorment
## contre quelques écus, et se réveillent avec tous leurs PV et PM, guéris du venin.
## Une petite étincelle le signale ; on l'examine avec la touche d'action, juste à côté.

const PRICE := 5

## Distance (en pixels) à laquelle Zylrak peut s'y coucher.
@export var reach := 40.0
## Position de l'étincelle, par rapport au nœud.
@export var sparkle_at := Vector2(0, -24)

var _t := 0.0
var _busy := false

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse := maxf(0.0, sin(_t * 2.6))
	if pulse <= 0.05:
		return
	var c := Color(1.0, 0.95, 0.8, pulse)
	var r := 2.0 + 3.0 * pulse
	draw_line(sparkle_at - Vector2(r, 0), sparkle_at + Vector2(r, 0), c, 1.0)
	draw_line(sparkle_at - Vector2(0, r), sparkle_at + Vector2(0, r), c, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if _busy or PlayerData.controls_locked or not event.is_action_pressed("interact"):
		return
	var player := Cutscene.find_player(get_tree())
	if player == null or player.global_position.distance_to(global_position) > reach:
		return
	get_viewport().set_input_as_handled()
	_offer()

func _offer() -> void:
	_busy = true
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	get_tree().current_scene.add_child(cs)
	var duo := PlayerData.ysolde_in_party()
	if _rested():
		await cs.say(_lines("Un lit propre, qui sent la lavande. %s pas sommeil pour l'instant." % ("Ni Zylrak ni Ysolde n'ont" if duo else "Zylrak n'a")))
	else:
		var ask := _narration("Un lit propre, qui sent la lavande. Oswin loue la nuit %d écus." % PRICE)
		var choice := await cs.choose(["Dormir (%d écus)" % PRICE, "Pas maintenant"], ask)
		if choice == 0:
			if PlayerData.ecus < PRICE:
				var broke := _narration("Je n'ai pas de quoi payer la nuit...")
				broke.speaker_name = "Zylrak"
				broke.portrait = load("res://assets/portrait/zylrak_embarrassé.tres")
				var broke_lines: Array[DialogueLine] = [broke]
				await cs.say(broke_lines)
			else:
				await _sleep(cs, duo)
	cs.queue_free()
	PlayerData.controls_locked = false
	_busy = false

## Tout le monde est déjà en pleine forme : rien à payer.
func _rested() -> bool:
	var full := PlayerData.current_hp >= PlayerData.max_hp and PlayerData.current_energy >= PlayerData.max_energy \
		and PlayerData.venin.is_empty()
	if PlayerData.ysolde_in_party():
		full = full and PlayerData.ysolde_hp >= PlayerData.ysolde_max_hp() and PlayerData.ysolde_energy >= PlayerData.ysolde_max_energy()
	return full

func _sleep(cs: Cutscene, duo: bool) -> void:
	PlayerData.ecus -= PRICE
	Sons.play("ecus")
	await SceneTransition.fade(1.0, 0.8)
	PlayerData.current_hp = PlayerData.max_hp
	PlayerData.current_energy = PlayerData.max_energy
	PlayerData.restore_ysolde()
	PlayerData.venin.clear()
	await cs.wait(1.2)
	await SceneTransition.fade(0.0, 0.8)
	Sons.play("soin")
	var who := "Zylrak et Ysolde dorment" if duo else "Zylrak dort"
	await cs.say(_lines("%s d'une traite. PV et PM rechargés." % who))

static func _narration(text: String) -> DialogueLine:
	var l := DialogueLine.new()
	l.text = text
	return l

static func _lines(text: String) -> Array[DialogueLine]:
	var out: Array[DialogueLine] = [_narration(text)]
	return out
