extends PlayerState
## Morreu: explode em pedaços, o tempo fica lento por um instante e aparece a
## tela de fim de jogo (GameOverScreen), com a wave alcançada e o recorde.


## Tempo REAL (segundos) entre a morte e a tela de fim de jogo.
const SCREEN_DELAY := 1.4


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.hurtbox.invincible = true
	player.sprite.visible = false
	player.get_node("Shadow").visible = false
	Juice.burst(player.hurtbox.global_position, Color("e8457a"), 30)
	Juice.neon_burst(player.hurtbox.global_position, 24)
	Juice.shake(0.8)
	Sound.play("death", 0.0)
	Juice.slow_motion(0.3)   # o momento da queda fica em câmera lenta

	# O último `true` (ignore_time_scale) conta em tempo REAL, apesar da câmera lenta.
	await get_tree().create_timer(SCREEN_DELAY, true, false, true).timeout
	Juice.slow_motion(1.0)
	var game := get_tree().current_scene as Game
	if game:
		game.game_over()
	else:
		get_tree().reload_current_scene()
