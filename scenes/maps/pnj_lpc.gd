extends "res://scenes/maps/npc_dialogue.gd"

## PNJ dont le sprite est pris dans une feuille LPC (cases de 64 px), créé au chargement : il suffit
## de poser le nœud avec `sheet` (ex. Margot, le colporteur, la vieille voyageuse).

@export var sheet: Texture2D
@export_enum("up", "down", "left", "right") var facing: String = "down"
## On ne le traverse pas (une petite boîte à ses pieds).
@export var solid: bool = true

func _ready() -> void:
	if get_node_or_null("AnimatedSprite2D") == null and sheet:
		var frames := SpriteFrames.new()
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(0, LPC_WALK_ROWS[facing] * LPC_FRAME, LPC_FRAME, LPC_FRAME)
		frames.add_frame("default", at)
		var s := AnimatedSprite2D.new()
		s.name = "AnimatedSprite2D"
		s.sprite_frames = frames
		s.position = Vector2(0, -6)
		add_child(s)
		if solid:
			var body := StaticBody2D.new()
			body.name = "Corps"
			var shape := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(22, 12)
			shape.shape = r
			shape.position = Vector2(0, 18)
			body.add_child(shape)
			add_child(body)
	super._ready()
