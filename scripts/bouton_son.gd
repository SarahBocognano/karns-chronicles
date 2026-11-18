extends Control
class_name BoutonSon

## Petit bouton rond en haut à droite de l'écran : coupe ou remet la musique (voir l'autoload Musique).
## Dessiné en code, aux couleurs de la mini-carte : plaque sombre cerclée d'or, haut-parleur,
## ondes quand la musique joue, croix quand elle est coupée.

signal toggled_mute

const SIZE := 56.0
const PLATE := Color("#1a1410", 0.78)
const GOLD := Color("#f2c14e")
const CREAM := Color("#f4e6c4")
const RED := Color("#d9644a")

var muted := false:
	set(v):
		muted = v
		tooltip_text = "Remettre la musique" if muted else "Couper la musique"
		queue_redraw()
var _hover := false

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	muted = muted
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		toggled_mute.emit()

func _draw() -> void:
	var c := size / 2.0
	var r := SIZE / 2.0 - 2.0
	draw_circle(c, r, PLATE)
	draw_arc(c, r, 0.0, TAU, 40, GOLD if _hover else GOLD.darkened(0.25), 3.0)
	var ink := CREAM if not _hover else Color.WHITE
	# Haut-parleur : le corps, puis le pavillon
	var o := c + Vector2(-7, 0)
	draw_rect(Rect2(o + Vector2(-9, -5), Vector2(7, 10)), ink)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-2, -5), o + Vector2(6, -12), o + Vector2(6, 12), o + Vector2(-2, 5)]), ink)
	if muted:
		var x := c + Vector2(11, 0)
		draw_line(x + Vector2(-5, -5), x + Vector2(5, 5), RED, 3.0)
		draw_line(x + Vector2(-5, 5), x + Vector2(5, -5), RED, 3.0)
	else:
		draw_arc(o + Vector2(6, 0), 7.0, -0.9, 0.9, 10, ink, 2.5)
		draw_arc(o + Vector2(6, 0), 13.0, -0.9, 0.9, 14, ink, 2.5)
