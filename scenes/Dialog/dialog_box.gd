extends CanvasLayer

@onready var panel: Control = $Root/Panel
@onready var portrait_display: TextureRect = $PortraitDisplay
@onready var name_label: Label = $Root/Panel/NameLabel
@onready var dialogue_label: RichTextLabel = $Root/Panel/DialogueLabel
@onready var continue_arrow: TextureRect = $Root/Panel/ContinueArrow

@export var left_margin: float = 200.0

var portrait_offset_x: float = 0.0

func _ready() -> void:
	hide_dialogue() 
	portrait_offset_x = portrait_display.global_position.x - panel.global_position.x
	_position_panel()
	get_viewport().size_changed.connect(_position_panel)

func _position_panel() -> void:
	panel.position.x = left_margin
	portrait_display.global_position.x = panel.global_position.x + portrait_offset_x
	print("Panel positionné à gauche: x=", panel.position.x, " | Portrait x=", portrait_display.global_position.x)

func show_dialogue(npc_name: String, text: String, portrait: Texture2D = null) -> void:
	name_label.text = npc_name
	dialogue_label.text = text
	if portrait:
		portrait_display.texture = portrait
		portrait_display.visible = true
	else:
		portrait_display.visible = false
	visible = true

func hide_dialogue() -> void:
	visible = false
