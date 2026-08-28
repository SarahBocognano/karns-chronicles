extends Node

## Stocke tout ce qui doit survivre à un changement de scène.

# --- Progression / état du joueur ---
var current_hp: int = 20
var max_hp: int = 20
var inventory: Array[String] = []

# --- Flags de quête (simple pour l'instant, on structurera plus tard si besoin) ---
var quest_flags: Dictionary = {
	"has_accepted_zylrak_quest": false,
	"has_defeated_chariot_monster": false,
}

# --- Système de spawn entre scènes ---
var next_spawn_point: String = ""

func set_flag(flag_name: String, value: bool) -> void:
	quest_flags[flag_name] = value

func get_flag(flag_name: String) -> bool:
	return quest_flags.get(flag_name, false)
