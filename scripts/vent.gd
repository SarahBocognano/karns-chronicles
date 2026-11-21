extends Node

## Le vent dans les arbres et les herbes (autoload « Vent »), sur toutes les cartes extérieures.
## Les cartes de la forêt portent déjà leurs matériaux (resources/shaders/vent_*.tres) ; pour les
## autres, on les pose ici à l'arrivée sur la carte :
## - les sprites de la planche veg_decoratives (lac, ruines) : arbres et touffes d'herbe, d'après
##   la zone de la planche (les souches et rochers restent immobiles) ;
## - les arbres peints en tuiles (village) : chaque tuile d'arbre reçoit vent_tuiles.gdshader,
##   avec la rangée du pied de son arbre, retrouvée en descendant le tronc sur la carte.

const VEG := "res://assets/sprites/tilesets/TreesAndPlants/veg_decoratives.png"
const ARBRES := preload("res://resources/shaders/vent_arbres.tres")
const HERBES := preload("res://resources/shaders/vent_herbes.tres")
const TUILES := preload("res://resources/shaders/vent_tuiles.gdshader")
## Cartes en intérieur : pas de vent.
const INDOOR := ["Auberge", "Maison", "Shop", "Temple"]
## Calques de tuiles sans arbres.
const FLAT_LAYERS := ["Ground", "Path", "Marches", "Dalles", "Falaises", "Details", "SuperpositionRocks"]

var _scene: Node
var _tile_materials := {}

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:
		_scene = scene
		if scene:
			apply(scene)

func apply(scene: Node) -> void:
	for word in INDOOR:
		if word in String(scene.name):
			return
	var ysort := scene.get_node_or_null("YSortLayer")
	if ysort:
		for s in ysort.get_children():
			if s is Sprite2D:
				_sprite(s)
	var layers: Array[TileMapLayer] = []
	for layer in scene.find_children("*", "TileMapLayer", true, false):
		if not layer.name in FLAT_LAYERS and layer.tile_set:
			layers.append(layer)
	_tiles(layers)

func _sprite(s: Sprite2D) -> void:
	if s.material != null or s.centered or not s.region_enabled or s.texture == null or s.texture.resource_path != VEG:
		return
	var r := s.region_rect
	if r.position.y >= 640.0:
		s.material = HERBES   # herbes hautes, fougères, fleurs
	elif r.size.y >= 50.0 and not (r.position.y >= 500.0 and r.position.x < 400.0):
		s.material = ARBRES   # pas les souches ni les rochers (en bas à gauche de la planche)

## Tuiles d'arbres : chaque tuile de la planche doit connaître la rangée du pied de son arbre. On
## regroupe les tuiles d'un même arbre (posées côte à côte sur la carte comme dans la planche, tous
## calques confondus : un arbre qui en chevauche un autre est réparti sur plusieurs calques), et le
## pied est la rangée la plus basse du groupe (les bords du feuillage n'ont pas de tronc dessous).
func _tiles(layers: Array[TileMapLayer]) -> void:
	var at := {}   # case (coordonnées du monde) -> tuiles de la planche posées là
	for layer in layers:
		for c in layer.get_used_cells():
			var ac := _veg_atlas(layer, c)
			if ac.x >= 0:
				var w := Vector2i(layer.to_global(layer.map_to_local(c)).round())
				if not at.has(w):
					at[w] = []
				at[w].append(ac)
	# les tuiles d'un même arbre : voisines sur la carte comme dans la planche (union-find)
	var parent := {}
	for w in at:
		for ac in at[w]:
			parent[ac] = parent.get(ac, ac)
	for w in at:
		for ac in at[w]:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Array = at.get(w + d * 32, [])
				if nb.has(ac + d):
					_union(parent, ac, ac + d)
	var feet := {}   # arbre (racine) -> rangée la plus basse
	for ac in parent:
		var r: Vector2i = _find(parent, ac)
		feet[r] = maxi(feet.get(r, 0), ac.y)
	for layer in layers:
		for sid_i in layer.tile_set.get_source_count():
			var src := layer.tile_set.get_source(layer.tile_set.get_source_id(sid_i)) as TileSetAtlasSource
			if src == null or src.texture == null or src.texture.resource_path != VEG:
				continue
			for ac in parent:
				if src.has_tile(ac):
					var td := src.get_tile_data(ac, 0)
					if td.material == null:
						td.material = _tile_material(feet[_find(parent, ac)], src.use_texture_padding)

func _find(parent: Dictionary, a: Vector2i) -> Vector2i:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a

func _union(parent: Dictionary, a: Vector2i, b: Vector2i) -> void:
	parent[_find(parent, a)] = _find(parent, b)

## Coordonnées dans la planche veg_decoratives de la tuile posée en `c` (-1, -1 : autre planche).
func _veg_atlas(layer: TileMapLayer, c: Vector2i) -> Vector2i:
	var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
	if src == null or src.texture == null or src.texture.resource_path != VEG:
		return Vector2i(-1, -1)
	return layer.get_cell_atlas_coords(c)

func _tile_material(foot_row: int, padding: bool) -> ShaderMaterial:
	var key := Vector2i(foot_row, int(padding))
	if not _tile_materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = TUILES
		m.set_shader_parameter("amplitude", ARBRES.get_shader_parameter("amplitude"))
		m.set_shader_parameter("speed", ARBRES.get_shader_parameter("speed"))
		m.set_shader_parameter("gust", ARBRES.get_shader_parameter("gust"))
		m.set_shader_parameter("foot_row", float(foot_row))
		m.set_shader_parameter("cell_px", 34.0 if padding else 32.0)
		m.set_shader_parameter("pad_px", 1.0 if padding else 0.0)
		_tile_materials[key] = m
	return _tile_materials[key]
