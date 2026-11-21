extends FenetreParchemin
class_name PanneauContratsUI

## Le panneau des contrats (voir scripts/contrats.gd) : les affiches à gauche, le détail à droite.
## Entrée sur un contrat : « Accepter / Plus tard ». Un contrat accepté passe dans le journal.

func _ready() -> void:
	super._ready()
	set_title("Panneau des contrats")
	set_side("%d écus" % PlayerData.ecus)
	_run.call_deferred()

func _run() -> void:
	if not Contrats.board_open():
		set_footer("Entrée  ·  Échap  fermer")
		ink("Le panneau est vide.", 32, Vector2(60, 60), UiKit.INK_GOLD)
		ink("Quelques clous rouillés, des bouts de papier arrachés... Rien d'intéressant pour l'instant.", 26, Vector2(60, 130), UiKit.INK, 720)
		await wait_key()
		close()
		return
	set_footer("↑ ↓  choisir      Entrée  lire / accepter      Échap  fermer")
	list.moved.connect(_show)
	while true:
		_refresh_list()
		_show(list.index)
		var i: int = await list.choose()
		if i < 0:
			break
		var c: Dictionary = Contrats.LIST[i]
		if Contrats.accepted(c.id):
			continue
		var answer: int = await ask(["Accepter le contrat", "Plus tard"], Vector2(60, CARD_SIZE.y - 120))
		if answer == 0:
			PlayerData.set_flag(Contrats.flag_for(c.id), true)
	close()

func _refresh_list() -> void:
	var names: Array = []
	for c in Contrats.LIST:
		names.append(("✓ " if Contrats.accepted(c.id) else "") + c.titre)
	list.set_entries(names)

func _show(k: int) -> void:
	clear_card()
	var c: Dictionary = Contrats.LIST[k]
	ink(c.titre, 34, Vector2(60, 40), UiKit.INK_GOLD)
	ink("Commanditaire : " + c.commanditaire, 24, Vector2(62, 96), UiKit.INK_SOFT)
	ink("Lieu : " + c.lieu, 24, Vector2(62, 128), UiKit.INK_SOFT)
	ink("Récompense : " + c.recompense, 24, Vector2(62, 160), UiKit.INK_SOFT)
	ink(c.texte, 26, Vector2(60, 214), UiKit.INK, 720)
	if Contrats.accepted(c.id):
		ink("Contrat accepté : voir le journal du grimoire.", 24, Vector2(60, CARD_SIZE.y - 80), UiKit.INK_GOLD)
