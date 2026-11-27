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

# --- Ysolde, l'archère (une fois qu'elle a rejoint Zylrak) ---
# Ses statistiques suivent le niveau de Zylrak ; ses PV et son mana sont gardés d'un combat à l'autre.
var ysolde_hp: int = 22
var ysolde_energy: int = 10

func ysolde_max_hp() -> int:
	return 22 + 4 * (level - 1)

func ysolde_max_energy() -> int:
	return 10 + 2 * (level - 1)

func ysolde_attack() -> int:
	return 6 + (level - 1)

func ysolde_defense() -> int:
	return 2 + (level - 1) / 2

func ysolde_speed() -> int:
	return 8 + (level - 1) / 3

## Ysolde se bat-elle aux côtés de Zylrak ?
func ysolde_in_party() -> bool:
	return get_flag("ysolde_joined")

## PV et mana d'Ysolde au maximum (quand elle rejoint Zylrak, après une défaite…).
func restore_ysolde() -> void:
	ysolde_hp = ysolde_max_hp()
	ysolde_energy = ysolde_max_energy()

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
		ysolde_hp += 4
		ysolde_energy += 2
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
# --- Équipement (voir BattleCatalog.EQUIPEMENTS) ---
## Ce que porte chaque héros, par emplacement ("" : rien).
var equipment := {
	"zylrak": {"arme": "epee_ordre", "armure": "cuir_ashwarden", "accessoire": ""},
	"ysolde": {"arme": "arc_frene", "armure": "brigandine", "accessoire": ""},
}
## Pièces d'équipement possédées mais portées par personne.
var gear_bag: Array[String] = []
## Équipement trouvé en avançant dans l'histoire : flag -> pièce gagnée (une seule fois).
const FLAG_REWARDS := {"found_merchant_cart": "anneau_marchand", "contrat_grotte_termine": "lame_braise",
	"voleur_chien_pepin": "caillou_pepin", "aldric_retrouvailles": "ruban_brenna"}
## Flags qui donnent un objet précieux (petit son de trouvaille).
const KEY_ITEM_FLAGS := ["fragment_lune", "fragment_loup", "fragment_epee", "fragment_flamme", "torche_forgeron",
	"fragment_ame_lune", "voleur_margot_vue"]
## Écus gagnés quand un flag passe à true (contrats).
const FLAG_ECUS := {"contrat_grotte_termine": 30, "contrat_voleur_termine": 40, "godric_merci_aldric": 30}
## Objets donnés quand un flag passe à true (récompense de quête).
const FLAG_ITEMS := {"quete_marchand_terminee": ["potion", "potion", "potion", "fiole", "fiole"]}

## Caractéristique d'un héros, équipement compris. hero : "zylrak" ou "ysolde" ;
## stat : "attaque", "defense", "magie" ou "vitesse".
func stat(hero: String, s: String) -> int:
	return base_stat(hero, s) + gear_bonus(hero, s)

func base_stat(hero: String, s: String) -> int:
	if hero == "ysolde":
		match s:
			"attaque": return ysolde_attack()
			"defense": return ysolde_defense()
			"vitesse": return ysolde_speed()
		return 0
	match s:
		"attaque": return attack
		"defense": return defense
		"magie": return magic
		"vitesse": return speed
	return 0

func gear_bonus(hero: String, s: String) -> int:
	var total := 0
	for slot in equipment.get(hero, {}):
		var id: String = equipment[hero][slot]
		if id != "" and BattleCatalog.EQUIPEMENTS.has(id):
			total += int(BattleCatalog.EQUIPEMENTS[id].bonus.get(s, 0))
	return total

## Équipe `id` (pris dans le sac) sur le héros ; ce qu'il portait retourne dans le sac. id "" : retirer.
func equip(hero: String, slot: String, id: String) -> void:
	var old: String = equipment[hero][slot]
	if id != "":
		gear_bag.erase(id)
	if old != "":
		gear_bag.append(old)
	equipment[hero][slot] = id

func owns_gear(id: String) -> bool:
	if gear_bag.has(id):
		return true
	for hero in equipment:
		if equipment[hero].values().has(id):
			return true
	return false

## Objets, un identifiant par exemplaire (voir BattleCatalog.OBJETS).
var inventory: Array[String] = ["potion", "potion", "potion"]

# --- Écus (la monnaie) : gagnés en combat et grâce aux contrats, dépensés chez Myrtille ---
var ecus: int = 30
## Les écus que Pépin a pris dans la bourse de Zylrak (contrat du voleur) : il les rend à la fin.
var ecus_voles: int = 0

