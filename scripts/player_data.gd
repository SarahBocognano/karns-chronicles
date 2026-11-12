extends Node

## Stocke tout ce qui doit survivre à un changement de scène.

## Émis à chaque changement de flag (les PNJ s'en servent pour leur « ! »).
signal flag_changed(flag_name: String, value: bool)

## true pendant un dialogue ou une scène scriptée : Zylrak ne peut plus bouger.
var controls_locked: bool = false

# --- Progression / état du joueur ---
var current_hp: int = 20
var max_hp: int = 20
## Énergie des Signes (la magie des Ashwardens).
var current_energy: int = 12
var max_energy: int = 12
var attack: int = 7      # coups d'épée
var defense: int = 3     # réduit les dégâts reçus
var magic: int = 6       # puissance des Signes
var speed: int = 6       # ordre de jeu en combat, chances de fuite
var level: int = 1
var xp: int = 0          # expérience totale depuis le début

const MAX_LEVEL := 30

## Expérience totale nécessaire pour atteindre le niveau `n` (niveau 2 : 20, 3 : 50, 4 : 90, 5 : 140…).
static func xp_for_level(n: int) -> int:
	return 5 * (n - 1) * (n + 2)

## Gains de statistiques en passant au niveau `n`.
static func level_gains(n: int) -> Dictionary:
	return {
		"max_hp": 4,
		"max_energy": 2,
		"attack": 1,
		"defense": 1 if n % 2 == 0 else 0,
		"magic": 1,
		"speed": 1 if n % 3 == 0 else 0,
	}

## Ajoute de l'expérience et applique les montées de niveau.
## Renvoie une entrée par niveau gagné : {"level", "gains", "signes"} (signes = Signes appris).
func gain_xp(amount: int) -> Array[Dictionary]:
	xp += amount
	var ups: Array[Dictionary] = []
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
		var gains := level_gains(level)
		max_hp += gains.max_hp
		current_hp += gains.max_hp
		max_energy += gains.max_energy
		current_energy += gains.max_energy
		attack += gains.attack
		defense += gains.defense
		magic += gains.magic
		speed += gains.speed
		var learned: Array[String] = []
		for s in BattleCatalog.SIGNES:
			if s.get("niveau", 1) == level:
				learned.append(s.nom)
		ups.append({"level": level, "gains": gains, "signes": learned})
	return ups

## Signes que Zylrak connaît à son niveau actuel.
func known_signs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in BattleCatalog.SIGNES:
		if s.get("niveau", 1) <= level:
			out.append(s)
	return out
## Objets, un identifiant par exemplaire (voir BattleCatalog.OBJETS).
var inventory: Array[String] = ["potion", "potion", "potion"]

func count_item(item_id: String) -> int:
	return inventory.count(item_id)

func use_item(item_id: String) -> bool:
	var i := inventory.find(item_id)
	if i == -1:
		return false
	inventory.remove_at(i)
	return true

# --- Flags de quête (simple pour l'instant, on structurera plus tard si besoin) ---
var quest_flags: Dictionary = {
	"has_accepted_zylrak_quest": false,  # quête principale, donnée par Oswin à l'auberge
	"has_defeated_chariot_monster": false,
	"talked_to_brenna": false,           # première conversation avec Brenna
	"aldric_quest_started": false,       # Brenna a demandé de retrouver son frère Aldric
	"aelis_rejected_once": false,        # Aelis a remballé Zylrak une première fois
	"aelis_rejected_twice": false,       # … puis une deuxième : elle l'ignore
	"talked_to_torvald": false,          # Torvald a parlé des cris près des ruines
	"talked_to_theobald": false,         # Théobald a parlé des Yrenn et de leurs symboles
	"barnabe_contest_done": false,       # concours de chopes perdu contre Barnabé
	"talked_to_mirabelle": false,        # Mirabelle, qui arrose ses fleurs sur la place
	"mirabelle_aldric_done": false,      # Mirabelle a parlé d'Aldric (après la demande de Brenna)
	"talked_to_godric": false,           # Godric, le vieux bûcheron, oncle d'Aldric et de Brenna
	"godric_talked_about_aldric": false, # Godric a dit où Aldric allait couper du bois
	"talked_to_pepin": false,            # Pépin, le gamin qui se moque de Zylrak
	"talked_to_inconnu": false,          # l'inconnu encapuchonné de l'auberge
	"found_merchant_cart": false,        # chariot du marchand retrouvé dans la forêt (indices vers les ruines)
}

# --- Système de spawn entre scènes ---
var next_spawn_point: String = ""
## Direction dans laquelle Zylrak regarde ("up", "down", "left", "right"), gardée d'une carte à l'autre.
var facing: String = "down"

func set_flag(flag_name: String, value: bool) -> void:
	quest_flags[flag_name] = value
	flag_changed.emit(flag_name, value)

func get_flag(flag_name: String) -> bool:
	return quest_flags.get(flag_name, false)
