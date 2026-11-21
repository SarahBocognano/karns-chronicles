class_name BattleCatalog

## niveau : niveau de Zylrak à partir duquel il connaît le Signe.
const SIGNES: Array[Dictionary] = [
	{"id": "feu", "nom": "Feu", "cout": 4, "type": "degats", "puissance": 1.8, "niveau": 1},
	{"id": "rempart", "nom": "Rempart de cendres", "cout": 3, "type": "protection", "tours": 3, "niveau": 1},
	{"id": "phoenix", "nom": "Phoenix", "cout": 5, "type": "soin", "soin": 0.4, "niveau": 2},
]

## Talents d'Ysolde (coût en mana). type : "percant" (ignore la défense), "pluie" (tous les ennemis),
## "pillage" (elle dérobe un objet à un monstre ; gratuit).
const TALENTS: Array[Dictionary] = [
	{"id": "percante", "nom": "Flèche perçante", "cout": 3, "type": "percant", "puissance": 1.5},
	{"id": "pluie", "nom": "Pluie de flèches", "cout": 5, "type": "pluie", "puissance": 0.8},
	{"id": "pillage", "nom": "Pillage", "cout": 0, "type": "pillage"},
]

## soin : PV rendus ; mana : mana rendu.
const OBJETS: Dictionary = {
	"potion": {"nom": "Potion", "soin": 15},
	"fiole": {"nom": "Fiole de mana", "mana": 8},
}

## Équipement : type ("arme", "armure", "accessoire"), qui peut le porter ("zylrak", "ysolde" ou
## "tous"), bonus ajoutés aux caractéristiques (attaque, defense, magie, vitesse).
const EQUIPEMENTS: Dictionary = {
	"epee_ordre": {"nom": "Épée de l'Ordre", "type": "arme", "pour": "zylrak", "bonus": {"attaque": 1},
		"desc": "L'épée des Ashwardens, trempée dans la flamme de l'Ordre."},
	"cuir_ashwarden": {"nom": "Cuir d'Ashwarden", "type": "armure", "pour": "zylrak", "bonus": {"defense": 1},
		"desc": "Cuir renforcé de plaques de métal, usé par les routes."},
	"arc_frene": {"nom": "Arc de frêne", "type": "arme", "pour": "ysolde", "bonus": {"attaque": 1},
		"desc": "Léger et précis. Ysolde l'a taillé elle-même."},
	"brigandine": {"nom": "Brigandine légère", "type": "armure", "pour": "ysolde", "bonus": {"defense": 1},
		"desc": "Une veste de toile doublée de petites plaques d'acier : elle ne gêne pas le tir."},
	"anneau_marchand": {"nom": "Anneau du marchand", "type": "accessoire", "pour": "tous", "bonus": {"vitesse": 2},
		"desc": "Un anneau d'argent trouvé sous les caisses du chariot. Il porte le sceau d'une guilde marchande."},
	"talisman_cendres": {"nom": "Talisman des Cendres", "type": "accessoire", "pour": "zylrak", "bonus": {"magie": 2},
		"desc": "Un médaillon noirci, frappé de la flamme de l'Ordre. Il chauffe au contact de la peau."},
	"carquois_tresse": {"nom": "Carquois tressé", "type": "accessoire", "pour": "ysolde", "bonus": {"attaque": 1, "vitesse": 1},
		"desc": "Un carquois de cuir tressé, léger : les flèches viennent toutes seules sous les doigts."},
	"cotte_mailles": {"nom": "Cotte de mailles", "type": "armure", "pour": "zylrak", "bonus": {"defense": 2},
		"desc": "Une cotte de mailles un peu rouillée, oubliée dans les ruines. Lourde, mais elle tient."},
	"amulette_yrenn": {"nom": "Amulette des Yrenn", "type": "accessoire", "pour": "tous", "bonus": {"magie": 1, "defense": 1},
		"desc": "Une pierre turquoise sertie d'argent, gravée d'une lune. Elle luit faiblement dans le noir."},
}
const SLOTS := ["arme", "armure", "accessoire"]
const SLOT_NAMES := {"arme": "Arme", "armure": "Armure", "accessoire": "Accessoire"}
const STAT_NAMES := {"attaque": "Attaque", "defense": "Défense", "magie": "Magie", "vitesse": "Vitesse"}

## Ce qu'Ysolde peut dérober aux monstres (Pillage) : [objet, poids].
const BUTIN := [["potion", 3], ["fiole", 2]]
