class_name Contrats

## Les contrats affichés sur le panneau du village, à côté de l'auberge (scenes/maps/panneau_contrats.gd).
## Le panneau se remplit une fois la quête d'Oswin acceptée. Accepter un contrat passe le flag
## "contrat_<id>_accepte" à vrai : le contrat apparaît alors dans le journal du grimoire.
## Détails du design : page Notion « Contrats d'Eclatvin ».

const LIST: Array[Dictionary] = [
	{
		"id": "voleur",
		"titre": "Le voleur d'Eclatvin",
		"commanditaire": "La mère Margot, fermière",
		"lieu": "Eclatvin et ses environs",
		"recompense": "40 écus",
		"texte": "Depuis plusieurs nuits, quelqu'un se sert dans ma réserve : du pain, un jambon, et même la paille de ma grange ! Rien de précieux, mais je n'en dors plus. Je paierai qui m'attrapera ce chapardeur.\n\n— Margot, à la ferme au bout du chemin.",
		"etape": "Aller voir la mère Margot, à sa ferme.",
	},
	{
		"id": "grotte",
		"titre": "Dans le noir de la grotte",
		"commanditaire": "Le forgeron",
		"lieu": "La grotte du sentier, au-dessus du chariot",
		"recompense": "Une lame forgée sur mesure, 30 écus",
		"texte": "Cherche gaillard pas trop froussard pour me rapporter de la pierre-de-braise, du fond de la grotte. Les araignées sont fournies, la torche aussi : passer à la forge.",
		"etape": "Passer à la forge chercher la torche.",
	},
]

static func flag_for(id: String) -> String:
	return "contrat_%s_accepte" % id

## Les indices du contrat du voleur.
const CLUES := ["voleur_margot_vue", "voleur_colporteur_vu", "voleur_voyageuse_vue", "voleur_poils_trouves", "voleur_godric_vu"]

static func clue_count() -> int:
	var n := 0
	for c in CLUES:
		if PlayerData.get_flag(c):
			n += 1
	return n

## Contrat rempli (récompense touchée).
static func done(id: String) -> bool:
	return PlayerData.get_flag("contrat_%s_termine" % id)

## Les étapes d'un contrat accepté, pour le journal : [[texte, faite], ...].
static func steps(id: String) -> Array:
	var f := PlayerData.get_flag
	match id:
		"grotte":
			var out: Array = [["Passer à la forge chercher la torche.", f.call("torche_forgeron")]]
			if f.call("torche_forgeron"):
				out.append(["Descendre au fond de la grotte du sentier, au-dessus du chariot, jusqu'au filon de pierre-de-braise.", f.call("pierre_de_braise")])
			if f.call("pierre_de_braise"):
				out.append(["Rapporter la pierre-de-braise au forgeron.", f.call("contrat_grotte_termine")])
			return out
		"voleur":
			var out: Array = [["Aller voir la mère Margot, à sa ferme, au bout du chemin du nord-est.", f.call("voleur_margot_vue")]]
			if f.call("voleur_bourse_volee"):
				out.append(["Retrouver la bourse que Pépin a « empruntée » sur la place.", f.call("voleur_goules_vaincues")])
			if not f.call("voleur_deduction"):
				# les témoins, un par un (ce qu'il reste à faire reste en clair)
				out.append(["Interroger les voyageurs qui logent à l'étage de l'auberge : le colporteur et la vieille voyageuse.",
					f.call("voleur_colporteur_vu") and f.call("voleur_voyageuse_vue")])
				out.append(["Parler à Aelis : elle se tient devant la longue maison qu'elle loue, au sud-est de la place.", f.call("voleur_aelis_parle")])
				if f.call("voleur_aelis_parle"):
					out.append(["Examiner la fenêtre de chez Aelis (la porte ouverte de la longue maison).", f.call("voleur_poils_trouves")])
				out.append(["Interroger Godric, le vieux bûcheron, près des tas de bois au nord-est du village.", f.call("voleur_godric_vu")])
			else:
				out.append(["Interroger les témoins (5 indices sur 5).", true])
			if f.call("voleur_deduction"):
				out.append(["Trouver la cachette de Pépin, dans les herbes hautes de la lisière.", f.call("voleur_goules_vaincues")])
			if f.call("voleur_goules_vaincues"):
				out.append(["Rendre compte à la mère Margot.", f.call("contrat_voleur_termine")])
			return out
	for c in LIST:
		if c.id == id:
			return [[c.etape, done(id)]]
	return []

## Le panneau se remplit une fois la quête d'Oswin acceptée.
static func board_open() -> bool:
	return PlayerData.get_flag("has_accepted_zylrak_quest")

static func accepted(id: String) -> bool:
	return PlayerData.get_flag(flag_for(id))

## Reste-t-il un contrat à accepter sur le panneau ?
static func has_new() -> bool:
	if not board_open():
		return false
	for c in LIST:
		if not accepted(c.id):
			return true
	return false
