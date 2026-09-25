extends PlayerState
## Tomou dano: é empurrado, perde o controle por um instante e fica invencível.


const STUN_TIME := 0.2

var time_left := 0.0


func enter() -> void:
	player.sprite.play("idle")
	player.velocity = player.knockback
	player.start_recovery()
	time_left = STUN_TIME


func physics_update(delta: float) -> void:
	player.apply_friction(delta)
	time_left -= delta
	if time_left <= 0.0:
		transitioned.emit(&"idle")
