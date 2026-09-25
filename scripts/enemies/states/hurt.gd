extends EnemyState
## Tomou dano (ou teve o ataque aparado): é empurrado e fica atordoado.


var time_left := 0.0


func enter() -> void:
	enemy.velocity = enemy.knockback
	enemy.sprite.play("walk")
	enemy.sprite.pause()
	time_left = enemy.stun_time


func physics_update(delta: float) -> void:
	enemy.apply_friction(delta)
	time_left -= delta
	if time_left <= 0.0:
		transitioned.emit(&"chase")
