extends PlayerState
## Parry: por uma janela curta, golpes recebidos são aparados (Hurtbox.parrying).
## Cada parry certo ESTENDE a janela, então dá para rebater vários projéteis seguidos.
## Se nada chegar, sobra um tempo vulnerável: errar o parry tem que custar algo.


const PARRY_BURST := preload("res://resources/effects/parry_burst.tres")

var time_left := 0.0     # tempo total até sair do estado
var window_left := 0.0   # tempo restante em que golpes são aparados
var successes := 0


func enter() -> void:
	player.velocity = Vector2.ZERO
	# stop() antes: se der parry duas vezes seguidas, a postura recomeça do quadro 0.
	player.sprite.stop()
	player.sprite.play("parry")   # postura de guarda (assets/Player/Parrystance.png)
	successes = 0
	window_left = player.parry_window
	time_left = player.parry_duration
	_set_guard(true)

	# O estado só escuta o sinal enquanto está ativo (conecta aqui, desconecta no exit).
	player.hurtbox.parried.connect(_on_parried)
	# "Abriu a guarda": anelzinho rápido na cor do chifre.
	Juice.ring(player.hurtbox.global_position, player.horn_color, 9.0, 0.12)
	Sound.play("parry_open")


func exit() -> void:
	_set_guard(false)
	player.hurtbox.parried.disconnect(_on_parried)
	if successes > 0:
		player.can_parry = true   # recompensa: parry certo não tem cooldown
	else:
		player.start_parry_cooldown()


func physics_update(delta: float) -> void:
	window_left -= delta
	time_left -= delta

	# Acabou a janela: baixa a guarda. Agora está vulnerável.
	if window_left <= 0.0 and player.hurtbox.parrying:
		_set_guard(false)

	if time_left <= 0.0:
		transitioned.emit(&"idle")


func _set_guard(active: bool) -> void:
	player.hurtbox.parrying = active
	player.parry_stance.visible = active
	if active:
		player.parry_stance.play("default")
	player.set_glow(0.5 if active else 0.0)


func _on_parried(hitbox: Hitbox) -> void:
	successes += 1
	window_left = maxf(window_left, player.parry_extend_window)
	time_left = maxf(time_left, window_left + 0.1)
	_set_guard(true)

	# Golpe corpo a corpo atordoa quem atacou. Projétil é PEGO (fica parado no ar)
	# e no fim desta função vamos para o estado ParryThrow, onde o jogador mira.
	# `is` testa o tipo; `as` converte (vira null se não for daquele tipo).
	var projectile := hitbox as Projectile
	if projectile:
		projectile.catch(player.horn_color)
		player.caught_projectiles.append(projectile)
	else:
		var attacker := hitbox.owner as Enemy
		if attacker:
			attacker.get_parried(player.global_position)
	player.add_soul(player.parry_soul)

	# Juice: o PRIMEIRO parry é o momento épico; os seguintes são mais curtos
	# (senão rebater 5 projéteis congelaria o jogo por 1 segundo).
	var contact := player.hurtbox.global_position.lerp(hitbox.global_position, 0.5)
	var first := successes == 1
	Sound.play("parry" if first else "parry_open", 0.1)
	Juice.hitstop(0.18 if first else 0.05, 0.02)
	Juice.shake(0.35 if first else 0.15)
	if first:
		Juice.punch(0.12)
	# O sheet já vem colorido (neon): modulate BRANCO = cores originais.
	Juice.play_effect(PARRY_BURST, contact)
	# Estilhaços neon voando para longe do jogador, na direção do golpe aparado.
	Juice.neon_burst(contact, 10 if first else 6,
		contact.direction_to(hitbox.global_position), 60.0,
		{"weights_main": Vector3(1.0, 0.5, 1.5), "weights_special": Vector3(1.5, 1.5, 0.5)})

	if projectile:
		transitioned.emit(&"parrythrow")
