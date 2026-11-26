extends FenetreParchemin
class_name Boutique

## La boutique d'herbes et de potions de Myrtille (maison des jumelles). La liste des articles à
## gauche, la fiche à droite ; Entrée achète un article, s'il y a assez d'écus.

## [objet (BattleCatalog.OBJETS), prix en écus]
const STOCK := [["potion", 15], ["fiole", 20], ["antidote", 12]]
const DESC := {
	"potion": "Une potion rouge, épaisse et sucrée. Rend %d PV.",
	"fiole": "Une fiole bleue qui sent la menthe et l'orage. Rend %d PM.",
	"antidote": "Une décoction amère d'herbes des marais. Soigne le venin des araignées, en combat ou depuis le grimoire (le venin, lui, ne part pas tout seul).%s",
}

var _note: Label

func _ready() -> void:
	super._ready()
	set_title("Herbes et potions de Myrtille")
	set_footer("↑ ↓  choisir      Entrée  acheter      Échap  sortir")
	_run.call_deferred()

func _run() -> void:
	list.moved.connect(func(k: int): _show(k, ""))
	_refresh()
	_show(0, "")
	while true:
		var i: int = await list.choose()
		if i < 0:
			break
		var id: String = STOCK[i][0]
		var price: int = STOCK[i][1]
		if PlayerData.spend_ecus(price):
			Sons.play("achat")
			PlayerData.inventory.append(id)
			_refresh()
			_show(i, "Acheté ! « Merci, et reviens vite. »")
		else:
			Sons.play("erreur")
			_show(i, "Pas assez d'écus.")
	close()

func _refresh() -> void:
	var names: Array = []
	for s in STOCK:
		names.append("%s   %d écus" % [BattleCatalog.OBJETS[s[0]].nom, s[1]])
	list.set_entries(names)
	set_side("%d écus" % PlayerData.ecus)

func _show(k: int, note: String) -> void:
	clear_card()
	var id: String = STOCK[k][0]
	var item: Dictionary = BattleCatalog.OBJETS[id]
	icon(UiKit.icon(id), Vector2(50, 40), 128)
	ink(item.nom, 34, Vector2(210, 56), UiKit.INK_GOLD)
	ink("%d écus" % STOCK[k][1], 26, Vector2(212, 108), UiKit.INK_SOFT)
	ink(DESC[id] % item.get("soin", item.get("mana", "")), 26, Vector2(56, 210), UiKit.INK, 720)
	ink("Dans ton sac : %d" % PlayerData.inventory.count(id), 24, Vector2(56, 330), UiKit.INK_SOFT)
	if note != "":
		ink(note, 26, Vector2(56, CARD_SIZE.y - 90), UiKit.INK_GOLD, 720)
