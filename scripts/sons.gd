extends Node

## Les bruitages du jeu (autoload « Sons ») : `Sons.play("valider")`. Chaque nom renvoie à un ou
## plusieurs fichiers de assets/audio/sons/ (un au hasard parmi eux), avec un volume et un léger
## écart de hauteur pour que les sons répétés (pas, coups d'épée) ne sonnent pas mécaniques.
## Les pas suivent le sol : terre dehors, bois dans les maisons, pierre dans la grotte et le temple.
## Une ambiance en boucle (forêt, grotte, intérieur, cascade) accompagne chaque carte, sous la
## musique, et se baisse pendant les combats.
## Bus audio « Effets », coupé avec la musique par le bouton du son.
## Sources : TomMusic (Free Fantasy SFX Pack), Chequered Ink (400 Sounds Pack, 96 Extra SFX),
## Kenney et rubberduck (CC0, opengameart.org). Pour changer un son : remplacer le fichier, ou son
## nom dans SOUNDS.

const DIR := "res://assets/audio/sons/"
const BUS := "Effets"
## nom -> [fichiers, volume en dB, écart de hauteur (± ; 0 : aucun)]
const SOUNDS := {
	# interface
	"curseur": [["curseur.wav"], -32.0, 0.0],
	"valider": [["valider.wav"], -30.0, 0.0],
	"retour": [["retour.wav"], -14.0, 0.0],
	"ouvrir": [["ouvrir.wav"], -8.0, 0.0],
	"fermer": [["fermer.wav"], -8.0, 0.0],
	"erreur": [["erreur.wav"], -12.0, 0.0],
	"dialogue": [["dialogue.ogg"], -18.0, 0.05],
	"parchemin": [["parchemin.wav"], -8.0, 0.0],
	"achat": [["achat.wav"], -8.0, 0.0],
	"ecus": [["ecus.wav"], -8.0, 0.0],
	# exploration
	"pas_terre": [["pas_terre_1.ogg", "pas_terre_2.ogg", "pas_terre_3.ogg", "pas_terre_4.ogg", "pas_terre_5.ogg"], -26.0, 0.06],
	"pas_bois": [["pas_bois_1.ogg", "pas_bois_2.ogg", "pas_bois_3.ogg", "pas_bois_4.ogg", "pas_bois_5.ogg"], -26.0, 0.06],
	"pas_pierre": [["pas_pierre_1.ogg", "pas_pierre_2.ogg", "pas_pierre_3.ogg", "pas_pierre_4.ogg", "pas_pierre_5.ogg"], -26.0, 0.06],
	"porte": [["porte.ogg"], -8.0, 0.05],
	"coffre": [["coffre.ogg"], -6.0, 0.0],
	"objet": [["objet.wav"], -8.0, 0.0],
	"objet_rare": [["objet_rare.wav"], -6.0, 0.0],
	"creuser": [["creuser.wav"], -8.0, 0.05],
	"aboiement": [["aboiement.ogg"], -8.0, 0.06],
	"barque": [["barque.wav"], -8.0, 0.0],
	"torche": [["torche.ogg"], -6.0, 0.0],
	# combat
	"combat_debut": [["combat_debut.ogg"], -8.0, 0.0],
	"epee": [["epee_1.ogg", "epee_2.ogg", "epee_3.ogg"], -6.0, 0.04],
	"fleche": [["fleche_1.ogg", "fleche_2.ogg"], -6.0, 0.05],
	"feu": [["feu_1.ogg", "feu_2.ogg", "feu_3.ogg"], -6.0, 0.0],
	"soin": [["soin.ogg"], -6.0, 0.0],
	"protection": [["protection.ogg"], -8.0, 0.0],
	"potion": [["potion.wav"], -6.0, 0.0],
	"monstre": [["monstre.ogg"], -8.0, 0.08],
	"goule": [["goule.ogg"], -8.0, 0.08],
	"araignee": [["araignee.ogg"], -8.0, 0.1],
	"gardien": [["gardien.ogg"], -6.0, 0.05],
	"mort_monstre": [["mort_monstre.ogg"], -6.0, 0.08],
	"venin": [["venin.wav"], -10.0, 0.05],
	"furie": [["furie.ogg"], -4.0, 0.0],
	"victoire": [["victoire.wav"], -12.0, 0.0],
	"niveau": [["niveau.wav"], -12.0, 0.0],
	"defaite": [["defaite.wav"], -6.0, 0.0],
	"fuite": [["fuite.ogg"], -8.0, 0.0],
}
## Le sol, d'après le nom de la carte (pour les pas), et l'ambiance de chaque carte.
const WOOD_FLOORS := ["Maison", "Auberge", "WeaponsShop"]
const STONE_FLOORS := ["Grotte", "Temple"]
## [mots du nom de la carte, fichier d'ambiance] (le premier qui correspond)
const AMBIENCES := [
	[["Maison", "Auberge", "WeaponsShop"], "ambiance_interieur.ogg"],
	[["Grotte", "Temple"], "ambiance_grotte.ogg"],
	[["Cascade"], "ambiance_cascade.ogg"],
	[["Forest", "Lac", "Ruines", "Village"], "ambiance_foret.ogg"],
]
const AMBIENCE_DB := -20.0
const SILENCE_DB := -60.0
const VOICES := 10

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
var _rng := RandomNumberGenerator.new()
var _ambience: AudioStreamPlayer
var _ambience_file := ""
var _scene: Node
var _floor := "pas_terre"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # les menus mettent le jeu en pause
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = BUS
	_ambience.volume_db = SILENCE_DB
	add_child(_ambience)
	_rng.randomize()

## Joue le son `name` (voir SOUNDS ; "pas" : le pas du sol de la carte) ; `volume` s'ajoute au
## volume prévu.
func play(name: String, volume := 0.0) -> void:
	if name == "pas":
		name = _floor
	if not SOUNDS.has(name):
		push_warning("Son inconnu : " + name)
		return
	var spec: Array = SOUNDS[name]
	var files: Array = spec[0]
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _load(files[_rng.randi() % files.size()])
	p.volume_db = spec[1] + volume
	p.pitch_scale = 1.0 + _rng.randf_range(-spec[2], spec[2])
	p.play()

func set_muted(value: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), value)

func _load(file: String) -> AudioStream:
	if not _cache.has(file):
		_cache[file] = load(DIR + file)
	return _cache[file]

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_on_scene(String(scene.name) if scene else "")
	# l'ambiance se baisse pendant les combats, et se fond à l'arrivée sur une carte
	var transition := get_node_or_null("/root/SceneTransition")
	var target := AMBIENCE_DB
	if _ambience_file == "" or (transition and transition.in_battle):
		target = SILENCE_DB
	_ambience.volume_db = move_toward(_ambience.volume_db, target, delta * 30.0)

func _on_scene(scene_name: String) -> void:
	_floor = "pas_terre"
	for w in WOOD_FLOORS:
		if w in scene_name:
			_floor = "pas_bois"
	for w in STONE_FLOORS:
		if w in scene_name:
			_floor = "pas_pierre"
	var file := ""
	for a in AMBIENCES:
		for w in a[0]:
			if file == "" and w in scene_name:
				file = a[1]
	if file == _ambience_file:
		return
	_ambience_file = file
	if file == "":
		return   # se tait en fondu (voir _process)
	var stream := _load(file)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_ambience.stream = stream
	_ambience.volume_db = SILENCE_DB
	_ambience.play()
