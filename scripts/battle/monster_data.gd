extends Resource
class_name MonsterData

@export var display_name: String = "Goule"
## Image du monstre, tournée vers la droite (vers Zylrak). Les pieds en bas de l'image.
@export var texture: Texture2D
## Planche exportée du générateur LPC (cases de 64 px, même format que Zylrak).
## Si elle est renseignée, elle remplace `texture` et le monstre est animé :
## repos, marche quand il s'élance, coup d'épée/griffe quand il attaque, chute quand il meurt.
@export var lpc_sheet: Texture2D
## Planche LPC d'animal (les araignées : cases de 64 px, 10 colonnes ; rangée 3 tournée vers la
## droite, colonnes 0-3 l'attaque, 4-9 la marche ; rangée 4 la mort). Remplace `texture`.
@export var beast_sheet: Texture2D
## Teinte appliquée au monstre (l'araignée géante est plus rouge).
@export var tint: Color = Color.WHITE
## Agrandissement de l'image dans le combat (le décor fait 480×270 pixels).
@export var sprite_scale: float = 1.0
## Cocher si l'image regarde vers la gauche : elle sera retournée pour faire face à Zylrak.
@export var flip_h: bool = false
## Ombre ovale sous le monstre (à décocher si l'image a déjà son ombre dessinée).
@export var shadow: bool = true

@export_group("Statistiques")
@export var max_hp: int = 18
@export var attack: int = 5
@export var defense: int = 1
@export var speed: int = 4
@export var xp: int = 6

@export_group("Attaques")
## Noms affichés quand le monstre attaque (tirés au hasard).
@export var attack_names: PackedStringArray = ["Griffes"]
## Son de son attaque (voir l'autoload Sons : "monstre", "goule", "araignee", "gardien"...).
@export var cri: String = "monstre"

@export_group("Venin")
## Chance d'empoisonner à chaque attaque (0 : jamais). Un héros empoisonné perd `venom_damage` PV
## au début de chacun de ses tours, jusqu'à la fin du combat ou un antidote.
@export_range(0.0, 1.0) var venom_chance: float = 0.0
@export var venom_damage: int = 2

@export_group("Boss")
## En dessous de cette part de ses PV (ex. 0.5 : la moitié), le monstre entre en furie : il agit
## deux fois par tour (0 : jamais).
@export_range(0.0, 1.0) var enrage_below: float = 0.0
