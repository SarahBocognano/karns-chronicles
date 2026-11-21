extends "res://scenes/maps/npc_dialogue.gd"

## Une marchande : on lui parle comme à un autre PNJ (ses conversations), puis sa boutique s'ouvre
## (scripts/ui/boutique.gd). Myrtille, l'herboriste, jumelle de Mirabelle.

var _shopping := false

func end_dialogue() -> void:
	super.end_dialogue()
	if _shopping:
		return
	_shopping = true
	var shop := Boutique.new()
	get_tree().root.add_child(shop)
	await shop.closed
	_shopping = false
