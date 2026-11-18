class_name BattleCatalog

## niveau : niveau de Zylrak à partir duquel il connaît le Signe.
const SIGNES: Array[Dictionary] = [
	{"id": "feu", "nom": "Feu", "cout": 4, "type": "degats", "puissance": 1.8, "niveau": 1},
	{"id": "rempart", "nom": "Rempart de cendres", "cout": 3, "type": "protection", "tours": 3, "niveau": 1},
	{"id": "phoenix", "nom": "Phoenix", "cout": 5, "type": "soin", "soin": 0.4, "niveau": 2},
]

## Talents d'Ysolde (coût en mana). type : "percant" (ignore la défense), "pluie" (tous les ennemis).
const TALENTS: Array[Dictionary] = [
	{"id": "percante", "nom": "Flèche perçante", "cout": 3, "type": "percant", "puissance": 1.5},
	{"id": "pluie", "nom": "Pluie de flèches", "cout": 5, "type": "pluie", "puissance": 0.8},
]

## soin : PV rendus ; mana : mana rendu.
const OBJETS: Dictionary = {
	"potion": {"nom": "Potion", "soin": 15},
	"fiole": {"nom": "Fiole de mana", "mana": 8},
}

## Ce qu'Ysolde peut dérober aux monstres (Pillage) : [objet, poids].
const BUTIN := [["potion", 3], ["fiole", 2]]
