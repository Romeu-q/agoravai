extends PlayerState


func enter() -> void:
	player.sprite.play("walk")


func physics_update(_delta: float) -> void:
	var direction := player.get_input_direction()

	if player.wants_to_dash():
		transitioned.emit(&"dash")
		return
	if player.wants_to_extract():
		transitioned.emit(&"extract")
		return
	if player.wants_to_parry():
		transitioned.emit(&"parry")
		return
	if player.wants_to_attack():
		transitioned.emit(&"attack")
		return
	if player.wants_to_heal():
		transitioned.emit(&"heal")   # curar exige ficar parado
		return
	if direction == Vector2.ZERO:
		transitioned.emit(&"idle")
		return

	player.update_facing(direction)
	player.velocity = direction * player.speed
	player.move_and_slide()
