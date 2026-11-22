extends Node

## Contrat du voleur : dès que les cinq indices sont réunis (Contrats.CLUES), et que Zylrak a les
## mains libres, il fait le point tout haut (flag "voleur_deduction") : Pépin cache un chien à la
## lisière. Posé sur les cartes où l'on trouve des indices.

const LINES := preload("res://resources/dialogues/voleur/deduction.tres")

var _busy := false

func _process(_delta: float) -> void:
	if _busy or PlayerData.get_flag("voleur_deduction") or Contrats.clue_count() < Contrats.CLUES.size():
		return
	if PlayerData.controls_locked or SceneTransition.in_battle or get_tree().paused:
		return
	_busy = true
	PlayerData.controls_locked = true
	var cs := Cutscene.new()
	add_child(cs)
	await get_tree().create_timer(0.4).timeout
	await cs.say(LINES.lines)
	cs.queue_free()
	PlayerData.set_flag("voleur_deduction", true)
	PlayerData.controls_locked = false
	_busy = false
