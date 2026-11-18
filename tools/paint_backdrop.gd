extends SceneTree

## Peint le décor lointain (ciel d'aube et sommets enneigés),
## en pixel art, dans assets/sprites/backdrops/. Chaque couche est une image qui se répète
## à l'horizontale ; scenes/maps/backdrop.gd les superpose avec un léger effet de parallaxe.
## Lancer : Godot --headless --path . -s tools/paint_backdrop.gd

const OUT := "res://assets/sprites/backdrops/"
const W := 640   # largeur d'une couche (pixels du jeu, avant le zoom ×3 de la caméra)

const SKY := [Color("#262a55"), Color("#343a6e"), Color("#474b85"), Color("#5e5a97"), Color("#7a67a2"),
	Color("#9873a6"), Color("#b97f9f"), Color("#d68f95"), Color("#eaa48b"), Color("#f4bd8c"), Color("#f9d69e")]
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_sky()
	_peaks("sommets_loin.png", 150, 0.010, 80.0, 11, Color("#8b7cab"), Color("#a796c2"), Color("#e4d8ec"), 30)
	_peaks("sommets_pres.png", 110, 0.016, 48.0, 23, Color("#4f477a"), Color("#685c92"), Color("#9c8db8"), 0)
	print("Décor lointain peint dans ", OUT)
	quit()

func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + name))

func _dither(x: int, y: int, t: float) -> bool:
	return t * 16.0 > BAYER[y % 4][x % 4] + 0.5

## Ciel : dégradé en bandes tramées, et un soleil levant pâle derrière les sommets.
func _sky() -> void:
	var h := 360
	var img := Image.create(W, h, false, Image.FORMAT_RGBA8)
	var sun := Vector2(470, 236)
	for y in h:
		var f := clampf(float(y) / 250.0, 0.0, 1.0) * (SKY.size() - 1)
		var i := mini(int(f), SKY.size() - 2)
		var t := f - i
		for x in W:
			var c: Color = SKY[i + 1] if _dither(x, y, t) else SKY[i]
			# halo du soleil : anneaux tramés de plus en plus clairs
			var d := Vector2(x, y).distance_to(sun)
			if d < 90.0:
				var k := 1.0 - d / 90.0
				var glow := Color("#ffe6b8")
				if d < 16.0:
					c = Color("#fff6dc")
				elif _dither(x, y, k * 0.9):
					c = c.lerp(glow, 0.35 + 0.4 * k)
			img.set_pixel(x, y, c)
	_save(img, "ciel_aube.png")

## Crête de montagnes (bruit fractal), en 3 tons : ombre, flanc éclairé (côté soleil, à droite), neige.
func _peaks(name: String, h: int, freq: float, amp: float, seed_: int, dark: Color, lit: Color, snow: Color, snow_depth: int) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_octaves = 4
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var img := Image.create(W, h, false, Image.FORMAT_RGBA8)
	var ridge := PackedFloat32Array()
	ridge.resize(W)
	for x in W:
		# bruit périodique sur la largeur (pour que la couche se répète sans couture)
		var a := TAU * x / W
		var v := n.get_noise_2d(cos(a) * W / TAU, sin(a) * W / TAU)
		ridge[x] = h - 12.0 - (v * 0.5 + 0.5) * amp - 0.45 * amp * absf(sin(a * 3.0 + seed_))
	# lissage de la crête (évite les fines aiguilles qui font des rayures)
	var smooth := PackedFloat32Array()
	smooth.resize(W)
	for x in W:
		var acc := 0.0
		for k in range(-3, 4):
			acc += ridge[posmod(x + k, W)]
		smooth[x] = acc / 7.0
	ridge = smooth
	var jag := FastNoiseLite.new()
	jag.seed = seed_ + 5
	jag.frequency = 0.15
	for x in W:
		var top := int(ridge[x])
		# pente lissée sur 8 px : de grandes faces éclairées ou à l'ombre, pas des rayures
		var slope := ridge[(x + 8) % W] - ridge[(x - 8 + W) % W]
		var high := ridge[x] < h - amp * 0.8   # seuls les plus hauts sommets ont de la neige
		for y in range(maxi(top, 0), h):
			var depth := y - top
			var c := lit if slope > 1.5 and depth < 26 + int(jag.get_noise_1d(x * 0.5) * 10.0) else dark
			if high and snow_depth > 0 and depth < snow_depth * 0.5 + jag.get_noise_2d(x, 0) * snow_depth * 0.35:
				c = snow
			img.set_pixel(x, y, c)
	_save(img, name)
