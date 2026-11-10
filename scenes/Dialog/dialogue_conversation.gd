extends Resource
class_name DialogueConversation

## Une conversation d'un PNJ avec Zylrak.
## Le PNJ joue la PREMIÈRE conversation de sa liste dont les conditions sont remplies.

@export var lines: Array[DialogueLine] = []

@export_group("Conditions")
## Flags de PlayerData qui doivent être à true pour que la conversation soit disponible.
@export var required_flags: Array[String] = []
## Flags de PlayerData qui doivent être à false.
@export var forbidden_flags: Array[String] = []

@export_group("Effets")
## Flags passés à true dans PlayerData à la fin de la conversation.
@export var flags_on_finish: Array[String] = []
## Affiche un « ! » au-dessus du PNJ tant que cette conversation est disponible.
@export var show_quest_marker: bool = false
## Se lance toute seule à l'arrivée dans la scène : le PNJ marche vers Zylrak puis lui parle.
@export var auto_start: bool = false

## `get_flag` : fonction qui renvoie la valeur d'un flag (en jeu : PlayerData.get_flag).
func is_available(get_flag: Callable) -> bool:
	if lines.is_empty():
		return false
	for flag in required_flags:
		if not get_flag.call(flag):
			return false
	for flag in forbidden_flags:
		if get_flag.call(flag):
			return false
	return true
