class_name Eclairage

## L'éclairage des cartes, posé à l'arrivée sur chacune (scenes/maps/map_camera_zoom.gd) : une teinte
## d'ambiance (CanvasModulate) et des lueurs sur les sources de lumière.
## - Les torches, bougies et cheminées des intérieurs sont trouvées d'après leur image (SOURCES).
## - Les autres lueurs (lanternes, fenêtres, four, braises de la forge) sont listées par carte, en
##   pixels du monde (MAPS).
## Les cartes qui ont déjà leur propre pénombre (grotte, temple, lac) ne sont pas touchées.
## Une ambiance fixe par carte : pas de cycle jour / nuit (idée notée pour plus tard).
## Les lueurs ne sont pas enregistrées dans les scènes (sans propriétaire) ; la mini-carte est
## cuite sans éclairage (méta "sans_eclairage", voir tools/bake_minimaps.gd).

## sorte -> [couleur, énergie, taille (texture de 256 px), vacillement, décalage depuis la source]
const KINDS := {
	"torche": [Color(1.0, 0.66, 0.36), 0.9, 0.75, 0.18, Vector2(0, -14)],
	"bougie": [Color(1.0, 0.78, 0.5), 0.6, 0.5, 0.12, Vector2(0, -8)],
	"cheminee": [Color(1.0, 0.55, 0.26), 1.3, 2.2, 0.2, Vector2(0, 12)],
	"braises": [Color(1.0, 0.4, 0.18), 0.7, 0.5, 0.15, Vector2.ZERO],
	"four": [Color(1.0, 0.5, 0.24), 0.6, 0.7, 0.12, Vector2(0, -28)],
	"lanterne": [Color(1.0, 0.74, 0.42), 0.85, 0.6, 0.1, Vector2.ZERO],
	"fenetre": [Color(0.8, 0.88, 1.0), 0.7, 1.2, 0.0, Vector2(0, 56)],
}
## Morceau du chemin de l'image d'un sprite -> sorte de lueur.
const SOURCES := {
	"FL_Houses_torch": "torche",
	"FL_Houses_candle": "bougie",
	"FL_Houses_fireplace": "cheminee",
}
## carte -> teinte d'ambiance et lueurs [sorte, position]
const MAPS := {
	# Eclatvin au crépuscule (l'intro : « un soir, un étranger arrive »), lanternes allumées
	"VillageV2Map": {"teinte": Color(0.8, 0.72, 0.72), "lueurs": [
		["lanterne", Vector2(-448, 214)], ["lanterne", Vector2(-64, 344)], ["lanterne", Vector2(96, 184)],
		["lanterne", Vector2(96, 478)], ["lanterne", Vector2(-20, -524)]]},
	# la forêt : verte et tamisée ; plus sombre là où le chariot a été attaqué
	"ForestMap": {"teinte": Color(0.8, 0.86, 0.8)},
	"ForestCascadeMap": {"teinte": Color(0.78, 0.87, 0.88)},
	"ForestChariotMap": {"teinte": Color(0.68, 0.72, 0.76)},
	# les ruines au couchant
	"RuinesMonteeMap": {"teinte": Color(1.0, 0.84, 0.74)},
	"RuinesParvisMap": {"teinte": Color(0.96, 0.8, 0.74)},
	# les intérieurs : pénombre chaude, éclairés par leurs feux et leurs fenêtres
	"AubergeMap": {"teinte": Color(0.6, 0.54, 0.5)},
	"AubergeEtageMap": {"teinte": Color(0.56, 0.52, 0.52), "lueurs": [["bougie", Vector2(16, -106)]]},
	"WeaponsShopMap": {"teinte": Color(0.6, 0.52, 0.47), "lueurs": [
		["braises", Vector2(-176, -218)], ["braises", Vector2(-129, -219)]]},
	"MaisonMargotMap": {"teinte": Color(0.7, 0.64, 0.6), "lueurs": [
		["fenetre", Vector2(368, 57)], ["fenetre", Vector2(416, 57)], ["fenetre", Vector2(464, 57)]]},
	"MaisonAelisMap": {"teinte": Color(0.7, 0.64, 0.62), "lueurs": [
		["fenetre", Vector2(368, 57)], ["fenetre", Vector2(416, 57)]]},
	"MaisonJumellesMap": {"teinte": Color(0.7, 0.64, 0.6), "lueurs": [
		["fenetre", Vector2(144, 57)], ["fenetre", Vector2(192, 57)], ["fenetre", Vector2(240, 57)]]},
}
## Nœuds nommés qui font de la lumière -> sorte (le four à pain de Margot).
const BY_NAME := {"Four": "four"}

static func apply(map: Node) -> void:
	if map.has_meta("sans_eclairage"):
		return
	var spec: Dictionary = MAPS.get(map.scene_file_path.get_file().get_basename(), {})
	if spec.is_empty() or not map.find_children("*", "CanvasModulate", true, false).is_empty():
		return
	var cm := CanvasModulate.new()
	cm.name = "Ambiance"
	cm.color = spec["teinte"]
	map.add_child(cm)
	for n in map.find_children("*", "Node2D", true, false):
		var kind: String = BY_NAME.get(String(n.name), "")
		if kind == "":
			var path := _texture_path(n)
			for key in SOURCES:
				if key in path:
					kind = SOURCES[key]
		if kind != "":
			n.add_child(_light(kind, Vector2.ZERO))
	var lights := Node2D.new()
	lights.name = "Lueurs"
	map.add_child(lights)
	for l in spec.get("lueurs", []):
		lights.add_child(_light(l[0], l[1]))

static func _light(kind: String, pos: Vector2) -> PointLight2D:
	var k: Array = KINDS[kind]
	var l: PointLight2D = load("res://scenes/maps/lueur.gd").new()
	l.name = kind.capitalize()
	l.color = k[0]
	l.base_energy = k[1]
	l.texture_scale = k[2]
	l.flicker = k[3]
	l.position = pos + k[4]
	return l

static func _texture_path(n: Node) -> String:
	var t: Texture2D = null
	if n is Sprite2D:
		t = n.texture
	elif n is AnimatedSprite2D and n.sprite_frames and n.sprite_frames.has_animation(n.animation) \
			and n.sprite_frames.get_frame_count(n.animation) > 0:
		t = n.sprite_frames.get_frame_texture(n.animation, 0)
	if t is AtlasTexture and t.atlas:
		return t.atlas.resource_path
	return t.resource_path if t else ""
