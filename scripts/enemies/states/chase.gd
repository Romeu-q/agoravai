extends EnemyState
## Anda em direção ao jogador; ataca quando chega perto.


func enter() -> void:
	enemy.sprite.play("walk")


func physics_update(_delta: float) -> void:
	if enemy.can_attack and enemy.distance_to_target() <= enemy.attack_range:
		transitioned.emit(&"attack")
		return
	if enemy.wants_to_shoot():
		transitioned.emit(&"shoot")
		return

	var direction := enemy.direction_to_target()
	enemy.face(direction)
	enemy.velocity = direction * enemy.speed
	enemy.move_and_slide()
