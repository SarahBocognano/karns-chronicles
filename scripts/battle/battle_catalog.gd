class_name BattleCatalog

## niveau : niveau de Zylrak à partir duquel il connaît le Signe.
const SIGNES: Array[Dictionary] = [
	{"id": "feu", "nom": "Feu", "cout": 4, "type": "degats", "puissance": 1.8, "niveau": 1},
	{"id": "rempart", "nom": "Rempart de cendres", "cout": 3, "type": "protection", "tours": 3, "niveau": 2},
	{"id": "phoenix", "nom": "Phoenix", "cout": 5, "type": "soin", "soin": 0.4, "niveau": 3},
]

const OBJETS: Dictionary = {
	"potion": {"nom": "Potion", "soin": 15},
}
