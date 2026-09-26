extends EnemyState
## Golpe corpo a corpo com INVESTIDA: nos frames ativos da animação, a Hitbox
## liga e o monstro avança na direção travada no aviso (enemy.attack_direction).
## Fora deles, freia. Depois vai para o Recover (fica vulnerável).


var hitbox_on := false


func enter() -> void:
	enemy.velocity = Vector2.ZERO
	# face() vira o sprite E o braço: a Hitbox tem o formato exato do respingo
	# do desenho (1:1), então ela espelha junto com o sprite.
	enemy.face(enemy.attack_direction)
	enemy.sprite.play("attack")
	hitbox_on = false


func exit() -> void:
	enemy.hitbox.deactivate()
	enemy.start_attack_cooldown()


func physics_update(delta: float) -> void:
	var active: bool = enemy.sprite.frame in enemy.attack_active_frames
	if active and not hitbox_on:
		enemy.hitbox.activate()
		enemy.velocity = enemy.attack_direction * enemy.lunge_speed   # o "bote"
	elif hitbox_on and not active:
		enemy.hitbox.deactivate()
	hitbox_on = active

	if not active:
		enemy.velocity = enemy.velocity.move_toward(Vector2.ZERO, enemy.friction * delta)
	enemy.move_and_slide()

	if not enemy.sprite.is_playing():
		transitioned.emit(&"recover")
