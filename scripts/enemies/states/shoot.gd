extends EnemyState
## Para, prepara e atira um projétil no jogador.
## Usa a animação "attack" como placeholder até existir uma animação de tiro.


var fired := false


func enter() -> void:
	enemy.velocity = Vector2.ZERO
	enemy.face(enemy.direction_to_target())
	enemy.sprite.play("attack")
	fired = false


func exit() -> void:
	enemy.start_shoot_cooldown()


func physics_update(_delta: float) -> void:
	if not fired and enemy.sprite.frame >= enemy.shoot_frame and enemy.has_target():
		fired = true
		enemy.shoot()
		Juice.burst(enemy.hurtbox.global_position, enemy.blood_color, 6,
			enemy.direction_to_target(), 30.0, 1.0, 80.0)

	if not enemy.sprite.is_playing():
		transitioned.emit(&"chase")
