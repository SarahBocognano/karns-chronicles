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

# --- Dark Ages UI (Hypnobius) : planche de 384 × 352, tuiles de 32 px, agrandie ×3 ---
const DA_SHEET := preload("res://assets/ui/dark_ages/dark_ages_ui.png")
const DA := 3
const DA_FRAME := Rect2(0, 0, 96, 96)            # grand cadre orné (or et bleu)
const DA_PARCHMENT := Rect2(96, 0, 96, 96)       # parchemin
const DA_DARK := Rect2(210, 18, 60, 60)          # cadre sombre
const DA_SLOT := Rect2(194, 101, 28, 27)         # case sombre
const DA_SLOT_SELECTED := Rect2(256, 96, 32, 32) # case bleue ornée (sélection)
const DA_TAB := Rect2(321, 106, 30, 15)          # onglet gris
const DA_TAB_ACTIVE := Rect2(289, 106, 30, 15)   # onglet bleu nuit
const DA_TAB_ORNAMENT := Rect2(360, 98, 16, 9)   # ornement doré de l'onglet actif
const DA_BAR := Rect2(102, 141, 84, 7)           # cadre de barre
const DA_FILL_HP := Rect2(199, 176, 82, 4)
const DA_FILL_MP := Rect2(296, 144, 82, 4)
const DA_FILL_XP := Rect2(295, 176, 82, 4)
const DA_DIAMOND := Rect2(10, 266, 13, 12)       # losange doré
const DA_DIVIDER := Rect2(213, 268, 55, 8)       # frise
## Encre sur le parchemin.
const INK := Color("#2e322a")
const INK_SOFT := Color("#6b5a44")
const INK_GOLD := Color("#8a5a1c")

# Icônes d'objets et d'équipement (16 px, voir tools/dev/draw_icones.gd).
const ICONS := preload("res://assets/sprites/objets/icones_objets.png")
const ICON_ORDER := ["potion", "fiole", "epee_ordre", "cuir_ashwarden", "arc_frene", "brigandine", "anneau_marchand",
	"talisman_cendres", "carquois_tresse", "cotte_mailles", "amulette_yrenn", "fragment_ame", "parchemin_yrenn", "antidote", "lame_braise", "torche", "pierre_braise"]

static func da_sheet() -> Texture2D:
	return px(DA_SHEET, DA)

## Morceau de la planche Dark Ages (agrandi ×3).
static func da_tex(r: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = da_sheet()
	a.region = Rect2(r.position * DA, r.size * DA)
	return a

## Style étirable (9 morceaux) à partir d'un élément de la planche ; margin en pixels d'origine.
static func da_style(r: Rect2, margin: float, content := 0.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = da_sheet()
	sb.region_rect = Rect2(r.position * DA, r.size * DA)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, margin * DA)
		sb.set_content_margin(side, content)
	return sb

static func da_panel(r: Rect2, margin: float, pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", da_style(r, margin))
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func da_image(r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = da_tex(r)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Barre de la planche (PV, PM, XP) : cadre étiré et remplissage.
static func da_bar(ratio: float, fill: Rect2, width: float) -> Control:
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", da_style(DA_BAR, 3))
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.custom_minimum_size = Vector2(width, DA_BAR.size.y * DA)
	var f := TextureRect.new()
	f.texture = da_tex(fill)
	f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.position = Vector2(2 * DA, (DA_BAR.size.y - fill.size.y) / 2.0 * DA)
	f.size = Vector2(maxf(0.0, (width - 4 * DA) * clampf(ratio, 0.0, 1.0)), fill.size.y * DA)
	frame.add_child(f)
	return frame

## Icône d'objet ou d'équipement (16 px) ; null si inconnue.
static func icon(id: String) -> AtlasTexture:
	var i := ICON_ORDER.find(id)
	if i == -1:
		return null
	var a := AtlasTexture.new()
	a.atlas = ICONS
	a.region = Rect2(i * 16, 0, 16, 16)
	return a

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
