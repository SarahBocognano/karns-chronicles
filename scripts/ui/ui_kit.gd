class_name UiKit

## Briques d'interface communes aux menus (même style que les combats) : cadre Mana Soul à fond
## bleu nuit, textes en Cinzel avec contour, couleurs.

const FONT := preload("res://assets/fonts/Cinzel-VariableFont_wght.ttf")
const FRAME := preload("res://assets/ui/mana_soul/cadre.png")
const HAND := preload("res://assets/ui/main_curseur.png")
const FRAME_MARGIN_X := 26   # largeur des volutes des coins (pixels de l'image d'origine)
const FRAME_MARGIN_Y := 18
const SCALE := 3
const GOLD := Color(0.78, 0.63, 0.36)
const TEXT := Color(0.93, 0.90, 0.84)
const GREY := Color(0.55, 0.53, 0.50)
const HP := Color("#d9644a")
const MP := Color("#5aa2e0")
const DIALOG_BLUE := Color(0.042, 0.078, 0.121)
const FRAME_FILL := Color8(0x11, 0x13, 0x43)

static var _cache := {}

## Panneau encadré, de la taille demandée.
static func panel(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxTexture.new()
	sb.texture = framed()
	sb.texture_margin_left = FRAME_MARGIN_X * SCALE
	sb.texture_margin_right = FRAME_MARGIN_X * SCALE
	sb.texture_margin_top = FRAME_MARGIN_Y * SCALE
	sb.texture_margin_bottom = FRAME_MARGIN_Y * SCALE
	p.add_theme_stylebox_override("panel", sb)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.position = pos
	p.size = size
	return p

## Le cadre agrandi ×3, fond rendu opaque (bleu nuit des boîtes de dialogue).
static func framed() -> Texture2D:
	if not _cache.has("cadre"):
		var img := FRAME.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.3:
					if absf(c.r - FRAME_FILL.r) + absf(c.g - FRAME_FILL.g) + absf(c.b - FRAME_FILL.b) < 0.03:
						c = DIALOG_BLUE
					c.a = 1.0
					img.set_pixel(x, y, c)
		img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		_cache["cadre"] = ImageTexture.create_from_image(img)
	return _cache["cadre"]

## Une texture pixel art agrandie (sans flou).
static func px(tex: Texture2D, k: int) -> Texture2D:
	var key := "%s@%d" % [tex.resource_path, k]
	if not _cache.has(key):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]

static func label(text: String, size: int = 30, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	l.add_theme_constant_override("outline_size", 4)
	return l

## Barre fine (PV, PM) : `ratio` entre 0 et 1.
static func bar(ratio: float, color: Color, width: float = 260.0) -> Control:
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.04)
	back.custom_minimum_size = Vector2(width, 8)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(1, 1)
	fill.size = Vector2(maxf(0.0, (width - 2) * clampf(ratio, 0.0, 1.0)), 6)
	back.add_child(fill)
	return back
