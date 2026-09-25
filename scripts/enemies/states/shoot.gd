extends EnemyState
## Atira: toca a animação "attack" e, no shoot_frame, solta a rajada mirando
## onde o jogador VAI estar (enemy.shoot() faz a previsão). Depois, Recover.


var fired := false


func enter() -> void:
	enemy.velocity = Vector2.ZERO
	enemy.face(enemy.direction_to_target())
	enemy.sprite.play("attack")
	fired = false


func exit() -> void:
	enemy.start_shoot_cooldown()


func physics_update(delta: float) -> void:
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.friction * delta)
	enemy.move_and_slide()

	if not fired and enemy.sprite.frame >= enemy.shoot_frame and enemy.has_target():
		fired = true
		enemy.shoot()
		# Coice: o tiro empurra o monstro um pouco para trás.
		enemy.velocity = -enemy.direction_to_target() * 60.0
		Juice.burst(enemy.hurtbox.global_position, enemy.blood_color, 6,
			enemy.direction_to_target(), 30.0, 1.0, 80.0)

	if not enemy.sprite.is_playing():
		transitioned.emit(&"recover")
