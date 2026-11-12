extends Node

## À placer comme enfant d'un personnage : au chargement de la carte, le personnage n'est présent
## que si les conditions sont remplies (sinon il est retiré de la scène).
## Ex. Ysolde est dans la forêt avant la rencontre, puis au village après.

## Flags de PlayerData qui doivent être à true.
@export var required_flags: Array[String] = []
## Flags de PlayerData qui doivent être à false.
@export var forbidden_flags: Array[String] = []

func _ready() -> void:
	for flag in required_flags:
		if not PlayerData.get_flag(flag):
			get_parent().queue_free()
			return
	for flag in forbidden_flags:
		if PlayerData.get_flag(flag):
			get_parent().queue_free()
			return
