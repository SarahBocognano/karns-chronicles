extends Resource
class_name MonsterData

@export var display_name: String = "Goule"
## Image du monstre, tournée vers la droite (vers Zylrak). Les pieds en bas de l'image.
@export var texture: Texture2D
## Planche exportée du générateur LPC (cases de 64 px, même format que Zylrak).
## Si elle est renseignée, elle remplace `texture` et le monstre est animé :
## repos, marche quand il s'élance, coup d'épée/griffe quand il attaque, chute quand il meurt.
@export var lpc_sheet: Texture2D
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
