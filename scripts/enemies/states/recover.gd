extends EnemyState
## Depois de atacar, o monstro fica parado um instante, "recuperando o fôlego".
## É a JANELA DE PUNIÇÃO: quem desviou do golpe tem tempo de revidar.


var time_left := 0.0


func enter() -> void:
	time_left = enemy.recover_time
	enemy.sprite.play("walk")
	enemy.sprite.speed_scale = 0.4   # anda em câmera lenta: parece cansado


func exit() -> void:
	enemy.sprite.speed_scale = 1.0
	enemy.release_attack()


func physics_update(delta: float) -> void:
	enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.friction * delta)
	enemy.move_and_slide()
	time_left -= delta
	if time_left <= 0.0:
		transitioned.emit(&"chase")
