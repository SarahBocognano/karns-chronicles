extends Area2D

func _ready() -> void:
	monitoring = false
	call_deferred("_enable_monitoring")
	body_entered.connect(_on_body_entered)
	
func _enable_monitoring() -> void:
	monitoring = true	

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		SceneTransition.change_scene(
			"res://scenes/maps/AubergeMap.tscn",
			"SpawnFromUpstairs"
		)
