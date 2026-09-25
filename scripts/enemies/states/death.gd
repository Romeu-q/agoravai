extends EnemyState
## Morre: explode em pedaços, "desteleporta" (animação de spawn ao contrário)
## e some da cena.


func enter() -> void:
	enemy.hurtbox.invincible = true
	enemy.hitbox.deactivate()
	# Tira o corpo das colisões para não bloquear os outros monstros.
	enemy.set_deferred("collision_layer", 0)

	enemy.velocity = enemy.knockback
	enemy.sprite.play_backwards("spawn")
	Juice.burst(enemy.hurtbox.global_position, Color.BLACK, 20)
	Juice.shake(0.3)


func physics_update(delta: float) -> void:
	enemy.apply_friction(delta)
	if not enemy.sprite.is_playing():
		enemy.queue_free()
