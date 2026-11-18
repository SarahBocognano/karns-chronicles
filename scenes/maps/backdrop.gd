extends CanvasLayer

## Décor lointain (ciel d'aube et sommets enneigés), dessiné derrière la carte : on le voit là où
## la carte n'a pas de sol, par exemple au-dessus de la crête rocheuse du temple des Yrenn.
## À la verticale, le décor est accroché à la carte (`horizon_y`) ; à l'horizontale, chaque couche
## suit un peu la caméra (parallaxe).
## Les images sont peintes par tools/paint_backdrop.gd (assets/sprites/backdrops/).

const DIR := "res://assets/sprites/backdrops/"
## Hauteur de référence : le pied des sommets lointains, dans la composition (pixels du jeu).
const REF_HORIZON := 232.0
## [image, haut de la couche dans la composition (pixels du jeu), parallaxe]
const LAYERS := [
	["ciel_aube.png", 0, 0.02],
	["sommets_loin.png", 82, 0.06],
	["sommets_pres.png", 152, 0.12],
]
const SKY_TOP := Color("#262a55")
const PEAKS_FILL := Color("#4f477a")   # sous les sommets proches (caché par la carte)

## Position (y, pixels du monde) du pied des sommets lointains sur la carte.
## Ex. juste au-dessus d'une crête, pour voir les sommets se dresser derrière.
@export var horizon_y: float = REF_HORIZON

var _sprites: Array[Sprite2D] = []
var _sky_fill: ColorRect
var _ground_fill: ColorRect

func _ready() -> void:
	layer = -20
	_sky_fill = _rect(SKY_TOP)
	for l in LAYERS:
		var s := Sprite2D.new()
		s.texture = load(DIR + l[0])
		s.centered = false
		s.region_enabled = true
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		_sprites.append(s)
	_ground_fill = _rect(PEAKS_FILL)
	_update()

func _process(_delta: float) -> void:
	_update()

func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _update() -> void:
	var cam := get_viewport().get_camera_2d()
	var zoom := cam.zoom.x if cam else 3.0
	var center := cam.get_screen_center_position() if cam else Vector2.ZERO
	var screen := get_viewport().get_visible_rect().size
	var art := screen / zoom
	var cam_top := center.y - art.y / 2.0
	# décalage de la composition pour que son horizon tombe sur `horizon_y` dans la carte
	var shift := horizon_y - cam_top - REF_HORIZON
	for i in _sprites.size():
		var s := _sprites[i]
		var l: Array = LAYERS[i]
		s.region_rect = Rect2(center.x * float(l[2]), 0, art.x + 2.0, s.texture.get_height())
		s.scale = Vector2(zoom, zoom)
		s.position = Vector2(-zoom, (float(l[1]) + shift) * zoom)
	# au-dessus du ciel : sa couleur du haut ; sous les sommets proches : leur couleur sombre
	_sky_fill.size = Vector2(screen.x, maxf(0.0, _sprites[0].position.y + zoom))
	var last := _sprites[_sprites.size() - 1]
	var bottom := last.position.y + last.texture.get_height() * zoom - zoom
	_ground_fill.position = Vector2(0, bottom)
	_ground_fill.size = Vector2(screen.x, maxf(0.0, screen.y - bottom))
