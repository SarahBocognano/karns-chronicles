class_name Objectifs

## Où aller pour les quêtes acceptées, pour la mini-carte (scripts/minimap.gd) : un point vert
## sur l'objectif quand il est sur la carte, sinon une flèche verte sur la sortie qui y mène.
## Chaque objectif : la carte, et le nœud à marquer ("" : pas de point précis, seule la route compte,
## par exemple pour un intérieur sans mini-carte).

## Les sorties de chaque carte et la carte où elles mènent (pour trouver la route).
const LINKS := {
	"VillageV2Map": {"ExitToForest": "ForestMap", "EnterAuberge": "AubergeMap", "EnterWeaponsShop": "WeaponsShopMap", "EnterJumelles": "MaisonJumellesMap"},
	"ForestMap": {"ExitToVillage": "VillageV2Map", "ExitToCascade": "ForestCascadeMap", "ExitToChariot": "ForestChariotMap"},
	"ForestChariotMap": {"ExitToLisiere": "ForestMap", "CheminEst": "RuinesMonteeMap", "Grotte": "GrotteEntreeMap"},
	"GrotteEntreeMap": {"ExitToChariot": "ForestChariotMap", "ExitToToiles": "GrotteToilesMap"},
	"GrotteToilesMap": {"ExitToEntree": "GrotteEntreeMap", "ExitToFilon": "GrotteFilonMap"},
	"GrotteFilonMap": {"ExitToToiles": "GrotteToilesMap"},
	"ForestCascadeMap": {"ExitToLisiere": "ForestMap", "CheminOuest": "LacMap"},
	"LacMap": {"ExitToCascade": "ForestCascadeMap"},
	"RuinesMonteeMap": {"ExitToForest": "ForestChariotMap", "ExitToParvis": "RuinesParvisMap"},
	"RuinesParvisMap": {"ExitToMontee": "RuinesMonteeMap", "ExitToTemple": "TempleVestibuleMap"},
	"AubergeMap": {"ExitToVillage": "VillageV2Map"},
	"WeaponsShopMap": {"ExitToVillage": "VillageV2Map"},
	"MaisonJumellesMap": {"ExitToVillage": "VillageV2Map"},
	"TempleVestibuleMap": {"ExitToParvis": "RuinesParvisMap"},
}

static func current() -> Array[Dictionary]:
	var f := PlayerData.get_flag
	var out: Array[Dictionary] = []
	if f.call("has_accepted_zylrak_quest") and not f.call("quete_marchand_terminee"):
		if not f.call("found_merchant_cart"):
			out.append({"map": "ForestChariotMap", "node": "ChariotMarchand"})
		elif not f.call("ysolde_joined"):
			out.append({"map": "RuinesMonteeMap", "node": "YSortLayer/Ysolde"})
		elif not f.call("temple_ouvert"):
			out.append({"map": "RuinesParvisMap", "node": "YSortLayer/PorteScellee"})
		elif not f.call("marchand_retrouve"):
			out.append({"map": "TempleVestibuleMap", "node": ""})
		else:
			out.append({"map": "AubergeMap", "node": ""})
	if Contrats.accepted("grotte") and not Contrats.done("grotte"):
		if f.call("torche_forgeron") and not f.call("pierre_de_braise"):
			out.append({"map": "GrotteFilonMap", "node": "YSortLayer/Filon"})
		else:
			out.append({"map": "WeaponsShopMap", "node": "Forgeron"})
	if f.call("aldric_quest_started"):
		out.append({"map": "LacMap", "node": ""})
	return out

## Nom de la sortie de `from` par laquelle passer pour aller vers `to` ("" : pas de route connue).
static func exit_toward(from: String, to: String) -> String:
	if from == to or not LINKS.has(from):
		return ""
	var first := {}   # carte atteinte -> sortie de `from` par laquelle on y arrive
	var queue: Array[String] = []
	for exit in LINKS[from]:
		var m: String = LINKS[from][exit]
		if not first.has(m):
			first[m] = exit
			queue.append(m)
	while not queue.is_empty():
		var m: String = queue.pop_front()
		if m == to:
			return first[m]
		for exit in LINKS.get(m, {}):
			var n: String = LINKS[m][exit]
			if n != from and not first.has(n):
				first[n] = first[m]
				queue.append(n)
	return ""
