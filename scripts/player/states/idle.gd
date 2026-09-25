extends PlayerState


func enter() -> void:
	player.sprite.play("idle")
	player.velocity = Vector2.ZERO


func physics_update(_delta: float) -> void:
	if player.wants_to_dash():
		transitioned.emit(&"dash")
	elif player.wants_to_extract():
		transitioned.emit(&"extract")
	elif player.wants_to_parry():
		transitioned.emit(&"parry")
	elif player.wants_to_attack():
		transitioned.emit(&"attack")
	elif player.wants_to_heal():
		transitioned.emit(&"heal")
	elif player.get_input_direction() != Vector2.ZERO:
		transitioned.emit(&"walk")