## Le venin des araignées : héros empoisonné -> PV perdus au début de chacun de ses tours, à chaque
## combat, tant qu'il n'a pas bu d'antidote (en combat ou depuis le grimoire). Ex. {"zylrak": 3}.
var venin: Dictionary = {}

func is_poisoned(hero: String) -> bool:
	return venin.has(hero)

func cure_poison(hero: String) -> void:
	venin.erase(hero)

## Pépin vole la bourse : tous les écus passent dans `ecus_voles`.
func steal_purse() -> void:
	ecus_voles += ecus
	ecus = 0

## Pépin rend la bourse.
func return_purse() -> void:
	ecus += ecus_voles
	ecus_voles = 0

## Retire `amount` écus s'il y en a assez ; renvoie false sinon.
func spend_ecus(amount: int) -> bool:
	if amount > ecus:
		return false
	ecus -= amount
	return true

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
	"ysolde_joined": false,              # Ysolde a rencontré Zylrak aux ruines et fait équipe avec lui : elle le suit partout
	"porte_temple_vue": false,           # Zylrak et Ysolde ont découvert la porte scellée du temple : les fragments apparaissent
	"fragment_lune": false,              # fragments gravés ramassés dans les ruines (énigme de la porte)
	"fragment_loup": false,
	"fragment_epee": false,
	"fragment_flamme": false,
	"temple_ouvert": false,              # les fragments posés dans l'ordre (lune, loup, épée, flamme) : le sceau est brisé
	"temple_vestibule_vu": false,        # Zylrak et Ysolde sont entrés dans le temple (le vestibule)
	"indice_ordre_vu": false,            # le cercle de cendres du vestibule : la flamme de l'Ordre, renversée, tracée avec du sang
	"salle_gardien_vue": false,          # arrivée dans la salle du gardien, au bout de la galerie
	"gardien_temple_vaincu": false,      # le gardien corrompu est tombé
	"fragment_ame_lune": false,          # Zylrak a enfermé dans la cendre le fragment d'âme de la Bête (premier temple)
	"marchand_retrouve": false,          # le corps du marchand, au fond du temple
	"parchemin_yrenn": false,            # le parchemin de l'autel : les quatre éclats, le temple du Loup sous le lac
	"quete_marchand_terminee": false,    # Zylrak a annoncé la mort du marchand à Oswin (récompense : FLAG_ITEMS)
	"torche_forgeron": false,            # contrat de la grotte : le forgeron a donné sa torche
	"araignee_geante_vaincue": false,    # l'araignée géante, au fond de la grotte, est tombée
	"pierre_de_braise": false,           # Zylrak a détaché la pierre-de-braise du filon
	"contrat_grotte_termine": false,     # la pierre rapportée : Lame de braise et 30 écus (FLAG_REWARDS, FLAG_ECUS)
	# quête de Brenna, au lac :
	"aldric_lac_vu": false,              # arrivée au lac pendant la quête
	"aldric_traces_vues": false,         # la clairière saccagée : Aldric a fui vers l'île
	"aldric_trouve": false,              # Aldric retrouvé sur l'île, les goules des brumes repoussées
	"aldric_sauve": false,               # Aldric ramené à la rive : il rentre au village
	"aldric_retrouvailles": false,       # Brenna remercie Zylrak (Ruban de Brenna)
	"godric_merci_aldric": false,        # Godric remercie Zylrak (30 écus)
	"mirabelle_aldric_fleurs": false,
	# contrat du voleur (voir Contrats.steps) :
	"voleur_bourse_volee": false,        # Pépin a bousculé Zylrak sur la place et pris sa bourse
	"voleur_margot_vue": false,          # Margot : traces de pas d'enfant dans la farine ; elle donne la viande séchée
	"voleur_colporteur_vu": false,       # le colporteur (étage de l'auberge) : on lui a pris une couverture
	"voleur_voyageuse_vue": false,       # la vieille voyageuse : un enfant avec un panier, vers la forêt
	"voleur_aelis_parle": false,         # Aelis : son coussin brodé ; elle ouvre la porte de chez elle
	"voleur_poils_trouves": false,       # des poils de chien sur le rebord de la fenêtre d'Aelis
	"voleur_godric_vu": false,           # Godric a vu Pépin à la lisière, une miche sous le bras
	"voleur_deduction": false,           # Zylrak a compris : Pépin cache un chien à la lisière
	"voleur_goules_vaincues": false,     # la cachette : Stone apprivoisé, les goules repoussées, la bourse rendue
	"voleur_chien_garde": false,         # choix : Stone suit Zylrak (il flaire des objets cachés)
	"voleur_chien_pepin": false,         # choix : Stone reste avec Pépin, dans la grange de Margot
	"contrat_voleur_termine": false,     # Margot a payé le contrat (40 écus)
}

