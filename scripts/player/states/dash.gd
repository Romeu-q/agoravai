extends PlayerState
## Dash: impulso rápido numa direção travada, invencível e com rastro neon.


## Receita das explosõezinhas de saída/chegada: só a paleta principal, pequenas e lentas.
const DASH_PUFF := {"weights_special": Vector3.ZERO, "speed_min": 30.0, "speed_max": 55.0,
	"size_max": 1, "white_time": 0.0}

var dash_direction := Vector2.ZERO
var time_left := 0.0


func enter() -> void:
	# Dash na direção das teclas; se estiver parado, para onde está virado.
	dash_direction = player.get_input_direction()
	if dash_direction == Vector2.ZERO:
		dash_direction = player.facing
	player.update_facing(dash_direction)

	time_left = player.dash_duration
	player.sprite.play("walk")
	player.set_dashing(true)   # i-frames: atravessa golpes durante o dash

	# O jogador "vira" o rastro: some durante o dash (sprite e sombra).
	player.sprite.visible = false
	player.get_node("Shadow").visible = false
	player.set_trail(true)

	Sound.play("dash")
	# Estilhaços na saída, para trás.
	Juice.neon_burst(player.global_position, 6, -dash_direction, 50.0, DASH_PUFF)


func exit() -> void:
	player.sprite.visible = true
	player.get_node("Shadow").visible = true
	player.set_trail(false)
	# Juice: reaparece com estilhaços para frente.
	Juice.neon_burst(player.global_position, 5, dash_direction, 60.0, DASH_PUFF)
	player.set_dashing(false)
	player.start_dash_cooldown()


func physics_update(delta: float) -> void:
	# Durante o dash o jogador NÃO controla a direção: é isso que dá o "impulso".
	player.velocity = dash_direction * player.dash_speed
	player.move_and_slide()

	time_left -= delta
	if time_left <= 0.0:
		if player.get_input_direction() == Vector2.ZERO:
			transitioned.emit(&"idle")
		else:
			transitioned.emit(&"walk")
