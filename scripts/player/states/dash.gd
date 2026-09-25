extends PlayerState
## Dash: impulso rápido numa direção travada, invencível e com rastro.


var dash_direction := Vector2.ZERO
var time_left := 0.0
var trail_timer := 0.0


func enter() -> void:
	# Dash na direção das teclas; se estiver parado, para onde está virado.
	dash_direction = player.get_input_direction()
	if dash_direction == Vector2.ZERO:
		dash_direction = player.facing
	player.update_facing(dash_direction)

	time_left = player.dash_duration
	trail_timer = 0.0
	player.sprite.play("walk")
	player.set_dashing(true)   # i-frames: atravessa golpes durante o dash

	# O jogador "vira" o rastro: some durante o dash (sprite e sombra).
	player.sprite.visible = false
	player.get_node("Shadow").visible = false

	# "Poeira" na saída, para trás.
	Juice.burst(player.global_position, Color.WHITE, 6, -dash_direction, 50.0, 1.0, 60.0)


func exit() -> void:
	player.sprite.visible = true
	player.get_node("Shadow").visible = true
	# Juice: reaparece com uma "poeirinha" para frente.
	Juice.burst(player.global_position, Color.BLACK, 5, dash_direction, 60.0, 1.0, 50.0)
	player.set_dashing(false)
	player.start_dash_cooldown()


func physics_update(delta: float) -> void:
	# Durante o dash o jogador NÃO controla a direção: é isso que dá o "impulso".
	player.velocity = dash_direction * player.dash_speed
	player.move_and_slide()

	# Rastro: um pedaço a cada TRAIL_INTERVAL segundos, apontando na direção do dash.
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = player.TRAIL_INTERVAL
		player.spawn_trail(dash_direction)

	time_left -= delta
	if time_left <= 0.0:
		if player.get_input_direction() == Vector2.ZERO:
			transitioned.emit(&"idle")
		else:
			transitioned.emit(&"walk")