# --- Système de spawn entre scènes ---
var next_spawn_point: String = ""
## Position exacte où placer Zylrak à l'arrivée sur la carte (chargement d'une sauvegarde) ;
## Vector2.INF : aucune (on utilise next_spawn_point ou la position de départ de la carte).
var load_position: Vector2 = Vector2.INF
## Temps de jeu, en secondes (compté par l'autoload Sauvegarde).
var play_time: float = 0.0
## Direction dans laquelle Zylrak regarde ("up", "down", "left", "right"), gardée d'une carte à l'autre.
var facing: String = "down"
## Nouvelle partie : Zylrak arrive au village et marche seul jusqu'à l'auberge (scenes/maps/arrivee_village.gd).
## Pas sauvegardé.
var arrival_pending := false

# --- Sauvegarde ---

const SAVED_FIELDS := ["current_hp", "max_hp", "current_energy", "max_energy", "attack", "defense", "magic",
	"speed", "level", "xp", "ysolde_hp", "ysolde_energy", "facing", "play_time", "ecus", "ecus_voles", "venin"]

## Tout ce qu'une sauvegarde doit retenir de Zylrak, d'Ysolde et de la quête.
func to_dict() -> Dictionary:
	var d := {}
	for f in SAVED_FIELDS:
		d[f] = get(f)
	d["inventory"] = inventory.duplicate()
	d["equipement"] = equipment.duplicate(true)
	d["sac_equipement"] = gear_bag.duplicate()
	d["quest_flags"] = quest_flags.duplicate()
	return d

## Remet l'état tel qu'il était dans `d` (voir to_dict ; les nombres relus du JSON sont des flottants).
func from_dict(d: Dictionary) -> void:
	for f in SAVED_FIELDS:
		if d.has(f):
			var v = d[f]
			if f == "venin":
				venin.clear()
				for k in v:
					venin[str(k)] = int(v[k])
			else:
				set(f, int(v) if typeof(get(f)) == TYPE_INT else v)
	inventory.assign(d.get("inventory", []))
	if d.has("equipement"):
		for hero in d.equipement:
			if equipment.has(hero):
				for slot in d.equipement[hero]:
					equipment[hero][slot] = str(d.equipement[hero][slot])
	if d.has("sac_equipement"):
		gear_bag.assign(d.sac_equipement)
	quest_flags.clear()
	for k in d.get("quest_flags", {}):
		quest_flags[k] = bool(d.quest_flags[k])
	controls_locked = false
	next_spawn_point = ""
	load_position = Vector2.INF
	for k in quest_flags:
		flag_changed.emit(k, quest_flags[k])

func set_flag(flag_name: String, value: bool) -> void:
	var was: bool = quest_flags.get(flag_name, false)
	quest_flags[flag_name] = value
	if value and FLAG_REWARDS.has(flag_name) and not owns_gear(FLAG_REWARDS[flag_name]):
		gear_bag.append(FLAG_REWARDS[flag_name])
		_sound("objet_rare")
	if value and not was and KEY_ITEM_FLAGS.has(flag_name):
		_sound("objet_rare")
	if value and FLAG_ECUS.has(flag_name) and not quest_flags.get(flag_name + "_ecus", false):
		quest_flags[flag_name + "_ecus"] = true
		ecus += FLAG_ECUS[flag_name]
		_sound("ecus")
	if value and FLAG_ITEMS.has(flag_name) and not quest_flags.get(flag_name + "_recompense", false):
		quest_flags[flag_name + "_recompense"] = true
		for item in FLAG_ITEMS[flag_name]:
			inventory.append(item)
	flag_changed.emit(flag_name, value)

## Un bruitage (l'autoload Sons n'existe pas dans les générateurs de cartes).
func _sound(name: String) -> void:
	var sons := get_node_or_null("/root/Sons")
	if sons:
		sons.play(name)

func get_flag(flag_name: String) -> bool:
	return quest_flags.get(flag_name, false)
