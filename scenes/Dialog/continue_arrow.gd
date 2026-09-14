extends TextureRect

func _ready() -> void:
	_animate_bounce()

func _animate_bounce() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 6, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", position.y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
