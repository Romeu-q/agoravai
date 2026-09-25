extends EnemyState
## Toca a animação de ataque; a Hitbox só fica ligada nos frames do golpe.


var hitbox_on := false


func enter() -> void:
	enemy.velocity = Vector2.ZERO
	enemy.face(enemy.direction_to_target())
	enemy.sprite.play("attack")
	hitbox_on = false


func exit() -> void:
	enemy.hitbox.deactivate()
	enemy.start_attack_cooldown()


func physics_update(_delta: float) -> void:
	var should_be_on: bool = enemy.sprite.frame in enemy.attack_active_frames
	if should_be_on and not hitbox_on:
		enemy.hitbox.activate()
	elif hitbox_on and not should_be_on:
		enemy.hitbox.deactivate()
	hitbox_on = should_be_on

	if not enemy.sprite.is_playing():
		transitioned.emit(&"chase")
