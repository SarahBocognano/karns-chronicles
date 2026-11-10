extends Node

## Stocke tout ce qui doit survivre à un changement de scène.

## Émis à chaque changement de flag (les PNJ s'en servent pour leur « ! »).
signal flag_changed(flag_name: String, value: bool)

## true pendant un dialogue ou une scène scriptée : Zylrak ne peut plus bouger.
var controls_locked: bool = false

# --- Progression / état du joueur ---
var current_hp: int = 20
var max_hp: int = 20
var inventory: Array[String] = []

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

func set_flag(flag_name: String, value: bool) -> void:
	quest_flags[flag_name] = value
	flag_changed.emit(flag_name, value)

func get_flag(flag_name: String) -> bool:
	return quest_flags.get(flag_name, false)
