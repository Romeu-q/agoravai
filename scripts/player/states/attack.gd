extends PlayerState
## Ataque corpo a corpo na direção do mouse, com um pequeno avanço ("lunge").
## COMBO: clicando de novo, o próximo slash vai no sentido contrário (ida e volta).
## Dá para emendar ainda dentro do golpe (a partir de attack_chain_ratio) ou
## logo depois dele (dentro de attack_combo_window).


var aim := Vector2.ZERO
var duration := 0.0
var time_left := 0.0


func enter() -> void:
	# Veio de Idle/Walk: continua o combo se o último golpe acabou há pouco.
	_swing(player.combo_time_left > 0.0)


func exit() -> void:
	player.attack_area.deactivate()
	player.slash_effect.visible = false
	player.combo_time_left = player.attack_combo_window
	player.start_attack_cooldown()


func physics_update(delta: float) -> void:
	# Cancelamentos (como em Hyper Light Drifter): dash e parry cortam o golpe.
	if player.wants_to_dash():
		transitioned.emit(&"dash")
		return
	if player.wants_to_parry():
		transitioned.emit(&"parry")
		return

	var progress := 1.0 - time_left / duration

	# Emendar o próximo golpe do combo sem sair do estado.
	if progress >= player.attack_chain_ratio and player.wants_to_attack():
		_swing(true)
		return

	# O avanço começa forte e vai diminuindo até parar.
	player.velocity = aim * player.attack_lunge_speed * (1.0 - progress)
	player.move_and_slide()

	time_left -= delta
	if time_left <= 0.0:
		if player.get_input_direction() == Vector2.ZERO:
			transitioned.emit(&"idle")
		else:
			transitioned.emit(&"walk")


## Começa um golpe. `continue_combo` = inverte o sentido em relação ao anterior.
func _swing(continue_combo: bool) -> void:
	player.slash_flipped = (not player.slash_flipped) if continue_combo else false
	player.combo_time_left = 0.0

	aim = player.get_aim_direction()
	player.update_facing(aim)
	# stop() antes de play(): garante que a animação recomeça do frame 0.
	player.sprite.stop()
	player.sprite.play("attack")

	# Gira o "braço" (AttackPivot) para apontar para o mouse. Tudo o que é filho
	# dele (área de dano e efeito) gira junto.
	player.attack_pivot.rotation = aim.angle()
	player.attack_area.activate()

	# O ataque dura o mesmo tempo que a animação: se você mudar os frames ou a
	# velocidade no SpriteFrames, o golpe se ajusta sozinho.
	duration = player.get_animation_length("attack")
	time_left = duration

	# flip_v espelha o arco: o slash "volta" pelo caminho contrário.
	# O speed_scale faz o slash durar exatamente o mesmo tempo que o corpo.
	var slash_length := player.get_animation_length("slash", player.slash_effect)
	player.slash_effect.flip_v = player.slash_flipped
	player.slash_effect.speed_scale = slash_length / duration
	player.slash_effect.visible = true
	player.slash_effect.stop()
	player.slash_effect.play("slash")

	# Juice: o golpe de volta sacode um pouquinho mais.
	Juice.shake(0.08 if player.slash_flipped else 0.04)
